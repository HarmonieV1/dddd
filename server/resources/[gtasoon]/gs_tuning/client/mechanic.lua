-- gs_tuning (client) : personnalisation complète par le mécano en service (LS Customs). Il vise le véhicule d'un client
-- (Alt), aperçu en direct, puis « Valider » : enregistré sur le véhicule possédé (garage). « Annuler » remet tout comme avant.
-- La facture se fait comme d'habitude (F6 → Facture).
local Bridge = exports.gs_bridge
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local PERF = { { 11, 'Moteur' }, { 12, 'Freins' }, { 13, 'Transmission' }, { 15, 'Suspension' }, { 16, 'Blindage' } }
local LOOK = { { 0, 'Aileron' }, { 1, 'Pare-chocs avant' }, { 2, 'Pare-chocs arrière' }, { 3, 'Bas de caisse' }, { 4, 'Échappement' },
    { 5, 'Arceau' }, { 6, 'Calandre' }, { 7, 'Capot' }, { 8, 'Aile gauche' }, { 9, 'Aile droite' }, { 10, 'Toit' }, { 14, 'Klaxon' },
    { 25, 'Support de plaque' }, { 48, 'Livrée' } }
local COLORS = { { 'Noir', 0 }, { 'Graphite', 1 }, { 'Argent', 4 }, { 'Blanc', 111 }, { 'Rouge', 27 }, { 'Rouge sombre', 31 },
    { 'Orange', 38 }, { 'Jaune', 88 }, { 'Vert', 53 }, { 'Vert citron', 55 }, { 'Bleu nuit', 62 }, { 'Bleu', 64 }, { 'Bleu vif', 70 },
    { 'Violet', 145 }, { 'Rose', 135 }, { 'Marron', 96 }, { 'Or', 158 }, { 'Acier brossé', 117 }, { 'Noir mat', 12 }, { 'Gris mat', 13 } }
local TINTS = { { 'Aucune', 0 }, { 'Fumée légère', 3 }, { 'Fumée foncée', 2 }, { 'Limousine', 1 }, { 'Verte', 5 } }
local WHEEL_TYPES = { { 'Sport', 0 }, { 'Muscle', 1 }, { 'Lowrider', 2 }, { 'SUV', 3 }, { 'Tout-terrain', 4 }, { 'Tuner', 5 }, { 'Haut de gamme', 7 } }
local XENON = { { 'Blanc', -1 }, { 'Bleu', 1 }, { 'Bleu électrique', 2 }, { 'Vert menthe', 3 }, { 'Vert acide', 4 }, { 'Jaune', 5 },
    { 'Or', 6 }, { 'Orange', 7 }, { 'Rouge', 8 }, { 'Rose', 9 }, { 'Violet', 11 } }

local veh, original

local function mechanicOnDuty()
    local j = Bridge:GetJob()
    return j and j.name == 'mechanic' and j.onduty
end

local function control()
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do NetworkRequestControlOfEntity(veh) Wait(50) end
    return NetworkHasControlOfEntity(veh)
end

local openMain

local function modLabel(modType, i)
    if i < 0 then return 'D\'origine' end
    local txt = GetModTextLabel(veh, modType, i)
    local lbl = txt and GetLabelText(txt)
    return (lbl and lbl ~= 'NULL' and lbl ~= '') and lbl or ('Option %d'):format(i + 1)
end

local function modMenu(modType, title, parent)
    local n = GetNumVehicleMods(veh, modType)
    local cur = GetVehicleMod(veh, modType)
    local options = {}
    for i = -1, n - 1 do
        options[#options + 1] = { title = modLabel(modType, i), icon = cur == i and 'check' or 'circle', iconColor = cur == i and '#5aff8c' or nil,
            onSelect = function()
                if control() then SetVehicleModKit(veh, 0) SetVehicleMod(veh, modType, i, false) end
                modMenu(modType, title, parent)
            end }
    end
    lib.registerContext({ id = 'gs_meca_mod', title = title, menu = parent, options = options })
    lib.showContext('gs_meca_mod')
end

local function listMenu(id, title, list, parent, apply, current)
    local options = {}
    for _, e in ipairs(list) do
        options[#options + 1] = { title = e[1], icon = current == e[2] and 'check' or 'circle', iconColor = current == e[2] and '#5aff8c' or nil,
            onSelect = function() if control() then apply(e[2]) end listMenu(id, title, list, parent, apply, e[2]) end }
    end
    lib.registerContext({ id = id, title = title, menu = parent, options = options })
    lib.showContext(id)
end

local function categoryMenu(id, title, list)
    local options = {}
    for _, m in ipairs(list) do
        if GetNumVehicleMods(veh, m[1]) > 0 then
            options[#options + 1] = { title = m[2], description = modLabel(m[1], GetVehicleMod(veh, m[1])), arrow = true,
                onSelect = function() modMenu(m[1], m[2], id) end }
        end
    end
    if id == 'gs_meca_perf' then
        local on = IsToggleModOn(veh, 18)
        options[#options + 1] = { title = ('Turbo : %s'):format(on and 'oui' or 'non'), icon = 'wind',
            onSelect = function() if control() then SetVehicleModKit(veh, 0) ToggleVehicleMod(veh, 18, not on) end categoryMenu(id, title, list) end }
    end
    if #options == 0 then options[1] = { title = 'Rien de disponible sur ce modèle', readOnly = true } end
    lib.registerContext({ id = id, title = title, menu = 'gs_meca_main', options = options })
    lib.showContext(id)
