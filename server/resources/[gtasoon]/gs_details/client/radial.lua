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

lib.registerRadial({ id = 'gs_me', items = {
    { label = 'Vêtements', icon = 'shirt', menu = 'gs_me_clothes' },
    { label = 'Mains en l\'air', icon = 'hands', onSelect = function() ExecuteCommand('levermains') end },
    { label = 'Animations', icon = 'person-walking', onSelect = function() exports.scully_emotemenu:toggleMenu() end }, -- [API] scully_emotemenu
    { label = 'Factures', icon = 'file-invoice-dollar', onSelect = function() ExecuteCommand('factures') end },
    { label = 'Téléphone', icon = 'mobile-screen', onSelect = function() ExecuteCommand('telephone') end },
    { label = 'Aide : touches', icon = 'keyboard', onSelect = function() ExecuteCommand('touches') end },
} })

lib.addRadialItem({ id = 'gs_me_menu', label = 'Moi', icon = 'user', menu = 'gs_me' }) -- [API] ox_lib (menu Z)
