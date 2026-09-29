-- Actions sur véhicule (réparer, nettoyer...) en 2 temps : start (contrôles) → barre de progression → finish.
-- Le serveur vérifie la durée réelle écoulée : impossible de sauter la barre de progression.
local Pending = {} -- [src] = { action, job, veh, doneAt }

local function actionDef(job, action)
    local def = Jobs[job]
    return def and def.vehicleActions and def.vehicleActions[action]
end

lib.callback.register('gs_jobs:vehicle:start', function(src, action, netId)
    if not GSJ.guard(src, 'veh_action', 5, 10000) then return false, L('slow_down') end
    local job = Bridge:GetJob(src)
    local adef = job and actionDef(job.name, action)
    if not adef or not job.onduty then return false, L('not_on_duty') end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, L('invalid') end
    if not Security:EntityInRange(src, veh, 5.0) then return false, L('too_far') end
    if adef.item and Bridge:GetItemCount(src, adef.item) < 1 then
        return false, L('missing_item', adef.itemLabel or adef.item)
    end
    Pending[src] = { action = action, job = job.name, veh = veh, doneAt = GetGameTimer() + adef.duration - 750 }
    return true, adef.duration
end)

lib.callback.register('gs_jobs:vehicle:finish', function(src)
    if not Security:RateLimit(src, 'gs_jobs:veh_finish', 5, 10000) then return false, L('slow_down') end
    local p = Pending[src]
    Pending[src] = nil
    if not p or GetGameTimer() < p.doneAt then return false, L('invalid') end
    local job = Bridge:GetJob(src)
    if not job or job.name ~= p.job or not job.onduty then return false, L('not_on_duty') end
    if not Security:EntityInRange(src, p.veh, 6.0) then return false, L('too_far') end
    local adef = actionDef(p.job, p.action)
    if adef.item and not Bridge:RemoveItem(src, adef.item, 1) then
        return false, L('missing_item', adef.itemLabel or adef.item)
    end
    -- L'effet est appliqué par le client propriétaire réseau de l'entité (sinon il ne se synchronise pas).
    local owner = NetworkGetEntityOwner(p.veh)
    TriggerClientEvent('gs_jobs:client:vehicleApply', (owner and owner > 0) and owner or src,
        NetworkGetNetworkIdFromEntity(p.veh), adef.effect)
    DB.audit('veh_' .. p.action, p.job, GSJ.cid(src), nil, nil, GetVehicleNumberPlateText(p.veh))
    return true, L('action_done')
end)

-- Double des clés d'un véhicule de service : même métier, en service, plaque du métier, à côté du véhicule.
lib.callback.register('gs_jobs:vehicle:keys', function(src, netId)
    if not GSJ.guard(src, 'veh_keys', 5, 10000) then return false, L('slow_down') end
    local job = Bridge:GetJob(src)
    local def = job and Jobs[job.name]
    if not def or not def.platePrefix or not job.onduty then return false, L('not_on_duty') end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, L('invalid') end
    if not Security:EntityInRange(src, veh, 5.0) then return false, L('too_far') end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', '')
    if plate:sub(1, #def.platePrefix) ~= def.platePrefix then return false, 'Ce n\'est pas un véhicule de ton service.' end
    Bridge:GiveVehicleKeys(src, veh)
    DB.audit('veh_keys', job.name, GSJ.cid(src), nil, nil, plate)
    return true, 'Clés récupérées.'
end)

RegisterNetEvent('gs_jobs:server:vehicleCancel', function()
    if Security:RateLimit(source, 'gs_jobs:veh_cancel', 5, 10000) then Pending[source] = nil end
end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Pending[src] = nil end)
