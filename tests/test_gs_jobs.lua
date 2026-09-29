-- Tests de la logique serveur gs_jobs + gs_security. Lancer : ./tests/run.sh
dofile('tests/mock.lua')

local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_jobs', {
    R .. 'gs_jobs/shared/locale.lua', R .. 'gs_jobs/shared/config.lua',
    R .. 'gs_jobs/shared/locations.lua', R .. 'gs_jobs/shared/jobs.lua',
    R .. 'gs_jobs/server/core.lua',
})
mockDB()
loadResource('gs_jobs', {
    R .. 'gs_jobs/server/society.lua', R .. 'gs_jobs/server/members.lua', R .. 'gs_jobs/server/payroll.lua',
    R .. 'gs_jobs/server/garage.lua', R .. 'gs_jobs/server/stash.lua', R .. 'gs_jobs/server/boss.lua',
    R .. 'gs_jobs/server/billing.lua', R .. 'gs_jobs/server/vehicle_actions.lua',
    R .. 'gs_jobs/server/missions.lua', R .. 'gs_jobs/server/admin.lua', R .. 'gs_jobs/server/orders.lua',
})
DB.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end -- sort des fenêtres de rate-limit

local P = Jobs.police.points
local far = vec3(0.0, 0.0, 0.0)

-- Joueurs : 1 = capitaine LSPD, 2 = citoyen, 3 = mécano
join(1, 'CID1', 'Alpha Boss', P.boss[1])
join(2, 'CID2', 'Bob Citoyen', P.boss[1])
join(3, 'CID3', 'Meca Nique', far)

-- Admin ----------------------------------------------------------------------------------
W.commands.gsjob(0, { action = 'add', target = 1, job = 'police', grade = 4 })
check('admin add police capitaine', Members[1].jobs.police == 4)
net('gs_jobs:server:switch', 1, 'police')
check('switch vers police', W.players[1].job.name == 'police' and W.players[1].job.grade == 4)
net('gs_jobs:server:switch', 2, 'police'); step()
check('switch refusé sans contrat', W.players[2].job.name == 'unemployed')

-- Réconciliation : job actif sans contrat -------------------------------------------------
join(4, 'CID4', 'Triche Ur', far, { name = 'police', grade = 4, onduty = true })
check('réconciliation : job sans contrat retiré', W.players[4].job.name == 'unemployed')

-- Direction : recrutement -----------------------------------------------------------------
local ok, msg = cb('gs_jobs:boss:action', 1, 'hire', { target = 2, grade = 4 }); step()
check('embauche au grade du patron refusée', not ok)
tp(2, far)
ok = cb('gs_jobs:boss:action', 1, 'hire', { target = 2, grade = 0 }); step()
check('embauche refusée si cible loin', not ok)
tp(2, P.boss[1])
tp(1, far)
ok, msg = cb('gs_jobs:boss:action', 1, 'hire', { target = 2, grade = 0 }); step()
check('menu direction refusé loin du point', not ok and msg == L('not_boss'))
tp(1, P.boss[1])
ok = cb('gs_jobs:boss:action', 1, 'hire', { target = 2, grade = 0 }); step()
check('offre envoyée', ok and lastClientEvent('gs_jobs:client:offer', 2) ~= nil)
advance(Config.OfferTimeout * 1000 + 1000)
net('gs_jobs:server:answerOffer', 2, true); step()
check('offre expirée refusée', Members[2].jobs.police == nil)
cb('gs_jobs:boss:action', 1, 'hire', { target = 2, grade = 0 }); step()
net('gs_jobs:server:answerOffer', 2, true); step()
check('offre acceptée', Members[2].jobs.police == 0)
net('gs_jobs:server:answerOffer', 2, true); step()
check('offre non rejouable', DB.countMemberships('CID2') == 1)

-- Pôle Emploi + limite de contrats ---------------------------------------------------------
tp(2, Config.JobCenter.coords)
net('gs_jobs:server:joinPublic', 2, 'taxi'); step()
net('gs_jobs:server:joinPublic', 2, 'delivery'); step()
net('gs_jobs:server:joinPublic', 2, 'garbage'); step()
check('3 contrats max', DB.countMemberships('CID2') == 3 and Members[2].jobs.garbage == nil)
net('gs_jobs:server:joinPublic', 2, 'police'); step()
check('job whitelisté non rejoignable au Pôle Emploi', Members[2].jobs.police == 0)

