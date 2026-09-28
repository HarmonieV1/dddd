-- gs_drugs (client) : zones de récolte / transformation, option « Vendre » sur les passants (ox_target). 0 boucle.
local zones = {}

local function act(drugId, stage, label, anim)
    local ok, res = lib.callback.await('gs_drugs:begin', false, drugId, stage)
    if not ok then return lib.notify({ description = res, type = 'error' }) end
    if not lib.progressBar({ duration = res, label = label, canCancel = true, anim = anim,
        disable = { move = true, car = true, combat = true } }) then
        return TriggerServerEvent('gs_drugs:server:cancel')
    end
    local success, msg = lib.callback.await('gs_drugs:finish', false)
    lib.notify({ description = msg, type = success and 'success' or 'error' })
end

CreateThread(function()
    for id, d in pairs(Config.Drugs) do
        for i, c in ipairs(d.harvest.points) do
            zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = c, radius = 1.2, options = { {
                name = ('gs_drug_h_%s_%d'):format(id, i), icon = 'fa-solid fa-leaf', label = 'Récolter',
                onSelect = function() act(id, 'harvest', 'Récolte…', { scenario = 'WORLD_HUMAN_GARDENER_PLANT' }) end,
            } } })
        end
        zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = d.process.center, radius = 1.2, options = { {
            name = 'gs_drug_p_' .. id, icon = 'fa-solid fa-flask', label = 'Préparer',
            onSelect = function() act(id, 'process', 'Préparation…', { dict = 'mp_arresting', clip = 'a_uncuff' }) end,
        } } })
    end

    exports.ox_target:addGlobalPed({ {
        name = 'gs_drug_sell', icon = 'fa-solid fa-handshake', label = 'Proposer quelque chose', distance = 2.0,
        canInteract = function(entity) return not IsPedAPlayer(entity) and not IsPedDeadOrDying(entity, true) and not IsPedInAnyVehicle(entity, false) end,
        onSelect = function(data)
            local netId = NetworkGetEntityIsNetworked(data.entity) and PedToNet(data.entity) or nil
            if not netId then return lib.notify({ description = 'Il n\'est pas intéressé.', type = 'error' }) end
            local ok, msg = lib.callback.await('gs_drugs:sell', false, netId)
            lib.notify({ description = msg, type = ok and 'success' or 'error' })
        end,
    } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, z in ipairs(zones) do exports.ox_target:removeZone(z) end
end)
