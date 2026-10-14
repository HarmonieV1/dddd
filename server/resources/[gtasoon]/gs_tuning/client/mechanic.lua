-- gs_tuning (client) : personnalisation complète par le mécano en service (atelier Benny's). Il vise le véhicule d'un client
-- (Alt), essaie les pièces en direct, puis « Valider » : il fait le travail (capot ouvert, outils, peinture…) et c'est
-- enregistré sur le véhicule possédé (garage), avec une facture automatique au client. « Annuler » remet tout comme avant.
-- V12.36 · Réglages validés appliqués par le propriétaire réseau (gs_tuning:client:applyProps), gardés au garage.
-- V12.40 · Refonte (« le joueur en face ne voit pas, pas d'interaction réelle, menu basique ») :
--  - aperçu VU PAR TOUS : chaque choix est appliqué ici (immédiat pour le mécano) ET envoyé au serveur, qui le fait appliquer
--    par le propriétaire réseau du véhicule (avant : rien ne se synchronisait si le mécano n'avait pas la main) ;
--  - plus besoin de « prendre la main » ni que le client descende pour essayer ;
--  - menu complet : performances (niveaux et prix), toutes les pièces de carrosserie et d'intérieur du modèle, peinture
--    (types, palettes, couleur sur mesure), jantes (types, modèles, fumée de pneus), néons (côtés + couleurs), xénon, vitres,
--    plaque, livrées, extras ; panier en tête (pièces, total) ;
--  - vrai travail à la validation : capot ouvert + clé à molette (performances), soudure (carrosserie), bombe de peinture,
--    à genoux aux roues (jantes), un passage par type de travail ;
--  - facture automatique au client (prix recalculés par le serveur) ; abandon (mécano parti, fin de service) = retour d'origine.
local Bridge = exports.gs_bridge
local M = Config.Mechanic
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local PERF = { { 11, 'modEngine', 'Moteur' }, { 12, 'modBrakes', 'Freins' }, { 13, 'modTransmission', 'Transmission' },
    { 15, 'modSuspension', 'Suspension' }, { 16, 'modArmor', 'Blindage' } }
local BODY = { { 0, 'Aileron' }, { 1, 'Pare-chocs avant' }, { 2, 'Pare-chocs arrière' }, { 3, 'Bas de caisse' }, { 4, 'Échappement' },
    { 5, 'Arceau' }, { 6, 'Calandre' }, { 7, 'Capot' }, { 8, 'Aile gauche' }, { 9, 'Aile droite' }, { 10, 'Toit' },
    { 25, 'Support de plaque' }, { 26, 'Plaque de vanité' }, { 37, 'Coffre' }, { 38, 'Hydraulique' }, { 39, 'Bloc moteur' },
    { 40, 'Filtre à air' }, { 41, 'Barres anti-rapprochement' }, { 42, 'Passage de roue' }, { 43, 'Antennes' }, { 44, 'Garnitures ext.' },
    { 45, 'Réservoir' }, { 46, 'Vitres' }, { 14, 'Klaxon' } }
local INTERIOR = { { 27, 'Garnitures' }, { 28, 'Ornements' }, { 29, 'Tableau de bord' }, { 30, 'Cadrans' }, { 31, 'Haut-parleurs de portes' },
    { 32, 'Sièges' }, { 33, 'Volant' }, { 34, 'Levier de vitesse' }, { 35, 'Plaque intérieure' }, { 36, 'Haut-parleurs' } }
local PAINT_TYPES = { { 'Classique', 0 }, { 'Métallisée', 1 }, { 'Nacrée', 2 }, { 'Mate', 3 }, { 'Métal brossé', 4 }, { 'Chrome', 5 } }
local PALETTES = {
    { 'Classiques', { { 'Noir', 0 }, { 'Noir carbone', 147 }, { 'Graphite', 1 }, { 'Gris anthracite', 11 }, { 'Argent', 4 }, { 'Gris acier', 6 },
        { 'Blanc', 111 }, { 'Blanc glacier', 112 }, { 'Rouge', 27 }, { 'Rouge course', 29 }, { 'Bordeaux', 34 }, { 'Orange', 38 },
        { 'Jaune', 88 }, { 'Jaune course', 89 }, { 'Vert', 53 }, { 'Vert racing', 50 }, { 'Vert citron', 55 }, { 'Bleu nuit', 62 },
        { 'Bleu', 64 }, { 'Bleu vif', 70 }, { 'Bleu marine', 61 }, { 'Violet', 145 }, { 'Rose', 135 }, { 'Rose vif', 137 }, { 'Marron', 96 },
        { 'Beige', 99 }, { 'Or', 158 }, { 'Bronze', 90 } } },
    { 'Mates', { { 'Noir mat', 12 }, { 'Gris mat', 13 }, { 'Blanc mat', 131 }, { 'Rouge mat', 39 }, { 'Bordeaux mat', 40 }, { 'Orange mat', 41 },
        { 'Jaune mat', 42 }, { 'Vert mat', 128 }, { 'Vert olive mat', 151 }, { 'Bleu mat', 83 }, { 'Bleu nuit mat', 82 }, { 'Violet mat', 149 },
        { 'Marron mat', 129 }, { 'Kaki mat', 152 }, { 'Sable mat', 153 } } },
    { 'Métaux', { { 'Acier brossé', 117 }, { 'Acier noir brossé', 118 }, { 'Aluminium brossé', 119 }, { 'Chrome', 120 },
        { 'Or pur', 159 }, { 'Or brossé', 160 } } },
}
local TINTS = { { 'Aucune', 0 }, { 'Fumée légère', 3 }, { 'Fumée foncée', 2 }, { 'Limousine', 1 }, { 'Verte', 5 } }
local WHEEL_TYPES = { { 'Sport', 0 }, { 'Muscle', 1 }, { 'Lowrider', 2 }, { 'SUV', 3 }, { 'Tout-terrain', 4 }, { 'Tuner', 5 },
    { 'Moto', 6 }, { 'Haut de gamme', 7 }, { 'Benny\'s origine', 8 }, { 'Benny\'s bespoke', 9 }, { 'Drift', 10 }, { 'Rue', 11 }, { 'Rallye', 12 } }
local XENON = { { 'Blanc', -1 }, { 'Bleu', 1 }, { 'Bleu électrique', 2 }, { 'Vert menthe', 3 }, { 'Vert acide', 4 }, { 'Jaune', 5 },
    { 'Or', 6 }, { 'Orange', 7 }, { 'Rouge', 8 }, { 'Rose', 9 }, { 'Violet', 11 } }
local PLATES = { { 'Bleu sur blanc 1', 0 }, { 'Jaune sur noir', 1 }, { 'Jaune sur bleu', 2 }, { 'Bleu sur blanc 2', 3 }, { 'Bleu sur blanc 3', 4 },
    { 'Yankton', 5 } }
local SMOKE = { { 'Blanche', { 255, 255, 255 } }, { 'Noire', { 1, 1, 1 } }, { 'Rose Vice', { 255, 46, 136 } }, { 'Cyan', { 40, 224, 255 } },
    { 'Violette', { 155, 107, 255 } }, { 'Rouge', { 255, 30, 60 } }, { 'Orange', { 255, 138, 61 } }, { 'Jaune', { 255, 220, 0 } }, { 'Verte', { 57, 255, 154 } } }

-- Travail réel à la validation : une animation par type de travail touché par le panier
local WORK = {
    perf = { label = 'Montage des pièces moteur', dict = 'mini@repair', clip = 'fixing_a_ped', hood = true, ms = 6000 },
    body = { label = 'Pose des éléments de carrosserie', scenario = 'WORLD_HUMAN_WELDING', ms = 6000 },
    paint = { label = 'Peinture', scenario = 'WORLD_HUMAN_MAID_CLEAN', ms = 7000 },
    wheels = { label = 'Montage des jantes', scenario = 'CODE_HUMAN_MEDIC_KNEEL', ms = 5000 },
    inside = { label = 'Travaux à l\'intérieur', dict = 'mini@repair', clip = 'fixing_a_player', ms = 4000 },
}
local KIND = { color1 = 'paint', color2 = 'paint', pearlescentColor = 'paint', paintType1 = 'paint', paintType2 = 'paint',
    customPrimaryColor = 'paint', customSecondaryColor = 'paint', modLivery = 'paint', livery = 'paint',
    wheelColor = 'wheels', wheels = 'wheels', modFrontWheels = 'wheels', tyreSmokeColor = 'wheels', modSmokeEnabled = 'wheels',
    windowTint = 'inside', interiorColor = 'inside', dashboardColor = 'inside', modXenon = 'body', xenonColor = 'body',
    neonEnabled = 'body', neonColor = 'body', plateIndex = 'body', extras = 'body', modTurbo = 'perf' }
for _, p in ipairs(PERF) do KIND[p[2]] = 'perf' end

local veh, netId, original
local job -- métier mis en cache (gs_bridge:client:jobUpdated) : jamais un appel d'export à chaque image en visée

AddEventHandler('gs_bridge:client:jobUpdated', function(j) job = j end)
AddEventHandler('gs_bridge:client:playerUnloaded', function() job = nil end)

local function mechanicOnDuty() return job ~= nil and job.name == 'mechanic' and job.onduty == true end

-- Prix / panier (même barème que le serveur, qui recalcule de toute façon) -----------------------------------------------
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function price(key, value)
    local P = M.prices
    if value == -1 or value == false then return 0 end
    local perf = P.perf[key]
    if perf then return type(value) == 'number' and (perf[value + 1] or perf[#perf]) or 0 end
    if key == 'modTurbo' then return P.turbo end
    return P.keys[key] or (key:sub(1, 3) == 'mod' and P.mod or 0)
end
local function money(n) return (tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' $' end

local function cart()
    if not veh or not original then return 0, 0, {} end
    local now = lib.getVehicleProperties(veh) -- [API] ox_lib
    local total, n, kinds = 0, 0, {}
    for k, v in pairs(now) do
        if type(k) == 'string' and not same(original[k], v) then
            local p = price(k, v)
            if p > 0 then total, n = total + p, n + 1 kinds[KIND[k] or (k:sub(1, 3) == 'mod' and 'body') or 'body'] = true end
        end
    end
    return math.min(total, M.maxBill), n, kinds
end

-- Aperçu partagé : appliqué ici, et par le propriétaire réseau via le serveur (vu par le client et les passants) ----------
local pending
local function share()
    if pending then return end
    pending = true
    SetTimeout(250, function() -- plusieurs clics rapides = un seul envoi
        pending = nil
        if veh and DoesEntityExist(veh) then TriggerServerEvent('gs_tuning:server:preview', netId, lib.getVehicleProperties(veh)) end
    end)
end

local buildMain
local function change(fn)
    if not veh or not DoesEntityExist(veh) then return notify(false, 'Le véhicule n\'est plus là.') end
    SetVehicleModKit(veh, 0)
    fn()
    share()
    buildMain() -- panier à jour au retour
end

local openMain

local function modLabel(modType, i)
    if i < 0 then return 'D\'origine' end
    local txt = GetModTextLabel(veh, modType, i)
    local lbl = txt and GetLabelText(txt)
    return (lbl and lbl ~= 'NULL' and lbl ~= '') and lbl or ('Option %d'):format(i + 1)
end

local function modMenu(modType, title, parent, key)
    SetVehicleModKit(veh, 0)
    local n, cur, options = GetNumVehicleMods(veh, modType), GetVehicleMod(veh, modType), {}
    for i = -1, n - 1 do
        local p = key and price(key, i) or (i >= 0 and M.prices.mod or 0)
        options[#options + 1] = { title = modLabel(modType, i), description = p > 0 and money(p) or 'Gratuit',
            icon = cur == i and 'check' or 'circle', iconColor = cur == i and '#5aff8c' or nil,
            onSelect = function() change(function() SetVehicleMod(veh, modType, i, false) end) modMenu(modType, title, parent, key) end }
    end
    lib.registerContext({ id = 'gs_meca_mod', title = title, menu = parent, options = options })
    lib.showContext('gs_meca_mod')
end

local function listMenu(id, title, list, parent, apply, current, cost)
    local options = {}
    for _, e in ipairs(list) do
        local on = same(current, e[2])
        options[#options + 1] = { title = e[1], description = cost and money(cost) or nil, icon = on and 'check' or 'circle',
            iconColor = on and '#5aff8c' or nil,
            onSelect = function() change(function() apply(e[2]) end) listMenu(id, title, list, parent, apply, e[2], cost) end }
    end
    lib.registerContext({ id = id, title = title, menu = parent, options = options })
    lib.showContext(id)
end

local function partsMenu(id, title, list)
    SetVehicleModKit(veh, 0)
    local options = {}
    for _, m in ipairs(list) do
        if GetNumVehicleMods(veh, m[1]) > 0 then
            options[#options + 1] = { title = m[2], description = modLabel(m[1], GetVehicleMod(veh, m[1])), arrow = true,
                onSelect = function() modMenu(m[1], m[2], id) end }
        end
    end
    if #options == 0 then options[1] = { title = 'Rien de disponible sur ce modèle', readOnly = true } end
    lib.registerContext({ id = id, title = title, menu = 'gs_meca_main', options = options })
    lib.showContext(id)
end

local function perfMenu()
    SetVehicleModKit(veh, 0)
    local options = {}
    for _, m in ipairs(PERF) do
        local n = GetNumVehicleMods(veh, m[1])
        if n > 0 then
            local cur = GetVehicleMod(veh, m[1])
            options[#options + 1] = { title = m[3], description = cur < 0 and 'D\'origine' or ('Niveau %d / %d'):format(cur + 1, n),
                progress = math.floor((cur + 1) / n * 100), colorScheme = 'violet', arrow = true,
                onSelect = function() modMenu(m[1], m[3], 'gs_meca_perf', m[2]) end }
        end
    end
    local on = IsToggleModOn(veh, 18)
    options[#options + 1] = { title = ('Turbo : %s'):format(on and 'monté' or 'non'), description = on and 'Retirer' or money(M.prices.turbo),
        icon = 'wind', onSelect = function() change(function() ToggleVehicleMod(veh, 18, not on) end) perfMenu() end }
    lib.registerContext({ id = 'gs_meca_perf', title = 'Performances', menu = 'gs_meca_main', options = options })
    lib.showContext('gs_meca_perf')
end

local function colorMenu(slot, parent)
    local options = {}
    for _, pal in ipairs(PALETTES) do
        options[#options + 1] = { title = pal[1], arrow = true, onSelect = function()
            listMenu('gs_meca_pal', pal[1], pal[2], 'gs_meca_color', function(v)
                local a, b = GetVehicleColours(veh)
                local pe, w = GetVehicleExtraColours(veh)
                if slot == 1 then ClearVehicleCustomPrimaryColour(veh) SetVehicleColours(veh, v, b)
                elseif slot == 2 then ClearVehicleCustomSecondaryColour(veh) SetVehicleColours(veh, a, v)
                elseif slot == 3 then SetVehicleExtraColours(veh, v, w)
                else SetVehicleExtraColours(veh, pe, v) end
            end, nil, M.prices.keys[({ 'color1', 'color2', 'pearlescentColor', 'wheelColor' })[slot]]) end }
    end
    if slot <= 2 then
        options[#options + 1] = { title = 'Couleur sur mesure', icon = 'eye-dropper', description = money(M.prices.keys[slot == 1 and 'customPrimaryColor' or 'customSecondaryColor']),
            onSelect = function()
                local r = lib.inputDialog('Couleur sur mesure', { { type = 'color', label = 'Couleur', default = '#a24bff' } })
                local hex = r and r[1]
                if type(hex) == 'string' and hex:match('^#%x%x%x%x%x%x$') then
                    local cr, cg, cb = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
                    change(function()
                        if slot == 1 then SetVehicleCustomPrimaryColour(veh, cr, cg, cb) else SetVehicleCustomSecondaryColour(veh, cr, cg, cb) end
                    end)
                end
                colorMenu(slot, parent)
            end }
    end
    lib.registerContext({ id = 'gs_meca_color', title = ({ 'Couleur principale', 'Couleur secondaire', 'Nacré', 'Couleur des jantes' })[slot],
        menu = parent, options = options })
    lib.showContext('gs_meca_color')
end

local function paintMenu()
    local options = {
        { title = 'Type de peinture (principale)', arrow = true, onSelect = function()
            listMenu('gs_meca_ptype', 'Type de peinture', PAINT_TYPES, 'gs_meca_paint', function(v)
                local _, c = GetVehicleModColor_1(veh) SetVehicleModColor_1(veh, v, c, 0) end, nil, M.prices.keys.paintType1) end },
        { title = 'Couleur principale', arrow = true, onSelect = function() colorMenu(1, 'gs_meca_paint') end },
        { title = 'Couleur secondaire', arrow = true, onSelect = function() colorMenu(2, 'gs_meca_paint') end },
        { title = 'Nacré', arrow = true, onSelect = function() colorMenu(3, 'gs_meca_paint') end },
    }
    local liveries = GetVehicleLiveryCount(veh)
    if GetNumVehicleMods(veh, 48) > 0 then
        options[#options + 1] = { title = 'Livrée', arrow = true, onSelect = function() modMenu(48, 'Livrée', 'gs_meca_paint', 'modLivery') end }
    elseif liveries and liveries > 1 then
        local list = {}
        for i = 0, liveries - 1 do list[#list + 1] = { ('Livrée %d'):format(i + 1), i } end
        options[#options + 1] = { title = 'Livrée', arrow = true, onSelect = function()
            listMenu('gs_meca_liv', 'Livrée', list, 'gs_meca_paint', function(v) SetVehicleLivery(veh, v) end, GetVehicleLivery(veh), M.prices.keys.livery) end }
    end
    lib.registerContext({ id = 'gs_meca_paint', title = 'Peinture', menu = 'gs_meca_main', options = options })
    lib.showContext('gs_meca_paint')
end

local function wheelsMenu()
    local r, g, b = GetVehicleTyreSmokeColor(veh)
    lib.registerContext({ id = 'gs_meca_wheels', title = 'Jantes et pneus', menu = 'gs_meca_main', options = {
        { title = 'Type de jantes', arrow = true, onSelect = function() listMenu('gs_meca_wtype', 'Type de jantes', WHEEL_TYPES, 'gs_meca_wheels',
            function(v) SetVehicleWheelType(veh, v) SetVehicleMod(veh, 23, -1, false) end, GetVehicleWheelType(veh), M.prices.keys.wheels) end },
        { title = 'Modèle de jantes', arrow = true, onSelect = function() modMenu(23, 'Modèle de jantes', 'gs_meca_wheels', 'modFrontWheels') end },
        { title = 'Couleur des jantes', arrow = true, onSelect = function() colorMenu(4, 'gs_meca_wheels') end },
        { title = 'Fumée des pneus', arrow = true, description = ('Actuelle : %d, %d, %d'):format(r, g, b), onSelect = function()
            listMenu('gs_meca_smoke', 'Fumée des pneus', SMOKE, 'gs_meca_wheels', function(v)
                ToggleVehicleMod(veh, 20, true) SetVehicleTyreSmokeColor(veh, v[1], v[2], v[3]) end, { r, g, b }, M.prices.keys.tyreSmokeColor) end },
    } })
    lib.showContext('gs_meca_wheels')
end

local function lightsMenu()
    local neons = Config.Neon
    local list = { { 'Éteints', false } }
    for _, n in ipairs(neons) do list[#list + 1] = { n.label, n.rgb } end
    lib.registerContext({ id = 'gs_meca_lights', title = 'Éclairage', menu = 'gs_meca_main', options = {
        { title = 'Phares xénon', arrow = true, onSelect = function()
            listMenu('gs_meca_xenon', 'Phares xénon', XENON, 'gs_meca_lights', function(v)
                ToggleVehicleMod(veh, 22, true) SetVehicleXenonLightsColor(veh, v) end, GetVehicleXenonLightsColor(veh), M.prices.keys.xenonColor) end },
        { title = 'Néons (4 côtés)', arrow = true, onSelect = function()
            listMenu('gs_meca_neon', 'Néons', list, 'gs_meca_lights', function(v)
                for side = 0, 3 do SetVehicleNeonLightEnabled(veh, side, v ~= false) end
                if v then SetVehicleNeonLightsColour(veh, v[1], v[2], v[3]) end
            end, nil, M.prices.keys.neonEnabled) end },
    } })
    lib.showContext('gs_meca_lights')
end

local function extrasMenu()
    local options = {}
    for i = 1, 14 do
        if DoesExtraExist(veh, i) then
            local on = IsVehicleExtraTurnedOn(veh, i)
            options[#options + 1] = { title = ('Extra %d : %s'):format(i, on and 'monté' or 'retiré'), icon = on and 'toggle-on' or 'toggle-off',
                onSelect = function() change(function() SetVehicleExtra(veh, i, on) end) extrasMenu() end } -- SetVehicleExtra : true = retirer
        end
    end
    if #options == 0 then options[1] = { title = 'Aucun extra sur ce modèle', readOnly = true } end
    lib.registerContext({ id = 'gs_meca_extras', title = 'Extras', menu = 'gs_meca_main', options = options })
    lib.showContext('gs_meca_extras')
end

local function stopSession(msg, ok)
    veh, netId, original = nil, nil, nil
    if msg then notify(ok, msg) end
end

local function cancel()
    if veh and original and DoesEntityExist(veh) then
        lib.setVehicleProperties(veh, original) -- [API] ox_lib
        TriggerServerEvent('gs_tuning:server:preview', netId, original) -- retour d'origine vu par tous
    end
    stopSession('Modifications annulées : véhicule d\'origine.', true)
end

--- Le vrai travail, un passage par type de travail du panier, puis enregistrement (et facture côté serveur).
local function save()
    if not veh or not DoesEntityExist(veh) then return stopSession('Le véhicule n\'est plus là.', false) end
    local total, n, kinds = cart()
    if n == 0 then return notify(false, 'Rien n\'a changé : choisis des pièces, puis valide.') end
    for _, k in ipairs({ 'perf', 'body', 'paint', 'wheels', 'inside' }) do
        if kinds[k] then
            local w = WORK[k]
            if w.hood then SetVehicleDoorOpen(veh, 4, false, false) end
            TaskTurnPedToFaceEntity(cache.ped, veh, 800) Wait(800)
            local done = lib.progressBar({ duration = w.ms, label = w.label, canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = w.dict and { dict = w.dict, clip = w.clip, flag = 1 } or { scenario = w.scenario } })
            ClearPedTasks(cache.ped)
            if w.hood and DoesEntityExist(veh) then SetVehicleDoorShut(veh, 4, false) end
            if not done then return notify(false, 'Travail interrompu : rien n\'est encore enregistré (le menu reste ouvert).') end
        end
    end
    local ok, msg = lib.callback.await('gs_tuning:mechanicSave', false, netId, lib.getVehicleProperties(veh))
    if ok then stopSession(msg, true) else notify(false, msg) end
end

--- Menu principal enregistré (sans l'afficher) : la flèche « retour » des sous-menus montre ainsi le panier à jour.
buildMain = function()
    local total, n = cart()
    local options = {
        { title = n > 0 and ('Panier : %d pièce%s · %s'):format(n, n > 1 and 's' or '', money(total)) or 'Panier vide',
            description = 'Le client voit chaque essai en direct. Facture envoyée automatiquement à la validation.', icon = 'cart-shopping', readOnly = true },
        { title = 'Performances', icon = 'gauge-high', arrow = true, onSelect = perfMenu },
        { title = 'Carrosserie', icon = 'car-side', arrow = true, onSelect = function() partsMenu('gs_meca_body', 'Carrosserie', BODY) end },
        { title = 'Intérieur', icon = 'couch', arrow = true, onSelect = function() partsMenu('gs_meca_inside', 'Intérieur', INTERIOR) end },
        { title = 'Peinture et livrée', icon = 'palette', arrow = true, onSelect = paintMenu },
        { title = 'Jantes et pneus', icon = 'circle-dot', arrow = true, onSelect = wheelsMenu },
        { title = 'Éclairage (xénon, néons)', icon = 'lightbulb', arrow = true, onSelect = lightsMenu },
        { title = 'Vitres teintées', icon = 'window-maximize', arrow = true, onSelect = function()
            listMenu('gs_meca_tint', 'Vitres teintées', TINTS, 'gs_meca_main', function(v) SetVehicleWindowTint(veh, v) end, GetVehicleWindowTint(veh), M.prices.keys.windowTint) end },
        { title = 'Plaque (style)', icon = 'id-card', arrow = true, onSelect = function()
            listMenu('gs_meca_plate', 'Style de plaque', PLATES, 'gs_meca_main', function(v) SetVehicleNumberPlateTextIndex(veh, v) end,
                GetVehicleNumberPlateTextIndex(veh), M.prices.keys.plateIndex) end },
        { title = 'Extras', icon = 'puzzle-piece', arrow = true, onSelect = extrasMenu },
        { title = n > 0 and ('Valider et faire le travail (%s)'):format(money(total)) or 'Valider', icon = 'screwdriver-wrench', iconColor = '#5aff8c', onSelect = save },
        { title = 'Annuler tout (retour d\'origine)', icon = 'rotate-left', iconColor = '#ff2e88', onSelect = cancel },
    }
    lib.registerContext({ id = 'gs_meca_main', title = ('Atelier · %s'):format(GetVehicleNumberPlateText(veh)), options = options })
end

openMain = function()
    if not veh or not DoesEntityExist(veh) then return stopSession('Le véhicule n\'est plus là.', false) end
    buildMain()
    lib.showContext('gs_meca_main')
end


--- Abandon : mécano parti (> 25 m), plus en service, ou véhicule disparu → retour d'origine pour tout le monde.
local function watch(v)
    CreateThread(function()
        while veh == v do
            if not DoesEntityExist(v) then stopSession('Le véhicule n\'est plus là.', false) break end
            if not mechanicOnDuty() or #(GetEntityCoords(cache.ped) - GetEntityCoords(v)) > 25.0 then cancel() break end
            Wait(1000)
        end
    end)
end

CreateThread(function()
    job = Bridge:GetJob()
    exports.ox_target:addGlobalVehicle({ { -- [API] ox_target
        name = 'gs_meca_custom', icon = 'fa-solid fa-paint-roller', label = 'Personnaliser (mécano)', distance = 3.0,
        canInteract = function() return not cache.vehicle and mechanicOnDuty() end,
        onSelect = function(data)
            local entity = data.entity
            if veh and veh ~= entity then cancel() end
            if veh ~= entity then
                local props = lib.getVehicleProperties(entity)
                local ok, msg = lib.callback.await('gs_tuning:mechanicCheck', false, VehToNet(entity), props)
                if not ok then return notify(false, msg) end
                veh, netId, original = entity, VehToNet(entity), props
                watch(entity)
            end
            SetVehicleModKit(veh, 0)
            openMain()
        end,
    } })
end)

-- V12.36 · Réglages envoyés par le serveur au propriétaire réseau du véhicule (validation, et V12.40 : aperçu en direct) :
-- appliqués ici avec ox_lib, comme le fait qbx_core à la sortie du garage. Sans identité ni état (ni plein ni réparation).
RegisterNetEvent('gs_tuning:client:applyProps', function(id, props)
    if type(id) ~= 'number' or type(props) ~= 'table' then return end
    local t = GetGameTimer() + 5000
    while not NetworkDoesNetworkIdExist(id) and GetGameTimer() < t do Wait(100) end
    local v = NetworkDoesNetworkIdExist(id) and NetToVeh(id) or 0
    if v == 0 or not DoesEntityExist(v) then return end
    t = GetGameTimer() + 5000
    while NetworkGetEntityOwner(v) ~= cache.playerId and GetGameTimer() < t do NetworkRequestControlOfEntity(v) Wait(100) end
    if not DoesEntityExist(v) or NetworkGetEntityOwner(v) ~= cache.playerId then return end
    props.plate, props.model = nil, nil
    lib.setVehicleProperties(v, props) -- [API] ox_lib
end)
