-- gs_showroom (client) · V12.40 : véhicules d'exposition (entités locales, figées, invincibles, verrouillées) créés à
-- l'approche (boucle lente 2 s, jamais par image) ; Alt dessus : prix, essayer 2 min, acheter, changer de modèle (vendeur).
-- Menu staff (F11 → Monde et lieux → Concessions) : poser un véhicule ici, départ des essais, liste, retirer.
local Bridge = exports.gs_bridge
local shown = {}   -- [id] = { veh, model }
local state = { slots = {}, starts = {} }
local testing

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
        { name = 'gs_showroom_model', icon = 'fa-solid fa-arrows-rotate', label = 'Changer le modèle exposé (vendeur)', distance = Config.Range,
            canInteract = function()
                local j = Bridge:GetJob()
                local d = Config.Dealers[slot.dealer]
                if not j or not j.onduty or not d then return false end
                for _, job in ipairs(d.jobs or {}) do if job == j.name then return true end end
                return false
            end,
            onSelect = function() pickModel(function(model) notify(lib.callback.await('gs_showroom:setModel', false, slot.id, model)) end) end },
    }
end

local function spawn(slot)
    local hash = GetHashKey(slot.model)
    if not IsModelInCdimage(hash) then return end
    if not pcall(lib.requestModel, hash, 5000) then return end
    local v = CreateVehicle(hash, slot.x, slot.y, slot.z, slot.h, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not v or v == 0 then return end
    SetEntityHeading(v, slot.h)
    SetVehicleOnGroundProperly(v)
    FreezeEntityPosition(v, true)
    SetEntityInvincible(v, true)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleNumberPlateText(v, 'EXPO')
    SetVehicleDirtLevel(v, 0.0)
    SetVehicleEngineOn(v, false, true, true)
    exports.ox_target:addLocalEntity(v, targetOptions(slot)) -- [API] ox_target
    shown[slot.id] = { veh = v, model = slot.model }
end

AddStateBagChangeHandler('gsShowroom', 'global', function(_, _, value)
    state = type(value) == 'table' and value or { slots = {}, starts = {} }
    local keep = {}
    for _, s in ipairs(state.slots or {}) do keep[s.id] = s.model end
    for id, s in pairs(shown) do if keep[id] ~= s.model then remove(id) end end -- retiré ou modèle changé : recréé à l'approche
end)

-- Boucle lente : création / retrait selon la distance (rien à faire sans emplacement)
CreateThread(function()
    Wait(2000)
    if GlobalState.gsShowroom then state = GlobalState.gsShowroom end
    while true do
        if state.slots and #state.slots > 0 then
            local me = GetEntityCoords(cache.ped)
            for _, s in ipairs(state.slots) do
                local d = #(me - vec3(s.x, s.y, s.z))
                if d < Config.StreamRange and not shown[s.id] then spawn(s)
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
