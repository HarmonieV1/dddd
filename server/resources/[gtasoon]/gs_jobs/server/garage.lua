-- Véhicules de service : spawn SERVEUR (OneSync), un seul par joueur, supprimé en fin de service.
local Vehicles = {} -- [src] = entity

local function deleteVehicle(src)
    local veh = Vehicles[src]
    Vehicles[src] = nil
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
end

function GSJ.getJobVehicle(src)
    local veh = Vehicles[src]
    if veh and DoesEntityExist(veh) then return veh end
    Vehicles[src] = nil
end

local function spawnBlocked(spawn)
    local pos = vec3(spawn.x, spawn.y, spawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - pos) < Config.Garage.clearRadius then return true end
    end
    return false
end

local function spawnVehicle(model, spawn, vtype)
    local veh = CreateVehicleServerSetter(GetHashKey(model), vtype or 'automobile', spawn.x, spawn.y, spawn.z, spawn.w)
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(veh) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return veh
end

local function makePlate(prefix)
    prefix = (prefix or 'GS'):sub(1, 4)
    return ('%s%0' .. (8 - #prefix) .. 'd'):format(prefix, math.random(0, 10 ^ (8 - #prefix) - 1))
end

lib.callback.register('gs_jobs:garage:spawn', function(src, garageIndex, vehicleIndex)
    if not GSJ.guard(src, 'garage', 3, 10000) then return false, L('slow_down') end
    local job, def = GSJ.activeJob(src)
    if not def or not job.onduty then return false, L('not_on_duty') end
    local garage = def.points.garage and def.points.garage[garageIndex]
    local vdef = def.vehicles and def.vehicles[vehicleIndex]
    if not garage or not vdef then return false, L('invalid') end
    if job.grade < (vdef.minGrade or 0) then return false, L('grade_too_low') end
    if not Security:InRange(src, garage.coords, Config.ZoneRadius + Config.ServerTolerance) then return false, L('too_far') end
    if GSJ.getJobVehicle(src) then return false, L('vehicle_already_out') end
    if spawnBlocked(garage.spawn) then return false, L('spawn_blocked') end

    local veh = spawnVehicle(vdef.model, garage.spawn, vdef.type)
    if not veh then return false, L('spawn_failed') end
    Vehicles[src] = veh
    SetVehicleNumberPlateText(veh, makePlate(def.platePrefix))
    local state = Entity(veh).state
    state:set('gsJob', job.name, true)
    state:set('gsOwner', GSJ.cid(src), true)
    Bridge:GiveVehicleKeys(src, veh)
    TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1)
    DB.audit('vehicle_out', job.name, GSJ.cid(src), nil, nil, vdef.model)
    return true, L('vehicle_out')
end)

lib.callback.register('gs_jobs:garage:store', function(src, garageIndex)
    if not GSJ.guard(src, 'garage', 3, 10000) then return false, L('slow_down') end
    local _, def = GSJ.activeJob(src)
    local garage = def and def.points.garage and def.points.garage[garageIndex]
    local veh = GSJ.getJobVehicle(src)
    if not garage then return false, L('invalid') end
    if not veh then return false, L('no_vehicle') end
    if not Security:InRange(src, garage.coords, Config.ZoneRadius + Config.ServerTolerance) then return false, L('too_far') end
    local s = garage.spawn
    if #(GetEntityCoords(veh) - vec3(s.x, s.y, s.z)) > Config.Garage.storeRadius then return false, L('vehicle_too_far') end
    deleteVehicle(src)
    return true, L('vehicle_stored')
end)

AddEventHandler('gs_jobs:internal:endService', deleteVehicle)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Vehicles) do deleteVehicle(src) end
end)
