-- Tests gs_gangs · racket (V9) : demande à la caisse, consentement du patron, prélèvement hebdomadaire vers la caisse
-- du gang, refus / impayé = 30 min pour « faire passer le message » (vitrine, dégâts, crime), police prévenue.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local socMoney, cops, crimes = { bar = 20000 }, {}, {}
local owner = { [2] = 'bar' }
local register = vec3(-560.4, 287.3, 82.2)
provide('gs_jobs', {
    IsOnDutyAs = function() return false end,
    GetOnDutyPlayers = function() return { 9 } end,
    GetSocietyMoney = function(j) return socMoney[j] or 0 end,
    RemoveSocietyMoney = function(j, n) if (socMoney[j] or 0) < n then return false end socMoney[j] = socMoney[j] - n return true end,
})
provide('gs_business', {
    GetBusinesses = function() return { bar = { label = 'Tequi-la-la', register = register } } end,
    IsOwner = function(src, id) return owner[src] == id end,
})
provide('gs_wanted', { ReportCrime = function(src, t) crimes[#crimes + 1] = t return true end })
local kvp = {}
function SetResourceKvp(k, v) kvp[k] = v end
function GetResourceKvpString(k) return kvp[k] end
json.encode = function() return '{}' end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua' })
local money = {}
Store = { addMoney = function(n, a) money[n] = (money[n] or 0) + a return true end }
Gangs = { online = {}, list = { ballas = { label = 'Ballas' }, vagos = { label = 'Vagos' } } }
loadResource('gs_gangs', { R .. 'gs_gangs/server/racket.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end
local offers = {}
local tce = TriggerClientEvent
TriggerClientEvent = function(n, s, ...) if n == 'gs_gangs:client:racketOffer' then offers[#offers + 1] = s end return tce(n, s, ...) end

join(1, 'CID1', 'Ballas', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Patron', register)
join(3, 'CID3', 'Recrue', register)
join(4, 'CID4', 'Vagos', register)
Gangs.online[1] = { cid = 'CID1', gang = 'ballas', grade = 2 }
Gangs.online[3] = { cid = 'CID3', gang = 'ballas', grade = 0 }
Gangs.online[4] = { cid = 'CID4', gang = 'vagos', grade = 3 }

local ok = cb('gs_gangs:racket', 1, 'demand', 1000); step()
check('loin de la caisse : rien', not ok)
tp(1, register)
ok = cb('gs_gangs:racket', 3, 'demand', 1000); step()
check('une recrue ne rackette pas', not ok)
ok = cb('gs_gangs:racket', 1, 'demand', 50); step()
check('montant hors barème', not ok)
ok = cb('gs_gangs:racket', 1, 'demand', 1000); step()
check('offre envoyée au patron', ok and offers[1] == 2 and Racket.pending.bar)
ok = cb('gs_gangs:racket', 4, 'answer', 'bar', 'accept'); step()
check('seul le patron répond', not ok)
ok = cb('gs_gangs:racket', 2, 'answer', 'bar', 'accept'); step()
check('accepté : 1er prélèvement caisse commerce → caisse du gang', ok and socMoney.bar == 19000 and money.ballas == 1000 and Racket.deals.bar.gang == 'ballas')
local i = cb('gs_gangs:racket', 4, 'info'); step()
check('un autre gang voit que le commerce est « protégé »', i.deal and i.deal.gang == 'Ballas' and not i.canDemand)
ok = cb('gs_gangs:racket', 4, 'demand', 2000); step()
check('pas de double racket', not ok)
Racket.tick()
check('pas de prélèvement avant la semaine', money.ballas == 1000)
Racket.deals.bar.next = os.time()
Racket.tick()
check('prélèvement hebdomadaire', money.ballas == 2000 and socMoney.bar == 18000 and Racket.deals.bar.next > os.time())
socMoney.bar = 100
Racket.deals.bar.next = os.time()
Racket.tick()
check('impayé : protection rompue, rancune', Racket.deals.bar == nil and Racket.grudge.bar.gang == 'ballas')
socMoney.bar = 5000
ok = cb('gs_gangs:racket', 4, 'punish'); step()
check('un autre gang ne peut pas « passer le message »', not ok)
ok = cb('gs_gangs:racket', 1, 'punish'); step()
check('message passé : dégâts sur la caisse, crime signalé', ok and socMoney.bar == 5000 - Config.Racket.damage and crimes[1] == 'racket' and not Racket.grudge.bar)
ok = cb('gs_gangs:racket', 1, 'punish'); step()
check('une seule fois par refus', not ok)

-- Refus + police
Racket.last.bar = nil
ok = cb('gs_gangs:racket', 4, 'demand', 1500); step()
ok = ok and cb('gs_gangs:racket', 2, 'answer', 'bar', 'police'); step()
check('refus avec police : rancune des Vagos', ok and Racket.grudge.bar.gang == 'vagos' and not Racket.deals.bar)
ok = cb('gs_gangs:racket', 1, 'demand', 1000); step()
check('une demande par heure et par commerce', not ok)
Racket.grudge.bar.untilAt = os.time() - 1
Racket.tick()
check('la rancune expire', Racket.grudge.bar == nil)
-- Patron absent
Racket.last.bar = nil
owner[2] = nil
ok = cb('gs_gangs:racket', 1, 'demand', 1000); step()
check('patron absent : pas d\'offre', not ok)
-- Arrêter de payer
owner[2] = 'bar'
Racket.deals.bar = { gang = 'ballas', amount = 1000, next = os.time() + 1000 }
ok = cb('gs_gangs:racket', 2, 'stop', 'bar'); step()
check('le patron arrête : rancune', ok and not Racket.deals.bar and Racket.grudge.bar.gang == 'ballas')
-- Offre expirée
Racket.grudge.bar, Racket.last.bar = nil, nil
cb('gs_gangs:racket', 1, 'demand', 1000); step()
Racket.pending.bar.at = os.time() - Config.Racket.answer - 1
ok = cb('gs_gangs:racket', 2, 'answer', 'bar', 'accept'); step()
check('offre expirée', not ok and not Racket.deals.bar)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
