-- gs_drugs (client) : zones de récolte / transformation, vente directe aux passants (ox_target, choix du produit,
-- échange animé), mode deal (/deal : des clients viennent à toi). Aucune boucle hors mode deal.
local offer
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

-- Vente directe à un PNJ -------------------------------------------------------------------------------------

local function handoff(ped)
    local me = PlayerPedId()
    lib.requestAnimDict('mp_common', 2000)
    TaskTurnPedToFaceEntity(me, ped, 800)
    if NetworkHasControlOfEntity(ped) then
        TaskTurnPedToFaceEntity(ped, me, 800)
        TaskPlayAnim(ped, 'mp_common', 'givetake1_b', 8.0, -8.0, 1500, 0, 0, false, false, false)
    end
    TaskPlayAnim(me, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 0, 0, false, false, false)
    Wait(1500)
    RemoveAnimDict('mp_common')
end

--- Produits vendables dans l'inventaire (un choix si plusieurs).
local function pickDrug()
    local have = {}
    for id, d in pairs(Config.Drugs) do
        local n = exports.gs_bridge:GetItemCount(d.sell.item)
        if n > 0 then have[#have + 1] = { id = id, label = ('%s (x%d)'):format(d.label, n) } end
    end
    if #have == 0 then return nil, 'Tu n\'as rien à vendre.' end
    if #have == 1 then return have[1].id end
    local opts = {}
    for _, h in ipairs(have) do opts[#opts + 1] = { value = h.id, label = h.label } end
    local r = lib.inputDialog('Que proposer ?', { { type = 'select', label = 'Produit', options = opts, required = true } })
    return r and r[1]
end

offer = function(ped)
    local netId = NetworkGetEntityIsNetworked(ped) and PedToNet(ped) or nil
    if not netId then return lib.notify({ description = 'Il n\'est pas intéressé.', type = 'error' }) end
    local drugId, err = pickDrug()
    if not drugId then return err and lib.notify({ description = err, type = 'error' }) end
    local ok, msg = lib.callback.await('gs_drugs:sell', false, netId, drugId)
    if ok then handoff(ped) end
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
    if ok or msg then
        SetPedKeepTask(ped, false)
        TaskWanderStandard(ped, 10.0, 10)
    end
end

-- Mode deal : les passants viennent à toi ----------------------------------------------------------------------
local dealing = false

local function findClient(me)
    local myPos = GetEntityCoords(me)
    local best, bestD
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, false)
            and IsPedHuman(ped) and NetworkGetEntityIsNetworked(ped) and not Entity(ped).state.gsSold then
            local d = #(GetEntityCoords(ped) - myPos)
            if d > 8.0 and d < Config.Deal.searchRadius and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    return best
end

RegisterCommand('deal', function()
    dealing = not dealing
    if not dealing then return lib.notify({ description = 'Mode deal : OFF', type = 'inform' }) end
    lib.notify({ title = 'Mode deal : ON', description = 'Reste dans le coin, des clients vont venir. Proposer = ox_target sur le client.', type = 'success' })
    CreateThread(function()
        while dealing do
            Wait(math.random(Config.Deal.interval[1], Config.Deal.interval[2]) * 1000)
            local me = PlayerPedId()
            if not dealing then break end
            if IsPedInAnyVehicle(me, false) or IsEntityDead(me) then
                dealing = false
                lib.notify({ description = 'Mode deal coupé.', type = 'inform' })
                break
            end
            local ped = findClient(me)
            if ped then
                NetworkRequestControlOfEntity(ped)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedKeepTask(ped, true)
                TaskGoToEntity(ped, me, -1, 1.5, 1.2, 1073741824, 0)
                lib.notify({ description = 'Un client s\'approche…', type = 'inform', icon = 'user-secret' })
                local deadline = GetGameTimer() + Config.Deal.wait * 1000
                while dealing and DoesEntityExist(ped) and GetGameTimer() < deadline do
                    if #(GetEntityCoords(ped) - GetEntityCoords(me)) < 2.0 then TaskTurnPedToFaceEntity(ped, me, -1) end
                    Wait(1000)
                end
                if DoesEntityExist(ped) then
                    SetBlockingOfNonTemporaryEvents(ped, false)
                    SetPedKeepTask(ped, false)
                    TaskWanderStandard(ped, 10.0, 10)
                end
            end
        end
    end)
end, false)

AddEventHandler('gs_drugs:client:act', function(id, stage)
    if stage == 'harvest' then act(id, 'harvest', 'Récolte…', { scenario = 'WORLD_HUMAN_GARDENER_PLANT' })
    else act(id, 'process', 'Préparation…', { dict = 'mp_arresting', clip = 'a_uncuff' }) end
end)

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
        -- [E] discret (aucun cercle : les spots restent secrets)
        for i, c in ipairs(d.harvest.points) do
            exports.gs_markers:Add(('gs_drugs:h:%s:%d'):format(id, i), { coords = c, style = 'hidden', ring = false, distance = 5.0,
                event = 'gs_drugs:client:act', args = { id, 'harvest' }, prompt = 'Récolter' })
        end
        local spots = { d.process.center }
        for _, c in ipairs((Config.Labs or {})[id] or {}) do spots[#spots + 1] = c end
        for i, c in ipairs(spots) do
            exports.gs_markers:Add(('gs_drugs:p:%s:%d'):format(id, i), { coords = c, style = 'hidden', ring = false, distance = 5.0,
                event = 'gs_drugs:client:act', args = { id, 'process' }, prompt = i == 1 and 'Préparer' or 'Préparer (labo ×2)' })
        end
    end

    exports.ox_target:addGlobalPed({ {
        name = 'gs_drug_sell', icon = 'fa-solid fa-handshake', label = 'Proposer quelque chose', distance = 2.0,
        canInteract = function(entity) return not IsPedAPlayer(entity) and not IsPedDeadOrDying(entity, true) and not IsPedInAnyVehicle(entity, false) end,
        onSelect = function(data) offer(data.entity) end,
    } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, z in ipairs(zones) do exports.ox_target:removeZone(z) end
    exports.gs_markers:RemovePrefix('gs_drugs:')
end)
