-- Tests gs_casino · V12.62 « Jetons de fête foraine » : guichet ou caisse du casino seulement, achat / revente sans profit,
-- ticket à gratter contre des jetons (casino seulement), échange 1 pour 1 avec le ticket d'un script installé, bornes.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_casino', { R .. 'gs_casino/shared/config.lua' })
Config.Fair.exchange = { { item = 'bumpercar_token', label = 'Ticket d\'auto-tamponneuse' }, { item = 'introuvable', label = 'Absent' } }
loadResource('gs_casino', { R .. 'gs_casino/server/fair.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local P = function() return W.players[1] end

join(1, 'CID1', 'Joueur', vec3(0.0, 0.0, 0.0))
P().money.cash = 100
local ok, msg = cb('gs_casino:fair', 1, 'buy', 5); step()
check('loin du guichet : refusé', not ok and msg:find('guichet'))
tp(1, Config.Fair.booth)
local d
ok, d = cb('gs_casino:fair', 1, 'info'); step()
check('infos : au guichet, seul le jeu installé est proposé', ok and d.at == 'booth' and #d.exchange == 1 and d.exchange[1].item == 'bumpercar_token')
ok = cb('gs_casino:fair', 1, 'buy', 10); step()
check('achat : 10 jetons contre 50 $', ok and P().items.fair_token == 10 and P().money.cash == 50)
ok = cb('gs_casino:fair', 1, 'buy', 20); step()
check('achat : pas assez de liquide', not ok and P().items.fair_token == 10 and P().money.cash == 50)
ok = cb('gs_casino:fair', 1, 'buy', 1000); step()
check('achat : quantité bornée', not ok)
ok = cb('gs_casino:fair', 1, 'sell', 2); step()
check('revente : moins cher qu\'à l\'achat', ok and P().items.fair_token == 8 and P().money.cash == 50 + 2 * Config.Fair.buyBack and Config.Fair.buyBack < Config.Fair.price)
ok = cb('gs_casino:fair', 1, 'scratch'); step()
check('ticket à gratter : au casino seulement', not ok)
ok = cb('gs_casino:fair', 1, 'toScript', 1, 3); step()
check('échange : 3 jetons → 3 tickets d\'auto-tamponneuse', ok and P().items.fair_token == 5 and P().items.bumpercar_token == 3)
ok = cb('gs_casino:fair', 1, 'fromScript', 1, 5); step()
check('échange inverse : pas plus que ce qu\'on a', not ok and P().items.bumpercar_token == 3)
ok = cb('gs_casino:fair', 1, 'toScript', 2, 1); step()
check('échange : jeu non installé refusé', not ok and P().items.fair_token == 5)
tp(1, Config.Lotto.cashier)
P().items.fair_token = 12
ok = cb('gs_casino:fair', 1, 'scratch'); step()
check('casino : 10 jetons → 1 ticket à gratter', ok and P().items.fair_token == 2 and P().items.scratch_ticket == 1)
ok = cb('gs_casino:fair', 1, 'scratch'); step()
check('casino : pas assez de jetons', not ok and P().items.scratch_ticket == 1)

io.write(('jetons de fête foraine : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
