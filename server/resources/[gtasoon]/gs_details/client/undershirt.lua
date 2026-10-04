-- gs_details (client) · Le « t-shirt blanc collé à la peau ». Dans GTA, le sous-vêtement par défaut (composant 8, n° 0)
-- est un t-shirt blanc porté SOUS tous les hauts : il ressort à travers les vestes, sweats, robes… en boutique, à la
-- création du perso, avec les tenues en objets. Ici, le n° 0 veut dire « aucun sous-vêtement » (15 homme, 14 femme).
-- Le t-shirt blanc reste disponible comme haut (catégorie Haut / Veste). Vérifié toutes les 0,5 s : rien d'autre.
local NONE = { [GetHashKey('mp_m_freemode_01')] = 15, [GetHashKey('mp_f_freemode_01')] = 14 }

local function fix(ped)
    local none = NONE[GetEntityModel(ped)]
    if none and GetPedDrawableVariation(ped, 8) == 0 then
        SetPedComponentVariation(ped, 8, none, 0, 0)
        return true
    end
    return false
end
exports('FixUndershirt', function() return fix(cache.ped) end)
GSFixUndershirt = fix -- utilisé par les tenues en objets (avant sauvegarde)

CreateThread(function()
    while true do
        fix(cache.ped)
        Wait(500)
    end
end)
