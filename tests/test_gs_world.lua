-- Tests gs_world : vols Cayo Perico (comptoir, véhicule, paiement, destination).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_world', { R .. 'gs_world/shared/config.lua', R .. 'gs_world/server/main.lua' })
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local F = Config.Island.flight

join(1, 'CID1', 'Voyageur', vec3(0.0, 0.0, 0.0))
local ok = cb('gs_world:fly', 1, 'mainland'); step()
check('loin du comptoir', not ok)
tp(1, F.mainland.counter)
ok = cb('gs_world:fly', 1, 'lune'); step()
check('vol inconnu', not ok)
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('sans argent', not ok and W.players[1].pos == F.mainland.counter)
W.players[1].money.bank = 1000
W.players[1].vehicle = 5
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('en véhicule : refusé', not ok)
W.players[1].vehicle = nil
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('arrivée sur l\'île, billet payé', ok and W.players[1].money.bank == 1000 - F.price and #(W.players[1].pos - F.island.arrival) < 1)
tp(1, F.island.counter)
ok = cb('gs_world:fly', 1, 'island'); step()
check('retour à LS', ok and #(W.players[1].pos - F.mainland.arrival) < 1)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
