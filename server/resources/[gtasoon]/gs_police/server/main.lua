-- gs_police (serveur). Chaque action : métier en service → cible à portée → état de la cible → effet → journal.
-- États partagés (state bags joueur, écrits ici seulement) : gsCuffed, gsEscortedBy.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Police = { jailed = {}, objects = {}, escorting = {} } -- jailed[src] = { cid, untilTs } ; objects[src] = { entity... }

local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function online(src) return type(src) == 'number' and GetPlayerName(src) ~= nil end
local function label(src) return ('%s [%d]'):format(Bridge:GetName(src) or GetPlayerName(src) or '?', src) end
local function state(src) return Player(src).state end
local function need(v, msg) if not v then error({ msg = msg }, 0) end return v end

local function onDutyAs(src, job) return JobsApi:IsOnDutyAs(src, job) end
local function isPolice(src) return onDutyAs(src, Config.PoliceJob) end
local function isEms(src) return onDutyAs(src, Config.EmsJob) end
local function inRange(src, target, range)
    return Security:PlayersInRange(src, target, (range or Config.Range) + Config.Tolerance)
end

local function cuffed(t) return state(t).gsCuffed == true end
local function downed(t) return Bridge:IsDowned(t) end
local function handsUp(t) return state(t).gsHandsUp == true end

local function stopEscort(target)
    local by = state(target).gsEscortedBy
    if by then Police.escorting[by] = nil end
    state(target):set('gsEscortedBy', nil, true)
end

-- Prison RP -----------------------------------------------------------------------------------------------------

local function teleport(src, c)
    local ped = GetPlayerPed(src)
    if ped ~= 0 then SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false) if c.w then SetEntityHeading(ped, c.w) end end
end

function Police.jail(target, minutes, reason)
    local cid = Bridge:GetIdentifier(target)
    local untilTs = os.time() + minutes * 60
    Police.jailed[target] = { cid = cid, untilTs = untilTs }
    Store.jailSet(cid, untilTs, reason)
    stopEscort(target)
    state(target):set('gsCuffed', nil, true)
    teleport(target, Config.Jail.cell)
    TriggerClientEvent('gs_police:client:jail', target, untilTs - os.time(), reason)
end

function Police.release(target)
    local j = Police.jailed[target]
    if not j then return false end
    Police.jailed[target] = nil
    Store.jailClear(j.cid)
    teleport(target, Config.Jail.release)
    TriggerClientEvent('gs_police:client:jail', target, 0)
    notify(target, 'Tu as purgé ta peine. Tu es libre.', 'success')
    return true
end

function Police.jailTick()
    local now = os.time()
    for src, j in pairs(Police.jailed) do
        if now >= j.untilTs then Police.release(src)
        else
            local ped = GetPlayerPed(src)
            local c = Config.Jail.cell
            if ped ~= 0 and #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > Config.Jail.radius then teleport(src, c) end
        end
    end
end

-- Objets de voirie ------------------------------------------------------------------------------------------------

