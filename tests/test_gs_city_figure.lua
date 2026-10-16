-- Tests V12.63 · « Le quartier adopte quelqu'un » (n° 148) : points d'activité légale par quartier, titre au-delà du seuil,
-- remise dans les commerces du quartier seulement, salut au retour, baisse des points sans activité.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
SetResourceKvpInt = SetResourceKvpInt or function() end
GetResourceKvpInt = GetResourceKvpInt or function() return 0 end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/figure.lua' })
local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
local FG = Config.Figure
local south, vesp = Config.Districts[2], Config.Districts[4]
join(1, 'CID1', 'Habitué', vec3(south.center.x, south.center.y, 30.0))
TriggerEvent('gs_quests:server:activity', 1, 'drug_sale')
check('activité illégale : aucun point', next(Figure.get('CID1').pts) == nil)
TriggerEvent('gs_quests:server:activity', 1, 'job_mission')
check('mission de métier : points dans le quartier où elle a lieu', Figure.get('CID1').pts[south.id] == FG.points.job_mission)
check('pas encore figure du coin : pas de remise', Figure.discount(1) == 0)
W.notes = {}
for _ = 1, math.ceil(FG.threshold / FG.points.job_mission) do TriggerEvent('gs_quests:server:activity', 1, 'job_mission') end
check('au-delà du seuil : figure du coin', Figure.districtOf('CID1') == south.id)
check('remise dans son quartier', Figure.discount(1) == FG.discount)
tp(1, vec3(vesp.center.x, vesp.center.y, 10.0))
check('pas de remise ailleurs', Figure.discount(1) == 0)
Figure.tick()
advance((FG.greetMinutes + 1) * 60000)
Figure.greeted[1] = os.time() - (FG.greetMinutes + 1) * 60
W.clientEvents = {}
tp(1, vec3(south.center.x, south.center.y, 30.0))
Figure.tick()
local ev = lastClientEvent('ox_lib:notify', 1)
check('salué en revenant dans son quartier', ev and ev.args[1].description:find('figure du coin'))
W.clientEvents = {}
tp(1, vec3(vesp.center.x, vesp.center.y, 10.0)) Figure.tick() tp(1, vec3(south.center.x, south.center.y, 30.0)) Figure.tick()
check('pas salué deux fois dans l\'heure', not lastClientEvent('ox_lib:notify', 1))
local f = Figure.get('CID1')
f.at = f.at - 4 -- 4 semaines sans activité
check('sans activité, les points baissent : plus figure du coin', Figure.districtOf('CID1') == nil)
io.write(('figure du coin : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