-- Service ------------------------------------------------------------------------------------
net('gs_jobs:server:switch', 2, 'police'); step()
net('gs_jobs:server:toggleDuty', 2); step()
check('service refusé loin du point', not W.players[2].job.onduty)
tp(2, P.duty[1])
net('gs_jobs:server:toggleDuty', 2); step()
check('prise de service au point', W.players[2].job.onduty)

-- Caisse -------------------------------------------------------------------------------------
W.players[1].money.cash = 1000
ok = cb('gs_jobs:boss:action', 1, 'deposit', { amount = 5000 }); step()
check('dépôt refusé sans cash', not ok and Society.balance('police') == 0)
ok = cb('gs_jobs:boss:action', 1, 'deposit', { amount = 800 }); step()
check('dépôt ok', ok and Society.balance('police') == 800 and W.players[1].money.cash == 200)
ok = cb('gs_jobs:boss:action', 1, 'withdraw', { amount = 900 }); step()
check('retrait > caisse refusé', not ok and Society.balance('police') == 800)
for _, bad in ipairs({ -50, 0, 1.5, 0 / 0, 1e12 }) do
    ok = cb('gs_jobs:boss:action', 1, 'withdraw', { amount = bad }); step()
    check('montant invalide refusé : ' .. tostring(bad), not ok)
end
check('caisse intacte après montants invalides', Society.balance('police') == 800)

-- Salaires et primes (V5) ------------------------------------------------------------------------
ok, msg = cb('gs_jobs:boss:action', 1, 'setSalary', { grade = 0, amount = 400 }); step()
check('salaire police : fixé par l\'État', not ok and msg:find('État'))
check('salaire par défaut', GSJ.salaryOf('police', 1) == 450)
GSJ.salaries.mechanic = { [1] = 500 }
check('salaire personnalisé lu', GSJ.salaryOf('mechanic', 1) == 500 and GSJ.salaryOf('mechanic', 0) == 250)
local bank2 = W.players[2].money.bank
ok = cb('gs_jobs:boss:action', 1, 'bonus', { cid = 'CID2', amount = 99999 }); step()
check('prime plafonnée', not ok)
ok = cb('gs_jobs:boss:action', 1, 'bonus', { cid = 'CID1', amount = 100 }); step()
check('pas de prime à soi-même', not ok)
ok = cb('gs_jobs:boss:action', 1, 'bonus', { cid = 'CID2', amount = 300 }); step()
check('prime versée depuis la caisse', ok and Society.balance('police') == 500 and W.players[2].money.bank == bank2 + 300)
ok = cb('gs_jobs:boss:action', 1, 'bonus', { cid = 'CID2', amount = 900 }); step()
check('prime > caisse refusée', not ok and Society.balance('police') == 500)
Society.add('police', 300)

-- Factures -------------------------------------------------------------------------------------
tp(1, P.duty[1])
W.players[1].money.bank = 100
ok = cb('gs_jobs:billing:create', 2, 1, 999999, 'Excès de vitesse'); step()
check('amende au-dessus du max refusée', not ok)
ok = cb('gs_jobs:billing:create', 2, 1, 500, '<b>@everyone</b> excès'); step()
check('amende créée', ok and DB.countBills('CID1') == 1)
local bill = DB.getBills('CID1')[1]
check('motif nettoyé', not bill.reason:find('[<>@]'))
ok = cb('gs_jobs:billing:pay', 1, bill.id); step()
check('paiement refusé sans fonds', not ok and DB.countBills('CID1') == 1)
W.players[1].money.bank = 1000
W.players[2].money.bank = 0
ok = cb('gs_jobs:billing:pay', 1, bill.id); step()
check('facture payée', ok and W.players[1].money.bank == 500)
check('commission émetteur 10 %', W.players[2].money.bank == 50)
check('reste à la caisse', Society.balance('police') == 800 + 450)
ok = cb('gs_jobs:billing:pay', 1, bill.id); step()
check('double paiement impossible', not ok and W.players[1].money.bank == 500)
ok = cb('gs_jobs:billing:pay', 2, bill.id); step()
check("facture d'un autre non payable", not ok)

