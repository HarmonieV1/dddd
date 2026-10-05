-- Tests gs_city · carte vivante (V10.2) : quartiers (tension + standing), rendez-vous, légendes (5 max), aucune position.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
SetHttpHandler = function() end
GetConvarInt = function(_, d) return d end
provide('gs_events', { Weekly = function() return { { dayName = 'vendredi', from = '21:00', label = 'Vendredi des courses' } } end })
provide('gs_wanted', { Legends = function() local l = {} for i = 1, 8 do l[i] = { name = 'Légende ' .. i, date = '01/10/2026', hours = 2 } end return l end })
provide('gs_weather', { GetWeather = function() return 'CLEAR' end })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/public.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
GlobalState.gsCity = { south = 3 }
GlobalState.gsStanding = { south = 1 }
local d = CityPublic()
local south
for _, x in ipairs(d.districts) do if x.id == 'south' then south = x end end
check('tous les quartiers', #d.districts == #Config.Districts)
check('tension et standing du quartier', south.tensionLabel == 'chaud' and south.standingLabel == 'à l\'abandon')
check('rendez-vous', d.weekly[1].label == 'Vendredi des courses')
check('légendes : 5 max, sans les heures', #d.legends == 5 and d.legends[1].hours == nil)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
