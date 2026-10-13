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
PointsStore = { init = function() end, all = function() return {} end, save = function() end } -- V12.37 : points.lua (armurerie) chargé
loadResource('gs_jobs', {
    R .. 'gs_jobs/server/society.lua', R .. 'gs_jobs/server/members.lua', R .. 'gs_jobs/server/payroll.lua',
    R .. 'gs_jobs/server/garage.lua', R .. 'gs_jobs/server/stash.lua', R .. 'gs_jobs/server/points.lua', R .. 'gs_jobs/server/boss.lua',
    R .. 'gs_jobs/server/billing.lua', R .. 'gs_jobs/server/vehicle_actions.lua',
    R .. 'gs_jobs/server/missions.lua', R .. 'gs_jobs/server/admin.lua', R .. 'gs_jobs/server/orders.lua',
})
DB.init()
GSJ.checkArmories()

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
net('gs_jobs:server:toggleDuty', 2, true); step()
check('V11.5 par téléphone sans téléphone : refusé', not W.players[2].job.onduty)
W.players[2].items.phone = 1
net('gs_jobs:server:toggleDuty', 2, true); step()
check('V11.5 par téléphone, loin du point : accepté', W.players[2].job.onduty)
net('gs_jobs:server:toggleDuty', 2, true); step()
check('fin de service par téléphone', not W.players[2].job.onduty)
W.players[2].items.phone = nil
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

-- V12.39 · Éboueur : sac porté de la poubelle à la benne, tournée payée au dépôt -------------------------------------
tp(3, Config.JobCenter.coords)
net('gs_jobs:server:joinPublic', 3, 'garbage'); step()
net('gs_jobs:server:switch', 3, 'garbage'); step()
net('gs_jobs:server:toggleDuty', 3); step()
local GG = Jobs.garbage.points.garage[1]
tp(3, GG.coords)
ok, msg = cb('gs_jobs:garage:spawn', 3, 1, 1); step()
local truck = GSJ.getJobVehicle(3)
check('benne sortie', ok and truck ~= nil)
ok = cb('gs_jobs:mission:start', 3); step()
check('tournée lancée', ok)
local gBank = W.players[3].money.bank
local gTotal = lastClientEvent('gs_jobs:client:missionStep', 3).args[1].total
check('étape avec sac à porter', lastClientEvent('gs_jobs:client:missionStep', 3).args[1].carry ~= nil)
for i = 1, gTotal do
    local s = lastClientEvent('gs_jobs:client:missionStep', 3).args[1]
    advance(120000)
    tp(3, s.coords); W.entities[truck].pos = s.coords + vec3(10.0, 0.0, 0.0)
    ok, msg = cb('gs_jobs:mission:step', 3)
    check('sac à ramasser avant la benne ' .. i, not ok and msg == L('mission_pick_first'))
    advance(6000)
    ok = cb('gs_jobs:mission:pickup', 3)
    check('sac ramassé ' .. i, ok)
    advance(6000)
    ok, msg = cb('gs_jobs:mission:pickup', 3)
    check('un seul sac à la fois ' .. i, not ok and msg == L('mission_carrying'))
    advance(6000)
    ok, msg = cb('gs_jobs:mission:step', 3)
    check('sac jeté loin de la benne refusé ' .. i, not ok and msg == L('too_far'))
    advance(6000)
    tp(3, s.coords + vec3(8.0, 0.0, 0.0))
    ok = cb('gs_jobs:mission:step', 3); step()
    check('sac jeté dans la benne ' .. i, ok)
    check('rien payé en route ' .. i, W.players[3].money.bank == gBank)
