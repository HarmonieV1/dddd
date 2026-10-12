-- gs_details (client) · V12.26 Garde-robe : ton personnage en grand au centre (caméra du jeu derrière l'écran), ses
-- pièces de vêtements tout autour. Clic sur une pièce portée = la retirer (elle devient un objet « Vêtement » dans le sac) ;
-- clic sur un vêtement ou une tenue du sac = l'enfiler (la pièce remplacée revient dans le sac). Touche U ou /garderobe.
-- Les vêtements s'enfilent aussi d'un double-clic dans l'inventaire (export wearCloth). Coiffure, visage, tatouages : jamais.
local W = Config.Wardrobe
local SLOT = {}
for _, s in ipairs(W.slots) do SLOT[s.key] = s end
local open, cam, view = false, nil, 'body'
local nuiReady = false -- V12.33 : l'interface a confirmé l'ouverture (sinon on referme : jamais de focus bloqué)

local function modelKey(ped) return GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') and 'f' or 'm' end
local function isFreemode(ped) local m = GetEntityModel(ped) return m == GetHashKey('mp_m_freemode_01') or m == GetHashKey('mp_f_freemode_01') end

--- Pièce portée à cet emplacement (nil = rien).
local function worn(s, ped)
    local m = modelKey(ped)
    if s.kind == 'p' then
        local d = GetPedPropIndex(ped, s.id)
        if d < 0 then return nil end
        return { key = s.key, d = d, t = math.max(GetPedPropTextureIndex(ped, s.id), 0), m = m }
    end
    local d = GetPedDrawableVariation(ped, s.id)
    if s.none and d == s.none[m] then return nil end
    local p = { key = s.key, d = d, t = GetPedTextureVariation(ped, s.id), m = m }
    if s.arms then p.a = { GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3) } end
    return p
end

local function save()
    if GSFixUndershirt then GSFixUndershirt(cache.ped) end
    local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(cache.ped) end) -- [API]
    if ok and app then TriggerServerEvent('illenium-appearance:server:saveAppearance', app) end -- [API]
end

local function wearPiece(p)
    local s, ped = SLOT[p.key], cache.ped
    if s.kind == 'p' then SetPedPropIndex(ped, s.id, p.d, p.t, true)
    else
        SetPedComponentVariation(ped, s.id, p.d, p.t, 0)
        if s.arms and p.a then SetPedComponentVariation(ped, 3, p.a[1], p.a[2], 0) end
    end
end

local function removePiece(s)
    local ped, m = cache.ped, modelKey(cache.ped)
    if s.kind == 'p' then ClearPedProp(ped, s.id)
    else
        SetPedComponentVariation(ped, s.id, s.none[m], 0, 0)
        if s.arms then SetPedComponentVariation(ped, 3, s.arms[m], 0, 0) end
    end
end

local function anim(dict, clip, ms)
    if open then return end -- pendant la garde-robe : pas d'animation (la caméra cadre le personnage immobile)
    lib.requestAnimDict(dict, 1000)
    TaskPlayAnim(cache.ped, dict, clip, 8.0, -8.0, ms, 48, 0, false, false, false)
    RemoveAnimDict(dict)
end

--- État envoyé à l'écran : chaque emplacement (porté ou non) + le sac.
local function state()
    local ped, slots = cache.ped, {}
    for _, s in ipairs(W.slots) do
        local p = worn(s, ped)
        slots[#slots + 1] = { key = s.key, label = s.label, image = s.image, side = s.side, worn = p ~= nil,
            detail = p and ('modèle %d · coloris %d'):format(p.d, p.t) or nil }
    end
    local bag = lib.callback.await('gs_details:wardrobeBag', false) or { pieces = {}, outfits = {} }
    local m = modelKey(ped)
    for _, b in ipairs(bag.pieces) do b.fits = b.m == m end
    for _, o in ipairs(bag.outfits) do o.fits = (o.m or m) == m end
    local ok, name = pcall(function() return exports.gs_bridge:GetCharName() end)
    return { slots = slots, bag = bag, name = ok and name or GetPlayerName(PlayerId()), view = view }
end

local function refresh() if open then SendNUIMessage({ action = 'state', data = state() }) end end

-- Caméra : le personnage en pied, de face (ou visage / jambes), comme dans une cabine d'essayage.
local VIEWS = { body = { 0.0, 2.6, 0.15, 0.0, 0.0, -0.05, 42.0 }, face = { 0.0, 0.95, 0.65, 0.0, 0.0, 0.62, 40.0 }, legs = { 0.0, 1.6, -0.45, 0.0, 0.0, -0.55, 45.0 } }
local baseHeading = 0.0 -- orientation du personnage à l'ouverture : la caméra reste fixe, seul le personnage tourne
local function offset(x, y, z)
    local c, h = GetEntityCoords(cache.ped), math.rad(baseHeading)
    return vector3(c.x + x * math.cos(h) - y * math.sin(h), c.y + x * math.sin(h) + y * math.cos(h), c.z + z)
end
local function placeCam()
    local v = VIEWS[view] or VIEWS.body
    local from, at = offset(v[1], v[2], v[3]), offset(v[4], v[5], v[6])
    local fresh = not cam
    if fresh then cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamCoord(cam, from.x, from.y, from.z)
    PointCamAtCoord(cam, at.x, at.y, at.z)
    SetCamFov(cam, v[7])
    if fresh then
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 400, true, true)
    end
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    RenderScriptCams(false, true, 400, true, true)
    if cam then DestroyCam(cam, false) cam = nil end
    SetEntityHeading(cache.ped, baseHeading) -- le joueur repart dans le sens où il était
    FreezeEntityPosition(cache.ped, false)
    save()
