-- gs_wanted (client) · V9 « La cavale » : /cavale (à 5 étoiles), avis de recherche placardés en ville, /livrer
-- (chasseur de primes : fugitif à terre devant un commissariat), /legendes.
local F = Config.Fugitive
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 8000 }) end end
local function call(action, arg) return lib.callback.await('gs_wanted:fugitive', false, action, arg) end

RegisterCommand('cavale', function()
    if lib.alertDialog({ header = 'Entrer en cavale ?', content = ('Avis de recherche dans toute la ville, prime sur ta tête. Tiens %d h de jeu sans te faire prendre et tu deviens une légende.'):format(F.hours),
        centered = true, cancel = true, labels = { confirm = 'Je pars en cavale', cancel = 'Non' } }) ~= 'confirm' then return end
    notify(call('start'))
end, false)

RegisterCommand('livrer', function()
    local me, best, bestD = GetEntityCoords(cache.ped), nil, 5.0
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - me)
            if d < bestD then best, bestD = pid, d end
        end
    end
    if not best then return notify(false, 'Personne à portée.') end
    notify(call('claim', GetPlayerServerId(best)))
end, false)

RegisterCommand('legendes', function()
    local ok, list = call('legends')
    if not ok then return end
    local options = {}
    for _, l in ipairs(list or {}) do
        options[#options + 1] = { title = l.name, icon = 'crown', iconColor = '#ffd23f', readOnly = true,
            description = ('Cavale de %d h tenue · %s'):format(l.hours or F.hours, l.date or '') }
    end
    if #options == 0 then options[1] = { title = 'Personne… pour l\'instant.', icon = 'crown', readOnly = true } end
    lib.registerContext({ id = 'gs_legends', title = 'Légendes de Los Santos', options = options })
    lib.showContext('gs_legends')
end, false)

RegisterNetEvent('gs_wanted:client:fugitive', function(title, bounty)
    lib.notify({ title = 'AVIS DE RECHERCHE', description = ('%s · prime %d $ · /livrer s\'il est à terre devant un commissariat'):format(title, bounty),
        type = 'error', icon = 'user-secret', duration = 12000 })
end)

-- Proposer la cavale quand on atteint 5 étoiles
local offered = false
AddEventHandler('gs_wanted:client:heatChanged', function(heat)
    if heat > F.minHeat and not offered then
        offered = true
        lib.notify({ title = '5 étoiles', description = 'Tu peux tenter la cavale : /cavale', type = 'warning', icon = 'person-running', duration = 10000 })
    elseif heat <= F.minHeat then offered = false end
end)

-- Avis de recherche placardés : visibles tant qu'il y a un fugitif. V12.63 (n° 149) : une affiche aussi là où la cavale a
-- commencé ; chaque affiche peut être arrachée (amende pour un civil, gratuit pour la police), recollée 30 min plus tard.
local function readPoster(key)
    local options = {}
    for _, f in ipairs(GlobalState.gsFugitives or {}) do
        options[#options + 1] = { title = f.title, icon = 'user-secret', iconColor = '#d0122f', readOnly = true,
            description = ('Prime : %d $ · %s'):format(f.bounty, f.desc ~= '' and f.desc or 'pas de description') }
    end
    if #options == 0 then options[1] = { title = 'Avis périmé.', readOnly = true } end
    if key then
        options[#options + 1] = { title = 'Arracher l\'affiche', icon = 'hand', iconColor = '#999999',
            description = ('Amende de %d $ (gratuit pour la police en service)'):format(F.tearFine or 300),
            onSelect = function() notify(call('tear', key)) end }
    end
    lib.registerContext({ id = 'gs_wanted_poster', title = 'AVIS DE RECHERCHE', options = options })
    lib.showContext('gs_wanted_poster')
end
AddEventHandler('gs_wanted:client:poster', readPoster)

