-- gs_weather (client) · V8 « Météo événementielle » : barrières sur les routes fermées, interventions tempête.
--
-- V12.37 · « Intervention dans le vide » (fondateur) : avant, tout était créé d'un coup à la publication de l'état, où que soit
-- le joueur. Hors streaming le sol n'est pas chargé : PlaceObjectOnGroundProperly / SetVehicleOnGroundProperly échouaient et
-- l'entité restait figée à la hauteur approximative de la config, en l'air ou sous la carte, parfois à 20 m de la route.
-- Désormais UNE boucle lente (2 s, jamais par image) crée chaque élément à moins de Config.Storm.streamIn m du joueur (sol
-- demandé et attendu, 5 s max), le retire au-delà de streamOut m et le recrée à l'approche. Le véhicule en détresse est posé
-- sur le nœud de route le plus proche du point configuré (≤ snapRadius m), puis le blip et le marqueur [E] sont déplacés sur
-- sa position réelle. Sans route ni sol : pas d'entité, message console propre (et nouvel essai plus tard pour le sol).
-- Les blips et marqueurs, eux, sont posés tout de suite : ils ne dépendent pas du sol.
local S = Config.Storm
local MODELS = { road = 'prop_barrier_work05', tree = 'prop_tree_fallen_pine_01' }
local GROUND_WAIT = 5000 -- ms : attente maximale du sol autour d'une entité créée
local RETRY_AFTER = 15000 -- ms : nouvel essai après un sol non chargé