end

local function openWardrobe()
    if open then return close() end
    if IsControlPressed(0, 36) or IsDisabledControlPressed(0, 36) then return end -- Ctrl + U = vol libre du staff, pas la garde-robe
    if IsNuiFocused() then return end -- V12.33 : une autre interface est ouverte (téléphone, inventaire…)
    local ped = cache.ped
    if cache.vehicle then return lib.notify({ description = 'Descends du véhicule.', type = 'error' }) end
    if not isFreemode(ped) then return lib.notify({ description = 'Garde-robe réservée aux personnages créés (pas aux personnages spéciaux).', type = 'error' }) end
    if IsPedDeadOrDying(ped, true) or IsPedCuffed(ped) or IsPedRagdoll(ped) or IsPedInMeleeCombat(ped) or LocalPlayer.state.invBusy then return end
    open, view = true, 'body'
    baseHeading = GetEntityHeading(ped)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    placeCam()
    nuiReady = false
    SendNUIMessage({ action = 'open', data = state() })
    SetNuiFocus(true, true)
    -- V12.33 : si l'interface ne confirme pas en 3 s (page non chargée, cache abîmé), on referme : F4 et les autres touches restent libres
    SetTimeout(3000, function()
        if open and not nuiReady then
            close()
            lib.notify({ description = 'Garde-robe indisponible (interface non chargée) : lance VIDER-CACHE-FIVEM.bat puis reconnecte-toi.', type = 'error', duration = 8000 })
        end
    end)
    -- Sécurité : si le joueur tombe, meurt ou est menotté pendant la garde-robe, on ferme.
    CreateThread(function()
        while open do
            if IsPedDeadOrDying(cache.ped, true) or IsPedCuffed(cache.ped) or cache.vehicle then close() end
            Wait(250)
        end
    end)
end

RegisterCommand('garderobe', openWardrobe, false)
RegisterKeyMapping('garderobe', 'Garde-robe (vêtements en objets)', 'keyboard', W.key)
exports('OpenWardrobe', openWardrobe)

-- Écran → jeu --------------------------------------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) close() cb(1) end)
RegisterNUICallback('ready', function(_, cb) nuiReady = true cb(1) end) -- V12.33

RegisterNUICallback('rotate', function(d, cb)
    local ped = cache.ped
    SetEntityHeading(ped, GetEntityHeading(ped) + ((tonumber(d.dir) or 1) > 0 and 30.0 or -30.0)) -- caméra fixe : on voit le dos
    cb(1)
end)

RegisterNUICallback('view', function(d, cb)
    if VIEWS[d.view] then view = d.view placeCam() end
    cb(1)
end)

RegisterNUICallback('takeOff', function(d, cb)
    local s = SLOT[d.key]
    local p = s and worn(s, cache.ped)
    if not p then cb(1) return refresh() end
    local ok, msg = lib.callback.await('gs_details:takeOffPiece', false, p)
    if ok then removePiece(s) end
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
    refresh()
    cb(1)
end)

local function wearFromBag(slot, key)
    local s = SLOT[key]
    if not s then return false end
    local ok, res = lib.callback.await('gs_details:wearPiece', false, slot, worn(s, cache.ped), modelKey(cache.ped))
    if not ok then lib.notify({ description = res, type = 'error' }) return false end
    wearPiece(res)
    return true
end

RegisterNUICallback('wear', function(d, cb)
    if wearFromBag(tonumber(d.slot) or 0, d.key) then lib.notify({ description = (SLOT[d.key] and SLOT[d.key].label or 'Vêtement') .. ' enfilé.', type = 'success' }) end
    refresh()
    cb(1)
end)

RegisterNUICallback('wearOutfit', function(d, cb)
    local before = exports.gs_details:CurrentOutfit()
    local ok, outfit, label = lib.callback.await('gs_details:takeOutfit', false, tonumber(d.slot) or 0, modelKey(cache.ped))
    if ok then
        exports.gs_details:ApplyOutfit(outfit)
        lib.callback.await('gs_details:foldOutfit', false, 'Tenue précédente', before)
        lib.notify({ description = ('Tu portes « %s ». Ta tenue précédente est dans ton sac.'):format(label or 'la tenue'), type = 'success' })
    else lib.notify({ description = outfit, type = 'error' }) end
    refresh()
    cb(1)
end)

RegisterNUICallback('fold', function(_, cb)
    local ok, msg = lib.callback.await('gs_details:foldOutfit', false, 'Ma tenue', exports.gs_details:CurrentOutfit())
    lib.notify({ description = ok and 'Copie de ta tenue rangée dans ton sac (« Ma tenue »).' or msg, type = ok and 'success' or 'error' })
    refresh()
    cb(1)
end)

--- Double-clic sur un Vêtement dans l'inventaire (ox_inventory : client.export = 'gs_details.wearCloth').
exports('wearCloth', function(_, slot)
    local piece = slot and slot.metadata and slot.metadata.piece
    if type(piece) ~= 'table' or not SLOT[piece.key] then return lib.notify({ description = 'Vêtement abîmé.', type = 'error' }) end
    if cache.vehicle then return lib.notify({ description = 'Descends du véhicule.', type = 'error' }) end
    if wearFromBag(slot.slot, piece.key) then
        anim('clothingshirt', 'try_shirt_positive_d', 1800)
        lib.notify({ description = SLOT[piece.key].label .. ' enfilé.', type = 'success' })
        save()
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and open then close() end end)
