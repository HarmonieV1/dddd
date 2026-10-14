-- Tests gs_tuning : salon, conducteur, propriété, validation de plaque (format, réservés, interdits, unicité), paiement, néons,
-- mécano (V12.36) : service, distances, client à côté, véhicule inconnu, fusion des réglages, application par le propriétaire réseau.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_tuning', { R .. 'gs_tuning/shared/config.lua' })
local db = { { id = 1, cid = 'CID1', plate = 'ABC 123' }, { id = 2, cid = 'CID2', plate = 'ZZZ 999' } }
local neon = {}
local function norm(p) return (p or ''):upper():gsub('^%s+', ''):gsub('%s+$', '') end
Store = {
    ownedByPlate = function(cid, plate) for _, v in ipairs(db) do if v.cid == cid and norm(v.plate) == norm(plate) then return v.id end end end,
    plateTaken = function(plate) for _, v in ipairs(db) do if norm(v.plate) == norm(plate) then return true end end return false end,
    setPlate = function(id, cid, plate) for _, v in ipairs(db) do if v.id == id and v.cid == cid then v.plate = plate return true end end return false end,
    setNeon = function(id, cid, rgb) neon[id] = rgb or false return true end,
}
function GetPedInVehicleSeat(veh) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end
loadResource('gs_tuning', { R .. 'gs_tuning/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(16000) end
local shop = Config.Shops[1].coords

-- Validation de plaque (pure)
local function v(t) return Tuning.validPlate(t) end
check('plaque valide', v('roadtrip') == 'ROADTRIP' or v('  vice 88 ') == 'VICE 88')
check('trop courte / trop longue', not v('A') and not v('ABCDEFGHI'))
check('caractères interdits', not v('AB-12') and not v('É12') and not v('A;B'))
check('préfixe réservé (police, staff, jobs)', not v('LSPD 1') and not v('ADMIN') and not v('TAXI 22') and not v('L S P D'))
check('mots interdits', not v('MERDE 1') and not v('X FDP') and not v('NIQUE'))
check('non-texte', not v(nil) and not v(12))

-- Joueur avec son véhicule
join(1, 'CID1', 'Proprio', vec3(0.0, 0.0, 0.0))
local car = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[car].plate, W.entities[car].driver = 'ABC 123', 1
W.players[1].vehicle = car
W.players[1].money.bank = 10000
check('hors salon : rien', cb('gs_tuning:info', 1) == nil)
local ok = cb('gs_tuning:plate', 1, 'VICE 88'); step()
check('hors salon : plaque refusée', not ok)
tp(1, shop)
local info = cb('gs_tuning:info', 1); step()
check('infos : véhicule à moi', info and info.ok and info.plate == 'ABC 123')

ok = cb('gs_tuning:plate', 1, 'ZZZ 999'); step()
check('plaque déjà prise', not ok)
ok = cb('gs_tuning:plate', 1, 'LSPD 01'); step()
check('plaque réservée', not ok and W.players[1].money.bank == 10000)
ok = cb('gs_tuning:plate', 1, 'abc 123'); step()
check('même plaque : rien à faire', not ok)
ok, msg, plate = cb('gs_tuning:plate', 1, 'vice 88'); step()
check('plaque changée : payée, base + entité mises à jour', ok and plate == 'VICE 88' and db[1].plate == 'VICE 88' and W.entities[car].plate == 'VICE 88'
    and W.players[1].money.bank == 10000 - Config.PlatePrice)

-- Néons
ok = cb('gs_tuning:neon', 1, 99); step()
check('couleur inconnue', not ok)
local ok2, m2, rgb = cb('gs_tuning:neon', 1, 2); step()
check('néons cyan posés et payés', ok2 and rgb[1] == Config.Neon[2].rgb[1] and neon[1] and W.players[1].money.bank == 10000 - Config.PlatePrice - Config.NeonPrice)
ok2 = cb('gs_tuning:neon', 1, 0); step()
check('éteindre : gratuit', ok2 and neon[1] == false and W.players[1].money.bank == 10000 - Config.PlatePrice - Config.NeonPrice)

-- Véhicule d'un autre / passager / pas d'argent
join(2, 'CID2', 'Autre', shop)
W.players[2].vehicle = car
ok = cb('gs_tuning:neon', 2, 1); step()
check('passager d\'un véhicule qui n\'est pas à lui : refusé', not ok)
W.entities[car].driver = 2
W.entities[car].plate = 'ABC 123'
ok = cb('gs_tuning:neon', 2, 1); step()
check('au volant d\'un véhicule d\'autrui : refusé', not ok)
W.players[1].money.bank, W.players[1].money.cash = 0, 100
W.entities[car].driver = 1 W.entities[car].plate = 'VICE 88'
ok = cb('gs_tuning:plate', 1, 'NEO 01'); step()
check('pas assez d\'argent', not ok and db[1].plate == 'VICE 88')

-- Mécano (V7, V12.36) : personnalisation complète du véhicule d'un client, enregistrée en base, plaque intouchable,
-- client à côté (son accord), réglages fusionnés (état du véhicule gardé), appliqués par le propriétaire réseau.
local onduty = {}
local bills = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return onduty[src] == job end,
    CreateBill = function(cid, job, amount, reason) bills[#bills + 1] = { cid = cid, job = job, amount = amount, reason = reason } return true end })
local saved = {}
local propsDb = { [2] = { model = 777, plate = 'ZZZ 999', fuelLevel = 42, lockState = 2, modEngine = -1, color1 = 0 }, [5] = { model = 1 } }
db[#db + 1] = { id = 3, cid = 'CID5', plate = 'MEC 001' }   -- la voiture du mécano lui-même
db[#db + 1] = { id = 4, cid = nil, plate = 'SOC 001' }      -- véhicule enregistré sans propriétaire (citizenid NULL)
db[#db + 1] = { id = 5, cid = 'CID9', plate = 'OFF 001' }   -- propriétaire jamais connecté
Store.byPlate = function(plate) for _, v in ipairs(db) do if norm(v.plate) == norm(plate) then return v.id, v.plate, v.cid end end end
Store.getProps = function(id) return propsDb[id] end
Store.setProps = function(id, json) saved[id] = json return true end
loadResource('gs_tuning', { R .. 'gs_tuning/server/mechanic.lua' })
json = { encode = function(t) return ('plate=%s;engine=%s;fuel=%s;model=%s;lock=%s'):format(tostring(t.plate), tostring(t.modEngine), tostring(t.fuelLevel), tostring(t.model), tostring(t.lockState)) end }
join(5, 'CID5', 'Mecano', vec3(0.0, 0.0, 0.0))
local client = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0) -- la voiture du joueur 2 (CID2, encore au salon : loin)
W.entities[client].plate, W.entities[client].model = 'ZZZ 999', 777
W.players[2].vehicle = nil
local okM, msgM = cb('gs_tuning:mechanicCheck', 5, client); step()
check('mécano hors service : refusé', not okM and msgM:find('mécanos'))
onduty[5] = 'mechanic'
local offline = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[offline].plate, W.entities[offline].model = 'OFF 001', 1
okM, msgM = cb('gs_tuning:mechanicCheck', 5, offline); step()
check('V12.36 propriétaire hors ligne : refusé avec message', not okM and msgM:find('propriétaire'))
okM, msgM = cb('gs_tuning:mechanicCheck', 5, client); step()
check('V12.36 client trop loin de sa voiture : refusé avec message', not okM and msgM:find('client doit rester'))
tp(2, vec3(3.0, 0.0, 0.0))
check('véhicule du client (client à côté) : accepté', cb('gs_tuning:mechanicCheck', 5, client)); step()
tp(5, vec3(50.0, 0.0, 0.0))
okM, msgM = cb('gs_tuning:mechanicCheck', 5, client); step()
check('mécano trop loin du véhicule', not okM and msgM:find('Approche'))
tp(5, vec3(0.0, 0.0, 0.0))
local rental = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[rental].plate = 'LOC 001'
okM, msgM = cb('gs_tuning:mechanicCheck', 5, rental); step()
check('véhicule sans propriétaire : refusé avec message', not okM and msgM:find('personne'))
local shared = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[shared].plate = 'SOC 001'
check('véhicule enregistré sans citizenid : refusé', not cb('gs_tuning:mechanicCheck', 5, shared)); step()
check('véhicule inconnu (netId sans entité) : refusé', not cb('gs_tuning:mechanicCheck', 5, 99999)); step()
local mine = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[mine].plate, W.entities[mine].model = 'MEC 001', 555
check('sa propre voiture : accepté sans autre client', cb('gs_tuning:mechanicCheck', 5, mine)); step()

-- Enregistrement : fusion (état gardé), plaque d'origine, appliqué par le propriétaire réseau
W.entities[client].owner = 2
local okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { plate = 'HACK', modEngine = 3, fuelLevel = 100, lockState = 1, model = 777 }); step()
check("enregistré, plaque d'origine gardée", okS and saved[2] and saved[2]:find('plate=ZZZ 999') and saved[2]:find('engine=3'))
check('V12.36 état du véhicule gardé depuis la base (carburant, verrou, modèle)', saved[2] and saved[2]:find('fuel=42') and saved[2]:find('lock=2') and saved[2]:find('model=777'))
local ev = lastClientEvent('gs_tuning:client:applyProps', 2)
check('V12.36 réglages envoyés au propriétaire réseau du véhicule', ev ~= nil and ev.args[1] == client)
check('V12.36 réglages appliqués sans plaque, modèle ni état', ev and ev.args[2].modEngine == 3 and ev.args[2].plate == nil and ev.args[2].fuelLevel == nil and ev.args[2].lockState == nil)
check('message de réussite avec la plaque', msgS and msgS:find('ZZZ 999'))
W.entities[client].owner = nil
cb('gs_tuning:mechanicSave', 5, client, { modEngine = 2 }); step()
check('V12.36 sans propriétaire réseau connu : envoyé au mécano', lastClientEvent('gs_tuning:client:applyProps', 5) ~= nil)
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 3, model = 1 }); step()
check("V12.36 réglages d'un autre véhicule : refusés", not okS and msgS:find('viennent pas'))
W.entities[client].model = 999
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 3 }); step()
check('V12.36 fausse plaque (modèle différent de la carte grise) : refusé', not okS and msgS:find('carte grise'))
W.entities[client].model = 777
check('réglages invalides refusés', not cb('gs_tuning:mechanicSave', 5, client, 'pas une table')); step()
Store.setProps = function() return false end
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 3 }); step()
check("V12.36 erreur d'écriture : message clair", not okS and msgS:find('Erreur'))
Store.setProps = function(id, json) saved[id] = json return true end
propsDb[2] = nil
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 3 }); step()
check('V12.36 ligne disparue : refusé', not okS and msgS:find('plus enregistré'))
propsDb[2] = {}
okS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 4 }); step()
check("V12.36 carte grise vide : modèle et plaque posés depuis l'entité", okS and saved[2]:find('model=777') and saved[2]:find('plate=ZZZ 999') and saved[2]:find('engine=4'))
tp(2, vec3(100.0, 0.0, 0.0))
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 3 }); step()
check('V12.36 enregistrement refusé si le client est parti', not okS and msgS:find('client doit rester'))


