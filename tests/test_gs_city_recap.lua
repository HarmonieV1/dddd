-- Tests gs_city · « Précédemment à Los Santos » (V11.1) : résumé des 24 h pour l'écran de chargement (handover).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
SetHttpHandler = function() end
GetConvarInt = function(_, d) return d end
local handlers = {}
local realAEH = AddEventHandler
AddEventHandler = function(name, fn) if name == 'playerConnecting' then handlers[#handlers + 1] = fn end return realAEH(name, fn) end
provide('gs_wanted', { Legends = function() return { { name = 'Le Fantôme', date = '05/10/2026' } } end })
provide('gs_events', { Weekly = function() return { { label = 'Vendredi des courses', dayName = 'vendredi', from = '21:00' } } end })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/timelapse.lua',
    R .. 'gs_city/server/public.lua', R .. 'gs_city/server/recap.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local now = os.time()
Timelapse.snaps, Timelapse.events = {}, {}
local calm = CityRecap(now)
check('journée calme : une phrase par défaut', #calm.lines == 1 and calm.lines[1]:find('calme') ~= nil)
local d = Config.Districts[2]
for _ = 1, 3 do Timelapse.record('crime', vec3(d.center.x, d.center.y, 0.0), now - 60) end
Timelapse.record('crime', nil, now - 30 * 3600) -- trop vieux : ignoré
Timelapse.record('verdict', nil, now - 100)
Timelapse.record('legende', nil, now - 100)
local r = CityRecap(now)
check('incidents comptés sur 24 h, quartier le plus touché', r.lines[1] == ('3 incidents signalés à la police, surtout à %s.'):format(d.label))
check('verdict au singulier', r.lines[2] == 'Un verdict est tombé au tribunal.')
check('légende publique citée', r.lines[3] == 'Nouvelle légende : Le Fantôme.')
check('4 lignes maximum', #r.lines <= 4)
check('prochain rendez-vous', r.next and r.next.label == 'Vendredi des courses')
local got
handlers[1]('Joueur', function() end, { handover = function(t) got = t end })
check('envoyé à l\'écran de chargement (handover)', got and got.roadline and got.roadline.lines ~= nil)
handlers[1]('Joueur', function() end, nil) -- pas de deferrals : aucune erreur
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
