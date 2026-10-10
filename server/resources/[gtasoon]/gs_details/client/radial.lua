-- gs_details (client) : menu radial (Z) enrichi. Accès rapides sans commande : tenue, accessoires, mains en l'air,
-- factures, téléphone, aide. (Radio et Véhicule sont ajoutés par gs_radio et vehicle.lua.)
local removed = {} -- [clé] = { drawable, texture } retiré, pour le remettre

local function toggleProp(id, label)
    local ped = cache.ped
    local k = 'p' .. id
    if removed[k] then
        SetPedPropIndex(ped, id, removed[k][1], removed[k][2], true)
        removed[k] = nil
        return
    end
    local d = GetPedPropIndex(ped, id)
    if d == -1 then return lib.notify({ description = ('Pas de %s.'):format(label), type = 'inform' }) end
    removed[k] = { d, GetPedPropTextureIndex(ped, id) }
    lib.requestAnimDict('mp_masks@standard_car@ds@', 1000)
    TaskPlayAnim(ped, 'mp_masks@standard_car@ds@', 'put_on_mask', 8.0, -8.0, 800, 48, 0, false, false, false)
    Wait(600)
    ClearPedProp(ped, id)
end

local function toggleMask()
    local ped = cache.ped
    if removed.mask then
        SetPedComponentVariation(ped, 1, removed.mask[1], removed.mask[2], 0)
        removed.mask = nil
        return
    end
    local d = GetPedDrawableVariation(ped, 1)
    if d == 0 then return lib.notify({ description = 'Pas de masque.', type = 'inform' }) end
    removed.mask = { d, GetPedTextureVariation(ped, 1) }
    lib.requestAnimDict('mp_masks@standard_car@ds@', 1000)
    TaskPlayAnim(ped, 'mp_masks@standard_car@ds@', 'put_on_mask', 8.0, -8.0, 800, 48, 0, false, false, false)
    Wait(600)
    SetPedComponentVariation(ped, 1, 0, 0, 0)
end

lib.registerRadial({ id = 'gs_me_clothes', items = {
    { label = 'Plier ma tenue (objet)', icon = 'shirt', onSelect = function() exports.gs_details:FoldOutfit() end },
    { label = 'Chapeau', icon = 'hat-cowboy', onSelect = function() toggleProp(0, 'chapeau') end },
    { label = 'Lunettes', icon = 'glasses', onSelect = function() toggleProp(1, 'lunettes') end },
    { label = 'Masque', icon = 'masks-theater', onSelect = toggleMask },
} })

-- V11.6 · Porter un objet (carton, caisse…) : raccourcis vers les emotes à prop de scully (F5 → Props en a d'autres)
local CARRY = {
    { cmd = 'box', label = 'Carton', icon = 'box' }, { cmd = 'toolbox', label = 'Caisse à outils', icon = 'toolbox' },
    { cmd = 'cbbox', label = 'Caisse de bière', icon = 'beer-mug-empty' }, { cmd = 'carrypizza', label = 'Pizzas', icon = 'pizza-slice' },
    { cmd = 'carryfoodbag', label = 'Sac de courses', icon = 'bag-shopping' }, { cmd = 'carrydrink', label = 'Boisson', icon = 'mug-hot' },
    { cmd = 'carrycones', label = 'Cônes', icon = 'triangle-exclamation' }, { cmd = 'tire', label = 'Pneu', icon = 'circle' },
    { cmd = 'gbin', label = 'Poubelle', icon = 'trash' }, { cmd = 'potplant1', label = 'Plante en pot', icon = 'seedling' },
    { cmd = 'guitarcarry', label = 'Guitare', icon = 'guitar' },
}
local function carry(cmd)
    if cache.vehicle then return lib.notify({ description = 'Descends du véhicule.', type = 'error' }) end
    local ok = pcall(function() exports.scully_emotemenu:playEmoteByCommand(cmd) end) -- [API] scully_emotemenu
    if not ok then lib.notify({ description = 'Animation indisponible.', type = 'error' }) end
end
local function carryMenu(parent)
    local o = {}
    for _, c in ipairs(CARRY) do o[#o + 1] = { title = c.label, icon = c.icon, onSelect = function() carry(c.cmd) end } end
    o[#o + 1] = { title = 'Poser (arrêter)', icon = 'hand', onSelect = function() pcall(function() exports.scully_emotemenu:cancelEmote() end) end }
    lib.registerContext({ id = 'gs_me_carry', title = 'Porter un objet', menu = parent, options = o })
    lib.showContext('gs_me_carry')
end
RegisterCommand('porter', function() if not IsNuiFocused() then carryMenu() end end, false)
TriggerEvent('chat:addSuggestion', '/porter', 'Porter un objet : carton, caisse, pizza… (aussi W → Moi → Porter)')

lib.registerRadial({ id = 'gs_me', items = {
    { label = 'Vêtements', icon = 'shirt', menu = 'gs_me_clothes' },
    { label = 'Porter un objet', icon = 'box-open', onSelect = function() carryMenu() end },
    { label = 'Mains en l\'air', icon = 'hands', onSelect = function() ExecuteCommand('levermains') end },
    { label = 'Animations', icon = 'person-walking', onSelect = function() exports.scully_emotemenu:toggleMenu() end }, -- [API] scully_emotemenu
    { label = 'Factures', icon = 'file-invoice-dollar', onSelect = function() ExecuteCommand('factures') end },
    { label = 'Téléphone', icon = 'mobile-screen', onSelect = function() ExecuteCommand('telephone') end },
    { label = 'Aide : touches', icon = 'keyboard', onSelect = function() ExecuteCommand('touches') end },
} })

lib.addRadialItem({ id = 'gs_me_menu', label = 'Moi', icon = 'user', menu = 'gs_me' }) -- [API] ox_lib (menu Z)
