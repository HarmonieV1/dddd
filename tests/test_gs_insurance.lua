-- Tests gs_insurance : guichet, propriétaire, prime selon le prix, paiement, durée cumulée, plafond, facteur de fourrière.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_insurance', { R .. 'gs_insurance/shared/config.lua' })
local owned = { CID1 = { { id = 10, model = 'sultan', plate = 'AAA111' }, { id = 11, model = 'panto', plate = 'BBB222' } }, CID2 = { { id = 20, model = 'sultan', plate = 'CCC333' } } }
local saved = {}
Store = {
    init = function() end, all = function() return {} end,
    set = function(id, ts) saved[id] = ts end,
    vehicles = function(cid) return owned[cid] or {} end,
    owns = function(cid, id) for _, v in ipairs(owned[cid] or {}) do if v.id == id then return true end end return false end,
}
loadResource('gs_insurance', { R .. 'gs_insurance/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local getFactor = getExport('gs_insurance', 'GetImpoundFactor')

join(1, 'CID1', 'Assuré', vec3(0.0, 0.0, 0.0))
W.players[1].money.bank = 10000
check('loin du guichet : pas de liste', cb('gs_insurance:list', 1) == nil)
local ok = cb('gs_insurance:buy', 1, 10); step()
check('loin du guichet : achat refusé', not ok)
tp(1, Config.Counter.coords)
local l = cb('gs_insurance:list', 1); step()
check('liste : 2 véhicules avec prime (4 % du prix, min 300)', #l.vehicles == 2 and l.vehicles[1].premium == 1600 and l.vehicles[2].premium == 320 and l.vehicles[1].daysLeft == 0)
ok = cb('gs_insurance:buy', 1, 20); step()
check('véhicule d\'un autre : refusé', not ok)
check('non assuré : plein tarif', getFactor(10) == 1.0)
ok = cb('gs_insurance:buy', 1, 10); step()
check('assuré : prime prélevée, fourrière à 25 %', ok and W.players[1].money.bank == 10000 - 1600 and getFactor(10) == Config.ImpoundFactor and saved[10] > os.time())
local first = saved[10]
ok = cb('gs_insurance:buy', 1, 10); step()
check('renouvellement : la durée s\'ajoute', ok and saved[10] == first + Config.Days * 86400)
for _ = 1, 4 do cb('gs_insurance:buy', 1, 10); step() end
ok = cb('gs_insurance:buy', 1, 10); step()
check('plafond de couverture à l\'avance', not ok)
W.players[1].money.bank, W.players[1].money.cash = 0, 100
ok = cb('gs_insurance:buy', 1, 11); step()
check('prime impayable : refusé', not ok and getFactor(11) == 1.0)
W.players[1].money.cash = 400
ok = cb('gs_insurance:buy', 1, 11); step()
check('payé en liquide à défaut', ok and W.players[1].money.cash == 80)
Insurance.expires[10] = os.time() - 5
check('contrat expiré : plein tarif', getFactor(10) == 1.0)
ok = cb('gs_insurance:buy', 1, 'x'); step()
check('identifiant invalide', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
