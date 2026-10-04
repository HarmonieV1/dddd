-- Tests gs_accords (V9) : proposition face à face, signature, prêt versé, échéances prélevées, dépôt si absent,
-- retards majorés puis litige (juges prévenus), fin du contrat (bénéficiaire / demande du payeur).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local judgeMsgs = {}
provide('gs_jobs', { GetOnDutyPlayers = function(job) return job == 'judge' and { 9 } or {} end, IsOnDutyAs = function(src, job) return src == 9 and job == 'judge' end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_accords', { R .. 'gs_accords/shared/config.lua' })
local nextId, saved = 0, {}
Store = { init = function() end, active = function() return {} end,
    insert = function() nextId = nextId + 1 return nextId end, save = function(c) saved[c.id] = c.status end }
loadResource('gs_accords', { R .. 'gs_accords/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local offers = {}
local tce = TriggerClientEvent
TriggerClientEvent = function(n, s, d) if n == 'gs_accords:client:offer' then offers[#offers + 1] = { s = s, d = d } end return tce(n, s, d) end

local here = vec3(0.0, 0.0, 30.0)
join(1, 'CID1', 'Prêteur', here)
join(2, 'CID2', 'Emprunteur', vec3(1.0, 0.0, 30.0))
join(3, 'CID3', 'Loin', vec3(100.0, 0.0, 30.0))
join(9, 'CID9', 'Juge', vec3(500.0, 0.0, 30.0))
W.players[1].money.bank, W.players[2].money.bank = 50000, 1000

local ok = cb('gs_accords:propose', 1, 3, { kind = 'loan', amount = 10000, count = 4, every = 7, rate = 0.2 }); step()
check('pas face à face : refusé', not ok)
ok = cb('gs_accords:propose', 1, 2, { kind = 'loan', amount = 10, count = 4, every = 7 }); step()
check('montant hors limites', not ok)
ok = cb('gs_accords:propose', 1, 2, { kind = 'loan', amount = 10000, count = 4, every = 7, rate = 0.2, terms = 'Remboursement anticipé possible' }); step()
check('proposition présentée au signataire', ok and offers[1].s == 2 and offers[1].d.text:find('12000') == nil and offers[1].d.text:find('3000 %$'))
ok = cb('gs_accords:sign', 2, true); step()
local c = Accords.list[1]
check('signé : prêt versé, échéance 3 000 $ (20 % d\'intérêts sur 4)', ok and c and W.players[1].money.bank == 40000 and W.players[2].money.bank == 11000 and c.principal == 3000)
check('copie papier aux deux parties', (W.players[1].items.gs_contrat or 0) == 1 and (W.players[2].items.gs_contrat or 0) == 1)
Accords.tick()
check('pas de prélèvement avant l\'échéance', c.paid == 0)
c.next_at = os.time()
Accords.tick()
check('échéance prélevée sur le payeur, versée au bénéficiaire', c.paid == 1 and W.players[2].money.bank == 8000 and W.players[1].money.bank == 43000)
-- bénéficiaire absent : dépôt
local lender = W.players[1]
W.players[1] = nil
c.next_at = os.time()
Accords.tick()
check('bénéficiaire absent : argent en dépôt', c.paid == 2 and c.held == 3000 and W.players[2].money.bank == 5000)
W.players[1] = lender
Accords.tick()
check('dépôt versé à son retour', c.held == 0 and W.players[1].money.bank == 46000)
-- retard
W.players[2].money.bank = 100
c.next_at = os.time()
Accords.tick()
check('pas d\'argent : délai de grâce', c.missed == 0 and c.paid == 2)
c.next_at = os.time() - Config.Grace * 3600
Accords.tick()
check('délai dépassé : retard, échéance majorée', c.missed == 1 and c.amount == 3300)
c.next_at = os.time() - Config.Grace * 3600
Accords.tick()
check('2e retard : litige', c.missed == 2 and c.status == 'dispute')
local j = cb('gs_accords:mine', 9); step()
check('le juge en service voit le litige', #j == 1 and j[1].status == 'dispute' and not j[1].mine)
W.players[2].money.bank = 10000
c.next_at = os.time()
Accords.tick()
check('paiement : litige levé, montant normal', c.status == 'active' and c.missed == 0 and c.amount == 3000 and c.paid == 3)
-- fin : payeur demande, bénéficiaire accepte
ok = cb('gs_accords:terminate', 2, 1); step()
check('le payeur ne peut que demander', ok and c.status == 'active' and Accords.endAsk[1] == 'CID2')
ok = cb('gs_accords:terminate', 1, 1); step()
check('le bénéficiaire met fin', ok and c.status == 'ended' and saved[1] == 'ended')
-- salaire : dernier versement = contrat honoré
ok = cb('gs_accords:propose', 1, 2, { kind = 'salary', amount = 500, count = 1, every = 7 }); step()
ok = ok and cb('gs_accords:sign', 2, true); step()
local s = Accords.list[2]
s.next_at = os.time()
Accords.tick()
check('salaire versé par le proposant, contrat honoré', ok and s.status == 'done' and W.players[2].money.bank == 10000 - 3630 + 500) -- échéance en retard payée majorée (3 000 × 1,1 × 1,1)
-- tout payé mais argent en dépôt (bénéficiaire absent) : plus jamais d'échéance en plus
ok = cb('gs_accords:propose', 1, 2, { kind = 'salary', amount = 300, count = 1, every = 7 }); step()
ok = ok and cb('gs_accords:sign', 2, true); step()
local d = Accords.list[3]
local saveP2 = W.players[2]
W.players[2] = nil
d.next_at = os.time()
Accords.tick()
local bank1 = W.players[1].money.bank
d.next_at = os.time()
Accords.tick()
check('tout payé, dépôt en attente : pas de 2e prélèvement', ok and d.paid == 1 and d.held == 300 and W.players[1].money.bank == bank1)
W.players[2] = saveP2
Accords.tick()
check('dépôt versé au retour, contrat honoré', d.held == 0 and d.status == 'done')
-- pas d'union ici : le mariage reste à la mairie (gs_civil)
ok = cb('gs_accords:propose', 1, 2, { kind = 'union' }); step()
check('union refusée (doublon du mariage de la mairie)', not ok)
-- refus
cb('gs_accords:propose', 1, 2, { kind = 'rent', amount = 800, count = 4, every = 7 }); step()
ok = cb('gs_accords:sign', 2, false); step()
check('refus : aucun contrat', ok and Accords.list[4] == nil)
ok = cb('gs_accords:sign', 2, true); step()
check('plus rien à signer', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