-- [key] = { key, kind = 'road'|'tree'|'stranded', idx, c = vec4 configuré, id (intervention), pos (réelle), blip, ents = {},
--           spawned, nextTry (sol non chargé), noNode (aucune route : on n'essaie plus) }
local items = {}

local function blip(c, sprite, color, label)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, sprite) SetBlipColour(b, color) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(b)
    return b
end

local function markerDef(item, pos)
    return { coords = vec3(pos.x, pos.y, pos.z + 0.5), style = 'job', label = 'Intervention',
        event = 'gs_weather:client:stormFix', args = { item.id }, reach = 6.0, snap = true,
        prompt = item.kind == 'tree' and 'Dégager l\'arbre (prime tempête)' or 'Remorquer / réparer (prime tempête)' }
end

--- Charge un modèle ; nil s'il est introuvable ou met plus de 5 s (lib.requestModel lève une erreur dans ce cas).
local function model(name)
    local h = GetHashKey(name)
    local ok = pcall(lib.requestModel, h, 5000)
    if ok then return h end
    print(('[gs_weather] tempête : modèle « %s » introuvable, élément ignoré'):format(tostring(name)))
    return nil
end

--- Demande le sol autour de `c` et attend qu'il soit chargé autour de `entity` (GROUND_WAIT max). Boucle lente (100 ms).
local function groundLoaded(entity, c)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local deadline = GetGameTimer() + GROUND_WAIT
    while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        Wait(100)
    end
    return HasCollisionLoadedAroundEntity(entity)
end

--- V12.40 · « véhicules dans le vide » : SetVehicleOnGroundProperly / PlaceObjectOnGroundProperly peuvent échouer en silence
--- (sol pas encore dense, pont, talus) ; l'entité était quand même figée là où elle était, en l'air. Désormais on lit le vrai sol
--- sous le point (sonde partant juste au-dessus : jamais le tablier d'un pont plus haut), on pose, on VÉRIFIE la hauteur au-dessus
--- du sol, et si c'est raté l'élément est retiré et réessayé plus tard. Jamais d'entité figée dans le vide.
local MAX_ABOVE = 1.2 -- m : au-delà, l'entité n'est pas posée (véhicule : roues au sol ≈ 0,5 m)

local function groundAt(x, y, zHint)
    for _ = 1, 10 do
        local ok, gz = GetGroundZFor_3dCoord(x, y, zHint + 2.0, false)
        if ok and math.abs(gz - zHint) < 4.0 then return gz end
        RequestCollisionAtCoord(x, y, zHint)
        Wait(100)
    end
end

local function settled(e)
    local h = GetEntityHeightAboveGround(e)
    return h >= -0.5 and h <= MAX_ABOVE
end

--- Objet figé posé au sol (barrière, arbre). false si modèle absent ou sol non chargé (l'appelant retire et réessaie plus tard).
local function placeProp(item, name, c, heading, offset)
    local h = model(name)
    if not h then return false end
    local pos = offset and vec3(c.x + offset.x, c.y + offset.y, c.z) or vec3(c.x, c.y, c.z)
    local o = CreateObject(h, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(h)
    if not o or o == 0 then return false end
    item.ents[#item.ents + 1] = o
    FreezeEntityPosition(o, true) -- figé tout de suite : il ne tombe pas pendant le chargement du sol
    SetEntityHeading(o, heading)
    if not groundLoaded(o, pos) then return false end
    local gz = groundAt(pos.x, pos.y, pos.z)
    if not gz then return false end
    SetEntityCoordsNoOffset(o, pos.x, pos.y, gz, false, false, false) -- au sol réel même si la pose fine échoue
    PlaceObjectOnGroundProperly(o) -- (l'origine d'un arbre couché n'est pas à sa base : pas de contrôle de hauteur ici)
    FreezeEntityPosition(o, true)
    return true
end

--- Véhicule en détresse : sur le nœud de route le plus proche du point (≤ snapRadius m), sol chargé, posé proprement,
--- puis blip et marqueur déplacés sur sa position réelle.
local function placeVehicle(item)
    local c = item.c
    local ok, node, heading = GetClosestVehicleNodeWithHeading(c.x, c.y, c.z, 1, 3.0, 0)
    if not ok or #(vec3(node.x, node.y, node.z) - vec3(c.x, c.y, c.z)) > S.snapRadius then
        item.noNode = true
        print(('[gs_weather] tempête : aucune route à moins de %d m du point %s (%.1f, %.1f, %.1f) : véhicule non créé, point à caler (F11 → Points)')
            :format(S.snapRadius, item.key, c.x, c.y, c.z))
        return false
    end
    local h = model(S.strandedModel)
    if not h then return false end
    local v = CreateVehicle(h, node.x, node.y, node.z + 0.5, heading, false, false)
    SetModelAsNoLongerNeeded(h)
    if not v or v == 0 then return false end
    item.ents[#item.ents + 1] = v
    FreezeEntityPosition(v, true)
    if not groundLoaded(v, node) then return false end
    local gz = groundAt(node.x, node.y, node.z)
    if not gz then return false end
    SetEntityCoordsNoOffset(v, node.x, node.y, gz + 0.3, false, false, false)
    SetEntityHeading(v, heading)
    FreezeEntityPosition(v, false)
    local placed = SetVehicleOnGroundProperly(v)
    FreezeEntityPosition(v, true) -- figé une fois au sol : ni vent ni collision ne le déplacent
    if not placed or not settled(v) then return false end -- raté : retiré, nouvel essai (jamais laissé en l'air)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleIndicatorLights(v, 0, true) SetVehicleIndicatorLights(v, 1, true)
    SetVehicleEngineHealth(v, 100.0)
    local pos = GetEntityCoords(v)
    item.pos = vec3(pos.x, pos.y, pos.z)
    if item.blip then SetBlipCoords(item.blip, pos.x, pos.y, pos.z) end
    exports.gs_markers:Add('gs_storm:' .. item.id, markerDef(item, item.pos)) -- même id : le point est remplacé
    return true
end

local function spawn(item)
    local c = item.c
    if item.kind == 'road' then
        local rad = math.rad(c.w)
        local right = vec3(math.cos(rad), math.sin(rad), 0.0)
        for k = -2, 2 do
            if not placeProp(item, MODELS.road, c, c.w, right * (k * 2.6)) then return false end
        end
        return true
    elseif item.kind == 'tree' then
        return placeProp(item, MODELS.tree, c, c.w)
    end
    return placeVehicle(item)
end

local function despawn(item)
    for _, e in ipairs(item.ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
    item.ents, item.spawned = {}, false
end

--- Retire complètement un élément (entités, blip, marqueur).
local function drop(key)
    local item = items[key]
    if not item then return end
    despawn(item)
    if item.blip then RemoveBlip(item.blip) end
    if item.id then exports.gs_markers:Remove('gs_storm:' .. item.id) end
    items[key] = nil
end

local function clear()
    for key in pairs(items) do drop(key) end
    exports.gs_markers:RemovePrefix('gs_storm:')
end

--- État publié par le serveur → liste d'éléments voulus. Ce qui existe déjà est gardé (plus de clignotement de toutes les
--- barrières à chaque intervention terminée) ; le reste est retiré ; les nouveaux reçoivent blip + marqueur tout de suite,
--- leurs entités arrivent par la boucle lente à l'approche du joueur.
local function apply(state)
    local want = {}
    if state then
        for _, i in ipairs(state.roads or {}) do
            local r = S.roads[i]
            if r then want['road:' .. i] = { kind = 'road', idx = i, c = r.coords, sprite = 650, color = 1, label = 'Route fermée (tempête)' } end
        end
        for id, idx in pairs(state.incidents or {}) do
            local sp = S.spots[idx]
            if sp then
                want['inc:' .. id] = { kind = sp.kind, idx = idx, c = sp.coords, id = id, sprite = 446, color = 47,
                    label = sp.kind == 'tree' and 'Arbre sur la route (tempête)' or 'Véhicule en détresse (tempête)' }
            end
        end
    end
    for key, item in pairs(items) do
        local w = want[key]
        if not w or w.kind ~= item.kind or w.idx ~= item.idx then drop(key) end
    end
    for key, w in pairs(want) do
        if not items[key] then
            w.key, w.ents, w.spawned, w.pos = key, {}, false, vec3(w.c.x, w.c.y, w.c.z)
            w.blip = blip(w.c, w.sprite, w.color, w.label)
            if w.id then exports.gs_markers:Add('gs_storm:' .. w.id, markerDef(w, w.pos)) end
            items[key] = w
        end
    end
end

AddEventHandler('gs_weather:client:stormFix', function(id)
    if not lib.progressBar({ duration = 10000, label = 'Intervention…', canCancel = true, anim = { scenario = 'WORLD_HUMAN_HAMMERING' },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_weather:stormFix', false, id)
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end)

AddStateBagChangeHandler('gsStorm', 'global', function(_, _, value) apply(value) end)

-- V12.37 · Boucle lente unique (2 s) : création à l'approche (< streamIn), retrait au loin (> streamOut). Rien à faire hors tempête.
CreateThread(function()
    Wait(3000)
    apply(GlobalState.gsStorm)
    while true do
        if next(items) then
            local me = GetEntityCoords(cache.ped)
            local now = GetGameTimer()
            for _, item in pairs(items) do
                local d = #(me - item.pos)
                if item.spawned then
                    if d > S.streamOut then despawn(item) end
                elseif d < S.streamIn and not item.noNode and (not item.nextTry or now >= item.nextTry) then
                    item.spawned = true -- posé avant de créer : spawn() attend (modèle, sol), la boucle ne doit pas le relancer
                    local ok = spawn(item)
                    if items[item.key] ~= item then
                        despawn(item) -- retiré (intervention faite, fin de tempête) pendant la création : rien ne traîne
                    elseif not ok then
                        despawn(item)
                        item.nextTry = GetGameTimer() + RETRY_AFTER
                        if not item.noNode then
                            print(('[gs_weather] tempête : sol non chargé ou modèle absent pour %s : retiré, nouvel essai dans %d s'):format(item.key, RETRY_AFTER // 1000))
                        end
                    end
                end
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
