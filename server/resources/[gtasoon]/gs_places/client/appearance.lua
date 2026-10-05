-- gs_places (client) : boutiques d'apparence (illenium-appearance) avec un vrai vendeur PNJ au comptoir (coiffeur,
-- tatoueur, chirurgien, vendeuse), aussi dans les boutiques posées par le staff. Le vendeur se braque comme une caisse
-- de supérette (gs_stickup). V10.2 :
--   - coiffeur : menu de barbier classique (coupe, couleur, reflets, barbe, sourcils, maquillage) avec aperçu en
--     direct et caméra sur le visage, au lieu de l'éditeur complet ;
--   - vêtements : une tenue achetée arrive AUSSI dans le sac sous forme d'objet Tenue (gs_details).
local KINDS, STORES = AppearanceKinds, AppearanceStores
local B = Config.Barber

local peds, placed = {}, {}

--- Vendeur posé au sol (les coordonnées d'illenium sont à hauteur de joueur : on recale sur le sol réel)
local function spawnPed(key, kind, c)
    local hash = GetHashKey(kind.model)
    if not lib.requestModel(hash, 5000) then return end
    local ped = CreatePed(4, hash, c.x, c.y, c.z, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if ok and math.abs(gz - c.z) < 3.0 then SetEntityCoords(ped, c.x, c.y, gz, false, false, false, false) end
    SetEntityHeading(ped, c.w)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, kind.scenario, 0, true)
    peds[key] = ped
end

-- Le point [E] est 1 m devant le vendeur (sinon on serait dans le PNJ)
local function front(c)
    local h = math.rad(c.w)
    return vec3(c.x - math.sin(h) * 1.0, c.y + math.cos(h) * 1.0, c.z)
end

-- Boutique de vêtements : la tenue achetée devient aussi un objet --------------------------------------------------
local function outfitKey()
    local ped, t = cache.ped, {}
    for _, id in ipairs({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do t[#t + 1] = GetPedDrawableVariation(ped, id) .. ':' .. GetPedTextureVariation(ped, id) end
    for _, id in ipairs({ 0, 1, 2, 6, 7 }) do t[#t + 1] = GetPedPropIndex(ped, id) .. ':' .. GetPedPropTextureIndex(ped, id) end
    return table.concat(t, ',')
end

local function clothingShop()
    local before = outfitKey()
    TriggerEvent(KINDS.clothing.event)
    CreateThread(function()
        local t = GetGameTimer() + 5000
        while not IsNuiFocused() and GetGameTimer() < t do Wait(200) end      -- le menu s'ouvre
        while IsNuiFocused() do Wait(500) end                                 -- … puis se ferme (achat ou annulation)
        Wait(800)
        if outfitKey() ~= before and GetResourceState('gs_details') == 'started' then
            local ok, msg = pcall(function() return exports.gs_details:CopyOutfit('Tenue achetée') end)
            if ok and msg then lib.notify({ description = 'Ta nouvelle tenue est aussi dans ton sac (objet Tenue).', type = 'success' }) end
        end
    end)
end

-- Coiffeur : menu de barbier ----------------------------------------------------------------------------------------
local cam
local function faceCam(on)
    if on then
        local ped = cache.ped
        local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
        local fwd = GetEntityForwardVector(ped)
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', head.x + fwd.x * 0.9, head.y + fwd.y * 0.9, head.z + 0.05, 0.0, 0.0, 0.0, 40.0, false, 0)
        PointCamAtCoord(cam, head.x, head.y, head.z)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
    elseif cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function overlay(ped, id)
    local ok, _, value, _, c1 = pcall(GetPedHeadOverlayData, ped, id)
    local v = GetPedHeadOverlayValue(ped, id)
    return { v = (v == 255 or v == nil) and -1 or v, c = ok and c1 or 0 }
end

local function snapshot(ped)
    return { hair = GetPedDrawableVariation(ped, 2), hairTex = GetPedTextureVariation(ped, 2),
        color = GetPedHairColor(ped), light = GetPedHairHighlightColor(ped),
        beard = overlay(ped, 1), brows = overlay(ped, 2), makeup = overlay(ped, 4), lips = overlay(ped, 8) }
end

local function apply(ped, s)
    SetPedComponentVariation(ped, 2, s.hair, s.hairTex, 0)
    SetPedHairColor(ped, s.color, s.light)
    local function ov(id, o, colorType)
        if o.v < 0 then SetPedHeadOverlay(ped, id, 255, 0.0)
        else SetPedHeadOverlay(ped, id, o.v, 1.0) SetPedHeadOverlayColor(ped, id, colorType, o.c, o.c) end
    end
    ov(1, s.beard, 1) ov(2, s.brows, 1) ov(4, s.makeup, 0) ov(8, s.lips, 2)
end

local function range(from, to) local t = {} for i = from, to do t[#t + 1] = i < 0 and 'Aucun' or tostring(i + 1) end return t end

local function barber()
    local ped = cache.ped
    local orig, cur = snapshot(ped), snapshot(ped)
    local hairs = math.max(1, GetNumberOfPedDrawableVariations(ped, 2))
    local colors = math.max(1, GetNumHairColors())
    local female = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01')
    local rows = {
        { key = 'hair', label = 'Coupe', values = range(0, hairs - 1), get = function() return cur.hair + 1 end,
            set = function(i) cur.hair, cur.hairTex = i - 1, 0 end },
        { key = 'color', label = 'Couleur', values = range(0, colors - 1), get = function() return cur.color + 1 end, set = function(i) cur.color = i - 1 end },
        { key = 'light', label = 'Reflets', values = range(0, colors - 1), get = function() return cur.light + 1 end, set = function(i) cur.light = i - 1 end },
    }
    local function ovRow(field, label, id, colorLabel)
        local n = GetPedHeadOverlayNum(id)
        rows[#rows + 1] = { label = label, values = range(-1, n - 1), get = function() return cur[field].v + 2 end, set = function(i) cur[field].v = i - 2 end }
        rows[#rows + 1] = { label = colorLabel, values = range(0, colors - 1), get = function() return cur[field].c + 1 end, set = function(i) cur[field].c = i - 1 end }
    end
    if not female then ovRow('beard', 'Barbe', 1, 'Couleur de la barbe') end
    ovRow('brows', 'Sourcils', 2, 'Couleur des sourcils')
    if female then ovRow('makeup', 'Maquillage', 4, 'Teinte du maquillage') ovRow('lips', 'Rouge à lèvres', 8, 'Couleur des lèvres') end

    local options = {}
    for i, r in ipairs(rows) do options[i] = { label = r.label, values = r.values, defaultIndex = r.get(), close = false } end
    options[#options + 1] = { label = ('Valider (%d $)'):format(B.price), icon = 'scissors' }
    local done = false
    lib.registerMenu({ id = 'gs_barber', title = 'Coiffeur', position = 'top-right', options = options,
        onSideScroll = function(sel, idx) local r = rows[sel] if r then r.set(idx) apply(ped, cur) end end,
        onClose = function() if not done then apply(ped, orig) end faceCam(false) end,
    }, function(sel)
        if sel ~= #options then return end
        local ok, msg = lib.callback.await('gs_places:barber', false)
        if not ok then apply(ped, orig) faceCam(false) return lib.notify({ description = msg, type = 'error' }) end
        done = true
        faceCam(false)
        local okA, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end) -- [API]
        if okA and app then TriggerServerEvent('illenium-appearance:server:saveAppearance', app) end -- [API]
        lib.notify({ description = msg, type = 'success' })
    end)
    faceCam(true)
    lib.showMenu('gs_barber')
end

AddEventHandler('gs_places:client:appearance', function(kindName)
    if kindName == 'barber' and B.enabled then return barber() end
    if kindName == 'clothing' then return clothingShop() end
    local k = KINDS[kindName]
    if k then TriggerEvent(k.event) end
end)

-- Boutiques posées par le staff (F11) : vendeur aussi
local function placedStores()
    local out = {}
    for _, p in ipairs(GlobalState.gsPlaces or {}) do
        if p.kind == 'clothing' then out[#out + 1] = { key = 'pl:' .. p.key, kind = 'clothing', c = vec4(p.x, p.y, p.z, ((p.h or 0.0) + 180.0) % 360.0) } end
    end
    return out
end

CreateThread(function()
    if GetResourceState('illenium-appearance') == 'missing' then return end
    for i, s in ipairs(STORES) do
        local kind = KINDS[s[1]]
        exports.gs_markers:Add('gs_places:app:' .. i, { coords = front(s[2]), style = 'shop', label = kind.prompt, prompt = kind.prompt,
            event = 'gs_places:client:appearance', args = { s[1] }, reach = 1.6 })
    end
    -- Vendeurs : créés à l'approche (60 m), supprimés au départ (pas 30 PNJ permanents)
    local tick = 0
    while true do
        if tick % 20 == 0 then placed = placedStores() end
        tick = tick + 1
        local me = GetEntityCoords(cache.ped)
        local all = {}
        for i, s in ipairs(STORES) do all[#all + 1] = { key = i, kind = s[1], c = s[2] } end
        for _, p in ipairs(placed) do all[#all + 1] = p end
        for _, s in ipairs(all) do
            local d = #(me - s.c.xyz)
            if d < 60.0 and not peds[s.key] then spawnPed(s.key, KINDS[s.kind], s.c)
            elseif d > 80.0 and peds[s.key] then
                if DoesEntityExist(peds[s.key]) then DeletePed(peds[s.key]) end
                peds[s.key] = nil
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    faceCam(false)
    for _, p in pairs(peds) do if DoesEntityExist(p) then DeletePed(p) end end
end)
