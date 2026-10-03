-- gs_world (serveur) : vols réguliers vers Cayo Perico (comptoir vérifié, billet payé en banque, puis téléportation).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

World = {}

--- Soirée plage de Cayo Perico (appelée par gs_admin, événements en un clic). seconds = 0 pour arrêter.
function World.party(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then GlobalState.gsCayoParty = nil return true end
    GlobalState.gsCayoParty = { untilAt = os.time() + math.min(seconds, 4 * 3600) }
    SetTimeout(math.min(seconds, 4 * 3600) * 1000, function()
        local g = GlobalState.gsCayoParty
        if g and os.time() >= g.untilAt then GlobalState.gsCayoParty = nil end
    end)
    return true
end
exports('StartParty', World.party)

lib.callback.register('gs_world:fly', function(src, side)
    if not Security:RateLimit(src, 'gs_world:fly', 2, 10000) then return false, 'Doucement.' end
    local f = Config.Island.flight
    local from = (side == 'mainland' or side == 'island') and f[side]
    if not from then return false, 'Vol inconnu.' end
    if not Security:InRangeFlat(src, from.counter, 4.0, 8.0) then return false, 'Présente-toi au comptoir.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    if f.price > 0 and not Bridge:RemoveMoney(src, 'bank', f.price, 'vol Cayo Perico') then return false, ('Billet : %d $ en banque.'):format(f.price) end
    local to = f[side == 'mainland' and 'island' or 'mainland'].arrival
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    SetEntityHeading(ped, to.w)
    return true, side == 'mainland' and 'Bienvenue à Cayo Perico.' or 'Retour à Los Santos.'
end)

-- Nombre de joueurs connectés, lu par les clients pour réduire PNJ / trafic quand le serveur se remplit.
CreateThread(function()
    while true do
        GlobalState.gsPlayers = #GetPlayers()
        Wait(30000)
    end
end)
