-- Options ox_target sur les véhicules pour les jobs qui ont des vehicleActions (mécano...).
local effects = {
    repair = function(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
    end,
    clean = function(veh)
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    end,
}

local function run(action, a, entity)
    local ok, res = lib.callback.await('gs_jobs:vehicle:start', false, action, VehToNet(entity))
    if not ok then return GSJ.result(false, res) end
    local done = lib.progressBar({
        duration = res, label = a.label, canCancel = true, anim = a.anim,
        disable = { move = true, car = true, combat = true },
    })
    if not done then return TriggerServerEvent('gs_jobs:server:vehicleCancel') end
    GSJ.result(lib.callback.await('gs_jobs:vehicle:finish', false))
end

CreateThread(function()
    local options = {}
    for name, def in pairs(Jobs) do
        for action, a in pairs(def.vehicleActions or {}) do
            options[#options + 1] = {
                name = ('gs_%s_%s'):format(name, action), icon = a.icon, label = a.label, distance = 3.0,
                -- pas de contrôle d'item ici (appelé à chaque frame en visée) : le serveur le fait.
                canInteract = function() return GSJ.isOnDuty(name) end,
                onSelect = function(data) run(action, a, data.entity) end,
            }
        end
    end
    if #options > 0 then exports.ox_target:addGlobalVehicle(options) end
end)

-- Appliqué par le client propriétaire réseau du véhicule, sur ordre du serveur.
RegisterNetEvent('gs_jobs:client:vehicleApply', function(netId, effect)
    local fn = effects[effect]
    if not fn or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetToVeh(netId)
    if veh ~= 0 and DoesEntityExist(veh) then fn(veh) end
end)
