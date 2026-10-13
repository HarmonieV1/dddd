-- gs_harvest (client) : nœuds de récolte (arbres, rochers, carcasses, légumes posés au sol chez le joueur ;
-- places de pêche), vestiaire (tenue de travail), acheteurs, dépeçage des animaux abattus (ox_target).
-- V12.36 : les PNJ (acheteurs, contremaîtres des vestiaires) sont portés par gs_markers (champ `ped` du point), plus de boucle ici.
local Bridge = exports.gs_bridge
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 6000 }) end end
local busy = false
local props = {}      -- ['id:i'] = entité locale
local marked = {}     -- ['id:i'] = true quand le marqueur [E] du nœud est posé (V12.36)
local ground = {}     -- ['id:i'] = vector3 recalé au sol
local depleted = {}   -- ['id:i'] = GetGameTimer() de retour
local inWorkOutfit = false

local function key(id, i) return id .. ':' .. i end
local function isDepleted(k) return depleted[k] ~= nil and depleted[k] > GetGameTimer() end

--- Position du nœud recalée au sol (les points de la config ont une hauteur approximative)
local function groundOf(c)
    for _, from in ipairs({ c.z + 3.0, c.z + 30.0 }) do
        local found, gz = GetGroundZFor_3dCoord(c.x, c.y, from, false)
        if found and math.abs(gz - c.z) < 25.0 then return vec3(c.x, c.y, gz), true end
    end
    return c, false
end
local grounded = {}   -- ['id:i'] = true quand la hauteur vient vraiment du sol (collision chargée)

