-- Tests gs_police : service obligatoire, distance, menottes (item), escorte, véhicule, fouille, prison persistante,
-- casier, fourrière, objets de voirie + herse, EMS (réanimer / soigner).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end,
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end })
provide('gs_wanted', { GetHeat = function(s) return s == 2 and 40 or 0 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_police', { R .. 'gs_police/shared/config.lua' })
local records, jail = {}, {}
Store = {
    init = function() end,
    addRecord = function(cid, charge, fine, j, officer) records[#records + 1] = { cid = cid, charge = charge, fine = fine, jail = j, officer = officer } end,
    records = function(cid) local l = {} for _, r in ipairs(records) do if r.cid == cid then l[#l + 1] = r end end return l end,
    jailSet = function(cid, u, r) jail[cid] = { until_ts = u, reason = r } end,
    jailGet = function(cid) return jail[cid] end,
    jailClear = function(cid) jail[cid] = nil end,
}
loadResource('gs_police', { R .. 'gs_police/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(2000) end
local here = vec3(200.0, -800.0, 30.0)
local function st(src) return W.pstate[src] or {} end

join(1, 'CID1', 'Agent Un', here, { name = 'police', grade = 1, onduty = true })
join(2, 'CID2', 'Suspect', vec3(201.0, -800.0, 30.0))
join(3, 'CID3', 'Ambulancier', vec3(202.0, -800.0, 30.0), { name = 'ambulance', grade = 0, onduty = true })
join(4, 'CID4', 'Civil', vec3(201.5, -800.0, 30.0))

local ok, msg = cb('gs_police:action', 1, 'cuff', 2); step()
check('hors service : refusé', not ok)
duty[1], duty[3] = 'police', 'ambulance'
ok, msg = cb('gs_police:action', 1, 'cuff', 2); step()
check('menottes requises', not ok and msg:find('menottes'))
W.players[1].items.handcuffs = 1
tp(2, vec3(260.0, -800.0, 30.0))
ok = cb('gs_police:action', 1, 'cuff', 2); step()
check('trop loin', not ok)
tp(2, vec3(201.0, -800.0, 30.0))
ok = cb('gs_police:action', 4, 'cuff', 2); step()
check('civil : refusé', not ok)
ok = cb('gs_police:action', 1, 'cuff', 2); step()
check('menotté (state bag)', ok and st(2).gsCuffed == true)
ok = cb('gs_police:action', 1, 'cuff', 1); step()
check('pas sur soi-même', not ok)

-- Fouille
ok = cb('gs_police:action', 1, 'search', 4); step()
check('fouille refusée si ni menotté ni mains en l\'air', not ok)
Player(4).state:set('gsHandsUp', true)
ok = cb('gs_police:action', 1, 'search', 4); step()
check('fouille : mains en l\'air OK', ok)
ok = cb('gs_police:action', 1, 'search', 2); step()
check('fouille : menotté OK', ok)

-- Escorte
ok = cb('gs_police:action', 1, 'escort', 4); step()
check('escorte refusée sur non menotté', not ok)
ok = cb('gs_police:action', 1, 'escort', 2); step()
check('escorte', ok and st(2).gsEscortedBy == 1)
ok = cb('gs_police:action', 1, 'escort', 2); step()
check('fin d\'escorte', ok and st(2).gsEscortedBy == nil)

-- Véhicule
local car = CreateVehicleServerSetter(0, 'automobile', 203.0, -800.0, 30.0)
ok = cb('gs_police:action', 1, 'putin', 2, { netId = car }); step()
check('mis dans le véhicule', ok and lastClientEvent('gs_police:client:putIn', 2).args[1] == car)
ok = cb('gs_police:action', 1, 'putin', 2, { netId = 99999 }); step()
check('véhicule inexistant', not ok)
ok = cb('gs_police:action', 1, 'takeout', 2); step()
check('sortir : pas en véhicule', not ok)
W.players[2].vehicle = car
ok = cb('gs_police:action', 1, 'takeout', 2); step()
check('sorti du véhicule', ok)
W.players[2].vehicle = nil

-- Casier
ok = cb('gs_police:action', 1, 'record', 2, { charge = 'Excès de vitesse', fine = 250 }); step()
check('casier : ajout', ok and records[1].charge == 'Excès de vitesse' and records[1].fine == 250)
ok = cb('gs_police:action', 1, 'record', 2, { charge = '' }); step()
check('casier : infraction obligatoire', not ok)
local list
ok, list = cb('gs_police:action', 1, 'records', 2); step()
check('casier : lecture', ok and #list == 1)

-- Prison
W.players[1].job.grade = 0
ok = cb('gs_police:action', 1, 'jail', 2, { minutes = 5, reason = 'Vol' }); step()
check('prison : grade requis', not ok)
W.players[1].job.grade = 1
ok = cb('gs_police:action', 1, 'jail', 2, { minutes = 500, reason = 'Vol' }); step()
check('prison : durée max', not ok)
ok = cb('gs_police:action', 1, 'jail', 2, { minutes = 5, reason = 'Vol à main armée' }); step()
check('incarcéré, démenotté, au casier', ok and Police.jailed[2] and st(2).gsCuffed == nil and jail.CID2 and #records == 2)
tp(2, vec3(0.0, 0.0, 0.0))
Police.jailTick()
local c = Config.Jail.cell
check('évasion : ramené', #(W.players[2].pos - vec3(c.x, c.y, c.z)) < 1)
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
join(2, 'CID2', 'Suspect', vec3(0.0, 0.0, 0.0))
check('déco / reco : toujours en prison', Police.jailed[2] ~= nil)
advance(6 * 60000)
Police.jailTick()
check('libéré à l\'échéance', not Police.jailed[2] and not jail.CID2)
tp(2, vec3(201.0, -800.0, 30.0))

-- Fourrière
W.entities[car].driver = 2
ok = cb('gs_police:action', 1, 'impound', nil, { netId = car }); step()
check('fourrière refusée si conducteur', not ok)
W.entities[car].driver = nil
ok = cb('gs_police:action', 1, 'impound', nil, { netId = car }); step()
check('fourrière', ok and not W.entities[car])

-- Objets
ok = cb('gs_police:action', 1, 'object', nil, { kind = 'spikes', coords = { x = 201.0, y = -799.0, z = 30.0 } }); step()
check('herse posée + publiée', ok and #GlobalState.gsSpikes == 1)
ok = cb('gs_police:action', 1, 'object', nil, { kind = 'cone', coords = { x = 900.0, y = 0.0, z = 30.0 } }); step()
check('objet loin : refusé', not ok)
ok = cb('gs_police:action', 1, 'object', nil, { kind = 'missile', coords = { x = 201.0, y = -799.0, z = 30.0 } }); step()
check('objet inconnu', not ok)
Config.Objects.max = 1
ok = cb('gs_police:action', 1, 'object', nil, { kind = 'cone', coords = { x = 201.0, y = -799.0, z = 30.0 } }); step()
check('limite d\'objets', not ok)
ok = cb('gs_police:action', 1, 'clearobjects'); step()
check('objets retirés', ok and #GlobalState.gsSpikes == 0 and not Police.objects[1])

-- EMS
ok = cb('gs_police:action', 3, 'revive', 4); step()
check('réanimer : pas à terre', not ok)
W.players[4].downed = true
ok, msg = cb('gs_police:action', 3, 'revive', 4); step()
check('réanimer : trousse requise', not ok and msg:find('trousse'))
W.players[3].items.firstaid = 1
ok = cb('gs_police:action', 3, 'revive', 4); step()
check('réanimé, trousse consommée', ok and not W.players[4].downed and W.players[3].items.firstaid == 0)
ok = cb('gs_police:action', 3, 'cuff', 4); step()
check('EMS ne menotte pas', not ok)
W.players[3].items.bandage = 1
ok = cb('gs_police:action', 3, 'heal', 4); step()
check('soigné au bandage', ok and lastClientEvent('gs_police:client:heal', 4) ~= nil)

-- Contrôles : identité, plaque, alcootest, renforts
W.players[2].licences = { driver = true }
local d
ok, d = cb('gs_police:action', 1, 'identity', 2); step()
check('identité : nom, permis, casier, recherché', ok and d.name == 'Suspect ' and d.driver and not d.weapon and d.records == 2 and d.wanted)
local car2 = CreateVehicleServerSetter(0, 'automobile', 203.0, -800.0, 30.0)
SetVehicleNumberPlateText(car2, 'GS 1234')
W.owners = { ['GS 1234'] = 'Alpha Boss' }
ok, d = cb('gs_police:action', 1, 'plate', nil, { netId = car2 }); step()
check('plaque : propriétaire', ok and d.plate == 'GS 1234' and d.owner == 'Alpha Boss')
Player(2).state:set('gsDrunk', 3)
ok, d = cb('gs_police:action', 1, 'breathalyzer', 2); step()
check('alcootest positif', ok and d == 3)
ok = cb('gs_police:action', 3, 'breathalyzer', 2); step()
check('alcootest réservé à la police', not ok)
ok = cb('gs_police:action', 1, 'backup'); step()
check('renforts envoyés aux policiers', ok and lastClientEvent('gs_police:client:backup', 1) ~= nil)
ok = cb('gs_police:action', 1, 'backup'); step()
check('renforts : pas de spam', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
