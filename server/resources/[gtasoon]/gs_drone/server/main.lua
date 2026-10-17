-- gs_drone (serveur) · V12.64. Qui peut voler (police en service / gradé d'un gang avec l'objet), cooldown de recharge,
-- drones en vol (annoncés à tous pour pouvoir les abattre), tirs au but vérifiés (distance), marquage d'un suspect par la
-- police (collègues prévenus, position rafraîchie), radar de la police sur les drones de gang.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Drone = { flying = {}, byNet = {}, cooldowns = {}, marks = {}, nextMark = 0 } -- flying[src] = { kind, net, hits, untilAt }

local function started(r) return GetResourceState(r) == 'started' end
local function now() return os.time() end

local function legal(src)
    local job = Bridge:GetJob(src)
    return job and Config.LegalJobs[job.name] and job.onduty == true
end

local function copsOnDuty()
    local out = {}
    for _, s in ipairs(Bridge:GetPlayers()) do if legal(s) then out[#out + 1] = s end end
    return out
end

--- Peut-il faire voler ce drone ? Rend le type de drone ou nil, message
function Drone.allowed(src, kind)
    if kind == 'police' then
        if not legal(src) then return nil, 'Réservé à la police en service.' end
        return 'police'
    end
    if (Bridge:GetItemCount(src, Config.Item) or 0) < 1 then return nil, 'Il te faut un drone de repérage.' end
    local gang, grade
    if started('gs_gangs') then
        local ok, g, gr = pcall(function() return exports.gs_gangs:GetGang(src) end)
        if ok then gang, grade = g, gr end
    end
    if not gang then return nil, 'Ce drone modifié ne s\'apprend pas seul : il faut un gang derrière toi.' end
    if (tonumber(grade) or 0) < Config.Types.gang.minGrade then return nil, 'Les recrues ne touchent pas au drone : fais tes preuves d\'abord.' end
    return 'gang'
end

local function broadcast(net, on) TriggerClientEvent('gs_drone:client:airborne', -1, net, on) end

function Drone.land(src, why)
    local f = Drone.flying[src]
    if not f then return false end
    Drone.flying[src] = nil
    if f.net then Drone.byNet[f.net] = nil broadcast(f.net, false) end
    return true
end

lib.callback.register('gs_drone:launch', function(src, kind)
    if not Security:RateLimit(src, 'gs_drone:launch', 3, 10000) or not Bridge:IsLoaded(src) then return false, 'Doucement.' end
    if Drone.flying[src] then return false, 'Ton drone est déjà en l\'air.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule pour piloter.' end
    local k, err = Drone.allowed(src, kind == 'police' and 'police' or 'gang')
    if not k then return false, err end
    local T = Config.Types[k]
    local key = (Bridge:GetIdentifier(src) or src) .. ':' .. k
    local left = (Drone.cooldowns[key] or 0) - now()
    if left > 0 then return false, ('Batterie en charge : encore %d s.'):format(left) end
    Drone.cooldowns[key] = now() + T.battery + T.cooldown
    Drone.flying[src] = { kind = k, hits = 0, untilAt = now() + T.battery + 30 }
    Security:LogStaff(('[Drone] %s fait décoller un %s'):format(GetPlayerName(src) or src, T.label), k == 'police' and 'jobs' or 'jobs')
    -- Radar de la police : un drone de gang peut être repéré (zone floue, jamais l'identité)
    if k == 'gang' and math.random() < T.radar then
        local c = GetEntityCoords(GetPlayerPed(src))
        local a, r = math.random() * 2 * math.pi, math.random() * T.radarRadius * 0.6
        local zone = vec3(c.x + math.cos(a) * r, c.y + math.sin(a) * r, c.z)
        SetTimeout(20000, function()
            if not Drone.flying[src] then return end
            for _, cop in ipairs(copsOnDuty()) do TriggerClientEvent('gs_drone:client:radar', cop, zone, T.radarRadius) end
        end)
    end
    SetTimeout((T.battery + 30) * 1000, function() -- filet : vol trop long (joueur bloqué, client muet)
        local f = Drone.flying[src]
        if f and f.untilAt <= now() then Drone.land(src) end
    end)
    return true, { kind = k, label = T.label, range = T.range, battery = T.battery, speed = T.speed, thermal = T.thermal, mark = T.mark,
        model = Config.Model, maxHeight = Config.MaxHeight }
end)

--- Le drone est créé chez le pilote : son identifiant réseau, pour que tout le monde puisse le voir et l'abattre
lib.callback.register('gs_drone:spawned', function(src, net)
    if not Security:RateLimit(src, 'gs_drone:spawned', 3, 10000) then return false end
    local f = Drone.flying[src]
    net = math.tointeger(tonumber(net))
    if not f or f.net or not net then return false end
    local ent = NetworkGetEntityFromNetworkId(net)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > 15.0 then return false end
    f.net = net
    Drone.byNet[net] = src
    broadcast(net, true)
    return true
end)

RegisterNetEvent('gs_drone:server:land', function()
    if Security:RateLimit(source, 'gs_drone:land', 5, 10000) then Drone.land(source) end
end)

--- Tir au but (vu par le tireur, vérifié ici : drone en vol, tireur assez près, pas le pilote)
RegisterNetEvent('gs_drone:server:hit', function(net)
    local src = source
    if not Security:RateLimit(src, 'gs_drone:hit', 10, 5000) then return end
    net = math.tointeger(tonumber(net))
    local pilot = net and Drone.byNet[net]
    local f = pilot and Drone.flying[pilot]
    if not f or pilot == src then return end
    local ent = NetworkGetEntityFromNetworkId(net)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > Config.Shooter.radius then return end
    f.hits = f.hits + 1
    if f.hits < Config.HitPoints then return TriggerClientEvent('gs_drone:client:hurt', pilot, f.hits) end
    local kind = f.kind
    Drone.land(pilot)
    if kind == 'gang' then Bridge:RemoveItem(pilot, Config.Item, 1) end
    TriggerClientEvent('gs_drone:client:destroyed', pilot, kind == 'gang')
    Security:LogStaff(('[Drone] %s abat le drone de %s'):format(GetPlayerName(src) or src, GetPlayerName(pilot) or pilot), 'jobs')
end)

--- Police : suspect marqué depuis le drone. Le drone doit voler, le suspect doit être à portée du drone.
RegisterNetEvent('gs_drone:server:mark', function(target, droneAt)
    local src = source
    if not Security:RateLimit(src, 'gs_drone:mark', 3, 10000) then return end
    local f = Drone.flying[src]
    target = math.tointeger(tonumber(target))
    if not f or not Config.Types[f.kind].mark or not target or target == src or not GetPlayerName(target) then return end
    local ent = f.net and NetworkGetEntityFromNetworkId(f.net)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local dronePos = GetEntityCoords(ent)
    if #(GetEntityCoords(GetPlayerPed(target)) - dronePos) > Config.Mark.maxDistance then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'Trop loin du drone pour le suivre.', type = 'error' })
    end
    Drone.nextMark = Drone.nextMark + 1
    local id = Drone.nextMark
    Drone.marks[id] = { target = target, untilAt = now() + Config.Mark.seconds, by = src }
    Security:LogStaff(('[Drone] %s marque un suspect (%s) depuis le drone'):format(GetPlayerName(src) or src, GetPlayerName(target) or target), 'jobs')
    local function tick()
        local m = Drone.marks[id]
        if not m then return end
        local left = m.untilAt - now()
        local alive = GetPlayerName(m.target) ~= nil and left > 0
        local pos = alive and GetEntityCoords(GetPlayerPed(m.target)) or nil
        for _, cop in ipairs(copsOnDuty()) do TriggerClientEvent('gs_drone:client:mark', cop, id, pos, alive and left or 0) end
        if not alive then Drone.marks[id] = nil return end
        SetTimeout(Config.Mark.refresh * 1000, tick)
    end
    tick()
end)

AddEventHandler('playerDropped', function() Drone.land(source) end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Drone.land(src) end)

exports('IsFlying', function(src) return Drone.flying[src] ~= nil end)
