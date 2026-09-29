-- gs_drugs (client) : props des plants proches (locaux, un par stade), menu du plant ([E]), plantation depuis
-- l'inventaire (graine → export plantSeed), vendeur de graines. Le serveur valide tout.
local P = Config.Plants
local spawned = {}  -- [id] = { obj, stage }

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function loadModel(name)
    local hash = GetHashKey(name)
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function despawn(id)
    local s = spawned[id]
    if not s then return end
    if DoesEntityExist(s.obj) then DeleteEntity(s.obj) end
    exports.gs_markers:Remove('gs_drugs:plant:' .. id)
    spawned[id] = nil
end

local function spawn(id, p)
    local prop = P.props[p.s]
    local hash = loadModel(prop.model)
    if not hash then return end
    local obj = CreateObject(hash, p.x, p.y, p.z + prop.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    spawned[id] = { obj = obj, stage = p.s }
    exports.gs_markers:Add('gs_drugs:plant:' .. id, { coords = vec3(p.x, p.y, p.z), style = 'hidden',
        event = 'gs_drugs:client:plant', args = { id }, prompt = p.r and 'Plant de cannabis (mûr)' or 'Plant de cannabis', reach = P.reach })
end

-- Props visibles à moins de 60 m (supprimés au-delà de 80 m), mis à jour quand le stade change
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local plants = GlobalState.gsPlants or {}
        for id in pairs(spawned) do
            local p = plants[id]
            if not p or #(me - vec3(p.x, p.y, p.z)) > 80.0 or p.s ~= spawned[id].stage then despawn(id) end
        end
        for id, p in pairs(plants) do
            if not spawned[id] and #(me - vec3(p.x, p.y, p.z)) < 60.0 then spawn(id, p) end
        end
        Wait(1500)
    end
end)

local function doAction(id, action, label, scenario, ms)
    if scenario and not lib.progressBar({ duration = ms or 3000, label = label, canCancel = true,
        anim = { scenario = scenario }, disable = { move = true, car = true, combat = true } }) then
        ClearPedTasks(cache.ped)
        return
    end
    ClearPedTasks(cache.ped)
    notify(lib.callback.await('gs_drugs:plantAction', false, tonumber(id), action))
end

AddEventHandler('gs_drugs:client:plant', function(id)
    local info = lib.callback.await('gs_drugs:plantInfo', false, tonumber(id))
    if not info then return notify(false, 'Plus de plant ici.') end
    local ready = info.growth >= 100
    local options = {
        { title = ready and 'Mûr : prêt à récolter' or ('Croissance : %d %%'):format(info.growth), progress = info.growth,
          colorScheme = ready and 'green' or 'violet', icon = 'seedling', readOnly = true },
        { title = ('Eau : %d %%'):format(info.water), progress = info.water, colorScheme = info.water > 0 and 'cyan' or 'red',
          icon = 'droplet', readOnly = true, description = info.water == 0 and not ready and ('Sans eau, il dépérit (santé %d %%).'):format(info.health) or nil },
    }
    if ready then
        options[#options + 1] = { title = 'Récolter', icon = 'hand', description = info.mine and nil or 'Ce n\'est pas ton plant… ça se remarque.',
            onSelect = function() doAction(id, 'harvest', 'Récolte…', 'WORLD_HUMAN_GARDENER_PLANT', 6000) end }
    else
        options[#options + 1] = { title = 'Arroser (bouteille d\'eau)', icon = 'droplet',
            onSelect = function() doAction(id, 'water', 'Arrosage…', 'WORLD_HUMAN_GARDENER_PLANT', 3000) end }
        if not info.fert then
            options[#options + 1] = { title = 'Mettre de l\'engrais', icon = 'flask',
                onSelect = function() doAction(id, 'fertilize', 'Engrais…', 'WORLD_HUMAN_GARDENER_PLANT', 3000) end }
        end
    end
    if info.mine or info.police then
        options[#options + 1] = { title = info.police and not info.mine and 'Saisir et détruire' or 'Arracher le plant', icon = 'trash',
            iconColor = '#ff4d6d', onSelect = function() doAction(id, 'destroy', 'Arrachage…', 'WORLD_HUMAN_GARDENER_PLANT', 4000) end }
    end
    lib.registerContext({ id = 'gs_drugs_plant', title = 'Plant de cannabis', options = options })
    lib.showContext('gs_drugs_plant')
end)

-- Item weed_seed (client.export = 'gs_drugs.plantSeed') : planter devant soi, dehors
exports('plantSeed', function()
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    if GetInteriorFromEntity(cache.ped) ~= 0 then return notify(false, 'Il faut planter dehors, en pleine terre.') end
    local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.9, 0.0)
    local found, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if not found then return notify(false, 'Pas de sol ici.') end
    if not lib.progressBar({ duration = 5000, label = 'Tu plantes la graine…', canCancel = true,
        anim = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' }, disable = { move = true, car = true, combat = true } }) then
        ClearPedTasks(cache.ped)
        return
    end
    ClearPedTasks(cache.ped)
    notify(lib.callback.await('gs_drugs:plant', false, { x = pos.x, y = pos.y, z = z }))
end)

-- Vendeur de graines : PNJ + [E]
AddEventHandler('gs_drugs:client:seeds', function()
    local r = lib.inputDialog(('Graines de cannabis · %d $ l\'unité (liquide)'):format(P.seedShop.price),
        { { type = 'number', label = 'Combien ?', default = 1, min = 1, max = 10, required = true } })
    if not r then return end
    notify(lib.callback.await('gs_drugs:buySeeds', false, r[1]))
end)

local seller
CreateThread(function()
    local s = P.seedShop
    exports.gs_markers:Add('gs_drugs:seeds', { coords = vec3(s.coords.x, s.coords.y, s.coords.z), style = 'hidden',
        event = 'gs_drugs:client:seeds', prompt = s.label, reach = 2.5 })
    local hash = loadModel(s.model)
    if not hash then return end
    seller = CreatePed(4, hash, s.coords.x, s.coords.y, s.coords.z - 1.0, s.coords.w, false, true)
    SetEntityInvincible(seller, true) SetBlockingOfNonTemporaryEvents(seller, true) FreezeEntityPosition(seller, true)
    TaskStartScenarioInPlace(seller, 'WORLD_HUMAN_SMOKING', 0, true)
    SetModelAsNoLongerNeeded(hash)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
    exports.gs_markers:Remove('gs_drugs:seeds')
    if seller and DoesEntityExist(seller) then DeleteEntity(seller) end
end)
