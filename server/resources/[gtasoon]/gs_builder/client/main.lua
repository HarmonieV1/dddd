-- gs_builder (client). 1) Streaming : objets créés localement (non réseau) seulement près du joueur.
-- 2) Mode placement (staff) : l'objet suit le viseur, flèches pour le réglage fin, Q/E pour tourner.
local objects = {}    -- [id] = { data, handle }
local editingId       -- objet masqué pendant qu'on le modifie

-- Streaming ------------------------------------------------------------------------------------------
local function despawn(o)
    if o.handle and DoesEntityExist(o.handle) then DeleteEntity(o.handle) end
    o.handle = nil
end

local function spawn(o)
    local d = o.data
    local hash = GetHashKey(d.model)
    if not IsModelInCdimage(hash) then o.invalid = true return end
    lib.requestModel(hash, 5000)
    local h = CreateObjectNoOffset(hash, d.x, d.y, d.z, false, false, false)
    SetEntityRotation(h, d.rx, d.ry, d.rz, 2, false)
    FreezeEntityPosition(h, true)
    SetModelAsNoLongerNeeded(hash)
    o.handle = h
end

local function set(data)
    local o = objects[data.id]
    if o then despawn(o) end
    objects[data.id] = { data = data }
end

RegisterNetEvent('gs_builder:client:set', set)
RegisterNetEvent('gs_builder:client:remove', function(id)
    local o = objects[id]
    if o then despawn(o) objects[id] = nil end
end)

CreateThread(function()
    for _, d in ipairs(lib.callback.await('gs_builder:list', false) or {}) do set(d) end
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, o in pairs(objects) do
            if not o.invalid then
                local dist = #(pos - vec3(o.data.x, o.data.y, o.data.z))
                if id == editingId then despawn(o)
                elseif not o.handle and dist < Config.StreamIn then spawn(o)
                elseif o.handle and dist > Config.StreamOut then despawn(o) end
            end
        end
        Wait(Config.StreamTick)
    end
end)

-- Mode placement -------------------------------------------------------------------------------------------
local HELP = table.concat({
    '[Souris] viser  ·  [TAB] mode viser / précis',
    '[Flèches] déplacer  ·  [PgUp/PgDn] hauteur',
    '[Q/E] tourner  ·  [Molette] rotation fine  ·  [X] remettre droit',
    '[G] poser au sol  ·  [Shift] rapide  ·  [Ctrl] précis',
    '[Entrée] valider  ·  [Retour] annuler',
}, '  \n')

local DISABLED = { 24, 25, 44, 38, 45, 47, 73, 172, 173, 174, 175, 10, 11, 14, 15, 16, 17, 37, 140, 141, 142, 257, 263 }

--- Lance le placement. start = { model, x?, y?, z?, rx?, ry?, rz? }. Retourne l'objet final ou nil.
local function place(start)
    local hash = GetHashKey(start.model)
    if not IsModelInCdimage(hash) then lib.notify({ description = 'Modèle inconnu : ' .. start.model, type = 'error' }) return nil end
    lib.requestModel(hash, 5000)
    local ped = PlayerPedId()
    local p = start.x and vec3(start.x, start.y, start.z) or GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local rot = vec3(start.rx or 0.0, start.ry or 0.0, start.rz or GetEntityHeading(ped))
    local preview = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(preview, 190, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    local aim = not start.x
    local result
    lib.showTextUI(HELP, { position = 'right-center' })

    -- par frame : seulement pendant le placement d'un objet (sortie avec Entrée / Retour)
    while true do
        for _, c in ipairs(DISABLED) do DisableControlAction(0, c, true) end
        local mult = (IsControlPressed(0, 21) and 5.0) or (IsControlPressed(0, 36) and 0.2) or 1.0
        local step, turn = 0.05 * mult, 2.0 * mult

        if IsDisabledControlJustPressed(0, 37) then aim = not aim end -- TAB
        if aim then
            local hit, _, coords = lib.raycast.cam(1 | 16, 4, 25.0) -- [API] ox_lib : monde + objets, ignore le joueur
            if hit then p = coords end
        else
            local camHeading = math.rad(GetGameplayCamRot(2).z)
            local fwd, right = vec3(-math.sin(camHeading), math.cos(camHeading), 0.0), vec3(math.cos(camHeading), math.sin(camHeading), 0.0)
            if IsDisabledControlPressed(0, 172) then p = p + fwd * step end
            if IsDisabledControlPressed(0, 173) then p = p - fwd * step end
            if IsDisabledControlPressed(0, 175) then p = p + right * step end
            if IsDisabledControlPressed(0, 174) then p = p - right * step end
        end
        if IsDisabledControlPressed(0, 10) then p = p + vec3(0.0, 0.0, step) end
        if IsDisabledControlPressed(0, 11) then p = p - vec3(0.0, 0.0, step) end
        if IsDisabledControlPressed(0, 44) then rot = rot + vec3(0.0, 0.0, turn) end
        if IsDisabledControlPressed(0, 38) then rot = rot - vec3(0.0, 0.0, turn) end
        if IsDisabledControlJustPressed(0, 14) then rot = rot + vec3(0.0, 0.0, 15.0) end
        if IsDisabledControlJustPressed(0, 15) then rot = rot - vec3(0.0, 0.0, 15.0) end
        if IsDisabledControlJustPressed(0, 73) then rot = vec3(0.0, 0.0, rot.z) end

        SetEntityCoordsNoOffset(preview, p.x, p.y, p.z, false, false, false)
        SetEntityRotation(preview, rot.x, rot.y, rot.z, 2, false)
        if IsDisabledControlJustPressed(0, 47) then -- G : poser au sol
            PlaceObjectOnGroundProperly(preview)
            p, rot = GetEntityCoords(preview), GetEntityRotation(preview, 2)
            aim = false
        end
        DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.08, 0.08, 0.08, 40, 224, 255, 200, false, false, 2, false, nil, nil, false)

        if IsControlJustPressed(0, 191) then -- Entrée
            result = { model = start.model, x = p.x, y = p.y, z = p.z, rx = rot.x, ry = rot.y, rz = rot.z }
            break
        elseif IsControlJustPressed(0, 194) then -- Retour
            break
        end
        Wait(0)
    end

    lib.hideTextUI()
    DeleteEntity(preview)
    return result
