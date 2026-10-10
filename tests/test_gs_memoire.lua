-- Tests gs_memoire (V12) : lieux par case, seuil de publication, genre dominant, plaque au 10e événement, radio,
-- événements sources (crime, arrestation, mariage, course, braquage), rechargement depuis la base.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local rawtype = type
type = function(v)
    if rawtype(v) == 'table' and getmetatable(v) and rawtype(v.x) == 'number' and rawtype(v.y) == 'number' then return v.w and 'vector4' or 'vector3' end
    return rawtype(v)
end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local plaques, radio = {}, {}
provide('gs_scars', { Plaque = function(c, text, by) plaques[#plaques + 1] = { c = c, text = text, by = by } return 1 end })
provide('gs_lsradio', { Say = function(t) radio[#radio + 1] = t return true end })
provide('gs_wanted', { CrimeLabel = function(t) return ({ bank = 'Braquage de banque', robbery = 'Vol à main armée' })[t] end })
function GetStreetNameAtCoord() return 1 end
function GetStreetNameFromHashKey() return 'Carson Avenue' end
local saved = {}
Store = { init = function() end, add = function(e) saved[#saved + 1] = e end, recent = function() return saved end }
loadResource('gs_memoire', { R .. 'gs_memoire/shared/config.lua', R .. 'gs_memoire/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
join(1, 'CID1', 'Passant', vec3(100.0, -1500.0, 30.0))

local here = vec3(105.0, -1505.0, 30.0)
check('coordonnées nulles ignorées', Memoire.record('crime', vec3(0.0, 0.0, 0.0)) == nil)
local cell = Memoire.record('crime', here, 'Une fusillade.')
check('événement rangé dans une case', cell ~= nil and Memoire.places[cell].n == 1 and Memoire.places[cell].kinds.crime == 1)
check('centre de la case, pas la position exacte', Memoire.places[cell].x ~= here.x and math.abs(Memoire.places[cell].x - here.x) < Config.Cell)
check('pas encore publié (seuil 3)', #(GlobalState.gsMemoire or {}) == 0)
Memoire.record('crime', vec3(110.0, -1510.0, 30.0))
Memoire.record('wedding', vec3(101.0, -1501.0, 30.0), 'Le mariage de A et B.')
check('publié au 3e événement, genre dominant crime', #GlobalState.gsMemoire == 1 and GlobalState.gsMemoire[1].kind == 'crime' and GlobalState.gsMemoire[1].n == 3)
check('dernière phrase gardée', GlobalState.gsMemoire[1].text == 'Le mariage de A et B.')
check('persisté', #saved == 3 and saved[1].kind == 'crime')
check('genre inconnu → générique', Memoire.record('bizarre', vec3(2000.0, 2000.0, 10.0)) ~= nil and Memoire.places['50:50'].kinds.generic == 1)

-- Sources
TriggerEvent('gs_wanted:server:reported', 1, 'bank', 50, vec3(115.0, -1490.0, 30.0)) -- même case (x 80-120, y -1520 à -1480)
check('braquage de banque signalé → genre heist', Memoire.places[cell].kinds.heist == 1)
TriggerEvent('gs_police:server:jailed', 1, 10, 2)
check('arrestation à la position du joueur', Memoire.places[cell].kinds.arrest == 1)
TriggerEvent('gs_civil:server:married', vec3(102.0, -1502.0, 30.0), 'C et D')
TriggerEvent('gs_races:server:won', 'Pilote', 'Boucle de Vespucci', vec3(103.0, -1503.0, 30.0))
TriggerEvent('gs_heists:server:done', 'Supérette', vec3(104.0, -1504.0, 30.0))
check('mariage, course, braquage comptés', Memoire.places[cell].kinds.wedding == 2 and Memoire.places[cell].kinds.race == 1 and Memoire.places[cell].kinds.heist == 2)
check('8 événements : pas encore de plaque', #plaques == 0 and Memoire.places[cell].n == 8)
Memoire.record('crime', here) Memoire.record('crime', here)
check('10e événement : plaque automatique (une seule)', #plaques == 1 and plaques[1].by == 'memoire' and Memoire.places[cell].plaque)
Memoire.record('crime', here)
check('11e : pas de 2e plaque', #plaques == 1)
check('radio : rappel d\'un lieu chargé', Memoire.radio() == true and radio[1]:find('Carson Avenue', 1, true))

-- Rechargement : les événements persistés reconstruisent les lieux sans reposer de plaque
Memoire.places = {}
for _, e in ipairs(saved) do Memoire.record(e.kind, vec3(e.x, e.y, e.z), e.text, false) end
check('rechargement : même nombre, rien de re-sauvegardé', Memoire.places[cell].n == 11 and #saved == 12) -- 12 = 11 ici + 1 ailleurs

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
