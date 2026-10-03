-- gs_police (serveur) · V8 « Prison vivante » : boulots (peine réduite + tickets), cantine, trafiquant, évasion à plusieurs.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local P = Config.Prison

Prison = { lastJob = {}, lastEscape = 0 }

local function near(src, c, r)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) <= r
end

local function gameHour()
    if GetResourceState('gs_weather') ~= 'started' then return 12 end
    local ok, h = pcall(function() return exports.gs_weather:GetGameTime() end)
    return ok and h or 12
end

--- Petit boulot : réduit la peine et rapporte des tickets de cantine
function Prison.work(src, i)
    local j, job = Police.jailed[src], P.jobs[tonumber(i) or 0]
    if not j then return false, 'Tu n\'es pas détenu.' end
    if not job or not near(src, job.coords, 4.0) then return false, 'Pas ici.' end
    local now = os.time()
    if (Prison.lastJob[src] or 0) + P.jobCooldown > now then return false, 'Le surveillant te dit de souffler un peu.' end
    Prison.lastJob[src] = now
    j.untilTs = math.max(now + P.minLeft, j.untilTs - job.reduce)
    Store.jailSet(j.cid, j.untilTs, 'peine réduite (travail)')
    TriggerClientEvent('gs_police:client:jail', src, j.untilTs - now)
    Bridge:AddItem(src, P.ticket, job.tickets)
    return true, ('Peine réduite de %d s · +%d ticket(s) de cantine'):format(job.reduce, job.tickets)
end

--- Cantine (tickets) et trafiquant (tickets + cigarettes)
function Prison.buy(src, shop, i)
    if not Police.jailed[src] then return false, 'Réservé aux détenus.' end
    local def = shop == 'dealer' and P.dealer or P.canteen
    local art = def.items[tonumber(i) or 0]
    if not art or not near(src, def.coords, 4.0) then return false, 'Pas ici.' end
    if Bridge:GetItemCount(src, P.ticket) < art.price then return false, 'Pas assez de tickets.' end
    if art.cigarettes and Bridge:GetItemCount(src, 'gs_cigarettes') < art.cigarettes then return false, ('Il veut aussi %d paquet(s) de cigarettes.'):format(art.cigarettes) end
    if not Bridge:CanCarry(src, art.item, 1) then return false, 'Tu ne peux pas le cacher sur toi.' end
    Bridge:RemoveItem(src, P.ticket, art.price)
    if art.cigarettes then Bridge:RemoveItem(src, 'gs_cigarettes', art.cigarettes) end
    Bridge:AddItem(src, art.item, 1)
    return true, shop == 'dealer' and 'Marché conclu. Tu ne m\'as jamais vu.' or 'Servi.'
end

--- Évasion : à plusieurs (détenus au point de fuite), la nuit, avec des outils de fortune. Tous ceux présents partent.
function Prison.escape(src)
    local E = P.escape
    if not Police.jailed[src] then return false, 'Tu n\'es pas détenu.' end
    if not near(src, E.coords, E.radius) then return false, 'Pas par ici.' end
    local h = gameHour()
    if not (h >= E.nightFrom or h < E.nightTo) then return false, 'En plein jour ? Les miradors te verraient.' end
    if os.time() - Prison.lastEscape < E.cooldown then return false, 'La surveillance est renforcée depuis la dernière évasion.' end
    if Bridge:GetItemCount(src, P.tools) < 1 then return false, 'Il faut des outils de fortune pour la grille.' end
    local crew = {}
    for s in pairs(Police.jailed) do if near(s, E.coords, E.radius) then crew[#crew + 1] = s end end
    if #crew < E.min then return false, ('Impossible seul : il faut être au moins %d détenus ici.'):format(E.min) end
    Bridge:RemoveItem(src, P.tools, 1)
    Prison.lastEscape = os.time()
    for i, s in ipairs(crew) do
        local j = Police.jailed[s]
        Police.jailed[s] = nil
        Store.jailClear(j.cid)
        local ped = GetPlayerPed(s)
        if ped ~= 0 then SetEntityCoords(ped, E.out.x + i * 1.5, E.out.y, E.out.z, false, false, false, false) end
        TriggerClientEvent('gs_police:client:jail', s, 0)
        Bridge:Notify(s, 'Évasion ! Cours, ne te retourne pas.', 'warning')
        if GetResourceState('gs_wanted') == 'started' then
            pcall(function() exports.gs_wanted:AddHeat(s, 60) end)
        end
    end
    if GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('flash', ('Évasion à Bolingbroke : %d détenus en fuite.'):format(#crew)) end)
    end
    for _, cop in ipairs(exports.gs_jobs:GetOnDutyPlayers(Config.PoliceJob)) do
        TriggerClientEvent('gs_police:client:backup', cop, { x = E.coords.x, y = E.coords.y, z = E.coords.z }, 'ALERTE ÉVASION Bolingbroke')
    end
    Security:LogStaff(('[Prison] évasion de %d détenus (lancée par %s)'):format(#crew, GetPlayerName(src) or src), 'jobs')
    return true, ('Grille découpée : %d détenus s\'évadent.'):format(#crew)
end

lib.callback.register('gs_police:prisonWork', function(src, i)
    if not Security:RateLimit(src, 'gs_police:prisonWork', 2, 5000) then return false, 'Doucement.' end
    return Prison.work(src, i)
end)
lib.callback.register('gs_police:prisonBuy', function(src, shop, i)
    if not Security:RateLimit(src, 'gs_police:prisonBuy', 4, 5000) then return false, 'Doucement.' end
    return Prison.buy(src, shop, i)
end)
lib.callback.register('gs_police:prisonEscape', function(src)
    if not Security:RateLimit(src, 'gs_police:prisonEscape', 1, 10000) then return false, 'Doucement.' end
    return Prison.escape(src)
end)

-- Arrivée en prison : rappel des possibilités
AddEventHandler('gs_police:server:jailed', function(target)
    Bridge:Notify(target, 'Bolingbroke : petits boulots (peine réduite), cantine, trafics… et pour les plus audacieux, la grille.', 'inform')
end)
AddEventHandler('playerDropped', function() Prison.lastJob[source] = nil end)
