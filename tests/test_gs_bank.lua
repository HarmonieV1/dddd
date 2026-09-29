-- Tests gs_bank : distance, véhicule, montants, plafond par opération et par jour, solde, dépôt, historique, guichet.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_bank', { R .. 'gs_bank/shared/config.lua' })
local tx, daily = {}, {}
Store = {
    init = function() end,
    addTx = function(cid, kind, amount, balance, place) tx[#tx + 1] = { cid = cid, kind = kind, amount = amount, balance = balance, place = place } end,
    history = function(cid) local l = {} for i = #tx, 1, -1 do if tx[i].cid == cid then l[#l + 1] = tx[i] end end return l end,
    withdrawn = function(cid, day) return daily[cid .. day] or 0 end,
    addWithdrawn = function(cid, day, a) daily[cid .. day] = (daily[cid .. day] or 0) + a end,
}
loadResource('gs_bank', { R .. 'gs_bank/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local atm = { x = 100.0, y = 100.0, z = 30.0 }
local here = vec3(101.0, 100.0, 30.0)

join(1, 'CID1', 'Client', vec3(0.0, 0.0, 0.0))
W.players[1].money.bank, W.players[1].money.cash = 30000, 100
check('distributeur : trop loin', cb('gs_bank:info', 1, 'atm', atm) == nil)
tp(1, here)
local info = cb('gs_bank:info', 1, 'atm', atm); step()
check('infos : soldes et reste du jour', info and info.bank == 30000 and info.leftToday == Config.Atm.dailyWithdraw)
check('coords invalides', cb('gs_bank:info', 1, 'atm', 'x') == nil)
check('lieu inconnu', cb('gs_bank:info', 1, 'banque_du_diable', atm) == nil)
check('guichet : pas à un guichet', cb('gs_bank:info', 1, 'counter') == nil)

local ok, msg = cb('gs_bank:withdraw', 1, 'atm', atm, 0); step()
check('montant nul refusé', not ok)
ok = cb('gs_bank:withdraw', 1, 'atm', atm, -50); step()
check('montant négatif refusé', not ok)
ok = cb('gs_bank:withdraw', 1, 'atm', atm, 12.5); step()
check('montant décimal refusé', not ok)
ok = cb('gs_bank:withdraw', 1, 'atm', atm, Config.Atm.perOperation + 1); step()
check('plafond par opération', not ok)
ok = cb('gs_bank:withdraw', 1, 'atm', atm, 5000); step()
check('retrait : banque → liquide', ok and W.players[1].money.bank == 25000 and W.players[1].money.cash == 5100)
cb('gs_bank:withdraw', 1, 'atm', atm, 5000); step()
cb('gs_bank:withdraw', 1, 'atm', atm, 5000); step()
ok, msg = cb('gs_bank:withdraw', 1, 'atm', atm, 100); step()
check('plafond du jour atteint', not ok and msg:find('Plafond') and W.players[1].money.bank == 15000)
check('reste du jour = 0', cb('gs_bank:info', 1, 'atm', atm).leftToday == 0)

ok = cb('gs_bank:deposit', 1, 'atm', atm, 99999); step()
check('dépôt : plafond par opération', not ok)
ok = cb('gs_bank:deposit', 1, 'atm', atm, 5000); step()
check('dépôt : liquide → banque', ok and W.players[1].money.bank == 20000 and W.players[1].money.cash == 10100)
W.players[1].money.cash = 10
ok = cb('gs_bank:deposit', 1, 'atm', atm, 500); step()
check('dépôt : pas assez de liquide', not ok)
join(2, 'CID2', 'Pauvre', here)
ok = cb('gs_bank:withdraw', 2, 'atm', atm, 100); step()
check('retrait : solde insuffisant', not ok)

local h = cb('gs_bank:info', 1, 'atm', atm).history
check('historique : 4 opérations, la plus récente d\'abord', #h == 4 and h[1].kind == 'deposit' and h[2].kind == 'withdraw')

-- Guichet : plafond plus haut, position connue du serveur
W.players[1].money.bank, W.players[1].money.cash = 500000, 0
tp(1, Config.Counters[1].coords)
ok = cb('gs_bank:withdraw', 1, 'counter', nil, 100000); step()
check('guichet : gros retrait autorisé', ok and W.players[1].money.cash == 100000)
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_bank:withdraw', 1, 'counter', nil, 1000); step()
check('guichet : loin de toute agence', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
