-- Tests gs_econstats : classement des motifs (neutres ignorés), cumuls, rapport (sources / puits), accès staff, inflation.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_econstats', { R .. 'gs_econstats/shared/config.lua' })
local db, supply, hist = {}, 1100000, { { day = 'j', supply = 1000000, price_index = 1.0 } }
Store = {
    init = function() end,
    add = function(rows) for _, r in ipairs(rows) do local k = r[1] .. r[2] db[k] = db[k] or { day = r[1], reason = r[2], created = 0, destroyed = 0 }
        db[k].created, db[k].destroyed = db[k].created + r[3], db[k].destroyed + r[4] end end,
    day = function(day) local l = {} for _, v in pairs(db) do if v.day == day then l[#l + 1] = v end end return l end,
    supply = function() return supply end, saveSupply = function() end, supplyHistory = function() return hist end,
    richest = function() return { { firstname = 'Riche', lastname = 'Un', total = 900000 } } end,
}
provide('gs_economy', { GetPriceIndex = function() return 1.12 end })
loadResource('gs_econstats', { R .. 'gs_econstats/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

check('virement : neutre', Econ.category('virement 555-1234') == nil)
check('facture : neutre', Econ.category('Facture police') == nil)
check('motif nettoyé (chiffres retirés)', Econ.category('niveau 12') == 'niveau')
check('motif vide', Econ.category(nil) == 'inconnu')

TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', 500, 'add', 'mission taxi')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'cash', 300, 'add', 'mission taxi')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', 1000, 'add', 'niveau 5')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'cash', 200, 'remove', 'achat supérette')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', 9999, 'add', 'virement 555-0000')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'crypto', 50, 'add', 'x')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', -5, 'add', 'bug')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', 70, 'set', 'staff')
local r = Econ.report(os.date('%Y-%m-%d'))
check('cumuls : créé / détruit / net (virement ignoré)', r.created == 1800 and r.destroyed == 200 and r.net == 1600)
check('première source = niveau (1000 $)', r.sources[1].reason == 'niveau' and r.sources[1].amount == 1000 and r.sources[2].amount == 800)
check('puits : achats', r.sinks[1].reason == 'achat supérette')

join(1, 'CID1', 'Joueur', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Admin', vec3(0.0, 0.0, 0.0))
W.players[2].aces = { ['gs.admin.admin'] = true }
check('joueur : pas accès', cb('gs_econstats:dashboard', 1) == nil)
local d = cb('gs_econstats:dashboard', 2)
check('staff : tableau complet', d and d.supply == 1100000 and math.abs(d.inflation7 - 10) < 0.01 and d.priceIndex == 1.12 and d.richest[1].name == 'Riche Un')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
