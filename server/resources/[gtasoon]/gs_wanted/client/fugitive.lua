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

-- Avis de recherche placardés : visibles tant qu'il y a un fugitif
local function readPoster()
    local options = {}
    for _, f in ipairs(GlobalState.gsFugitives or {}) do
        options[#options + 1] = { title = f.title, icon = 'user-secret', iconColor = '#d0122f', readOnly = true,
            description = ('Prime : %d $ · %s'):format(f.bounty, f.desc ~= '' and f.desc or 'pas de description') }
    end
    if #options == 0 then options[1] = { title = 'Avis périmé.', readOnly = true } end
    lib.registerContext({ id = 'gs_wanted_poster', title = 'AVIS DE RECHERCHE', options = options })
    lib.showContext('gs_wanted_poster')
end
AddEventHandler('gs_wanted:client:poster', readPoster)

CreateThread(function()
    local shown = false
    while true do
        local active = #(GlobalState.gsFugitives or {}) > 0
        if active ~= shown then
            shown = active
            for i, c in ipairs(F.posters) do
                if active then exports.gs_markers:Add('gs_wanted:poster' .. i, { coords = c, style = 'hidden', event = 'gs_wanted:client:poster', prompt = 'Lire l\'avis de recherche', reach = 2.0 })
                else exports.gs_markers:Remove('gs_wanted:poster' .. i) end
            end
        end
        if active then
            local me, drew = GetEntityCoords(cache.ped), false
            for _, c in ipairs(F.posters) do
                if #(me - c) < 25.0 then
                    drew = true
                    local on, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.2)
                    if on then
                        SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline() SetTextColour(208, 18, 47, 240)
                        BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('AVIS DE RECHERCHE') EndTextCommandDisplayText(x, y)
                    end
                end
            end
            Wait(drew and 0 or 1500)
        else Wait(3000) end
    end
end)
