-- Tests gs_bank · V12.64 · Piratage de distributeur : boîtier obligatoire, distance, policier refusé, durées réelles
-- vérifiées, mini-jeu raté = alarme, réussi = argent sale, cooldowns (distributeur, joueur), usure du boîtier, caméra.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local reports, logs = {}, {}
local sec = { RateLimit = function() return true end, InRange = getExport('gs_security', 'InRange'),
    Sanitize = getExport('gs_security', 'Sanitize'), LogStaff = function(m) logs[#logs + 1] = m end }
provide('gs_security', sec)
provide('gs_wanted', { ReportCrime = function(src, crime, coords, opts) reports[#reports + 1] = { src = src, crime = crime, opts = opts or {} } return true end })
local hour = 12
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end, GetWeather = function() return 'CLEAR' end, GetEvent = function() return nil end })
loadResource('gs_bank', { R .. 'gs_bank/shared/config.lua', R .. 'gs_bank/server/hack.lua' })
local H = Config.Hack

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
local rnd = 0.99 -- tirages : 0,99 = rien de spécial (pas d'alarme, pas de caméra, boîtier intact)
math.random = function(a, b) if a then return b and a or 1 end return rnd end

local atm = { x = 100.0, y = 100.0, z = 30.0 }
join(1, 'CID1', 'Pirate', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_bank:hackBegin', 1, atm)
check('trop loin du distributeur : refusé', not ok and msg:find('loin'))
tp(1, vec3(101.0, 100.0, 30.0))
ok, msg = cb('gs_bank:hackBegin', 1, atm)
check('sans boîtier : refusé (marché noir)', not ok and msg:find('boîtier'))
W.players[1].items[H.item] = 2
check('coords invalides : refusé', not cb('gs_bank:hackBegin', 1, 'x'))
W.players[1].job = { name = 'police', grade = 1, onduty = true }
ok, msg = cb('gs_bank:hackBegin', 1, atm)
check('policier en service : refusé', not ok and msg:find('police'))
W.players[1].job = { name = 'unemployed', grade = 0, onduty = false }
local data
ok, data = cb('gs_bank:hackBegin', 1, atm)
check('début : durée d\'installation et mini-jeu envoyés', ok and data.install == H.install and #data.skill == #H.skill)
check('un seul piratage à la fois', not cb('gs_bank:hackBegin', 1, atm))
ok = cb('gs_bank:hackResult', 1, true)
check('mini-jeu annoncé avant la fin de l\'installation : refusé', not ok and Hack.pending[1] == nil)

-- Raté : alarme certaine, boîtier usé selon le tirage, distributeur verrouillé un moment, joueur en cooldown
advance(60000)
cb('gs_bank:hackBegin', 1, atm)
advance(H.install)
rnd = 0.1
local okR, msgR, alarm = cb('gs_bank:hackResult', 1, false)
check('raté : alarme signalée à la police (crime piratage)', not okR and alarm == true and reports[#reports].crime == H.crime and reports[#reports].opts.alarm == true)
check('raté : la caméra du distributeur filme', reports[#reports].opts.camera == H.cameraLabel)
check('raté : le boîtier peut griller', W.players[1].items[H.item] == 1 and msgR:find('grillé'))
ok, msg = cb('gs_bank:hackBegin', 1, atm)
check('raté : joueur en cooldown', not ok and msg:find('oublier'))

-- Réussi : second joueur, la nuit (meilleur butin), argent sale
rnd = 0.99
hour = 23
join(2, 'CID2', 'Pirate Deux', vec3(100.0, 101.0, 30.0))
W.players[2].items[H.item] = 1
ok, msg = cb('gs_bank:hackBegin', 2, atm)
check('distributeur verrouillé après une alarme', not ok and msg:find('vidé'))
ok, msg = cb('gs_bank:hackBegin', 2, { x = 101.0, y = 100.0, z = 30.0 })
check('même distributeur décalé d\'un mètre : toujours verrouillé', not ok and msg:find('vidé'))
local atm2 = { x = 300.0, y = 300.0, z = 30.0 }
tp(2, vec3(300.5, 300.0, 30.0))
ok = cb('gs_bank:hackBegin', 2, atm2)
advance(H.install)
local good, drain = cb('gs_bank:hackResult', 2, true)
check('réussi : retrait lancé', good and drain == H.drain and Hack.pending[2].stage == 'drain')
check('réussi la nuit : pas d\'alarme au tirage', reports[#reports].src == 2 and reports[#reports].opts.alarm == false)
ok = cb('gs_bank:hackFinish', 2)
check('retrait annoncé trop tôt : refusé', not ok)
net('gs_bank:server:hackCancel', 2) -- interrompu pendant le retrait
check('annulation : plus de piratage en cours', Hack.pending[2] == nil)
ok, msg = cb('gs_bank:hackBegin', 2, atm2)
check('distributeur déjà vidé (même s\'il a été interrompu)', not ok and msg:find('vidé'))
-- nouveau distributeur, cette fois jusqu'au bout
Hack.atms, Hack.pending = {}, {}
cb('gs_bank:hackBegin', 2, atm2)
advance(H.install) cb('gs_bank:hackResult', 2, true)
tp(2, vec3(320.0, 300.0, 30.0))
advance(H.drain)
ok, msg = cb('gs_bank:hackFinish', 2)
check('parti pendant le retrait : rien', not ok and msg:find('éloigné'))
tp(2, vec3(300.5, 300.0, 30.0))
Hack.atms, Hack.pending, Hack.players = {}, {}, {}
cb('gs_bank:hackBegin', 2, atm2)
advance(H.install) cb('gs_bank:hackResult', 2, true)
advance(H.drain)
ok, msg = cb('gs_bank:hackFinish', 2)
local expected = math.floor(H.reward[1] * H.nightBonus) -- math.random(a, b) simulé = a
check('butin en argent sale, bonus de nuit', ok and W.players[2].items[H.dirtyItem] == expected and msg:find('argent sale'))
check('boîtier intact au tirage', W.players[2].items[H.item] == 1)
check('journal staff', logs[#logs]:find('pirate un distributeur'))
ok, msg = cb('gs_bank:hackBegin', 2, { x = 500.0, y = 500.0, z = 30.0 })
check('après un piratage : cooldown du joueur', not ok)
-- en véhicule : refusé
Hack.players = {}
W.players[2].vehicle = 55
tp(2, vec3(500.0, 500.0, 30.0))
ok, msg = cb('gs_bank:hackBegin', 2, { x = 500.0, y = 500.0, z = 30.0 })
check('en véhicule : refusé', not ok and msg:find('véhicule'))
io.write(('piratage distributeur : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
