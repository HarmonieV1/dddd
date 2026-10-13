-- Véhicules de service : spawn SERVEUR (OneSync), un seul par joueur, supprimé en fin de service.
local Vehicles = {} -- [src] = entity
local Spawning = {} -- V12.37 · [src] = true le temps de la création (asynchrone) : un double clic ne sort pas deux véhicules

local function deleteVehicle(src)
    local veh = Vehicles[src]
    Vehicles[src] = nil
    Spawning[src] = nil -- V12.37
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

--- V12.37 · Métier actif + sa définition, ou nil + le message EXACT du refus (avant : « Tu dois être en service. » aussi bien
--- sans métier actif qu'au garage d'un autre métier). `jobName` = métier du point visé par le client (optionnel).
local function garageJob(src, jobName)
    local job, def = GSJ.activeJob(src)
    if not job or not def then return nil, L('no_active_job') end
    if type(jobName) == 'string' and jobName ~= job.name then return nil, L('wrong_job_garage', GSJ.jobLabel(jobName)) end
    if not job.onduty then return nil, L('not_on_duty') end
    return job, def
end

-- V12.37 : rate-limit 5 / 10 s (avant 3, partagé sortir + ranger : la 4e action en 10 s répondait « Doucement »)
lib.callback.register('gs_jobs:garage:spawn', function(src, garageIndex, vehicleIndex, jobName)
    if not GSJ.guard(src, 'garage', 5, 10000) then return false, L('slow_down') end
    local job, def = garageJob(src, jobName)
    if not job then return false, def end -- def = message du refus
    local garage = def.points.garage and def.points.garage[garageIndex]
    local vdef = def.vehicles and def.vehicles[vehicleIndex]
    if not garage or not vdef then return false, L('invalid') end
    if job.grade < (vdef.minGrade or 0) then return false, L('grade_too_low') end
    if not Security:InRange(src, garage.coords, Config.ZoneRadius + Config.ServerTolerance) then return false, L('too_far') end
    if Spawning[src] then return false, L('garage_busy') end -- V12.37 : sortie déjà en cours (double clic)
    if GSJ.getJobVehicle(src) then return false, L('vehicle_already_out') end
    if spawnBlocked(garage.spawn) then return false, L('spawn_blocked') end

    Spawning[src] = true
    local veh = spawnVehicle(vdef.model, garage.spawn, vdef.type)
    if not veh then
        Spawning[src] = nil
        return false, L('spawn_failed')
    end
    Vehicles[src] = veh
    Spawning[src] = nil -- le véhicule est suivi : un 2e appel répond « déjà un véhicule sorti »
    SetVehicleNumberPlateText(veh, makePlate(def.platePrefix))
    local state = Entity(veh).state
    state:set('gsJob', job.name, true)
    state:set('gsOwner', GSJ.cid(src), true)
    Bridge:GiveVehicleKeys(src, veh)
    Bridge:WarpIntoVehicle(src, veh) -- V12.26 : fiable (avant : un seul essai, souvent ignoré)
    DB.audit('vehicle_out', job.name, GSJ.cid(src), nil, nil, vdef.model)
    return true, L('vehicle_out')
end)

lib.callback.register('gs_jobs:garage:store', function(src, garageIndex, jobName)
    if not GSJ.guard(src, 'garage', 5, 10000) then return false, L('slow_down') end
    local job, def = garageJob(src, jobName) -- V12.37 : mêmes messages exacts qu'à la sortie
    if not job then return false, def end -- def = message du refus
    local garage = def.points.garage and def.points.garage[garageIndex]
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