-- Garage + missions ------------------------------------------------------------------------------
net('gs_jobs:server:switch', 2, 'delivery'); step()
check('changement de job = hors service', not W.players[2].job.onduty)
net('gs_jobs:server:toggleDuty', 2); step()
check('service partout pour job public', W.players[2].job.onduty)
ok, msg = cb('gs_jobs:mission:start', 2); step()
check('mission refusée sans véhicule', not ok)
local G = Jobs.delivery.points.garage[1]
tp(2, G.coords)
ok = cb('gs_jobs:garage:spawn', 2, 1, 1); step()
local veh = GSJ.getJobVehicle(2)
check('véhicule sorti', ok and veh ~= nil)
ok = cb('gs_jobs:garage:spawn', 2, 1, 1); step()
check('un seul véhicule à la fois', not ok)
ok = cb('gs_jobs:mission:start', 2); step()
check('mission lancée', ok)
local ev = lastClientEvent('gs_jobs:client:missionStep', 2)
local target = ev.args[1].coords
tp(2, target)
W.entities[veh].pos = target
ok, msg = cb('gs_jobs:mission:step', 2)
check('téléportation détectée', not ok and msg == L('mission_suspicious'))
step(); advance(Config.Missions.cooldown * 1000)
tp(2, Locations.shops[1]); W.entities[veh].pos = Locations.shops[1]
ok = cb('gs_jobs:mission:start', 2); step()
ev = lastClientEvent('gs_jobs:client:missionStep', 2)
check('1re étape loin du joueur', #(ev.args[1].coords - Locations.shops[1]) >= Config.Missions.minStepDistance)
local bankBefore = W.players[2].money.bank
for i = 1, ev.args[1].total do
    local s = lastClientEvent('gs_jobs:client:missionStep', 2).args[1]
    ok = cb('gs_jobs:mission:step', 2)
    check('étape refusée si loin ' .. i, not ok)
    advance(120000)
    tp(2, s.coords); W.entities[veh].pos = s.coords
    ok = cb('gs_jobs:mission:step', 2); step()
    check('étape validée ' .. i, ok)
end
check('mission payée', W.players[2].money.bank > bankBefore)
check('mission terminée', lastClientEvent('gs_jobs:client:missionEnd', 2).args[1] == 'done')

net('gs_jobs:server:toggleDuty', 2); step()
check('fin de service = véhicule rendu', not DoesEntityExist(veh))

-- Actions véhicule (mécano) -------------------------------------------------------------------------
W.commands.gsjob(0, { action = 'add', target = 3, job = 'mechanic', grade = 1 })
net('gs_jobs:server:switch', 3, 'mechanic'); step()
tp(3, Jobs.mechanic.points.duty[1])
net('gs_jobs:server:toggleDuty', 3); step()
local car = CreateVehicleServerSetter(0, 'automobile', 736.0, -1082.0, 22.2)
ok, msg = cb('gs_jobs:vehicle:start', 3, 'repair', car); step()
check('réparation refusée sans kit', not ok)
W.players[3].items.repairkit = 1
ok = cb('gs_jobs:vehicle:start', 3, 'repair', car)
check('réparation démarrée', ok)
ok = cb('gs_jobs:vehicle:finish', 3); step()
check('barre de progression non sautable', not ok and W.players[3].items.repairkit == 1)
cb('gs_jobs:vehicle:start', 3, 'repair', car)
advance(Jobs.mechanic.vehicleActions.repair.duration)
ok = cb('gs_jobs:vehicle:finish', 3); step()
check('réparation terminée, kit consommé', ok and W.players[3].items.repairkit == 0)
check('effet envoyé au client', lastClientEvent('gs_jobs:client:vehicleApply').args[2] == 'repair')
ok = cb('gs_jobs:vehicle:start', 2, 'repair', car); step()
check('non-mécano ne peut pas réparer', not ok)

-- Grades / licenciement ----------------------------------------------------------------------------
tp(1, P.boss[1])
net('gs_jobs:server:switch', 2, 'police'); step()
ok = cb('gs_jobs:boss:action', 1, 'setGrade', { cid = 'CID2', grade = 2 }); step()
check('promotion', ok and Members[2].jobs.police == 2 and W.players[2].job.grade == 2)
ok = cb('gs_jobs:boss:action', 1, 'setGrade', { cid = 'CID1', grade = 0 }); step()
check('pas de rétrogradation de soi-même', not ok)
ok = cb('gs_jobs:boss:action', 1, 'fire', { cid = 'CID2' }); step()
check('licenciement', ok and Members[2].jobs.police == nil and W.players[2].job.name == 'unemployed')
ok = cb('gs_jobs:boss:action', 1, 'nimporte', {}); step()
check('action inconnue refusée', not ok)

-- Rate-limit -----------------------------------------------------------------------------------------
local refused = 0
for _ = 1, 10 do
    local r = cb('gs_jobs:billing:list', 1)
    if #r == 0 and DB.countBills('CID1') > 0 then refused = refused + 1 end
end
DB.createBill('CID1', 'police', 10, 'x', 'CID2', 'Bob')
advance(11000)
refused = 0
for _ = 1, 10 do if #cb('gs_jobs:billing:list', 1) == 0 then refused = refused + 1 end end
check('rate-limit : 5 appels / 10 s', refused == 5)

-- Démission + déconnexion ------------------------------------------------------------------------------
net('gs_jobs:server:resign', 2, 'taxi'); step()
check('démission', Members[2].jobs.taxi == nil and DB.countMemberships('CID2') == 1)
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('déconnexion nettoyée', Members[2] == nil)

-- Carnet de commandes (mécano) -------------------------------------------------------------------------
join(20, 'CID20', 'Client Panne', far)
join(21, 'CID21', 'Meca Service', far)
W.players[21].job = { name = 'mechanic', grade = 1, onduty = true }
local okO, msgO = cb('gs_jobs:orders:create', 20, 'mechanic', 'Pneu crevé')
check('demande de dépannage envoyée', okO and lastClientEvent('gs_jobs:client:orderNew', 21))
check('une seule demande à la fois', not cb('gs_jobs:orders:create', 20, 'mechanic', 'encore'))
check('job sans carnet refusé', not cb('gs_jobs:orders:create', 20, 'police', 'x'))
local listO = cb('gs_jobs:orders:list', 21)
check('liste des demandes (mécano en service)', listO and #listO == 1 and listO[1].message == 'Pneu crevé')
check('liste refusée au client', cb('gs_jobs:orders:list', 20) == nil)
local oid = listO[1].id
check('clôture refusée sans la prendre', not cb('gs_jobs:orders:close', 21, oid))
check('demande prise', cb('gs_jobs:orders:take', 21, oid) == true)
check('demande clôturée', cb('gs_jobs:orders:close', 21, oid) == true and Orders.list[oid] == nil)

-- Blanchiment (entreprise privée) ------------------------------------------------------------------------
provide('gs_wanted', { ReportCrime = function() return true end, GetHeat = function() return 0 end })
ok, msg = cb('gs_jobs:boss:action', 1, 'launder', { amount = 500 }); step()
check('blanchiment : pas dans un service public', not ok and msg:find('Pas de blanchiment'))
join(30, 'CID30', 'Patron Garage', Jobs.mechanic.points.boss[1])
W.commands.gsjob(0, { action = 'add', target = 30, job = 'mechanic', grade = 3 })
net('gs_jobs:server:switch', 30, 'mechanic'); step()
W.players[30].items.black_money = 20000
ok, msg = cb('gs_jobs:boss:action', 30, 'launder', { amount = 1000 }); step()
check('blanchiment : pas de chiffre = pas de blanchiment', not ok and msg:find('chiffre'))
Society.recordRevenue('mechanic', 2000)
ok, msg = cb('gs_jobs:boss:action', 30, 'launder', { amount = 5000 }); step()
check('blanchiment plafonné au chiffre × 1,5', not ok and msg:find('3000'))
local before = Society.balance('mechanic')
ok = cb('gs_jobs:boss:action', 30, 'launder', { amount = 3000 }); step()
check('argent sale pris tout de suite', ok and W.players[30].items.black_money == 17000 and GSJ.launderCap('mechanic') == 0)
GSJ.launderTick()
check('rien avant le délai', Society.balance('mechanic') == before)
GSJ.laundering[1].readyAt = os.time() - 1
GSJ.launderTick()
check('caisse créditée (-30 %)', Society.balance('mechanic') == before + 2100 and #GSJ.laundering == 0)

print = io.write
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