end

-- Menu ------------------------------------------------------------------------------------------------------
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function newObject(model)
    local o = place({ model = model })
    if o then notify(lib.callback.await('gs_builder:place', false, o)) end
end

local function editObject(id)
    local o = objects[id]
    if not o then return end
    editingId = id
    despawn(o)
    local moved = place(o.data)
    editingId = nil
    if moved then notify(lib.callback.await('gs_builder:update', false, id, moved)) end
    if objects[id] then spawn(objects[id]) end
end

local function nearbyMenu()
    local pos = GetEntityCoords(PlayerPedId())
    local list = {}
    for id, o in pairs(objects) do
        local d = #(pos - vec3(o.data.x, o.data.y, o.data.z))
        if d < 30.0 then list[#list + 1] = { id = id, model = o.data.model, dist = d } end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local options = {}
    for _, e in ipairs(list) do
        options[#options + 1] = {
            title = ('#%d · %s'):format(e.id, e.model), description = ('%.1f m'):format(e.dist), icon = 'cube',
            onSelect = function()
                lib.registerContext({ id = 'gs_builder_obj', title = e.model, menu = 'gs_builder_near', options = {
                    { title = 'Déplacer / tourner', icon = 'arrows-up-down-left-right', onSelect = function() editObject(e.id) end },
                    { title = 'Dupliquer', icon = 'clone', onSelect = function()
                        local d = objects[e.id].data
                        local o = place({ model = d.model, x = d.x + 1.0, y = d.y, z = d.z, rx = d.rx, ry = d.ry, rz = d.rz })
                        if o then notify(lib.callback.await('gs_builder:place', false, o)) end
                    end },
                    { title = 'Supprimer', icon = 'trash', iconColor = '#ff4d6d', onSelect = function()
                        if lib.alertDialog({ header = 'Supprimer ' .. e.model, content = 'Définitif.', centered = true, cancel = true }) == 'confirm' then
                            notify(lib.callback.await('gs_builder:delete', false, e.id))
                        end
                    end },
                } })
                lib.showContext('gs_builder_obj')
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Aucun objet placé à moins de 30 m', readOnly = true } end
    lib.registerContext({ id = 'gs_builder_near', title = 'Objets à proximité', menu = 'gs_builder', options = options })
    lib.showContext('gs_builder_near')
end

local function aimedObject()
    local hit, entity = lib.raycast.cam(16, 4, 30.0) -- [API] ox_lib
    if not hit or entity == 0 then return lib.notify({ description = 'Vise un objet placé.', type = 'error' }) end
    for id, o in pairs(objects) do
        if o.handle == entity then return editObject(id) end
    end
    lib.notify({ description = 'Cet objet fait partie de la map d\'origine (non modifiable).', type = 'error' })
end

local function openMenu()
    if not lib.callback.await('gs_builder:canUse', false) then
        return lib.notify({ description = 'Accès réservé au staff.', type = 'error' })
    end
    local favorites = {}
    for _, f in ipairs(Config.Favorites) do
        favorites[#favorites + 1] = { title = f.label, description = f.model, icon = 'cube', onSelect = function() newObject(f.model) end }
    end
    lib.registerContext({ id = 'gs_builder_fav', title = 'Objets favoris', menu = 'gs_builder', options = favorites })

    lib.registerContext({ id = 'gs_builder', title = 'Mapping', options = {
        { title = 'Placer un objet (nom du modèle)', icon = 'plus', onSelect = function()
            local i = lib.inputDialog('Nom du modèle', { { type = 'input', label = 'ex : prop_bench_01a', required = true } })
            if i then newObject(i[1]:gsub('%s', '')) end
        end },
        { title = 'Objets favoris', icon = 'star', menu = 'gs_builder_fav' },
        { title = 'Modifier l\'objet visé', icon = 'crosshairs', onSelect = aimedObject },
        { title = 'Objets à proximité', icon = 'list', onSelect = nearbyMenu },
        { title = 'Placer une planque de gang ici', icon = 'box', onSelect = function()
            local gangs = lib.callback.await('gs_builder:gangs', false) or {}
            if #gangs == 0 then return notify(false, 'Aucun gang (crée-le avec /gsgang create).') end
            local opts = {}
            for _, g in ipairs(gangs) do opts[#opts + 1] = { value = g.name, label = g.label } end
            local i = lib.inputDialog('Planque', { { type = 'select', label = 'Gang', options = opts, required = true } })
            if i then notify(lib.callback.await('gs_builder:setStash', false, i[1])) end
        end },
    } })
    lib.showContext('gs_builder')
end

RegisterCommand('builder', openMenu, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, o in pairs(objects) do despawn(o) end
    lib.hideTextUI()
end)
