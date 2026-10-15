-- gs_showroom (client) · V12.40 : véhicules d'exposition (entités locales, figées, invincibles, verrouillées) créés à
-- l'approche (boucle lente 2 s, jamais par image) ; Alt dessus : prix, essayer 2 min, acheter, changer de modèle (vendeur).
-- Menu staff (F11 → Monde et lieux → Concessions) : poser un véhicule ici, départ des essais, liste, retirer.
local Bridge = exports.gs_bridge
local shown = {}   -- [id] = { veh, model }
local placed = {}  -- V12.62 : [id] = true une fois apparu (un changement de modèle réapparaît même si le vendeur est collé à la voiture)
local failed = {}  -- V12.62 : [id .. modèle] = true : modèle introuvable / trop long à charger (prévenu une fois, pas de boucle)
local state = { slots = {}, starts = {} }
local testing
local isStaff = false -- V12.41 : le staff voit aussi « Changer le modèle » au Alt (demandé au serveur, pas deviné)

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function catalog()
    local ok, all = pcall(function() return exports.qbx_core:GetVehiclesByName() end) -- [API] qbx_core
    return ok and type(all) == 'table' and all or {}
end

local function info(model)
    local v = catalog()[model]
    if not v then return model, 0 end
    return ((v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. (v.name or model)), tonumber(v.price) or 0
end

local function money(n) return (tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' $' end

local function remove(id)
    local s = shown[id]
    if not s then return end
    if DoesEntityExist(s.veh) then
        exports.ox_target:removeLocalEntity(s.veh) -- [API] ox_target
        DeleteEntity(s.veh)
    end
    shown[id] = nil
end

local pickModel -- (défini plus bas)

local function targetOptions(slot)
    return {
        { name = 'gs_showroom_info', icon = 'fa-solid fa-tag', label = 'Prix et infos', distance = Config.Range,
            onSelect = function() local name, price = info(slot.model) notify(true, ('%s · %s'):format(name, money(price))) end },
        { name = 'gs_showroom_test', icon = 'fa-solid fa-flag-checkered', label = ('Essayer (%d min)'):format(math.floor(Config.TestDrive.seconds / 60)),
            distance = Config.Range, canInteract = function() return testing == nil end,
            onSelect = function()
                local ok, msg, seconds = lib.callback.await('gs_showroom:test', false, slot.id)
                notify(ok, msg)
                if ok then
                    testing = GetGameTimer() + (seconds or Config.TestDrive.seconds) * 1000
                    CreateThread(function()
                        while testing do
                            local left = math.max(0, math.floor((testing - GetGameTimer()) / 1000))
                            lib.showTextUI(('Essai : %d:%02d · /finessai pour arrêter'):format(left // 60, left % 60), { position = 'top-center' })
                            Wait(1000)
                        end
                        lib.hideTextUI()
                    end)
                end
            end },
        { name = 'gs_showroom_buy', icon = 'fa-solid fa-cart-shopping', label = 'Acheter', distance = Config.Range,
            onSelect = function()
                local name, price = info(slot.model)
                local c = lib.alertDialog({ header = 'Acheter ' .. name .. ' ?', centered = true, cancel = true,
                    content = ('Prix : **%s** (carte, sinon espèces). Le véhicule est livré dans tes garages.'):format(money(price)) })
                if c ~= 'confirm' then return end
                notify(lib.callback.await('gs_showroom:buy', false, slot.id))
            end },
        -- V12.62 : sans vendeur en service, tout le monde peut choisir le modèle exposé (le serveur vérifie qu'aucun vendeur n'est là)
        { name = 'gs_showroom_model', icon = 'fa-solid fa-arrows-rotate', label = 'Changer le modèle exposé', distance = Config.Range,
            onSelect = function() pickModel(function(model) notify(lib.callback.await('gs_showroom:setModel', false, slot.id, model)) end) end },
    }
end

local spawning = {}
local spawnSlot
local function spawn(slot)
    if spawning[slot.id] then return end -- la boucle et le changement de modèle ne créent jamais deux voitures
    spawning[slot.id] = true
    local ok, err = pcall(spawnSlot, slot)
    spawning[slot.id] = nil
    if not ok then print(('^3[gs_showroom] véhicule exposé n°%s : %s^0'):format(slot.id, tostring(err))) end
end
function spawnSlot(slot)
    local key = slot.id .. ':' .. slot.model
    if failed[key] or shown[slot.id] then return end
    local hash = GetHashKey(slot.model)
    -- V12.62 : modèle absent (mod pas installé / en pause) ou trop long à charger : on le dit au lieu de « charger » sans fin
    if not IsModelInCdimage(hash) or not pcall(lib.requestModel, hash, 10000) then
        failed[key] = true
        if #(GetEntityCoords(cache.ped) - vec3(slot.x, slot.y, slot.z)) < 25.0 then
            notify(false, ('Véhicule « %s » introuvable dans le jeu (mod pas installé, en pause ou pas encore téléchargé). Choisis un autre modèle.'):format(slot.model))
        end
        return
    end
    -- V12.62 : posé AU SOL (avant : créé à la hauteur des hanches du staff qui a posé l'emplacement puis figé, sol pas encore chargé)
    RequestCollisionAtCoord(slot.x, slot.y, slot.z)
    local found, gz = GetGroundZFor_3dCoord(slot.x, slot.y, slot.z + 1.0, false)
    local z = (found and math.abs(gz - slot.z) < 3.0) and gz or (slot.z - 0.9)
    local v = CreateVehicle(hash, slot.x, slot.y, z, slot.h, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not v or v == 0 then return end
    SetEntityHeading(v, slot.h)
    local t = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(v) and GetGameTimer() < t do Wait(50) end
    for _ = 1, 10 do if SetVehicleOnGroundProperly(v) then break end Wait(50) end
    FreezeEntityPosition(v, true)
    SetEntityInvincible(v, true)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleNumberPlateText(v, 'EXPO')
    SetVehicleDirtLevel(v, 0.0)
    SetVehicleEngineOn(v, false, true, true)
    exports.ox_target:addLocalEntity(v, targetOptions(slot)) -- [API] ox_target
    shown[slot.id] = { veh = v, model = slot.model }
    placed[slot.id] = true
end

AddStateBagChangeHandler('gsShowroom', 'global', function(_, _, value)
    state = type(value) == 'table' and value or { slots = {}, starts = {} }
    local keep = {}
    for _, s in ipairs(state.slots or {}) do keep[s.id] = s.model end
    for id, s in pairs(shown) do if keep[id] ~= s.model then remove(id) end end -- retiré ou modèle changé : recréé à l'approche
    -- V12.62 : nouveau modèle affiché tout de suite (avant : jusqu'à 2 s, et jamais si le vendeur restait à moins de 3 m)
    CreateThread(function()
        local me = GetEntityCoords(cache.ped)
        for _, s in ipairs(state.slots or {}) do
            if placed[s.id] and not shown[s.id] and #(me - vec3(s.x, s.y, s.z)) < Config.StreamRange then spawn(s) end
        end
    end)
end)

-- Boucle lente : création / retrait selon la distance (rien à faire sans emplacement)
CreateThread(function()
    Wait(2000)
    if GlobalState.gsShowroom then state = GlobalState.gsShowroom end
    isStaff = lib.callback.await('gs_showroom:me', false) == true
    while true do
        if state.slots and #state.slots > 0 then
            local me = GetEntityCoords(cache.ped)
            for _, s in ipairs(state.slots) do
                local d = #(me - vec3(s.x, s.y, s.z))
                -- pas sur la tête de quelqu'un : on attend qu'il s'écarte (le staff qui vient de poser l'emplacement)
                if d < Config.StreamRange and (d > 3.0 or placed[s.id]) and not shown[s.id] then spawn(s)
                elseif d > Config.StreamRange + 20.0 and shown[s.id] then remove(s.id) end
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('gs_showroom:client:testEnd', function(why)
    testing = nil
    lib.hideTextUI()
    notify(true, why)
end)

RegisterCommand('finessai', function() if testing then lib.callback.await('gs_showroom:stopTest', false) end end, false)

--- Catalogue par catégorie → callback(model)
pickModel = function(cb)
    local byCat = {}
    for model, v in pairs(catalog()) do
        if not Config.Excluded[v.category or ''] and tonumber(v.price) and tonumber(v.price) > 0 then
            byCat[v.category or 'autre'] = byCat[v.category or 'autre'] or {}
            table.insert(byCat[v.category or 'autre'], { model = model, label = ((v.brand or '') .. ' ' .. (v.name or model)):gsub('^ ', ''), price = tonumber(v.price) })
        end
    end
    local cats = {}
    for c, l in pairs(byCat) do table.sort(l, function(a, b) return a.label < b.label end) cats[#cats + 1] = c end
    table.sort(cats)
    local o = {}
    for _, c in ipairs(cats) do
        o[#o + 1] = { title = c, arrow = true, description = ('%d modèle(s)'):format(#byCat[c]), onSelect = function()
            local l = {}
            for _, e in ipairs(byCat[c]) do
                l[#l + 1] = { title = e.label, description = money(e.price), onSelect = function() cb(e.model) end }
            end
            lib.registerContext({ id = 'gs_showroom_models', title = c, menu = 'gs_showroom_cats', options = l })
            lib.showContext('gs_showroom_models')
        end }
    end
    lib.registerContext({ id = 'gs_showroom_cats', title = 'Catalogue', options = o })
    lib.showContext('gs_showroom_cats')
end

--- Menu staff (appelé par gs_admin, F11 → Monde et lieux → Concessions)
local function staffMenu()
    isStaff = true -- ouvert depuis F11 (déjà contrôlé par gs_admin ; le serveur revérifie chaque action)
    local o = {}
    for id, d in pairs(Config.Dealers) do
        local count = 0
        for _, s in ipairs(state.slots or {}) do if s.dealer == id then count = count + 1 end end
        o[#o + 1] = { title = d.label, icon = 'car', arrow = true,
            description = ('%d véhicule(s) exposé(s) · départ des essais : %s'):format(count, state.starts and state.starts[id] and 'posé' or 'à poser'),
            onSelect = function()
                local m = {
                    { title = 'Exposer un véhicule ICI', icon = 'plus', description = 'Place-toi à l\'emplacement voulu, face au sens voulu', onSelect = function()
                        pickModel(function(model) notify(lib.callback.await('gs_showroom:staff', false, 'add', { dealer = id, model = model })) end) end },
                    { title = 'Départ des essais ICI', icon = 'flag-checkered', description = 'Sur la route, dans le sens de la sortie', onSelect = function()
                        notify(lib.callback.await('gs_showroom:staff', false, 'start', { dealer = id })) end },
                }
                for _, s in ipairs(state.slots or {}) do
                    if s.dealer == id then
                        local name = info(s.model)
                        m[#m + 1] = { title = ('n°%d · %s'):format(s.id, name), icon = 'car-side', arrow = true, onSelect = function()
                            lib.registerContext({ id = 'gs_showroom_slot', title = ('n°%d · %s'):format(s.id, name), menu = 'gs_showroom_dealer', options = {
                                { title = 'Y aller', icon = 'location-arrow', onSelect = function() SetEntityCoords(cache.ped, s.x, s.y, s.z + 1.0, false, false, false, false) end },
                                { title = 'Replacer ICI', icon = 'up-down-left-right', description = 'Ta position et ton cap actuels', onSelect = function()
                                    notify(lib.callback.await('gs_showroom:staff', false, 'move', { id = s.id })) end },
                                { title = 'Changer le modèle', icon = 'arrows-rotate', onSelect = function()
                                    pickModel(function(model) notify(lib.callback.await('gs_showroom:setModel', false, s.id, model)) end) end },
                                { title = 'Retirer', icon = 'trash', iconColor = '#ff6b6b', onSelect = function()
                                    notify(lib.callback.await('gs_showroom:staff', false, 'remove', { id = s.id })) end },
                            } })
                            lib.showContext('gs_showroom_slot')
                        end }
                    end
                end
                lib.registerContext({ id = 'gs_showroom_dealer', title = d.label, menu = 'gs_showroom_staff', options = m })
                lib.showContext('gs_showroom_dealer')
            end }
    end
    lib.registerContext({ id = 'gs_showroom_staff', title = 'Concessions : véhicules d\'exposition', options = o })
    lib.showContext('gs_showroom_staff')
end
exports('OpenStaffMenu', staffMenu)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(shown) do remove(id) end
    if testing then lib.hideTextUI() end
end)
