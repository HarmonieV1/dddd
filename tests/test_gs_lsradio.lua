-- Tests gs_lsradio (V10) : vrais événements → interventions, une à la fois (écart minimum), file plafonnée,
-- point de la ville quand rien ne se passe, jamais d'adresse de ring.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
provide('gs_weather', { GetGameTime = function() return 22, 0, 0 end })
loadResource('gs_lsradio', { R .. 'gs_lsradio/shared/config.lua', R .. 'gs_lsradio/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local said = {}
local tce = TriggerClientEvent
TriggerClientEvent = function(n, s, host, text) if n == 'gs_lsradio:client:say' then said[#said + 1] = text end return tce(n, s, host, text) end

TriggerEvent('gs_events:server:remind', 'Vendredi des courses', 'Courses de rue.', 30)
TriggerEvent('gs_wanted:server:fugitive', 'Homme, masqué', 7500)
TriggerEvent('gs_faitsdivers:server:new', 'Cambriolage', 'Davis')
LSRadio.last = 0
check('un rendez-vous annoncé', LSRadio.tick():find('Vendredi des courses dans 30 minutes'))
check('pas deux interventions d\'affilée', LSRadio.tick() == nil)
advance(Config.Gap * 1000)
check('fugitif annoncé avec la prime', LSRadio.tick():find('7500 %$'))
advance(Config.Gap * 1000)
check('fait divers annoncé', said[#said] and LSRadio.tick():find('cambriolage du côté de Davis'))
for i = 1, 10 do LSRadio.say('info ' .. i) end
check('file plafonnée (les plus fraîches)', #LSRadio.queue == 6 and LSRadio.queue[6] == 'info 10')
LSRadio.queue = {}
advance(Config.Gap * 1000)
LSRadio.lastChatter = -100000
local c = LSRadio.tick()
check('rien de neuf : point de la ville (heure, météo, astuce)', c and c:find('22h') and c:find('Que faire'))
check('le ring : jamais d\'adresse', not Config.Lines.ring:find('%%s'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
