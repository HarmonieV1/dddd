-- Tests des points déplaçables (gs_bridge/shared/points.lua + server/points.lua) : positions de Config remplacées par
-- celles du staff, clés stables, tailles ignorées, sauvegarde KVP, relance de la bonne ressource, clés refusées.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'

-- En jeu, type(vec3) vaut « vector3 » : on reproduit ça pour les vecteurs du simulateur
local rawtype = type
type = function(v)
    if rawtype(v) == 'table' and getmetatable(v) and rawtype(v.x) == 'number' and rawtype(v.y) == 'number' then
        return v.w and 'vector4' or 'vector3'
    end
    return rawtype(v)
end
vector3, vector4 = vec3, vec4
local kvp = {}
function GetResourceKvpString(k) return kvp[k] end
function SetResourceKvp(k, v) kvp[k] = v end
local restarted = {}
function StopResource(r) restarted[#restarted + 1] = 'stop:' .. r end
function StartResource(r) restarted[#restarted + 1] = 'start:' .. r end
function GetNumResources() return 0 end
function IsDuplicityVersion() return true end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

local function loadConfig(res, overrides)
    GlobalState.gsPoints = overrides
    GetCurrentResourceName = function() return res end
    Config = {
        Activities = { fishing = { label = 'Pêche', spots = { vec3(-1850.3, -1250.2, 8.6), vec3(1299.4, 4217.9, 33.9) } } },
        Buyers = { { label = 'Poissonnerie', coords = vec3(-1846.3, -1195.4, 14.3) } },
        Zone = { center = vec4(100.0, 200.0, 30.0, 90.0), size = vec3(4.0, 4.0, 4.0) },
    }
    dofile(R .. 'gs_bridge/shared/points.lua')
    return Config
end

local c = loadConfig('gs_harvest', {})
check('sans déplacement : config intacte', c.Activities.fishing.spots[2].x == 1299.4 and c.Buyers[1].coords.y == -1195.4)

c = loadConfig('gs_harvest', {
    ['gs_harvest:Config.Activities.fishing.spots.2'] = { x = 1.0e3, y = 2.0e3, z = 30.0 },
    ['gs_harvest:Config.Zone.center'] = { x = 500.0, y = 600.0, z = 31.0, w = 180.0 },
    ['gs_harvest:Config.Zone.size'] = { x = 999.0, y = 999.0, z = 999.0 },
    ['gs_economy:Config.Buyers.1.coords'] = { x = 0.0, y = 0.0, z = 0.0 },
})
check('point déplacé appliqué', c.Activities.fishing.spots[2].x == 1000.0 and c.Activities.fishing.spots[2].y == 2000.0)
check('autre point inchangé', c.Activities.fishing.spots[1].x == -1850.3)
check('vec4 : cap gardé du staff', c.Zone.center.x == 500.0 and c.Zone.center.w == 180.0)
check('taille jamais traitée comme une position', c.Zone.size.x == 4.0)
check('clé d\'une autre ressource ignorée', c.Buyers[1].coords.x == -1846.3)

-- Serveur : sauvegarde et relance
loadResource('gs_bridge', { R .. 'gs_bridge/server/points.lua' })
local set, reset = getExport('gs_bridge', 'SetPoint'), getExport('gs_bridge', 'ResetPoint')
local ok, res = set('gs_harvest:Config.Buyers.1.coords', vec4(10.0, 20.0, 30.0, 45.0))
check('déplacement accepté', ok and res == 'gs_harvest')
check('ressource relancée', restarted[1] == 'stop:gs_harvest' and restarted[2] == 'start:gs_harvest')
check('sauvegardé (KVP) et publié', kvp.gs_points ~= nil and GlobalState.gsPoints['gs_harvest:Config.Buyers.1.coords'].w == 45.0)
check('gs_bridge lui-même refusé', not set('gs_bridge:Config.X', vec3(1.0, 2.0, 3.0)))
check('clé hors gs_ refusée', not set('qbx_core:Config.X', vec3(1.0, 2.0, 3.0)))
check('chemin invalide refusé', not set('gs_harvest:os.exit()', vec3(1.0, 2.0, 3.0)))
check('remise à l\'origine', reset('gs_harvest:Config.Buyers.1.coords') and GlobalState.gsPoints['gs_harvest:Config.Buyers.1.coords'] == nil)
check('remise d\'un point jamais déplacé refusée', not reset('gs_harvest:Config.Buyers.1.coords'))

-- V11.6 · Retirer un point du jeu (réversible)
local disable, enable = getExport('gs_bridge', 'DisablePoint'), getExport('gs_bridge', 'EnablePoint')
restarted = {}
ok, res = disable('gs_harvest:Config.Activities.fishing.spots.1')
check('retrait accepté, ressource relancée, sauvegardé', ok and res == 'gs_harvest' and restarted[1] == 'stop:gs_harvest' and kvp.gs_points_off ~= nil
    and GlobalState.gsPointsOff['gs_harvest:Config.Activities.fishing.spots.1'] == true)
check('retrait en double refusé', not disable('gs_harvest:Config.Activities.fishing.spots.1'))
check('réactivation d\'un point non retiré refusée', not enable('gs_harvest:Config.Buyers.1.coords'))
c = loadConfig('gs_harvest', {})
check('point retiré : hors carte dans la config, position réelle gardée pour le menu', c.Activities.fishing.spots[1].x == -9000.0 and c.Activities.fishing.spots[2].x == 1299.4)
check('réactivation', enable('gs_harvest:Config.Activities.fishing.spots.1') and GlobalState.gsPointsOff['gs_harvest:Config.Activities.fishing.spots.1'] == nil)
c = loadConfig('gs_harvest', {})
check('point réactivé : position d\'origine', c.Activities.fishing.spots[1].x == -1850.3)

-- V12.5 · Scénario signalé en jeu : « je déplace la cabine (ou Max), rien ne bouge » -------------------------------
-- 1. Les personnages de quête sont recensés (quests.lua est maintenant chargé AVANT points.lua)
local loadedEvents = {}
AddEventHandler('gs_bridge:server:pointsLoaded', function(res, applied) loadedEvents[#loadedEvents + 1] = { res = res, applied = applied } end)
local function loadQuests(overrides)
    GlobalState.gsPoints = overrides
    GetCurrentResourceName = function() return 'gs_quests' end
    Config = {}
    dofile(R .. 'gs_quests/shared/config.lua')
    dofile(R .. 'gs_quests/shared/quests.lua')
    dofile(R .. 'gs_bridge/shared/points.lua')
end
local manifest = io.open(R .. 'gs_quests/fxmanifest.lua'):read('a')
check('gs_quests : quests.lua chargé avant points.lua', manifest:find("'shared/quests.lua', '@gs_bridge/shared/points.lua'", 1, true) ~= nil)
loadQuests({})
check('personnages exposés dans Config (déplaçables au F11)', Config.Characters == Characters and Characters.voice and Characters.guide)
local VOICE = 'gs_quests:Config.Characters.voice.coords'
loadQuests({ [VOICE] = { x = 250.5, y = -880.25, z = 30.5, w = 90.0 } })
check('cabine de la Voix déplacée par le staff : appliquée', Characters.voice.coords.x == 250.5 and Characters.voice.coords.w == 90.0)
check('les autres personnages ne bougent pas', Characters.guide.coords.x == -536.9)
check('calage court quand le staff a placé la cabine (son choix respecté)', Config.PhoneSnapNear and Config.PhoneSnapNear <= 10.0)
-- 2. La ressource annonce ce qu'elle a vraiment appliqué, gs_bridge confirme au staff
local last = loadedEvents[#loadedEvents]
check('chargement annoncé avec la position appliquée', last and last.res == 'gs_quests' and last.applied[VOICE] and last.applied[VOICE].x == 250.5)
local checkPoint = getExport('gs_bridge', 'CheckPoint')
W.now = W.now + 10000
local since = GetGameTimer() - 1
check('pas encore redémarrée : signalé', checkPoint(VOICE, vec3(250.5, -880.25, 30.5), since + 5) == 'pas_relance')
TriggerEvent('gs_bridge:server:pointsLoaded', 'gs_quests', { [VOICE] = { x = 250.5, y = -880.25, z = 30.5 } })
-- parseKey exige la ressource démarrée
GetResourceState = function() return 'started' end
check('redémarrée avec la nouvelle position : confirmé', checkPoint(VOICE, vec3(250.5, -880.25, 30.5), since) == 'ok')
TriggerEvent('gs_bridge:server:pointsLoaded', 'gs_quests', {})
check('redémarrée SANS la position : signalé', checkPoint(VOICE, vec3(250.5, -880.25, 30.5), since) == 'ancienne_position')
-- 3. L'arrivée en bus ne déclare plus Max une seconde fois (doublon au F11)
GetCurrentResourceName = function() return 'gs_onboarding' end
Config = {}
dofile(R .. 'gs_onboarding/shared/config.lua')
check('arrivée : plus de doublon de Max dans Config', Config.Arrival and Config.Arrival.guide == nil)

-- V12.37 · Placement libre et PNJ / objets posés par le staff ----------------------------------------------------------
-- 1. Pose vérifiée par le serveur (nombres, distance, cap normalisé)
local cleanPose = getExport('gs_bridge', 'CleanPose')
local me = vec3(100.0, 200.0, 30.0)
local pose, perr = cleanPose({ x = 103, y = 204, z = 30.5, heading = 400 }, me, 60.0)
check('pose propre : flottants, cap ramené dans [0, 360[', pose and pose.x == 103.0 and pose.z == 30.5 and pose.w == 40.0 and math.type(pose.x) == 'float')
check('pose : `w` accepté à la place de `heading`, cap négatif normalisé', cleanPose({ x = 1, y = 2, z = 3, w = -90 }, nil).w == 270.0)
pose, perr = cleanPose({ x = 100.0 + 61.0, y = 200.0, z = 30.0, heading = 0 }, me, 60.0)
check('pose trop loin du staff refusée (message)', pose == nil and perr:find('Trop loin', 1, true))
check('pose : sans `from`, pas de contrôle de distance', cleanPose({ x = 9000, y = 9000, z = 0, heading = 0 }, nil) ~= nil)
check('pose : NaN refusé', cleanPose({ x = 0 / 0, y = 0, z = 0, heading = 0 }, nil) == nil)
check('pose : valeur hors carte refusée', cleanPose({ x = 1e6, y = 0, z = 0, heading = 0 }, nil) == nil)
check('pose : chaîne injectée refusée', cleanPose({ x = 'abc', y = 0, z = 0, heading = 0 }, nil) == nil)
check('pose : pas une table refusée', cleanPose('x', nil) == nil)

-- 2. Fonctions pures partagées (gs_bridge/shared/points.lua) : liaison d'un PNJ staff à un point de métier / gang
check('cible d\'un point de métier : premier point sans index, les suivants numérotés',
    GsPoints.pedTarget('police', 'duty', 1) == 'job:police:duty' and GsPoints.pedTarget('police', 'garage', 2) == 'job:police:garage2')
local staffList = {
    { id = 7, kind = 'ped', target = 'job:police:duty', model = 's_f_y_cop_01', scenario = 'WORLD_HUMAN_CLIPBOARD', x = 441.5, y = -982.0, z = 29.7, heading = 180.0 },
    { id = 8, kind = 'prop', target = 'job:police:boss', model = 'prop_bench_01a', x = 1.0, y = 2.0, z = 3.0, heading = 0.0 },
    { id = 9, kind = 'ped', target = 'gang:ballas', model = 'g_m_y_ballasout_01', x = 10.0, y = 20.0, z = 30.0, heading = 90.0 },
}
local cfgPed = { model = 's_m_y_cop_01', heading = 90.0, scenario = 'WORLD_HUMAN_STAND_MOBILE' }
local resolved = GsPoints.pointPed(cfgPed, 'job:police:duty', staffList)
check('PNJ staff relié à job:police:duty : remplace celui de la config (modèle, scénario, position absolue, id repris)',
    resolved.model == 's_f_y_cop_01' and resolved.scenario == 'WORLD_HUMAN_CLIPBOARD' and resolved.staffId == 7
    and resolved.at and resolved.at.x == 441.5 and resolved.at.heading == 180.0)
check('PNJ staff : pas de PNJ dans la config → il s\'ajoute quand même', GsPoints.pointPed(nil, 'gang:ballas', staffList).staffId == 9)
check('aucun PNJ staff pour ce point : PNJ de la config gardé', GsPoints.pointPed(cfgPed, 'job:police:garage', staffList) == cfgPed)
check('un OBJET relié à un point ne remplace pas son PNJ', GsPoints.pointPed(cfgPed, 'job:police:boss', staffList) == cfgPed)
check('liste absente (GlobalState vide) : config gardée', GsPoints.pointPed(cfgPed, 'job:police:duty', nil) == cfgPed and GsPoints.staffPed('x', nil) == nil)

-- 3. Table SQL simulée (gs_staff_peds) : chargement, ajout, retrait, limite, publication GlobalState
local rows, nextId, deleted = {}, 1, {}
MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then local l = {} for _, r in ipairs(rows) do l[#l + 1] = r end return l end return nil end },
    insert = { await = function(_, p)
        local r = { id = nextId, kind = p[1], target = p[2], model = p[3], scenario = p[4], x = p[5], y = p[6], z = p[7], heading = p[8], by = p[9], at = p[10] }
        rows[#rows + 1] = r
        nextId = nextId + 1
        return r.id
    end },
    update = function(_, p) deleted[#deleted + 1] = p[1] for i = #rows, 1, -1 do if rows[i].id == p[1] then table.remove(rows, i) end end end,
}
rows[1] = { id = 1, kind = 'ped', target = 'libre', model = 'a_m_y_hipster_01', scenario = nil, x = 5, y = 6, z = 7, heading = 45, by = 'Alpha', at = 1 }
nextId = 2
StaffPeds.load()
check('chargement au démarrage : ligne SQL publiée dans GlobalState.gsStaffPeds (flottants)', #GlobalState.gsStaffPeds == 1
    and GlobalState.gsStaffPeds[1].model == 'a_m_y_hipster_01' and math.type(GlobalState.gsStaffPeds[1].x) == 'float')
local addStaff, removeStaff, listStaff = getExport('gs_bridge', 'AddStaffPed'), getExport('gs_bridge', 'RemoveStaffPed'), getExport('gs_bridge', 'ListStaffPeds')
local okA, idA = addStaff({ kind = 'ped', target = 'job:police:duty', model = 's_f_y_cop_01', scenario = 'WORLD_HUMAN_CLIPBOARD', x = 441.5, y = -982.0, z = 29.7, heading = 180, by = 'Alpha Boss [1]' })
check('ajout d\'un PNJ : inséré en BDD, id rendu, publié', okA and idA == 2 and #rows == 2 and #GlobalState.gsStaffPeds == 2 and GlobalState.gsStaffPeds[2].id == 2)
check('ajout : `at` horodaté, `by` gardé', GlobalState.gsStaffPeds[2].at == os.time() and GlobalState.gsStaffPeds[2].by == 'Alpha Boss [1]')
local okB, msgB = addStaff({ kind = 'ped', target = 'job:police:duty', model = 's_m_y_cop_01', x = 441.5, y = -982.0, z = 29.7, heading = 0 })
check('un seul PNJ staff par point de métier', not okB and msgB:find('déjà un PNJ', 1, true))
check('un objet sur la même cible reste possible', addStaff({ kind = 'prop', target = 'job:police:duty', model = 'prop_bench_01a', x = 1, y = 2, z = 3, heading = 0 }))
check('deux PNJ « libre » possibles', addStaff({ kind = 'ped', model = 'a_m_y_beach_01', x = 1, y = 2, z = 3, heading = 0 }) and GlobalState.gsStaffPeds[4].target == 'libre')
check('type inconnu refusé', not addStaff({ kind = 'vehicle', model = 'sultan', x = 1, y = 2, z = 3, heading = 0 }))
check('modèle injecté refusé', not addStaff({ kind = 'ped', model = "a'; DROP TABLE", x = 1, y = 2, z = 3, heading = 0 }))
check('cible mal formée refusée', not addStaff({ kind = 'ped', target = 'job:police:duty; --', model = 'a_m_y_beach_01', x = 1, y = 2, z = 3, heading = 0 }))
check('scénario mal formé refusé', not addStaff({ kind = 'ped', model = 'a_m_y_beach_01', scenario = 'walk()', x = 1, y = 2, z = 3, heading = 0 }))
check('position invalide refusée', not addStaff({ kind = 'ped', model = 'a_m_y_beach_01', x = 'x', y = 2, z = 3, heading = 0 }))
check('liste : copie triée par id', #listStaff() == 4 and listStaff()[1].id == 1)
local okR, entry = removeStaff(2)
check('retrait : ligne supprimée en BDD, entrée rendue, publication à jour', okR and entry.model == 's_f_y_cop_01' and deleted[1] == 2 and #rows == 3 and #GlobalState.gsStaffPeds == 3)
check('retrait d\'une entrée inconnue refusé', not removeStaff(2) and not removeStaff('abc'))
check('après retrait : le point de métier retrouve son PNJ de config', GsPoints.pointPed(cfgPed, 'job:police:duty', GlobalState.gsStaffPeds) == cfgPed)
local n = 0
while #GlobalState.gsStaffPeds < StaffPeds.max do
    if not addStaff({ kind = 'prop', model = 'prop_cone', x = n, y = 0, z = 0, heading = 0 }) then break end
    n = n + 1
end
local okL, msgL = addStaff({ kind = 'prop', model = 'prop_cone', x = 0, y = 0, z = 0, heading = 0 })
check('limite de 200 entrées', StaffPeds.max == 200 and #GlobalState.gsStaffPeds == 200 and not okL and msgL:find('Limite', 1, true))

type = rawtype
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