end

local function paintMenu()
    local p, s = GetVehicleColours(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    lib.registerContext({ id = 'gs_meca_paint', title = 'Peinture', menu = 'gs_meca_main', options = {
        { title = 'Couleur principale', arrow = true, onSelect = function() listMenu('gs_meca_c1', 'Couleur principale', COLORS, 'gs_meca_paint',
            function(v) local _, b = GetVehicleColours(veh) SetVehicleColours(veh, v, b) end, p) end },
        { title = 'Couleur secondaire', arrow = true, onSelect = function() listMenu('gs_meca_c2', 'Couleur secondaire', COLORS, 'gs_meca_paint',
            function(v) local a = GetVehicleColours(veh) SetVehicleColours(veh, a, v) end, s) end },
        { title = 'Nacré', arrow = true, onSelect = function() listMenu('gs_meca_pearl', 'Nacré', COLORS, 'gs_meca_paint',
            function(v) local _, w = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, v, w) end, pearl) end },
        { title = 'Couleur des jantes', arrow = true, onSelect = function() listMenu('gs_meca_wcol', 'Couleur des jantes', COLORS, 'gs_meca_paint',
            function(v) local pe = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, pe, v) end, wheel) end },
    } })
    lib.showContext('gs_meca_paint')
end

local function wheelsMenu()
    lib.registerContext({ id = 'gs_meca_wheels', title = 'Jantes', menu = 'gs_meca_main', options = {
        { title = 'Type de jantes', arrow = true, onSelect = function() listMenu('gs_meca_wtype', 'Type de jantes', WHEEL_TYPES, 'gs_meca_wheels',
            function(v) SetVehicleWheelType(veh, v) SetVehicleModKit(veh, 0) SetVehicleMod(veh, 23, -1, false) end, GetVehicleWheelType(veh)) end },
        { title = 'Modèle de jantes', arrow = true, onSelect = function() modMenu(23, 'Modèle de jantes', 'gs_meca_wheels') end },
    } })
    lib.showContext('gs_meca_wheels')
end

local function save()
    local props = lib.getVehicleProperties(veh) -- [API] ox_lib
    local ok, msg = lib.callback.await('gs_tuning:mechanicSave', false, VehToNet(veh), props)
    notify(ok, msg)
    if ok then original = nil veh = nil end
end

local function cancel()
    if veh and original and DoesEntityExist(veh) and control() then lib.setVehicleProperties(veh, original) end -- [API] ox_lib
    veh, original = nil, nil
    notify(true, 'Modifications annulées.')
end

openMain = function()
    lib.registerContext({ id = 'gs_meca_main', title = 'Personnalisation (mécano)', onExit = function() end, options = {
        { title = 'Performances', icon = 'gauge-high', arrow = true, onSelect = function() categoryMenu('gs_meca_perf', 'Performances', PERF) end },
        { title = 'Carrosserie', icon = 'car-side', arrow = true, onSelect = function() categoryMenu('gs_meca_look', 'Carrosserie', LOOK) end },
        { title = 'Peinture', icon = 'palette', arrow = true, onSelect = paintMenu },
        { title = 'Jantes', icon = 'circle-dot', arrow = true, onSelect = wheelsMenu },
        { title = 'Vitres teintées', icon = 'window-maximize', arrow = true, onSelect = function()
            listMenu('gs_meca_tint', 'Vitres teintées', TINTS, 'gs_meca_main', function(v) SetVehicleWindowTint(veh, v) end, GetVehicleWindowTint(veh)) end },
        { title = 'Phares xénon', icon = 'lightbulb', arrow = true, onSelect = function()
            listMenu('gs_meca_xenon', 'Phares xénon', XENON, 'gs_meca_main', function(v)
                SetVehicleModKit(veh, 0) ToggleVehicleMod(veh, 22, true) SetVehicleXenonLightsColor(veh, v) end, GetVehicleXenonLightsColor(veh)) end },
        { title = 'Valider (enregistrer sur le véhicule)', icon = 'floppy-disk', iconColor = '#5aff8c', onSelect = save },
        { title = 'Annuler tout', icon = 'rotate-left', iconColor = '#ff2e88', onSelect = cancel },
    } })
    lib.showContext('gs_meca_main')
end

CreateThread(function()
    exports.ox_target:addGlobalVehicle({ { -- [API] ox_target
        name = 'gs_meca_custom', icon = 'fa-solid fa-paint-roller', label = 'Personnaliser (mécano)', distance = 3.0,
        canInteract = function(ent) return not cache.vehicle and mechanicOnDuty() end,
        onSelect = function(data)
            local ok, msg = lib.callback.await('gs_tuning:mechanicCheck', false, VehToNet(data.entity))
            if not ok then return notify(false, msg) end
            if veh ~= data.entity then veh, original = data.entity, lib.getVehicleProperties(data.entity) end
            openMain()
        end,
    } })
end)
