-- Tests gs_furniture (V12.58) : réglage d'un meuble enregistré par le staff pour tout le monde (/meubleregle).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_furniture', { R .. 'gs_furniture/shared/config.lua', R .. 'gs_furniture/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
join(1, 'CID1', 'Joueur', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Staff', vec3(0.0, 0.0, 0.0)) W.players[2].aces = { ['gs.admin.admin'] = true, ['gs.admin.superadmin'] = true }
join(3, 'CID3', 'Admin', vec3(0.0, 0.0, 0.0)) W.players[3].aces = { ['gs.admin.admin'] = true }
local ok, msg = cb('gs_furniture:adjust', 1, 'prop_bench_01a', { z = 0.5, y = -0.3, h = 180.0 })
check('joueur : refusé', not ok and msg:find('super%-admin'))
ok, msg = cb('gs_furniture:adjust', 3, 'prop_bench_01a', { z = 0.5, y = -0.3, h = 180.0 })
check('V12.65 : admin refusé (super-admin et fondateur seulement)', not ok and msg:find('super%-admin'))
ok = cb('gs_furniture:adjust', 2, 'prop_inconnu', { z = 0.5, y = 0.0, h = 0.0 })
check('modèle inconnu refusé', not ok)
ok = cb('gs_furniture:adjust', 2, 'prop_bench_01a', { z = 'x', y = 0.0, h = 0.0 })
check('valeurs invalides refusées', not ok)
ok = cb('gs_furniture:adjust', 2, 'prop_bench_01a', { z = 0.456, y = -9.0, h = 540.0 })
local a = GlobalState.gsFurniture.prop_bench_01a
check('staff : enregistré, borné, arrondi, publié', ok and a.z == 0.46 and a.y == -2.0 and a.h == 180.0)
check('gardé (KVP)', W_KVP['gs_furniture:adj'] ~= nil)
ok = cb('gs_furniture:adjust', 2, 'prop_bench_01a', nil)
check('annuler : réglage d\'origine', ok and GlobalState.gsFurniture.prop_bench_01a == nil)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
