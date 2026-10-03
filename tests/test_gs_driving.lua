-- Tests gs_driving : permis retiré aux nouveaux (anciens avec véhicule conservés), code (tirage, correction serveur,
-- délai), conduite (points dans l'ordre, vitesse et dégâts relevés serveur, abandon), moniteur.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
loadResource('gs_driving', { R .. 'gs_driving/shared/config.lua' })
local rows, vehicles = {}, { OLD = true }
Store = { init = function() end, get = function(cid) return rows[cid] end, set = function(cid, s) rows[cid] = s end,
    hasVehicle = function(cid) return vehicles[cid] == true end }
function GetVehicleBodyHealth(veh) return W.entities[veh] and (W.entities[veh].body or 1000.0) or 0 end
function GetEntitySpeed(veh) return W.entities[veh] and (W.entities[veh].speed or 0.0) or 0 end
function GetPedInVehicleSeat(veh) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end
loadResource('gs_driving', { R .. 'gs_driving/server/main.lua' })
local P = Config.Practical

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

-- Connexion : ancien avec véhicule garde son permis, nouveau le perd
join(1, 'CID1', 'Nouveau', Config.Desk) W.players[1].licences = { driver = true }
join(2, 'OLD', 'Ancien', Config.Desk) W.players[2].licences = { driver = true }
rows = {} Driving.onLoaded(1) Driving.onLoaded(2)
check('nouveau personnage : permis retiré', W.players[1].licences.driver == false and rows.CID1 == 0)
check('ancien avec véhicule : permis conservé', W.players[2].licences.driver == true and rows.OLD == 2)

-- Code
W.players[1].money.bank = 5000
local ok, qs = cb('gs_driving:theoryStart', 1); step()
if not ok then io.stderr:write(tostring(qs)..'\n') end
check('code : questions sans les réponses', ok and #qs == Config.Theory.questions and qs[1].answer == nil and qs[1].options)
local quiz = Driving.quiz[1]
local wrong = {}
for i, id in ipairs(quiz.ids) do wrong[i] = (Config.Questions[id].answer % 3) + 1 end
ok = cb('gs_driving:theoryAnswer', 1, wrong); step()
check('toutes fausses : raté, payé', not ok and rows.CID1 == 0 and W.players[1].money.bank == 5000 - Config.Theory.price)
ok = cb('gs_driving:theoryStart', 1); step()
check('délai avant de repasser', not ok)
advance(Config.Theory.cooldown * 1000)
ok = cb('gs_driving:theoryStart', 1); step()
local right = {}
for i, id in ipairs(Driving.quiz[1].ids) do right[i] = Config.Questions[id].answer end
right[1] = 0 right[2] = 0 -- 8 / 10
ok = cb('gs_driving:theoryAnswer', 1, right); step()
check('8 / 10 : code obtenu', ok and rows.CID1 == 1)
ok = cb('gs_driving:theoryAnswer', 1, right); step()
check('pas de deuxième correction sans nouvel essai', not ok)

-- Conduite
ok = cb('gs_driving:practicalStart', 2); step()
check('déjà permis : refusé', not ok)
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_driving:practicalStart', 1); step()
check('hors de l\'accueil', not ok)
tp(1, Config.Desk)
ok = cb('gs_driving:practicalStart', 1); step()
local e = Driving.exams[1]
check('examen lancé : véhicule créé, payé', ok and e and W.entities[e.veh] and W.players[1].money.bank == 5000 - 2 * Config.Theory.price - P.price)
W.entities[e.veh].driver = 1
W.entities[e.veh].pos = P.route[2]
tp(1, P.route[2])
ok = cb('gs_driving:checkpoint', 1); step()
check('point sauté : refusé', not ok and e.cp == 0)
W.entities[e.veh].pos = P.route[1] tp(1, P.route[1])
ok = cb('gs_driving:checkpoint', 1); step()
check('point 1 validé', ok and e.cp == 1)
W.entities[e.veh].speed = P.speedLimit * 1.5
Driving.tick() Driving.tick()
check('excès de vitesse : une faute (pas à chaque seconde)', e.faults == 1)
W.entities[e.veh].speed = 10.0 Driving.tick()
W.entities[e.veh].body = 1000.0 - P.damageFault - 1
Driving.tick()
check('choc : faute', e.faults == 2)
for i = 2, #P.route do
    W.entities[e.veh].pos = P.route[i] tp(1, P.route[i])
    ok = cb('gs_driving:checkpoint', 1); step()
end
check('parcours fini : permis obtenu, véhicule rendu', Driving.exams[1] == nil and rows.CID1 == 2 and W.players[1].licences.driver == true and not W.entities[e.veh])

-- Échec par fautes
join(3, 'CID3', 'Chauffard', Config.Desk) W.players[3].money.bank = 5000
rows.CID3 = 1
local okk, rr = cb('gs_driving:practicalStart', 3); step() if not okk then io.stderr:write(tostring(rr)..'\n') end
local e3 = Driving.exams[3]
W.entities[e3.veh].driver = 3
for _ = 1, P.maxFaults + 1 do
    if not Driving.exams[3] then break end
    W.entities[e3.veh].speed = 99 Driving.tick()
    if not Driving.exams[3] then break end
    W.entities[e3.veh].speed = 0 Driving.tick()
end
check('trop de fautes : raté, véhicule rendu', Driving.exams[3] == nil and rows.CID3 == 1 and not W.entities[e3.veh])

-- Moniteur
join(4, 'CID4', 'Moniteur', Config.Desk)
ok = cb('gs_driving:grant', 4, 3); step()
check('hors service : refusé', not ok)
duty[4] = Config.Job
ok = cb('gs_driving:grant', 4, 3); step()
check('moniteur : permis délivré', ok and rows.CID3 == 2 and W.players[3].licences.driver == true)
rows.CID5 = 0 join(5, 'CID5', 'Sans code', Config.Desk)
ok = cb('gs_driving:grant', 4, 5); step()
check('moniteur : il faut le code', not ok)

-- V8 · Permis à points --------------------------------------------------------------------------------------------
do
    local pts = {}
    Store.points = function(cid) local r = pts[cid] if not r then return nil end return r[1], r[2] end
    Store.setPoints = function(cid, p, last) pts[cid] = { p, last } end
    local records = {}
    provide('gs_police', { AddRecord = function(cid, charge) records[#records + 1] = charge return true end })
    rows.OLD = 2 W.players[2].licences.driver = true
    check('permis : 12 points au départ', Driving.points('OLD') == 12)
    check('retrait de 3 points', Driving.removePoints(2, 3, 'Excès de vitesse') == 9)
    check('retrait hors limites refusé', Driving.removePoints(2, 9, 'x') == nil and Driving.removePoints(2, 0, 'x') == nil)
    join(9, 'CID9', 'Sans Permis', Config.Desk) rows.CID9 = 0
    check('sans permis : pas de points', Driving.removePoints(9, 2, 'x') == nil)
    advance(Config.Points.recoverDays * 86400 * 1000 + 1000)
    check('récupération : +1 point après la période sans infraction', Driving.points('OLD') == 10)
    Driving.removePoints(2, 6, 'Refus d\'obtempérer')
    check('solde 4', Driving.points('OLD') == 4)
    check('solde nul : permis annulé, retour à l\'auto-école', Driving.removePoints(2, 6, 'Délit de fuite') == 0
        and rows.OLD == 0 and W.players[2].licences.driver == false and records[#records]:find('Permis annulé'))
    check('plus de permis : plus de points', Driving.points('OLD') == nil)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