--- V12.63 (backtest : « pas réaliste, grosse écriture rouge ») : une petite affiche papier (fond crème, texte sombre), à hauteur
--- d'yeux, lisible de près seulement, de plus en plus petite avec la distance. Affiche « sur place » = ce fugitif ; affiche fixe =
--- la plus grosse prime (+ le nombre d'autres).
local function posterText(key)
    local list = GlobalState.gsFugitives or {}
    local id = math.tointeger(tonumber(key:match('^s(%d+)$')))
    local pick, others = nil, 0
    for _, f in ipairs(list) do
        if id then if f.id == id then pick = f end
        else
            if not pick or (f.bounty or 0) > (pick.bounty or 0) then pick = f end
        end
    end
    if not id then others = math.max(0, #list - 1) end
    return pick, others
end

local function text(str, x, y, scale, r, g, b, font)
    SetTextFont(font or 4) SetTextScale(0.0, scale) SetTextCentre(true) SetTextColour(r, g, b, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(str) EndTextCommandDisplayText(x, y)
end

local function drawPoster(key, c, d)
    local f, others = posterText(key)
    if not f then return end
    local on, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 0.55)
    if not on then return end
    local s = math.max(0.45, math.min(1.0, 4.0 / math.max(d, 0.1)))
    local w, h = 0.085 * s, 0.092 * s
    DrawRect(x, y + h * 0.42, w + 0.003 * s, h + 0.003 * s, 60, 50, 40, 200)   -- bord
    DrawRect(x, y + h * 0.42, w, h, 236, 226, 200, 235)                         -- papier
    text('RECHERCHÉ', x, y - h * 0.02, 0.48 * s, 25, 22, 20, 4)
    text(f.title or 'Fugitif', x, y + h * 0.30, 0.30 * s, 40, 36, 32, 4)
    text(('Prime : %d $'):format(f.bounty or 0), x, y + h * 0.52, 0.30 * s, 110, 22, 22, 4)
    if others > 0 then text(('+ %d autre%s'):format(others, others > 1 and 's' or ''), x, y + h * 0.72, 0.24 * s, 70, 64, 58, 4) end
end

--- Affiches à afficher maintenant : { [clé] = position } (fixes + sur place, moins celles arrachées)
local function postersNow()
    local list, out, torn = GlobalState.gsFugitives or {}, {}, GlobalState.gsPostersTorn or {}
    if #list == 0 then return out end
    for i, c in ipairs(F.posters) do if not torn['p' .. i] then out['p' .. i] = c end end
    for _, f in ipairs(list) do
        if f.at and not torn['s' .. f.id] then out['s' .. f.id] = vec3(f.at.x + 0.0, f.at.y + 0.0, f.at.z + 0.0) end
    end
    return out
end

CreateThread(function()
    local placed = {} -- [clé] = position déclarée à gs_markers
    while true do
        local want = postersNow()
        for key in pairs(placed) do if not want[key] then exports.gs_markers:Remove('gs_wanted:poster:' .. key) placed[key] = nil end end
        for key, c in pairs(want) do
            if not placed[key] or #(placed[key] - c) > 0.5 then
                exports.gs_markers:Add('gs_wanted:poster:' .. key, { coords = c, style = 'hidden', event = 'gs_wanted:client:poster', args = { key }, prompt = 'Lire l\'avis de recherche', reach = 2.0 })
                placed[key] = c
            end
        end
        if next(want) then
            local untilT = GetGameTimer() + 3000
            repeat -- affiche dessinée seulement de près ; la liste est relue toutes les 3 s (une affiche arrachée disparaît)
                local drew = false
                local me = GetEntityCoords(cache.ped)
                for key, c in pairs(want) do
                    local d = #(me - c)
                    if d < 12.0 and not (GlobalState.gsPostersTorn or {})[key] then
                        drew = true
                        drawPoster(key, c, d)
                    end
                end
                Wait(drew and 0 or 1000)
            until GetGameTimer() >= untilT
        else Wait(3000) end
    end
end)

-- V12.63 · Mur des légendes (proposition n° 163) : devant le commissariat, la liste des légendes de la cavale ; le dernier nom
-- est écrit au-dessus du mur (liste relue au plus toutes les 5 min, seulement quand on passe à côté).
local wall = { at = 0, last = nil }
local function showLegends()
    local ok, list = call('legends')
    if not ok then return end
    local options = {}
    for _, l in ipairs(list or {}) do
        options[#options + 1] = { title = l.name, icon = 'crown', iconColor = '#ffd23f', readOnly = true,
            description = ('Cavale de %d h tenue · %s'):format(l.hours or F.hours, l.date or '') }
    end
    if #options == 0 then options[1] = { title = 'Personne… pour l\'instant. Tiens une cavale et ton nom sera gravé ici.', icon = 'crown', readOnly = true } end
    lib.registerContext({ id = 'gs_legends', title = 'Mur des légendes de Los Santos', options = options })
    lib.showContext('gs_legends')
end
AddEventHandler('gs_wanted:client:legendWall', showLegends)
CreateThread(function()
    if not F.legendWall then return end
    exports.gs_markers:Add('gs_wanted:legendwall', { coords = F.legendWall, style = 'hidden', event = 'gs_wanted:client:legendWall', prompt = 'Mur des légendes', reach = 2.5 })
    while true do
        local c = F.legendWall
        local d = #(GetEntityCoords(cache.ped) - c)
        if d < 20.0 then
            if GetGameTimer() - wall.at > 300000 then
                wall.at = GetGameTimer()
                local ok, list = call('legends')
                wall.last = ok and list and list[1] and list[1].name or false
            end
            local on, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.4)
            if on then
                SetTextFont(4) SetTextScale(0.0, 0.55) SetTextCentre(true) SetTextOutline() SetTextColour(255, 210, 63, 240)
                BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('MUR DES LÉGENDES') EndTextCommandDisplayText(x, y)
                if wall.last then
                    SetTextFont(4) SetTextScale(0.0, 0.38) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 220)
                    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('Dernière légende : ' .. wall.last) EndTextCommandDisplayText(x, y + 0.03)
                end
            end
            Wait(0)
        else Wait(1500) end
    end
end)
