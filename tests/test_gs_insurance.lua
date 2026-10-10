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
local claimsSaved, owners = {}, { BBB222 = 'CID1', AAA111 = 'CID1' }
Store.claims = function() return {} end
Store.saveClaim = function(c) claimsSaved[c.id] = c.status end
Store.ownerOf = function(plate) return owners[plate] end
local records = {}
provide('gs_police', { AddRecord = function(cid, charge, fine) records[#records + 1] = { cid = cid, charge = charge, fine = fine } return true end })
provide('gs_jobs', { GetOnDutyPlayers = function() return {} end })
local rumors = {}
provide('gs_rumors', { Add = function(t, d) rumors[#rumors + 1] = { t = t, d = d } end, Zone = function() return 'Rogers Salvage' end })
-- V12 : registre des véhicules disparus
local lostRows = {}
Store.initLost = function() end
Store.modelOf = function(id) return ({ [10] = 'sultan', [11] = 'panto', [30] = 'sultan' })[id] end
Store.lostAll = function() return {} end
Store.lostSet = function(e) lostRows[e.id] = e end
Store.lostClear = function(id) lostRows[id] = nil end
loadResource('gs_insurance', { R .. 'gs_insurance/server/main.lua', R .. 'gs_insurance/server/claims.lua', R .. 'gs_insurance/server/lost.lua' })

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

-- V9 · Déclaration de vol et fraude ------------------------------------------------------------------------------
Insurance.expires[10] = os.time() + 86400 * 3
W_KVP['since:10'] = os.time()
W.players[1].money.bank = 100000
ok = cb('gs_insurance:claim', 1, 10); step()
check('vol déclaré juste après l\'assurance : refusé', not ok)
W_KVP['since:10'] = os.time() - 3 * 86400
ok = cb('gs_insurance:claim', 1, 20); step()
check('véhicule d\'un autre : pas de déclaration', not ok)
Claims.driven('AAA111', 1)
ok = cb('gs_insurance:claim', 1, 10); step()
check('vu au volant il y a peu : l\'expert refuse', not ok and not Claims.list[10])
Claims.seen.AAA111.at = os.time() - 3600
ok = cb('gs_insurance:claim', 1, 10); step()
check('déclaration ouverte (60 % du prix)', ok and Claims.list[10].status == 'pending' and Claims.list[10].amount == 24000 and claimsSaved[10] == 'pending')
ok = cb('gs_insurance:claim', 1, 10); step()
check('dossier déjà ouvert', not ok)
check('plaque déclarée volée (police)', getExport('gs_insurance', 'IsDeclaredStolen')('AAA111 ') == true)
Claims.tick()
check('pas versé avant l\'enquête', Claims.list[10].status == 'pending')
Claims.list[10].at = os.time() - Config.Claim.review * 60
local bank = W.players[1].money.bank
Claims.tick()
check('indemnité versée après l\'enquête, contrat clos', Claims.list[10].status == 'paid' and W.players[1].money.bank == bank + 24000 and getFactor(10) == 1.0)
join(2, 'CID2', 'Voleur', vec3(0.0, 0.0, 0.0))
Claims.driven('AAA111', 2)
check('un autre conducteur (voleur) : pas de fraude', Claims.list[10].status == 'paid')
bank = W.players[1].money.bank
Claims.driven('AAA111', 1)
check('propriétaire revu au volant : fraude, remboursement majoré, casier', Claims.list[10].status == 'fraud'
    and W.players[1].money.bank == bank - 36000 and records[1] and records[1].cid == 'CID1')
check('fraude : plus déclarée volée', getExport('gs_insurance', 'IsDeclaredStolen')('AAA111') == false)
-- revente pendant l'enquête
W_KVP['claimcd:CID1'] = nil
Insurance.expires[11] = os.time() + 86400
W_KVP['since:11'] = os.time() - 3 * 86400
ok = cb('gs_insurance:claim', 1, 11); step()
check('deuxième dossier', ok and Claims.list[11].status == 'pending')
owners.BBB222 = 'CID2'
Claims.ownerChanged('BBB222')
check('voiture « volée » revendue : fraude sans versement', Claims.list[11].status == 'fraud' and records[2] and records[2].fine == 0)
W_KVP['claimcd:CID1'] = os.time()
Insurance.expires[10] = os.time() + 86400 Claims.list[10] = nil
ok = cb('gs_insurance:claim', 1, 10); step()
check('une déclaration toutes les 2 semaines', not ok)

-- V12 · Le registre des véhicules disparus ------------------------------------------------------------------------
do
    owners.DDD444 = 'CID1'
    Claims.list[30] = { id = 30, plate = 'DDD444', cid = 'CID1', amount = 5000, status = 'paid', at = os.time() - 10 * 3600 }
    check('moins de 48 h : rien ne refait surface', Lost.scan(Claims.list) == 0)
    Claims.list[30].at = os.time() - 49 * 3600
    fixRandom(0.1)
    check('48 h après : la voiture refait surface à la casse', Lost.scan(Claims.list) == 1 and Lost.list[30] and Lost.list[30].fate == 'casse' and Lost.list[30].x ~= nil and lostRows[30] ~= nil)
    fixRandom()
    check('rumeur et tuyau au propriétaire', rumors[#rumors].d:find('DDD444', 1, true) and W.notes[1] and W.notes[1].msg:find('casse', 1, true))
    check('pas refait surface deux fois', Lost.scan(Claims.list) == 0)
    local e = Lost.list[30]
    tp(1, vec3(e.x + 20.0, e.y, e.z))
    Lost.tick()
    check('joueur proche : véhicule créé avec sa plaque', Lost.spawned[30] and W.entities[Lost.spawned[30]] ~= nil)
    W.players[1].money.bank = 6000
    Claims.driven('DDD444', 1)
    check('propriétaire au volant : indemnité reprise, dossier « recovered », pas de fraude', Claims.list[30].status == 'recovered'
        and W.players[1].money.bank == 1000 and Lost.list[30] == nil and lostRows[30] == nil)
    -- aux enchères : l'événement de la fourrière part vers gs_auction
    local impounded = {}
    AddEventHandler('gs_police:server:impounded', function(hash, plate) impounded[#impounded + 1] = plate end)
    Claims.list[31] = { id = 31, plate = 'EEE555', cid = 'CID1', amount = 5000, status = 'pending', at = os.time() - 50 * 3600 }
    Store.modelOf = function() return 'panto' end
    fixRandom(0.95)
    check('sort « enchères » : lot de la fourrière', Lost.scan(Claims.list) == 1 and Lost.list[31].fate == 'encheres' and impounded[1] == 'EEE555' and Lost.list[31].x == nil)
    fixRandom()
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
