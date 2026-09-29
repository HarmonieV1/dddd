-- Tests gs_police : service obligatoire, distance, menottes (item), escorte, véhicule, fouille, prison persistante,
-- casier, fourrière, objets de voirie + herse, EMS (réanimer / soigner).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end,
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end })
provide('gs_wanted', { GetHeat = function(s) return s == 2 and 40 or 0 end })
provide('gs_civil', { GetSpouseName = function() return nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_police', { R .. 'gs_police/shared/config.lua' })
local records, jail = {}, {}
local warrants, reports, nextW, nextR = {}, {}, 0, 0
Store = {
    init = function() end,
    addRecord = function(cid, charge, fine, j, officer) records[#records + 1] = { cid = cid, charge = charge, fine = fine, jail = j, officer = officer } end,
    records = function(cid) local l = {} for _, r in ipairs(records) do if r.cid == cid then l[#l + 1] = r end end return l end,
    jailSet = function(cid, u, r) jail[cid] = { until_ts = u, reason = r } end,
    jailGet = function(cid) return jail[cid] end,
    jailClear = function(cid) jail[cid] = nil end,
    searchCitizens = function(term)
        local l = {}
        for cid, n in pairs({ CID2 = 'Suspect', CID4 = 'Civil' }) do if n:lower():find(term:lower(), 1, true) then l[#l + 1] = { citizenid = cid, firstname = n, lastname = 'X', birthdate = '1990-01-01' } end end
        return l
    end,
    addWarrant = function(cid, name, reason, officer, ocid) nextW = nextW + 1 warrants[nextW] = { id = nextW, cid = cid, name = name, reason = reason, officer = officer, ocid = ocid, active = true } return nextW end,
    hasWarrant = function(cid) for _, w in pairs(warrants) do if w.cid == cid and w.active then return true end end return false end,
    warrantsOf = function(cid) local l = {} for _, w in pairs(warrants) do if w.cid == cid and w.active then l[#l + 1] = w end end return l end,
    activeWarrants = function() local l = {} for _, w in pairs(warrants) do if w.active then l[#l + 1] = w end end return l end,
    countOfficerWarrants = function(ocid) local n = 0 for _, w in pairs(warrants) do if w.ocid == ocid and w.active then n = n + 1 end end return n end,
    closeWarrant = function(id) local w = warrants[id] if w and w.active then w.active = false return true end return false end,
    addReport = function(t, b, o, ocid) nextR = nextR + 1 reports[nextR] = { id = nextR, title = t, body = b, officer = o, officer_cid = ocid } return nextR end,
    reports = function() local l = {} for _, r in pairs(reports) do l[#l + 1] = r end return l end,
    report = function(id) local r = reports[id] return r and { id = r.id, title = r.title, body = r.body, officer = r.officer, officer_cid = r.officer_cid } end,
    deleteReport = function(id) if reports[id] then reports[id] = nil return true end return false end,
}
loadResource('gs_police', { R .. 'gs_police/server/main.lua', R .. 'gs_police/server/dossiers.lua' })

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

-- Anti-triche : le suspect se démenotte lui-même → annulé
W.pstate[2].gsCuffed = nil
W.sbh.gsCuffed('player:2', 'gsCuffed', nil)
check('démenottage côté client annulé', st(2).gsCuffed == true)
W.sbh.gsEscortedBy('player:4', 'gsEscortedBy', 1)
check('escorte inventée côté client annulée', st(4).gsEscortedBy == nil)

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

-- Permis : grade minimum, délivrer puis retirer
ok, d = cb('gs_police:action', 1, 'licence', 2, { kind = 'weapon', on = true }); step()
check('permis : grade insuffisant', not ok)
W.players[1].job.grade = Config.Licences.minGrade
ok = cb('gs_police:action', 1, 'licence', 2, { kind = 'nimporte', on = true }); step()
check('permis inconnu', not ok)
ok = cb('gs_police:action', 1, 'licence', 2, { kind = 'hunting', on = true }); step()
check('permis de chasse délivré', ok and W.players[2].licences.hunting == true)
ok = cb('gs_police:action', 1, 'licence', 2, { kind = 'hunting', on = false }); step()
check('permis retiré', ok and W.players[2].licences.hunting == false)

-- Dossiers : recherche par nom, mandats, rapports
W.players[1].job.grade = 1
local ok2, list = cb('gs_police:action', 1, 'dossier_search', nil, { term = 'susp' }); step()
check('recherche par nom', ok2 and #list == 1 and list[1].name:find('Suspect') and list[1].cid == nil)
ok2 = cb('gs_police:action', 1, 'dossier_search', nil, { term = 'a' }); step()
check('recherche : 2 lettres minimum', not ok2)
ok2 = cb('gs_police:action', 4, 'dossier_search', nil, { term = 'susp' }); step()
check('dossiers réservés à la police en service', not ok2)
ok2, d = cb('gs_police:action', 1, 'dossier_open', nil, { index = 9 }); step()
check('dossier : index inconnu', not ok2)
ok2, d = cb('gs_police:action', 1, 'dossier_open', nil, { index = 1 }); step()
check('dossier ouvert : casier + mandats', ok2 and d.name:find('Suspect') and #d.records >= 1 and #d.warrants == 0)
ok2 = cb('gs_police:action', 1, 'warrant_add', nil, { index = 1, reason = '' }); step()
check('mandat : motif obligatoire', not ok2)
W.players[1].job.grade = 0
ok2 = cb('gs_police:action', 1, 'warrant_add', nil, { index = 1, reason = 'Braquage' }); step()
check('mandat : grade insuffisant', not ok2)
W.players[1].job.grade = 1
ok2 = cb('gs_police:action', 1, 'warrant_add', nil, { index = 1, reason = 'Braquage de la banque' }); step()
check('mandat délivré', ok2 and Store.hasWarrant('CID2'))
ok2, d = cb('gs_police:action', 1, 'identity', 2); step()
check('identité : mandat actif signalé', ok2 and d.warrant == true)
ok2 = cb('gs_police:action', 1, 'warrant_close', nil, { id = 1 }); step()
check('clore : grade insuffisant', not ok2 and Store.hasWarrant('CID2'))
W.players[1].job.grade = Config.Dossiers.closeGrade
ok2 = cb('gs_police:action', 1, 'warrant_close', nil, { id = 1 }); step()
check('mandat clos', ok2 and not Store.hasWarrant('CID2'))
ok2 = cb('gs_police:action', 1, 'report_add', nil, { title = 'Course-poursuite', body = 'Deux suspects, une Sultan noire.' }); step()
check('rapport ajouté', ok2 and #Store.reports() == 1)
ok2 = cb('gs_police:action', 1, 'report_add', nil, { title = 'Vide', body = '' }); step()
check('rapport vide refusé', not ok2)
ok2, d = cb('gs_police:action', 1, 'report_read', nil, { id = 1 }); step()
check('rapport lu : auteur sans citizenid', ok2 and d.mine == true and d.officer_cid == nil)
join(5, 'CID5', 'Agent Cinq', here, { name = 'police', grade = 1, onduty = true }); duty[5] = 'police'
ok2 = cb('gs_police:action', 5, 'report_delete', nil, { id = 1 }); step()
check('rapport : un autre agent (grade bas) ne supprime pas', not ok2 and #Store.reports() == 1)
ok2 = cb('gs_police:action', 1, 'report_delete', nil, { id = 1 }); step()
check('rapport : l\'auteur supprime', ok2 and #Store.reports() == 0)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
