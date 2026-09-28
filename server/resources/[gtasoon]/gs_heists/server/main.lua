-- gs_heists (serveur). Une action = 2 temps : begin (contrôles) → barre de progression → finish (durée réelle
-- vérifiée, butin). Tout ce qui touche au butin est calculé ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local WantedApi = exports.gs_wanted

Heists = { sessions = {}, cooldowns = {}, pending = {} }

local UNARMED = GetHashKey('WEAPON_UNARMED')
local function started(res) return GetResourceState(res) == 'started' end
local function now() return os.time() end

local function near(src, coords, radius)
    return Security:InRange(src, coords, radius + Config.Tolerance)
end

function Heists.policeCount()
    return #JobsApi:GetOnDutyPlayers(Config.PoliceJob)
end

--- Multiplicateur de butin : nuit, événement météo, lien de duo, territoire de son gang.
function Heists.multiplier(src, site)
    local m = 1.0
    if started('gs_weather') then
        local hour = exports.gs_weather:GetGameTime()
        if hour >= 22 or hour < 5 then m = m * Config.Bonus.night end
        if exports.gs_weather:GetEvent() then m = m * Config.Bonus.weatherEvent end
    end
    if started('gs_duo') then m = m * exports.gs_duo:GetPayBonus(src, Config.DuoRadius) end
    if started('gs_gangs') then
        local gang = exports.gs_gangs:GetGang(src)
        local zone = exports.gs_gangs:GetTerritoryAt(site.center)
        if gang and zone then
            if exports.gs_gangs:GetTerritoryOwner(zone) == gang then m = m * Config.Bonus.ownTerritory end
            exports.gs_gangs:AddInfluence(gang, zone, Config.Bonus.influence)
        end
    end
    return m
end

local function giveLoot(src, amount)
    if Config.DirtyItem and Bridge:ItemExists(Config.DirtyItem) and Bridge:AddItem(src, Config.DirtyItem, amount) then
        return ('%d $ en argent sale'):format(amount)
    end
    Bridge:AddMoney(src, 'cash', amount, 'braquage')
    return ('%d $'):format(amount)
end

local function endSession(id)
    Heists.sessions[id] = nil
    Heists.cooldowns[id] = now() + Config.Sites[id].cooldown
end

--- Début d'une action de pillage. Retourne ok, durée|message.
lib.callback.register('gs_heists:begin', function(src, id, point)
    if not Security:RateLimit(src, 'gs_heists:begin', 5, 10000) then return false, 'Doucement.' end
    local site = Config.Sites[id]
    point = tonumber(point)
    local coords = site and point and site.points[point]
    if not coords then return false, 'Invalide.' end
    if not near(src, coords, 1.5) then return false, 'Trop loin.' end
    if Heists.pending[src] then return false, 'Déjà en train de piller.' end
    if JobsApi:IsOnDutyAs(src, Config.PoliceJob) then return false, 'Pas en service de police.' end
    local ped = GetPlayerPed(src)
    if GetSelectedPedWeapon(ped) == UNARMED then return false, 'Il te faut une arme en main.' end

    local session = Heists.sessions[id]
    if session and now() - session.startedAt > Config.SessionTimeout then
        endSession(id)
        session = nil
    end
    if not session then
        if (Heists.cooldowns[id] or 0) > now() then return false, 'Déjà braqué récemment : l\'endroit est sous surveillance.' end
        if Heists.policeCount() < site.minPolice then
            return false, ('Pas assez de policiers en ville (%d requis).'):format(site.minPolice)
        end
        session = { startedAt = now(), done = {} }
        Heists.sessions[id] = session
        -- Alarme silencieuse (sinon : signalement selon les témoins, l'heure, la météo)
        local alarm = math.random() < site.alarmChance
        WantedApi:ReportCrime(src, site.crime, site.center, { alarm = alarm })
        Security:LogStaff(('[Braquage] %s commence %s (alarme : %s)'):format(GetPlayerName(src), site.label, alarm and 'oui' or 'non'), 'jobs')
    end
    if session.done[point] then return false, 'Déjà vidé.' end
    Heists.pending[src] = { id = id, point = point, doneAt = GetGameTimer() + site.action - 750 }
    return true, site.action
end)

lib.callback.register('gs_heists:finish', function(src)
    if not Security:RateLimit(src, 'gs_heists:finish', 5, 10000) then return false, 'Doucement.' end
    local p = Heists.pending[src]
    Heists.pending[src] = nil
    if not p or GetGameTimer() < p.doneAt then return false, 'Interrompu.' end
    local site, session = Config.Sites[p.id], Heists.sessions[p.id]
    if not session or session.done[p.point] then return false, 'Trop tard.' end
    if not near(src, site.points[p.point], 1.5) then return false, 'Tu t\'es éloigné.' end
    session.done[p.point] = true

    local amount = math.floor(math.random(site.reward[1], site.reward[2]) * Heists.multiplier(src, site))
    local loot = giveLoot(src, amount)
    local remaining = 0
    for i in ipairs(site.points) do if not session.done[i] then remaining = remaining + 1 end end
    if remaining == 0 then endSession(p.id) end
    return true, ('Butin : %s%s'):format(loot, remaining > 0 and (' · encore %d'):format(remaining) or ' · tout est vidé, file !')
end)

RegisterNetEvent('gs_heists:server:cancel', function()
    if Security:RateLimit(source, 'gs_heists:cancel', 5, 10000) then Heists.pending[source] = nil end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Heists.pending[src] = nil end)

lib.addCommand('braquages', { help = 'État des braquages (staff)', restricted = 'group.admin' }, function(src)
    local lines = { ('Policiers en service : %d'):format(Heists.policeCount()) }
    for id, site in pairs(Config.Sites) do
        local cd = (Heists.cooldowns[id] or 0) - now()
        lines[#lines + 1] = ('%s : %s'):format(site.label, Heists.sessions[id] and 'EN COURS' or (cd > 0 and ('cooldown %d min'):format(math.ceil(cd / 60)) or 'disponible'))
    end
    local text = table.concat(lines, ' | ')
    if src == 0 then print(text) else TriggerClientEvent('ox_lib:notify', src, { description = text, duration = 15000 }) end
end)

exports('ResetCooldown', function(id) Heists.cooldowns[id] = nil return true end)
