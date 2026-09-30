-- gs_world (serveur) : vols réguliers vers Cayo Perico (comptoir vérifié, billet payé en banque, puis téléportation).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

World = {}

lib.callback.register('gs_world:fly', function(src, side)
    if not Security:RateLimit(src, 'gs_world:fly', 2, 10000) then return false, 'Doucement.' end
    local f = Config.Island.flight
    local from = (side == 'mainland' or side == 'island') and f[side]
    if not from then return false, 'Vol inconnu.' end
    if not Security:InRange(src, from.counter, 4.0) then return false, 'Présente-toi au comptoir.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    if f.price > 0 and not Bridge:RemoveMoney(src, 'bank', f.price, 'vol Cayo Perico') then return false, ('Billet : %d $ en banque.'):format(f.price) end
    local to = f[side == 'mainland' and 'island' or 'mainland'].arrival
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    SetEntityHeading(ped, to.w)
    return true, side == 'mainland' and 'Bienvenue à Cayo Perico.' or 'Retour à Los Santos.'
end)
