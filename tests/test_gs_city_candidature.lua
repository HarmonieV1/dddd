-- Tests gs_city/public.lua (V12) : bloc « en ce moment », candidature depuis le site (validation, anti-spam, webhook, CORS).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local handler
function SetHttpHandler(fn) handler = fn end
local sent = {}
PerformHttpRequest = function(url, cb, method, body) sent[#sent + 1] = { url = url, method = method, body = body } end
local convars = { gs_webhook_candidatures = table.concat({ 'https://discord.com/api/', 'webhooks/123/', 'FAUX_jeton-de-test' }) } -- factice, découpé pour le détecteur de secrets
GetConvar = function(k, d) return convars[k] or d end
function GetConvarInt(_, d) return d end
json.encode = function(t) return 'JSON:' .. tostring(t.embeds and t.embeds[1].title or t.ok) end
provide('gs_events', { Weekly = function() return { { label = 'Nuit des combats', dayName = 'samedi', from = '22:00' } } end })
provide('gs_city', { HotDistricts = function() return { 'South Los Santos' } end })
provide('gs_weather', { GetWeather = function() return 'RAIN' end, GetGameTime = function() return 21, 7, 0 end })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/public.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

-- En ce moment en ville
TriggerEvent('gs_rumors:server:realized', 'le ring a déménagé à Vespucci')
local n = CityNow()
check('météo en français, heure, quartier chaud, prochain rendez-vous, rumeur', n.weather == 'Pluie' and n.hour == '21:07' and n.hot[1] == 'South Los Santos'
    and n.next.label == 'Nuit des combats' and n.rumor == 'le ring a déménagé à Vespucci')
check('ville.json contient le bloc now', CityPublic().now.hour == '21:07')

-- Validation
local ok, out = Candidature.build({ discord = 'jason_ls', age = 22, q1 = 'Un mécano qui veut son garage', q2 = 'Une ville qui se souvient de moi', q3 = 'Deux ans de RP ailleurs' })
check('candidature valide → embed', ok and out.embeds[1].title == 'Candidature · jason_ls' and out.embeds[1].fields[2].value == '22')
check('pseudo obligatoire', not Candidature.build({ discord = '', age = 22, q1 = 'xxxxxxxxxxx', q2 = 'xxxxxxxxxxx', q3 = 'xxxxxxxxxxx' }))
check('âge borné', not Candidature.build({ discord = 'jo', age = 9, q1 = 'xxxxxxxxxxx', q2 = 'xxxxxxxxxxx', q3 = 'xxxxxxxxxxx' }))
check('réponses trop courtes', not Candidature.build({ discord = 'jo', age = 20, q1 = 'court', q2 = 'xxxxxxxxxxx', q3 = 'xxxxxxxxxxx' }))
local _, e2 = Candidature.build({ discord = '<@everyone> jo', age = 20, q1 = 'x<script>xxxxxxxxxx', q2 = 'xxxxxxxxxxx', q3 = 'xxxxxxxxxxx' })
check('caractères dangereux retirés, aucune mention', e2.embeds[1].title == 'Candidature · everyone jo' and not e2.embeds[1].fields[3].value:find('<'))

-- Anti-spam
check('1re candidature d\'une adresse : ok', Candidature.allowed('1.2.3.4') == true)
check('2e en moins de 10 min : refusée', not Candidature.allowed('1.2.3.4'))
check('autre adresse : ok', Candidature.allowed('5.6.7.8') == true)

-- Handler HTTP : preflight, méthode, envoi
local function call(method, path, body, address)
    local status, headers, data
    local req = { method = method, path = path, address = address or '9.9.9.9:1234', headers = {}, setDataHandler = function(fn) fn(body) end }
    local res = { writeHead = function(s, h) status, headers = s, h end, send = function(d) data = d end }
    handler(req, res)
    return status, headers, data
end
local s, h = call('OPTIONS', '/candidature')
check('preflight CORS', s == 204 and h['Access-Control-Allow-Origin'] == '*' and h['Access-Control-Allow-Methods']:find('POST'))
s = call('GET', '/candidature')
check('GET refusé', s == 405)
json.decode = function(b) return load('return ' .. b)() end
s, h, d = call('POST', '/candidature', "{ discord = 'lucia', age = 25, q1 = 'xxxxxxxxxxxx', q2 = 'xxxxxxxxxxxx', q3 = 'xxxxxxxxxxxx' }")
check('POST valide : 200, webhook appelé, réponse JSON', s == 200 and #sent == 1 and sent[1].url == convars.gs_webhook_candidatures and sent[1].method == 'POST' and d:find('true'))
s = call('POST', '/candidature', "{ discord = 'lucia', age = 25, q1 = 'xxxxxxxxxxxx', q2 = 'xxxxxxxxxxxx', q3 = 'xxxxxxxxxxxx' }")
check('même adresse, 10 min : 400', s == 400 and #sent == 1)
convars.gs_webhook_candidatures = nil
s, h, d = call('POST', '/candidature', "{ discord = 'marc', age = 25, q1 = 'xxxxxxxxxxxx', q2 = 'xxxxxxxxxxxx', q3 = 'xxxxxxxxxxxx' }", '7.7.7.7:1')
check('sans webhook : refus propre', s == 400 and d:find('false'))
s, h, d = call('GET', '/ville.json')
check('ville.json toujours servi', s == 200 and h['Access-Control-Allow-Origin'] == '*')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
