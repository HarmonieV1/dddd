-- Tests gs_rental : distance, paiement liquide puis banque, une location à la fois, place occupée, retour, échéance.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function GetPedInVehicleSeat(veh) return W.entities[veh].driver and GetPlayerPed(W.entities[veh].driver) or 0 end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_rental', { R .. 'gs_rental/shared/config.lua', R .. 'gs_rental/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local P1 = Config.Points[1]
local counter = P1.coords

join(1, 'CID1', 'Loueur', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_rental:rent', 1, 1, 1); step()
check('trop loin du comptoir', not ok)
tp(1, counter)
ok = cb('gs_rental:rent', 1, 1, 4); step()
check('sans argent : refusé', not ok and msg ~= nil)
W.players[1].money.bank = 200
ok, msg = cb('gs_rental:rent', 1, 1, 4); step()
check('payé par la banque', ok and W.players[1].money.bank == 200 - Config.Vehicles[4].price)
local r = Rental.active[1]
check('véhicule créé, joueur au volant', r and W.entities[r.veh].model == 'panto' and W.entities[r.veh].driver == 1)
check('plaque LOC', W.entities[r.veh].plate:sub(1, 3) == 'LOC')
ok = cb('gs_rental:rent', 1, 1, 1); step()
check('une seule location à la fois', not ok)
ok = cb('gs_rental:rent', 1, 99, 1); step()
check('comptoir inconnu', not ok)

-- Place occupée pour un 2e joueur
join(2, 'CID2', 'Second', counter); W.players[2].money.cash = 50
ok, msg = cb('gs_rental:rent', 2, 1, 1); step()
check('place occupée', not ok and msg:find('occupée'))

-- Retour : véhicule trop loin puis ramené
W.entities[r.veh].pos = vec3(500.0, 500.0, 30.0)
ok = cb('gs_rental:return', 1, 1); step()
check('retour refusé si véhicule loin', not ok and Rental.active[1])
W.entities[r.veh].pos = counter
ok = cb('gs_rental:return', 1, 1); step()
check('véhicule rendu et supprimé', ok and not Rental.active[1] and not W.entities[r.veh])

-- Liquide en priorité, échéance
ok = cb('gs_rental:rent', 2, 1, 1); step()
check('payé en liquide', ok and W.players[2].money.cash == 50 - Config.Vehicles[1].price)
local veh = Rental.active[2].veh
W.entities[veh].driver = 2
advance((Config.Vehicles[1].minutes - Config.WarnBefore + 1) * 60000)
Rental.tick()
check('avertissement avant la fin', Rental.active[2].warned and W.notes[2].type == 'warning')
advance(Config.WarnBefore * 60000)
Rental.tick()
check('échu mais conducteur à bord : délai de grâce', Rental.active[2] ~= nil)
W.entities[veh].driver = nil
Rental.tick()
check('échu et vide : récupéré', not Rental.active[2] and not W.entities[veh])

-- Déconnexion
ok = cb('gs_rental:rent', 2, 1, 1); step()
veh = Rental.active[2] and Rental.active[2].veh
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('déconnexion : véhicule retiré', veh and not W.entities[veh] and not Rental.active[2])

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