-- V12.40 · Aperçu vu par tous (relayé au propriétaire réseau), prix recalculés par le serveur, facture automatique
tp(2, vec3(3.0, 0.0, 0.0))
W.entities[client].owner = 2
local orig = { modEngine = -1, color1 = 0, modSpoilers = -1 }
check('V12.40 ouverture de session', cb('gs_tuning:mechanicCheck', 5, client, orig)); step()
net('gs_tuning:server:preview', 5, client, { modEngine = 2, plate = 'HACK', fuelLevel = 100 })
local pv = lastClientEvent('gs_tuning:client:applyProps', 2)
check('V12.40 aperçu relayé au propriétaire réseau, sans plaque ni état', pv and pv.args[2].modEngine == 2 and pv.args[2].plate == nil and pv.args[2].fuelLevel == nil)
local before = #W.clientEvents
net('gs_tuning:server:preview', 5, rental, { modEngine = 2 })
check('V12.40 aperçu refusé sur un autre véhicule que la session', #W.clientEvents == before)
bills = {}
propsDb[2] = { model = 777, plate = 'ZZZ 999' }
okS, msgS = cb('gs_tuning:mechanicSave', 5, client, { modEngine = 2, color1 = 27, modSpoilers = 1, modTurbo = false }); step()
local P = Config.Mechanic.prices
local expected = P.perf.modEngine[3] + P.keys.color1 + P.mod
check('V12.40 facture automatique au client, prix du serveur', okS and #bills == 1 and bills[1].cid == 'CID2' and bills[1].job == 'mechanic' and bills[1].amount == expected)
check('V12.40 message avec le montant', msgS and msgS:find(tostring(expected)))
check('V12.40 session close après validation', Mechanic.sessions[5] == nil)
net('gs_tuning:server:preview', 5, client, { modEngine = 3 })
check('V12.40 plus d\'aperçu sans session', lastClientEvent('gs_tuning:client:applyProps', 2).args[2].modEngine == 2)
check('V12.40 prix : d\'origine gratuit, turbo, plafond', Mechanic.price('modEngine', -1) == 0 and Mechanic.price('modTurbo', true) == P.turbo
    and Mechanic.bill({}, { modEngine = 3, modArmor = 4, modBrakes = 2, modTransmission = 2, modSuspension = 3, modTurbo = true, color1 = 1, customPrimaryColor = { 1, 2, 3 } }) <= Config.Mechanic.maxBill)
bills = {}
cb('gs_tuning:mechanicCheck', 5, mine, {}); step()
cb('gs_tuning:mechanicSave', 5, mine, { modEngine = 1 }); step()
check('V12.40 sa propre voiture : pas de facture', #bills == 0)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
