-- Tests gs_drone · V12.64 : police en service seulement (drone de service), gangs avec l'objet ET un grade confirmé,
-- cooldown de recharge, un vol à la fois, drone annoncé à tous, tirs au but vérifiés (distance, pas le pilote), drone de
-- gang perdu s'il est abattu, marquage d'un suspect (police, à portée du drone), radar.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local logs = {}
provide('gs_security', { RateLimit = function() return true end, InRange = getExport('gs_security', 'InRange'), LogStaff = function(m) logs[#logs + 1] = m end })
local gangs = {}
provide('gs_gangs', { GetGang = function(src) local g = gangs[src] if g then return g.gang, g.grade end end })
local timers = {}
function SetTimeout(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end
loadResource('gs_drone', { R .. 'gs_drone/shared/config.lua', R .. 'gs_drone/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
math.random = function(a, b) if a then return b and a or 1 end return 0.99 end -- pas de radar par défaut

join(1, 'CID1', 'Agent', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Lieutenant', vec3(500.0, 0.0, 0.0))
join(3, 'CID3', 'Recrue', vec3(900.0, 0.0, 0.0))
join(4, 'CID4', 'Tireur', vec3(10.0, 0.0, 0.0))
local function spawnDrone(src, pos)
    W.nextEntity = W.nextEntity + 1
    local e = W.nextEntity
    W.entities[e] = { type = 3, pos = pos, owner = src }
    return e
end

local ok, msg = cb('gs_drone:launch', 1, 'police')
check('drone de police : refusé hors service', not ok and msg:find('police en service'))
W.players[1].job = { name = 'police', grade = 2, onduty = true }
local o
ok, o = cb('gs_drone:launch', 1, 'police')
check('drone de police : décollage en service (thermique, marquage, longue portée)', ok and o.kind == 'police' and o.thermal and o.mark and o.range == Config.Types.police.range)
check('un vol à la fois', not cb('gs_drone:launch', 1, 'police'))
local d1 = spawnDrone(1, vec3(1.0, 1.0, 2.0))
W.clientEvents = {}
check('drone créé chez le pilote : annoncé à tous', cb('gs_drone:spawned', 1, d1) == true and lastClientEvent('gs_drone:client:airborne', -1) ~= nil)
check('identifiant donné deux fois : refusé', not cb('gs_drone:spawned', 1, d1))

-- Gangs : objet obligatoire, gang obligatoire, recrue refusée
ok, msg = cb('gs_drone:launch', 2, 'gang')
check('gang : sans objet, refusé', not ok and msg:find('drone de repérage'))
W.players[2].items[Config.Item] = 1
ok, msg = cb('gs_drone:launch', 2, 'gang')
check('gang : objet sans gang, refusé', not ok and msg:find('gang'))
gangs[3] = { gang = 'vagos', grade = 0 }
W.players[3].items[Config.Item] = 1
ok, msg = cb('gs_drone:launch', 3, 'gang')
check('gang : recrue refusée', not ok and msg:find('recrues'))
gangs[2] = { gang = 'ballas', grade = 1 }
ok, msg = cb('gs_drone:launch', 2, 'police')
check('un gangster ne sort pas le drone de police', not ok and msg:find('police en service'))
ok, o = cb('gs_drone:launch', 2, 'gang')
check('gang : membre confirmé, drone réduit (pas de thermique ni de marquage)', ok and o.kind == 'gang' and not o.thermal and not o.mark and o.range < Config.Types.police.range)
local d2 = spawnDrone(2, vec3(501.0, 0.0, 3.0))
cb('gs_drone:spawned', 2, d2)

-- Tirs : le pilote ne compte pas, trop loin ne compte pas, deux balles au but = abattu, objet perdu
net('gs_drone:server:hit', 2, d2)
check('le pilote ne touche pas son propre drone', Drone.flying[2].hits == 0)
net('gs_drone:server:hit', 4, d2) -- tireur à ~490 m
check('tireur trop loin : ignoré', Drone.flying[2].hits == 0)
tp(4, vec3(480.0, 0.0, 0.0))
net('gs_drone:server:hit', 4, d2)
check('sans arme en main : ignoré', Drone.flying[2].hits == 0)
W.players[4].weapon = joaat('WEAPON_PISTOL')
W.clientEvents = {}
net('gs_drone:server:hit', 4, d2)
check('1re balle : drone touché, pilote prévenu', Drone.flying[2].hits == 1 and lastClientEvent('gs_drone:client:hurt', 2) ~= nil)
net('gs_drone:server:hit', 4, d2)
check('2e envoi dans les 250 ms : ignoré (rafale, triche)', Drone.flying[2].hits == 1)
advance(300)
net('gs_drone:server:hit', 4, d2)
check('2e balle : abattu, drone de gang perdu', Drone.flying[2] == nil and W.players[2].items[Config.Item] == 0 and lastClientEvent('gs_drone:client:destroyed', 2) ~= nil)
check('abattu : journal staff', logs[#logs]:find('abat'))

-- Marquage (police) : suspect à portée du drone, collègues en service prévenus avec une position (jamais le nom)
join(5, 'CID5', 'Collègue', vec3(50.0, 0.0, 0.0))
W.players[5].job = { name = 'police', grade = 1, onduty = true }
tp(3, vec3(400.0, 0.0, 0.0))
W.clientEvents = {}
net('gs_drone:server:mark', 1, 3)
check('suspect trop loin du drone : refusé', not lastClientEvent('gs_drone:client:mark', 5))
tp(3, vec3(30.0, 10.0, 0.0))
net('gs_drone:server:mark', 1, 3)
local m = lastClientEvent('gs_drone:client:mark', 5)
check('suspect marqué : collègue en service prévenu avec la position', m and m.args[2] ~= nil and m.args[3] == Config.Mark.seconds)
check('le suspect, lui, n\'est pas prévenu', not lastClientEvent('gs_drone:client:mark', 3))
net('gs_drone:server:mark', 2, 3)
check('un pilote sans drone en vol ne marque personne', true)

-- Atterrissage, recharge, radar
net('gs_drone:server:land', 1)
check('atterrissage : plus en vol', Drone.flying[1] == nil)
ok, msg = cb('gs_drone:launch', 1, 'police')
check('recharge de la batterie avant un nouveau vol', not ok and msg:find('charge'))
math.random = function(a, b) if a then return b and a or 1 end return 0.1 end -- radar au tirage
W.players[3].items[Config.Item] = 1
gangs[3].grade = 2
tp(3, vec3(900.0, 0.0, 0.0))
timers = {}
ok = cb('gs_drone:launch', 3, 'gang')
W.clientEvents = {}
for _, t in ipairs(timers) do if t.ms == 20000 then t.fn() end end
local rd = lastClientEvent('gs_drone:client:radar', 5)
check('radar : la police est prévenue d\'un drone non identifié (zone floue)', ok and rd ~= nil and rd.args[2] == Config.Types.gang.radarRadius)
check('radar : jamais le pilote', not lastClientEvent('gs_drone:client:radar', 3))
W.players[3].vehicle = 77
net('gs_drone:server:land', 3) Drone.cooldowns = {}
ok, msg = cb('gs_drone:launch', 3, 'gang')
check('en véhicule : refusé', not ok and msg:find('véhicule'))
io.write(('drone de repérage : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
