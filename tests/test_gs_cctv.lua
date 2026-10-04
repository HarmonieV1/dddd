-- Tests gs_cctv (V10.1) : relevé serveur des véhicules près d'une caméra (plaque, vitesse), pas de doublon immédiat,
-- recherche réservée à la police au commissariat, caméra aveuglée à la bombe (plus de relevés), ménage.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, crimes = {}, {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_wanted', { ColorName = function() return 'bleu' end, VehicleType = function() return 'Voiture' end, ReportCrime = function(_, t) crimes[#crimes + 1] = t return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_cctv', { R .. 'gs_cctv/shared/config.lua', R .. 'gs_cctv/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local cam = Config.Cameras[1].coords
join(1, 'CID1', 'Chauffard', vec3(cam.x + 5.0, cam.y, cam.z))
local veh = CreateVehicleServerSetter(0, 'automobile', cam.x + 5.0, cam.y, cam.z)
SetVehicleNumberPlateText(veh, '4X2KQ81 ')
W.players[1].vehicle = veh
W.entities[veh].driver = 1
function GetEntitySpeed() return 25.0 end
CCTV.sample()
local l = CCTV.log[1]
check('passage relevé (plaque, modèle, couleur)', l and #l == 1 and l[1].plate == '4X2KQ81' and l[1].model == 'Voiture' and l[1].color == 'bleu')
CCTV.sample()
check('pas de doublon immédiat', #CCTV.log[1] == 1)
join(2, 'CID2', 'Agent', vec3(500.0, 500.0, 0.0))
local ok = cb('gs_cctv:search', 2, '4X2')
check('civil : pas d\'accès', not ok)
duty[2] = 'police'
advance(6000)
ok = cb('gs_cctv:search', 2, '4X2')
check('police loin du commissariat : refusé', not ok)
tp(2, Config.Terminals[1]) advance(6000)
local res
ok, res = cb('gs_cctv:search', 2, '4x2')
check('police au commissariat : trouvé par morceau de plaque', ok and #res == 1 and res[1].cam == Config.Cameras[1].label)
advance(6000)
ok, res = cb('gs_cctv:search', 2, 'ZZZ')
check('plaque inconnue : rien', ok and #res == 0)
-- aveugler
join(3, 'CID3', 'Tagueur', cam)
W.players[3].items.spraycan = 1
ok = cb('gs_cctv:blind', 3, 1)
check('caméra aveuglée, bombe consommée, vandalisme signalé', ok and not CCTV.active(1) and (W.players[3].items.spraycan or 0) == 0 and crimes[1])
CCTV.seen = {}
CCTV.log = {}
CCTV.sample()
check('caméra aveugle : plus de relevé', CCTV.log[1] == nil)
advance(6000)
ok = cb('gs_cctv:blind', 3, 1)
check('déjà aveugle', not ok)
CCTV.blind[1] = os.time() - 1
CCTV.sample()
check('réparée avec le temps : relève de nouveau', CCTV.log[1] and #CCTV.log[1] == 1)
CCTV.log[1][1].at = os.time() - Config.MaxAge * 60 - 1
CCTV.clean()
check('ménage des vieux passages', CCTV.log[1] == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
