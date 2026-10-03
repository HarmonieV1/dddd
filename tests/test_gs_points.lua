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

type = rawtype
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
