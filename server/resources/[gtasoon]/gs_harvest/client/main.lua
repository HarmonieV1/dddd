-- gs_harvest (client) : nœuds de récolte (arbres, rochers, tas de ferraille, légumes posés au sol chez le joueur ;
-- places de pêche), vestiaire (tenue de travail), acheteurs, dépeçage des animaux abattus (ox_target).
local Bridge = exports.gs_bridge
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 6000 }) end end
local busy = false
local props = {}      -- ['id:i'] = entité locale
local ground = {}     -- ['id:i'] = vector3 recalé au sol
local depleted = {}   -- ['id:i'] = GetGameTimer() de retour
local inWorkOutfit = false

local function key(id, i) return id .. ':' .. i end

--- Position du nœud recalée au sol (les points de la config ont une hauteur approximative)
local function groundOf(c)
    for _, from in ipairs({ c.z + 3.0, c.z + 30.0 }) do
        local found, gz = GetGroundZFor_3dCoord(c.x, c.y, from, false)
        if found and math.abs(gz - c.z) < 25.0 then return vec3(c.x, c.y, gz), true end
    end
    return c, false
end
local grounded = {}   -- ['id:i'] = true quand la hauteur vient vraiment du sol (collision chargée)

local function removeNode(k)
    if props[k] then
        exports.ox_target:removeLocalEntity(props[k])
        if DoesEntityExist(props[k]) then DeleteEntity(props[k]) end
        props[k] = nil
    end
    exports.gs_markers:Remove('gs_harvest:n:' .. k)
end

local doHarvest

local function addNode(id, i)
    local a, k = Config.Activities[id], key(id, i)
    local g = ground[k]
    if not g then
        local found
        g, found = groundOf(a.spots[i])
        grounded[k] = found
    end
    ground[k] = g
    if a.prop then
        local hash = GetHashKey(a.prop)
        if lib.requestModel(hash, 5000) then
            local obj = CreateObject(hash, g.x, g.y, g.z, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)
            props[k] = obj
            exports.ox_target:addLocalEntity(obj, { { name = 'gs_harvest_' .. k, icon = 'fa-solid fa-hand', label = a.verb, distance = 3.0,
                onSelect = function() doHarvest(id, i) end } })
        end
    end
    exports.gs_markers:Add('gs_harvest:n:' .. k, { coords = g + vec3(0.0, 0.0, 1.0), style = a.prop and 'hidden' or 'job', label = a.label,
        event = 'gs_harvest:client:do', args = { id, i }, reach = 2.2,
        prompt = a.verb .. (a.tool and (' (' .. a.toolLabel .. ')') or '') })
end

doHarvest = function(id, i)
    if busy or cache.vehicle then return end
    local a = Config.Activities[id]
    local ok, res = lib.callback.await('gs_harvest:begin', false, id, i)
    if not ok then return notify(false, res) end
    busy = true
    local g = ground[key(id, i)]
    if g then TaskTurnPedToFaceCoord(cache.ped, g.x, g.y, g.z, 600) Wait(600) end
    local done = lib.progressBar({ duration = res, label = a.verb .. '…', canCancel = true,
        anim = a.scenario and { scenario = a.scenario } or (a.anim and { dict = a.anim.dict, clip = a.anim.clip, flag = 1 }),
        prop = a.handProp, disable = { move = true, car = true, combat = true } })
    ClearPedTasks(cache.ped)
    busy = false
    if not done then return TriggerServerEvent('gs_harvest:server:cancel') end
    local ok2, msg, info = lib.callback.await('gs_harvest:finish', false)
    notify(ok2, msg)
    if ok2 and info then
        if info.depleted then
            local k = key(id, info.node)
            depleted[k] = GetGameTimer() + Config.Regrow * 1000
            removeNode(k)
        end
        if info.sell then lib.notify({ description = 'Revente : ' .. info.sell .. ' (logo sur la carte)', type = 'inform', duration = 4000 }) end
    end
end
AddEventHandler('gs_harvest:client:do', doHarvest)

-- Vestiaire : tenue de travail / retour en civil
AddEventHandler('gs_harvest:client:locker', function()
    if inWorkOutfit then
        inWorkOutfit = false
        Bridge:RestoreAppearance()
        return notify(true, 'Tenue civile remise.')
    end
    local ped = cache.ped
    local set = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') and Config.WorkOutfit.female or Config.WorkOutfit.male
    Bridge:SaveAppearance()
    inWorkOutfit = true
    for comp, v in pairs(set) do SetPedComponentVariation(ped, comp, v[1], v[2], 0) end
    notify(true, 'Tenue de travail. Reviens au vestiaire pour la retirer.')
end)

