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

type = rawtype
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