end
local dep = lastClientEvent('gs_jobs:client:missionStep', 3).args[1]
check('retour au dépôt demandé', dep.kind == 'depot' and #(dep.coords - GG.coords) < 0.1)
advance(6000)
ok, msg = cb('gs_jobs:mission:depot', 3)
check('dépôt : il faut y être', not ok and msg == L('too_far'))
advance(120000)
tp(3, GG.coords); W.entities[truck].pos = GG.coords + vec3(5.0, 0.0, 0.0)
ok = cb('gs_jobs:mission:depot', 3); step()
check('tournée payée au dépôt', ok and W.players[3].money.bank > gBank)
check('tournée terminée', lastClientEvent('gs_jobs:client:missionEnd', 3).args[1] == 'done')
ok = cb('gs_jobs:mission:depot', 3)
check('pas de double paiement au dépôt', not ok)
net('gs_jobs:server:toggleDuty', 3); step()

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

-- V12.36 · PNJ aux points de métier (gs_markers) : config valide, index existants, jamais sur coffre / armurerie / vestiaire --
local function validPed(p)
    return type(p) == 'table' and type(p.model) == 'string' and p.model ~= '' and type(p.heading) == 'number'
        and p.heading >= 0 and p.heading < 360 and (p.scenario == nil or (type(p.scenario) == 'string' and p.scenario ~= ''))
end
local PED_KINDS = { duty = true, boss = true, garage = true }
local nPeds, badPeds, orphanPeds, badKinds = 0, 0, 0, 0
for name, def in pairs(Jobs) do
    for kind, list in pairs(def.peds) do
        if not PED_KINDS[kind] then badKinds = badKinds + 1 end
        for i, p in pairs(list) do
            nPeds = nPeds + 1
            if not validPed(p) then badPeds = badPeds + 1 end
            if not (def.points[kind] and def.points[kind][i]) then orphanPeds = orphanPeds + 1 end
        end
    end
end
check('PNJ de métier : au moins vingt points habités', nPeds >= 20)
check('PNJ de métier : modèle non vide, cap dans [0, 360[, scénario texte', badPeds == 0)
check('PNJ de métier : chaque PNJ a son point (même index)', orphanPeds == 0)
check('PNJ de métier : seulement accueil, direction, garage', badKinds == 0)
check('PNJ de métier : chaque métier avec accueil / direction / garage en a au moins un', (function()
    for _, def in pairs(Jobs) do
        local p = def.points
        local has = (p.duty and #p.duty > 0) or (p.boss and #p.boss > 0) or (p.garage and #p.garage > 0)
        if has and next(def.peds) == nil then return false end
    end
    return true
end)())
check('PNJ du Pôle Emploi (agent d\'accueil)', validPed(Config.JobCenter.ped))

-- V12.37 · Garage : message exact pour chaque refus (avant : « Tu dois être en service. » dans tous les cas) -----------------
local GP = Jobs.police.points.garage[1]
join(40, 'CID40', 'Sans Metier', GP.coords)
ok, msg = cb('gs_jobs:garage:spawn', 40, 1, 1, 'police'); step()
check('V12.37 garage sans métier actif : message exact', not ok and msg == L('no_active_job'))
W.commands.gsjob(0, { action = 'add', target = 40, job = 'police', grade = 1 })
net('gs_jobs:server:switch', 40, 'police'); step()
ok, msg = cb('gs_jobs:garage:spawn', 40, 1, 1, 'ambulance'); step()
check('V12.37 garage d\'un autre métier : message exact', not ok and msg == L('wrong_job_garage', 'EMS'))
ok, msg = cb('gs_jobs:garage:spawn', 40, 1, 1, 'police'); step()
check('V12.37 garage hors service : « Tu dois être en service. »', not ok and msg == L('not_on_duty'))
ok, msg = cb('gs_jobs:garage:store', 40, 1, 'police'); step()
check('V12.37 ranger hors service : même message exact', not ok and msg == L('not_on_duty'))
ok, msg = cb('gs_jobs:garage:spawn', 40, 1, 1); step()
check('V12.37 ancien appel sans nom de métier : toujours accepté', not ok and msg == L('not_on_duty'))

-- V12.37 · Prise de service : double déclenchement (PNJ + zone, [E] + clic) ne rebascule plus hors service ------------------
tp(40, P.duty[1])
net('gs_jobs:server:toggleDuty', 40, false, true)
net('gs_jobs:server:toggleDuty', 40, false, true) -- même instant
check('V12.37 double déclenchement : toujours en service', W.players[40].job.onduty == true)
step()
net('gs_jobs:server:toggleDuty', 40, false, true)
check('V12.37 déjà en service : état inchangé, message exact', W.players[40].job.onduty == true and W.notes[40].msg == L('already_on_duty'))
tp(40, GP.coords)
check('V12.37 en service : le garage ne refuse plus', (cb('gs_jobs:garage:spawn', 40, 1, 1, 'police')) == true)
step()
W.players[40].items.phone = 1
net('gs_jobs:server:toggleDuty', 40, true) -- appli téléphone (sans intention, loin du point) : bascule → hors service
advance(500)
net('gs_jobs:server:toggleDuty', 40, true) -- 2e bascule 0,5 s plus tard : ignorée
check('V12.37 bascule rapprochée ignorée (anti-rebond)', W.players[40].job.onduty == false)
check('V12.37 fin de service : véhicule rendu', GSJ.getJobVehicle(40) == nil)
step()
net('gs_jobs:server:toggleDuty', 40, true, false)
check('V12.37 déjà hors service : message exact', W.players[40].job.onduty == false and W.notes[40].msg == L('already_off_duty'))

-- V12.37 · Équipement de service : prêté, repris à la fin du service (seulement les quantités fournies) ----------------------
join(41, 'CID41', 'Agent Equipe', P.armory[1])
W.commands.gsjob(0, { action = 'add', target = 41, job = 'police', grade = 1 })
net('gs_jobs:server:switch', 41, 'police'); step()
W.players[41].items.handcuffs = 1      -- une paire à lui, d'avant
W.players[41].items['ammo-9'] = 20     -- 20 balles à lui
W.players[41].items.phone = 1
net('gs_jobs:server:toggleDuty', 41, true, true); step() -- par téléphone
check('V12.37 en service par téléphone', W.players[41].job.onduty == true)
ok = cb('gs_jobs:armory', 41, 'handcuffs'); step()
check('V12.37 menottes complétées : 1 fournie (il en avait 1)', ok and W.players[41].items.handcuffs == 2 and Armory.issued[41].handcuffs.given == 1 and Armory.issued[41].handcuffs.base == 1)
cb('gs_jobs:armory', 41, 'WEAPON_PISTOL'); step()
cb('gs_jobs:armory', 41, 'ammo-9'); step()
check('V12.37 arme + 40 balles fournies', W.players[41].items.WEAPON_PISTOL == 1 and W.players[41].items['ammo-9'] == 60 and Armory.issued[41]['ammo-9'].given == 40)
check('V12.37 suivi écrit en KVP (par citizenid)', W_KVP['gs_jobs:armory:CID41'] == 'WEAPON_PISTOL=1/0,ammo-9=40/20,handcuffs=1/1')
W.players[41].items['ammo-9'] = 35 -- il a tiré 25 balles
net('gs_jobs:server:toggleDuty', 41, true, false); step() -- fin de service par téléphone (/service)
check('V12.37 fin de service : arme reprise', W.players[41].items.WEAPON_PISTOL == 0)
check('V12.37 fin de service : la paire de menottes fournie reprise, la sienne reste', W.players[41].items.handcuffs == 1)
check('V12.37 fin de service : munitions reprises sans toucher aux 20 à lui (35 → 20)', W.players[41].items['ammo-9'] == 20)
check('V12.37 suivi remis à zéro (mémoire + KVP)', Armory.issued[41] == nil and W_KVP['gs_jobs:armory:CID41'] == nil)
check('V12.37 audit du rendu', (function()
    for i = #W.audit, 1, -1 do if W.audit[i].action == 'armory_return' then return W.audit[i].amount == 17 end end
    return false
end)())
net('gs_jobs:server:toggleDuty', 41, true, false); step()
check('V12.37 hors service sans équipement : rien repris, pas de message « rendu »', W.notes[41].msg == L('already_off_duty'))

-- Changement de métier
net('gs_jobs:server:toggleDuty', 41, true, true); step()
cb('gs_jobs:armory', 41, 'WEAPON_PISTOL'); step()
check('V12.37 arme refournie en service', W.players[41].items.WEAPON_PISTOL == 1)
W.commands.gsjob(0, { action = 'add', target = 41, job = 'taxi', grade = 0 })
net('gs_jobs:server:switch', 41, 'taxi'); step()
check('V12.37 changement de métier : arme reprise', W.players[41].items.WEAPON_PISTOL == 0 and Armory.issued[41] == nil)

-- Licenciement du métier actif
net('gs_jobs:server:switch', 41, 'police'); step()
net('gs_jobs:server:toggleDuty', 41, true, true); step()
cb('gs_jobs:armory', 41, 'WEAPON_PISTOL'); step()
cb('gs_jobs:armory', 41, 'radio'); step()
check('V12.37 équipé avant licenciement', W.players[41].items.WEAPON_PISTOL == 1 and W.players[41].items.radio == 1)
tp(1, P.boss[1])
ok = cb('gs_jobs:boss:action', 1, 'fire', { cid = 'CID41' }); step()
check('V12.37 licenciement : arme et radio reprises', ok and W.players[41].items.WEAPON_PISTOL == 0 and W.players[41].items.radio == 0)

-- Déconnexion (le joueur est encore chargé quand gs_jobs passe)
W.commands.gsjob(0, { action = 'add', target = 41, job = 'police', grade = 1 })
net('gs_jobs:server:switch', 41, 'police'); step()
net('gs_jobs:server:toggleDuty', 41, true, true); step()
cb('gs_jobs:armory', 41, 'WEAPON_PISTOL'); step()
TriggerEvent('gs_bridge:server:playerUnloaded', 41)
check('V12.37 déconnexion : équipement repris + message « Équipement de service rendu »', W.players[41].items.WEAPON_PISTOL == 0 and W.notes[41].msg == L('armory_returned'))
check('V12.37 déconnexion : KVP vide', W_KVP['gs_jobs:armory:CID41'] == nil)

-- Déconnexion brutale : Qbox a déjà déchargé le joueur → repris à la reconnexion, une fois l'inventaire chargé
join(42, 'CID42', 'Parti Vite', P.armory[1])
W.commands.gsjob(0, { action = 'add', target = 42, job = 'police', grade = 1 })
net('gs_jobs:server:switch', 42, 'police'); step()
W.players[42].items.phone = 1
net('gs_jobs:server:toggleDuty', 42, true, true); step()
cb('gs_jobs:armory', 42, 'WEAPON_PISTOL'); step()
cb('gs_jobs:armory', 42, 'ammo-9'); step()
local bag = W.players[42].items
W.players[42] = nil
TriggerEvent('gs_bridge:server:playerUnloaded', 42)
check('V12.37 déco brutale : suivi conservé en KVP, mémoire libérée', W_KVP['gs_jobs:armory:CID42'] == 'WEAPON_PISTOL=1/0,ammo-9=60/0' and Armory.issued[42] == nil)
local deferred
local realTimeout = SetTimeout
SetTimeout = function(_, fn) deferred = fn end -- l'inventaire ox_inventory arrive après le personnage
join(42, 'CID42', 'Parti Vite', far)
SetTimeout = realTimeout
W.players[42].items = bag
check('V12.37 reconnexion : reprise différée, rien touché avant le chargement de l\'inventaire', bag.WEAPON_PISTOL == 1 and deferred ~= nil)
deferred()
check('V12.37 reconnexion : équipement repris, KVP effacé', bag.WEAPON_PISTOL == 0 and bag['ammo-9'] == 0 and W_KVP['gs_jobs:armory:CID42'] == nil)
check('V12.37 encodage / décodage du suivi', (function()
    local t = Armory.decode(Armory.encode({ ['ammo-9'] = { given = 40, base = 20 }, radio = { given = 1, base = 0 }, vide = { given = 0, base = 3 } }))
    return t['ammo-9'].given == 40 and t['ammo-9'].base == 20 and t.radio.given == 1 and t.vide == nil and next(Armory.decode(nil)) == nil
end)())

print = io.write
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