AddEventHandler('gs_harvest:client:licence', function()
    notify(lib.callback.await('gs_harvest:buyLicence', false))
end)

AddEventHandler('gs_harvest:client:sell', function(i)
    notify(lib.callback.await('gs_harvest:sell', false, i))
end)

local blips = {}
local function blip(c, b, label, short)
    local h = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(h, b.sprite) SetBlipColour(h, b.color) SetBlipScale(h, 0.7) SetBlipAsShortRange(h, short ~= false)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(h)
    blips[#blips + 1] = h
end

-- Nœuds créés à l'approche, supprimés au loin ; ceux épuisés reviennent après Config.Regrow
CreateThread(function()
    for id in pairs(Config.Activities) do
        for i, n in pairs(lib.callback.await('gs_harvest:depleted', false, id) or {}) do depleted[key(id, i)] = GetGameTimer() + n * 1000 end
    end
    while true do
        local me = GetEntityCoords(cache.ped)
        local now = GetGameTimer()
        for id, a in pairs(Config.Activities) do
            for i, c in ipairs(a.spots) do
                local k = key(id, i)
                local near = #(vec2(me.x, me.y) - vec2(c.x, c.y)) < Config.PropRange
                local gone = depleted[k] and depleted[k] > now
                if near and not gone then
                    -- posé avant que le sol soit chargé : recalé une fois de près
                    if (props[k] or ground[k]) and not grounded[k] and #(me - c) < 50.0 then
                        local g, found = groundOf(c)
                        if found then removeNode(k) ground[k] = g grounded[k] = true addNode(id, i) end
                    end
                    if not props[k] and not (not a.prop and ground[k]) then addNode(id, i) end
                elseif props[k] or (not a.prop and ground[k]) then
                    removeNode(k)
                    if not a.prop then ground[k] = nil grounded[k] = nil end
                end
            end
        end
        Wait(1500)
    end
end)

CreateThread(function()
    for id, a in pairs(Config.Activities) do
        blip(a.spots[1], a.blip, a.label)
        if a.outfit ~= false then
            -- vestiaire à côté du premier nœud (recalé au sol à la création du point)
            local c = a.spots[1]
            exports.gs_markers:Add('gs_harvest:locker:' .. id, { coords = groundOf(c) + vec3(2.5, 2.5, 1.0), style = 'entry', label = 'Vestiaire',
                event = 'gs_harvest:client:locker', prompt = 'Vestiaire (tenue de travail / civile)', reach = 1.8 })
        end
    end
    for i, b in ipairs(Config.Buyers) do
        blip(b.coords, b.blip, b.label, false) -- acheteurs visibles de loin
        exports.gs_markers:Add('gs_harvest:buyer:' .. i, { coords = b.coords, style = 'shop', label = b.label,
            event = 'gs_harvest:client:sell', args = { i }, prompt = 'Vendre · ' .. b.label })
    end
    blip(Config.Hunting.center, Config.Hunting.blip, Config.Hunting.label)
    exports.gs_markers:Add('gs_harvest:licence', { coords = Config.Hunting.lodge, style = 'shop', label = 'Permis de chasse',
        event = 'gs_harvest:client:licence', prompt = ('Permis de chasse (%d $)'):format(Config.Hunting.licencePrice) })

    -- Dépecer : ox_target sur les animaux abattus (le serveur vérifie que c'est bien du gibier de la zone)
    local models = {}
    for m in pairs(Config.Hunting.animals) do models[#models + 1] = m end
    exports.ox_target:addModel(models, { { -- [API] ox_target
        name = 'gs_harvest:skin', icon = 'fa-solid fa-drumstick-bite', label = 'Dépecer', distance = 2.5,
        canInteract = function(ent) return IsEntityDead(ent) end,
        onSelect = function(data)
            if not NetworkGetEntityIsNetworked(data.entity) then return notify(false, 'Rien à dépecer.') end
            if not lib.progressBar({ duration = Config.Hunting.skinTime, label = 'Dépeçage…', canCancel = true,
                anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base' }, disable = { move = true, car = true, combat = true } }) then return end
            ClearPedTasks(cache.ped)
            notify(lib.callback.await('gs_harvest:skin', false, NetworkGetNetworkIdFromEntity(data.entity)))
        end,
    } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_harvest:')
    for k in pairs(props) do removeNode(k) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
