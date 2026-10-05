-- Tests gs_city · ville en timelapse (V11) : faits marquants par quartier, photos de tension, 24 h gardées, rien de privé.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
SetHttpHandler = function() end
GetConvarInt = function(_, d) return d end
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/timelapse.lua', R .. 'gs_city/server/public.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
Timelapse.snaps, Timelapse.events = {}, {}
local d1 = Config.Districts[1]
local now = 1000000
check('crime rangé dans son quartier', Timelapse.record('crime', vec3(d1.center.x, d1.center.y, 30.0), now) and Timelapse.events[1].d == d1.id)
check('aucune coordonnée gardée', Timelapse.events[1].x == nil and Timelapse.events[1].coords == nil)
check('fait sans lieu accepté', Timelapse.record('verdict', nil, now) and Timelapse.events[2].d == nil)
check('type inconnu refusé', not Timelapse.record('position_joueur', nil, now))
City.heat[d1.id] = 9999
Timelapse.snapshot(now)
check('photo : quartier tendu noté', (Timelapse.snaps[1].lv[d1.id] or 1) > 1)
Timelapse.record('rumeur', nil, now + 25 * 3600)
check('plus de 24 h : oublié', #Timelapse.events == 1 and Timelapse.events[1].k == 'rumeur' and #Timelapse.snaps == 0)
for i = 1, 700 do Timelapse.record('crime', nil, now + 25 * 3600 + i) end
check('600 faits maximum', #Timelapse.events == 600)
local pub = CityPublic()
check('exposé dans ville.json avec les libellés', pub.timelapse and pub.timelapse.kinds.crime ~= nil and pub.ids[d1.id] ~= nil)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