--- V12.36 · Objet d'un nœud : `props` (liste, choix fixe par nœud pour que tout le monde voie le même objet) sinon `prop`.
--- Un modèle absent du jeu retombe sur `prop`.
local function nodeModel(a, i)
    local list = a.props
    if type(list) ~= 'table' or #list == 0 then return a.prop end
    local name = list[((i - 1) % #list) + 1]
    local hash = GetHashKey(name)
    if IsModelInCdimage(hash) and IsModelValid(hash) then return name end
    return a.prop
end

local function removeProp(k)
    if props[k] then
        exports.ox_target:removeLocalEntity(props[k])
        if DoesEntityExist(props[k]) then DeleteEntity(props[k]) end
        props[k] = nil
    end
end

local function removeMarker(k)
    if marked[k] then exports.gs_markers:Remove('gs_harvest:n:' .. k) marked[k] = nil end
end

local function removeNode(k) removeProp(k) removeMarker(k) end

local doHarvest

--- Position au sol du nœud, calculée une fois (recalée de près si le sol n'était pas chargé, voir la boucle)
local function nodeGround(id, i)
    local k = key(id, i)
    if not ground[k] then
        local g, found = groundOf(Config.Activities[id].spots[i])
        ground[k], grounded[k] = g, found
    end
    return ground[k]
end

local function addProp(id, i)
    local a, k = Config.Activities[id], key(id, i)
    local g = nodeGround(id, i)
    local hash = GetHashKey(nodeModel(a, i))
    if not pcall(lib.requestModel, hash, 5000) then return end -- V12.36 : modèle absent → pas d'erreur de script, le nœud reste un simple point
    local obj = CreateObject(hash, g.x, g.y, g.z, false, false, false)
    SetEntityHeading(obj, (i * 73) % 360 + 0.0) -- V12.36 : cap propre à chaque nœud (des carcasses toutes orientées pareil, ça se voit)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    props[k] = obj
    exports.ox_target:addLocalEntity(obj, { { name = 'gs_harvest_' .. k, icon = a.icon or 'fa-solid fa-hand', label = a.verb, distance = 3.0,
        canInteract = function() return not isDepleted(k) end, -- V12.36 : nœud épuisé encore visible (carcasse) = plus rien à prendre
        onSelect = function() doHarvest(id, i) end } })
end

local function addMarker(id, i)
    local a, k = Config.Activities[id], key(id, i)
    local g = nodeGround(id, i)
    exports.gs_markers:Add('gs_harvest:n:' .. k, { coords = g + vec3(0.0, 0.0, 1.0), style = a.prop and 'hidden' or 'job', label = a.label,
        event = 'gs_harvest:client:do', args = { id, i }, reach = 2.2,
        prompt = a.verb .. (a.tool and (' (' .. a.toolLabel .. ')') or '') })
    marked[k] = true
end

--- V12.36 · Scène de récolte en une ou plusieurs phases (ferraille : fouiller la carcasse accroupi, puis dévisser à genoux, clé en
--- main) : chaque phase a son animation, son outil en main et sa part (`share`) de la durée totale fixée par le serveur.
local function playScene(a, total)
    local phases = a.phases or { { label = a.verb .. '…', share = 1.0, anim = a.anim, scenario = a.scenario, handProp = a.handProp } }
    for _, ph in ipairs(phases) do
        -- pcall : un dictionnaire d'animation ou un objet absent du jeu annule la scène proprement au lieu de bloquer le joueur
        local ok, done = pcall(lib.progressBar, { duration = math.floor(total * (ph.share or 1.0)), label = ph.label, canCancel = true,
            anim = ph.scenario and { scenario = ph.scenario } or (ph.anim and { dict = ph.anim.dict, clip = ph.anim.clip, flag = ph.anim.flag or 1 }),
            prop = ph.handProp, disable = { move = true, car = true, combat = true } })
        ClearPedTasks(cache.ped)
        if not ok then
            print(('[gs_harvest] scène « %s » : animation ou objet indisponible (%s)'):format(ph.label, tostring(done)))
            notify(false, 'Scène indisponible, réessaie.')
            return false
        end
        if not done then return false end
    end
    return true
end

doHarvest = function(id, i)
    if busy or cache.vehicle then return end
    local a = Config.Activities[id]
    local ok, res = lib.callback.await('gs_harvest:begin', false, id, i)
    if not ok then return notify(false, res) end
    busy = true
    local g = ground[key(id, i)]
    if g then TaskTurnPedToFaceCoord(cache.ped, g.x, g.y, g.z, 600) Wait(600) end
    local done = playScene(a, res)
    busy = false
    if not done then return TriggerServerEvent('gs_harvest:server:cancel') end
    local ok2, msg, info = lib.callback.await('gs_harvest:finish', false)
    notify(ok2, msg)
    if ok2 and info then
        if info.depleted then
            local k = key(id, info.node)
            depleted[k] = GetGameTimer() + Config.Regrow * 1000
            if a.keepWhenDepleted then removeMarker(k) else removeNode(k) end -- la carcasse dépouillée reste, seul [E] s'éteint
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

-- Nœuds créés à l'approche, supprimés au loin ; ceux épuisés reviennent après Config.Regrow.
-- V12.36 : un nœud épuisé garde son objet si l'activité le demande (keepWhenDepleted : la carcasse dépouillée reste là),
-- mais perd son [E] et sa cible jusqu'à la repousse.
CreateThread(function()
    for id in pairs(Config.Activities) do
        for i, n in pairs(lib.callback.await('gs_harvest:depleted', false, id) or {}) do depleted[key(id, i)] = GetGameTimer() + n * 1000 end
    end
    while true do
        local me = GetEntityCoords(cache.ped)
        for id, a in pairs(Config.Activities) do
            for i, c in ipairs(a.spots) do
                local k = key(id, i)
                local near = #(vec2(me.x, me.y) - vec2(c.x, c.y)) < Config.PropRange
                if near then
                    -- posé avant que le sol soit chargé : recalé une fois de près
                    if ground[k] and not grounded[k] and #(me - c) < 50.0 then
                        local g, found = groundOf(c)
                        if found then removeNode(k) ground[k] = g grounded[k] = true end
                    end
                    local gone = isDepleted(k)
                    local wantProp = a.prop ~= nil and (not gone or a.keepWhenDepleted == true)
                    if wantProp and not props[k] then addProp(id, i) end
                    if not wantProp and props[k] then removeProp(k) end
                    if not gone and not marked[k] then addMarker(id, i) end
                    if gone and marked[k] then removeMarker(k) end
                elseif props[k] or marked[k] then
                    removeNode(k)
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
            -- vestiaire à côté du premier nœud (recalé au sol à la création du point) ; V12.36 : contremaître (PNJ) au vestiaire
            local c = a.spots[1]
            exports.gs_markers:Add('gs_harvest:locker:' .. id, { coords = groundOf(c) + vec3(2.5, 2.5, 1.0), style = 'entry', label = 'Vestiaire',
                event = 'gs_harvest:client:locker', prompt = 'Vestiaire (tenue de travail / civile)', reach = 1.8,
                ped = a.lockerPed })
        end
    end
    for i, b in ipairs(Config.Buyers) do
        blip(b.coords, b.blip, b.label, false) -- acheteurs visibles de loin
        -- V11.5 acheteur visible ; V12.36 : créé par gs_markers (ox_target « Vendre » sur le PNJ, en plus du [E])
        exports.gs_markers:Add('gs_harvest:buyer:' .. i, { coords = b.coords, style = 'shop', label = b.label,
            event = 'gs_harvest:client:sell', args = { i }, prompt = 'Vendre · ' .. b.label,
            ped = b.ped and { model = b.ped.model, heading = b.ped.heading, scenario = b.ped.scenario, icon = 'fa-solid fa-sack-dollar' } or nil })
    end
end)

CreateThread(function()
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
    exports.gs_markers:RemovePrefix('gs_harvest:') -- retire aussi les PNJ des acheteurs / vestiaires (gs_markers)
    for k in pairs(props) do removeNode(k) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
