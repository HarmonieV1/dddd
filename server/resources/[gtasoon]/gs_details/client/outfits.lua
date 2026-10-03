-- gs_details (client) : tenues en objets (item gs_outfit). « Plier ma tenue » (menu radial, touche W sur clavier français) crée un objet Tenue avec les
-- vêtements portés ; l'utiliser (double-clic) l'enfile, et la tenue d'avant devient à son tour un objet. Échangeable,
-- rangeable dans un coffre, vendable entre joueurs. Coiffure, visage et tatouages ne bougent jamais.
local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }   -- masque, bras, jambes, sac, chaussures, accessoires, t-shirt, gilet, logos, haut
local PROPS = { 0, 1, 2, 6, 7 }                          -- chapeau, lunettes, oreilles, montre, bracelet

--- Vêtements portés → { c = { [id] = { d, t } }, p = { [id] = { d, t } }, m = modèle }
local function current()
    local ped = cache.ped
    local o = { c = {}, p = {}, m = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') and 'f' or 'm' }
    for _, id in ipairs(COMPONENTS) do o.c[tostring(id)] = { GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id) } end
    for _, id in ipairs(PROPS) do o.p[tostring(id)] = { GetPedPropIndex(ped, id), GetPedPropTextureIndex(ped, id) } end
    return o
end

local function apply(o)
    local ped = cache.ped
    for id, v in pairs(o.c or {}) do SetPedComponentVariation(ped, tonumber(id), v[1], v[2], 0) end
    for id, v in pairs(o.p or {}) do
        if v[1] == -1 then ClearPedProp(ped, tonumber(id)) else SetPedPropIndex(ped, tonumber(id), v[1], v[2], true) end
    end
    -- sauvegarde de l'apparence (illenium-appearance) : la tenue reste après reconnexion
    local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end) -- [API]
    if ok and app then TriggerServerEvent('illenium-appearance:server:saveAppearance', app) end -- [API]
end

local function fold()
    if cache.vehicle then return lib.notify({ description = 'Descends du véhicule.', type = 'error' }) end
    local r = lib.inputDialog('Plier ma tenue', { { type = 'input', label = 'Nom de la tenue', placeholder = 'Tenue de soirée', required = true, max = 30 } })
    if not r then return end
    if not lib.progressBar({ duration = 2500, label = 'Tu plies ta tenue…', canCancel = true,
        anim = { dict = 'clothingtie', clip = 'try_tie_neutral_a' }, disable = { move = true, car = true, combat = true } }) then return end
    local ok, msg = lib.callback.await('gs_details:foldOutfit', false, r[1], current())
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end
exports('FoldOutfit', fold)

--- Utilisation de l'objet (ox_inventory, client.export = 'gs_details.wearOutfit')
exports('wearOutfit', function(data, slot)
    local o = slot and slot.metadata and slot.metadata.outfit
    if type(o) ~= 'table' then return lib.notify({ description = 'Tenue vide.', type = 'error' }) end
    if (o.m or 'm') ~= (GetEntityModel(cache.ped) == GetHashKey('mp_f_freemode_01') and 'f' or 'm') then
        return lib.notify({ description = 'Cette tenue n\'est pas à ta taille (modèle homme / femme).', type = 'error' })
    end
    local before = current()
    exports.ox_inventory:useItem(data, function(used) -- [API] ox_inventory : retire l'objet
        if not used then return end
        lib.progressBar({ duration = 3000, label = 'Tu te changes…', anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            disable = { move = true, car = true, combat = true } })
        ClearPedTasks(cache.ped)
        apply(o)
        local ok, msg = lib.callback.await('gs_details:foldOutfit', false, 'Tenue précédente', before)
        lib.notify({ description = ok and ('Tu portes « %s ». Ta tenue précédente est dans ton sac.'):format(slot.metadata.label or 'la tenue') or msg,
            type = ok and 'success' or 'error' })
    end)
end)