local function publishSpikes()
    local list = {}
    for _, objs in pairs(Police.objects) do
        for _, o in ipairs(objs) do
            if o.spikes and DoesEntityExist(o.entity) then
                local c = GetEntityCoords(o.entity)
                list[#list + 1] = { x = c.x, y = c.y, z = c.z }
            end
        end
    end
    GlobalState.gsSpikes = list
end

local function clearObjects(src)
    for _, o in ipairs(Police.objects[src] or {}) do if DoesEntityExist(o.entity) then DeleteEntity(o.entity) end end
    Police.objects[src] = nil
    publishSpikes()
end

-- Actions -----------------------------------------------------------------------------------------------------------
-- job : 'police' | 'ems' | 'both' ; target : cible joueur à portée requise

local Actions = {}

Actions.cuff = { job = 'police', target = true, run = function(src, target)
    need(Bridge:GetItemCount(src, Config.CuffItem) > 0, 'Il te faut des menottes.')
    local on = not cuffed(target)
    state(target):set('gsCuffed', on or nil, true)
    if not on then stopEscort(target) end
    notify(target, on and 'Tu es menotté.' or 'On t\'a retiré les menottes.', on and 'warning' or 'success')
    return on and 'Menotté' or 'Démenotté'
end }

Actions.escort = { job = 'both', target = true, run = function(src, target)
    if state(target).gsEscortedBy == src then stopEscort(target) return 'Escorte terminée' end
    need(cuffed(target) or downed(target), 'La personne doit être menottée ou à terre.')
    need(not Police.escorting[src], 'Tu escortes déjà quelqu\'un.')
    stopEscort(target)
    state(target):set('gsEscortedBy', src, true)
    Police.escorting[src] = target
    return 'Tu escortes ' .. label(target)
end }

Actions.putin = { job = 'both', target = true, run = function(src, target, data)
    need(cuffed(target) or downed(target), 'La personne doit être menottée ou à terre.')
    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    need(veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2, 'Aucun véhicule.')
    need(#(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) <= 8.0, 'Véhicule trop loin.')
    stopEscort(target)
    TriggerClientEvent('gs_police:client:putIn', target, data.netId)
    return 'Placé dans le véhicule'
end }

Actions.takeout = { job = 'both', target = true, range = 6.0, run = function(_, target)
    need(GetVehiclePedIsIn(GetPlayerPed(target), false) ~= 0, 'La personne n\'est pas dans un véhicule.')
    TriggerClientEvent('gs_police:client:takeOut', target)
    return 'Sorti du véhicule'
end }

Actions.search = { job = 'police', target = true, run = function(_, target)
    need(cuffed(target) or downed(target) or handsUp(target), 'Il faut qu\'elle soit menottée, à terre ou mains en l\'air.')
    return 'Fouille de ' .. label(target)
end }

Actions.jail = { job = 'police', target = true, run = function(src, target, data)
    local job = Bridge:GetJob(src)
    need(job.grade >= Config.Jail.minGrade, 'Grade insuffisant pour incarcérer.')
    need(cuffed(target), 'La personne doit être menottée.')
    local minutes = tonumber(data.minutes)
    need(minutes and minutes == math.floor(minutes) and minutes >= 1 and minutes <= Config.Jail.maxMinutes,
        ('Peine : 1 à %d min.'):format(Config.Jail.maxMinutes))
    local reason = need(Security:Sanitize(data.reason, 120), 'Motif obligatoire.')
    Police.jail(target, minutes, reason)
    Store.addRecord(Bridge:GetIdentifier(target), reason, 0, minutes, label(src))
    return ('Incarcéré %d min'):format(minutes)
end }

Actions.record = { job = 'police', target = true, run = function(src, target, data)
    local charge = need(Security:Sanitize(data.charge, 120), 'Infraction obligatoire.')
    local fine = math.floor(tonumber(data.fine) or 0)
    need(fine >= 0 and fine <= 100000, 'Montant invalide.')
    Store.addRecord(Bridge:GetIdentifier(target), charge, fine, 0, label(src))
    return 'Ajouté au casier'
end }

Actions.records = { job = 'police', target = true, run = function(_, target)
    return Store.records(Bridge:GetIdentifier(target))
end }

Actions.impound = { job = 'police', run = function(src, _, data)
    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    need(veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2, 'Aucun véhicule.')
    need(#(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) <= Config.Impound.range + Config.Tolerance, 'Trop loin.')
    need(GetPedInVehicleSeat(veh, -1) == 0, 'Quelqu\'un est au volant.')
    local plate = GetVehicleNumberPlateText(veh)
    DeleteEntity(veh)
    return ('Véhicule %s envoyé à la fourrière'):format(plate or '?')
end }

Actions.object = { job = 'police', run = function(src, _, data)
    local def = need(Config.Objects.list[data.kind], 'Objet inconnu.')
    local list = Police.objects[src] or {}
    need(#list < Config.Objects.max, ('Maximum %d objets posés.'):format(Config.Objects.max))
    local c = type(data.coords) == 'table' and tonumber(data.coords.x) and vec3(data.coords.x, data.coords.y, data.coords.z)
    need(c and #(c - GetEntityCoords(GetPlayerPed(src))) <= 4.0, 'Position invalide.')
    local ent = CreateObjectNoOffset(GetHashKey(def.model), c.x, c.y, c.z, true, true, false)
    need(ent and ent ~= 0, 'Création impossible.')
    FreezeEntityPosition(ent, true)
    SetEntityHeading(ent, tonumber(data.heading) or 0.0)
    list[#list + 1] = { entity = ent, spikes = def.spikes }
    Police.objects[src] = list
    if def.spikes then publishSpikes() end
    return def.label .. ' posé'
end }

Actions.clearobjects = { job = 'police', run = function(src)
    clearObjects(src)
    return 'Tes objets sont retirés'
end }

Actions.identity = { job = 'police', target = true, run = function(_, target)
    local ci = Bridge:GetCharInfo(target) or {}
    local lic = Bridge:GetLicences(target) or {}
    local heat = GetResourceState('gs_wanted') == 'started' and exports.gs_wanted:GetHeat(target) or 0
    return {
        name = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), birthdate = ci.birthdate, nationality = ci.nationality,
        driver = lic.driver == true, weapon = lic.weapon == true, records = #Store.records(Bridge:GetIdentifier(target)),
        wanted = heat > 0,
    }
end }

Actions.plate = { job = 'police', run = function(src, _, data)
    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    need(veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2, 'Aucun véhicule.')
    need(#(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) <= 25.0, 'Véhicule trop loin.')
    local plate = GetVehicleNumberPlateText(veh) or '?'
    return { plate = plate, owner = Bridge:GetVehicleOwner(plate) }
end }

Actions.breathalyzer = { job = 'police', target = true, run = function(_, target)
    local level = tonumber(state(target).gsDrunk) or 0
    return level
end }

Actions.backup = { job = 'police', run = function(src)
    need(Security:RateLimit(src, 'gs_police:backup', 1, 30000), 'Renforts déjà demandés, patiente.')
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do
        TriggerClientEvent('gs_police:client:backup', cop, { x = c.x, y = c.y, z = c.z }, Bridge:GetName(src) or GetPlayerName(src))
    end
    return 'Renforts demandés'
end }

Actions.revive = { job = 'ems', target = true, run = function(src, target)
    need(downed(target), 'La personne n\'est pas à terre.')
    need(Bridge:RemoveItem(src, Config.Revive.item, 1), 'Il te faut une trousse de secours.')
    Bridge:Revive(target)
    return 'Réanimé'
end }

Actions.heal = { job = 'both', target = true, run = function(src, target)
    need(not downed(target), 'À terre : il faut réanimer.')
    need(Bridge:RemoveItem(src, Config.Heal.item, 1), 'Il te faut un bandage.')
    TriggerClientEvent('gs_police:client:heal', target)
    return 'Soigné'
end }

function Police.run(src, name, target, data)
    local a = Actions[name]
    if not a then return false, 'Action inconnue.' end
    local ok = (a.job == 'police' and isPolice(src)) or (a.job == 'ems' and isEms(src))
        or (a.job == 'both' and (isPolice(src) or isEms(src)))
    if not ok then return false, 'Il faut être en service.' end
    data = type(data) == 'table' and data or {}
    target = tonumber(target)
    if a.target then
        if not online(target) or target == src then return false, 'Personne à portée.' end
        if not inRange(src, target, a.range) then return false, 'Trop loin.' end
    end
    local success, res = pcall(a.run, src, target, data)
    if not success then
        if type(res) == 'table' and res.msg then return false, res.msg end
        print(('[gs_police] erreur %s : %s'):format(name, tostring(res)))
        return false, 'Erreur interne.'
    end
    if name ~= 'records' and name ~= 'identity' and name ~= 'breathalyzer' then
        Security:LogStaff(('[Police] %s → %s %s'):format(label(src), name, a.target and label(target) or ''), 'jobs')
    end
    return true, res
end

lib.callback.register('gs_police:action', function(src, name, target, data)
    if not Security:RateLimit(src, 'gs_police:action', 10, 10000) then return false, 'Doucement.' end
    return Police.run(src, name, target, data)
end)

-- Anti-triche : un client peut écrire dans son propre state bag. gsCuffed / gsEscortedBy ne sont écrits QUE par ce
-- fichier ; toute autre modification (client qui se démenotte) est annulée et journalisée.
Police.authority = {} -- [src] = { gsCuffed = v, gsEscortedBy = v } : dernière valeur posée par le serveur

local rawState = state
state = function(src)
    local bag = rawState(src)
    return setmetatable({ set = function(_, key, value, replicated)
        if key == 'gsCuffed' or key == 'gsEscortedBy' then
            Police.authority[src] = Police.authority[src] or {}
            Police.authority[src][key] = value == nil and false or value
        end
        bag:set(key, value, replicated)
    end }, { __index = function(_, k) return bag[k] end })
end

for _, key in ipairs({ 'gsCuffed', 'gsEscortedBy' }) do
    AddStateBagChangeHandler(key, nil, function(bagName, _, value)
        local src = tonumber(bagName:match('^player:(%d+)$'))
        if not src then return end
        local auth = Police.authority[src] or {}
        local expected = auth[key]
        if expected == nil then expected = false end
        local got = value == nil and false or value
        if got ~= expected then
            SetTimeout(0, function() rawState(src):set(key, expected ~= false and expected or nil, true) end)
            Security:LogStaff(('[Anti-triche] %s a modifié %s lui-même (annulé)'):format(label(src), key))
        end
    end)
end

-- Cycle de vie ----------------------------------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local cid = Bridge:GetIdentifier(src)
    local j = cid and Store.jailGet(cid)
    if j and j.until_ts > os.time() then
        Police.jailed[src] = { cid = cid, untilTs = j.until_ts }
        teleport(src, Config.Jail.cell)
        TriggerClientEvent('gs_police:client:jail', src, j.until_ts - os.time(), j.reason)
    elseif j then Store.jailClear(cid) end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    clearObjects(src)
    local escorted = Police.escorting[src]
    if escorted and online(escorted) then stopEscort(escorted) end
    Police.escorting[src] = nil
    Police.jailed[src] = nil
    Police.authority[src] = nil
end)

CreateThread(function()
    Store.init()
    GlobalState.gsSpikes = {}
    while true do
        Wait(5000)
        Police.jailTick()
    end
end)

exports('IsCuffed', function(src) return cuffed(src) end)
exports('IsJailed', function(src) return Police.jailed[src] ~= nil end)
