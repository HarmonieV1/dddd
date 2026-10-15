-- Tests gs_lives (V12.60) : staff en mode staff seulement, message clair sans screenshot-basic, une capture à la fois par
-- fenêtre, image renvoyée au seul membre du staff qui regarde, visionnage journalisé une fois.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local levels, duty, shots, states, logs = { [1] = 2 }, { [1] = true }, {}, { gs_admin = 'started', ['screenshot-basic'] = 'missing' }, {}
provide('gs_admin', { GetStaffLevel = function(s) return levels[s] or 0 end, IsOnDuty = function(s) return duty[s] == true end })
function GetResourceState(r) return states[r] or 'started' end
function TriggerLatentClientEvent(name, target, _, ...) TriggerClientEvent(name, target, ...) end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local sec = { RateLimit = getExport('gs_security', 'RateLimit'), Sanitize = getExport('gs_security', 'Sanitize'), InRange = getExport('gs_security', 'InRange') }
sec.LogStaff = function(msg) logs[#logs + 1] = msg end
provide('gs_security', sec)
function SetTimeout() end -- le filet de 10 s (joueur muet) ne se déclenche pas pendant le test
loadResource('gs_lives', { R .. 'gs_lives/shared/config.lua', R .. 'gs_lives/server/main.lua' })
provide('screenshot-basic', { requestClientScreenshot = function(target, opts, fn) shots[#shots + 1] = { target = target, fn = fn, opts = opts } end })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end

join(1, 'STAFF', 'Modo', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Joueur Deux', vec3(5.0, 0.0, 0.0))
join(3, 'CID3', 'Curieux', vec3(9.0, 0.0, 0.0))
local ok, msg = cb('gs_lives:players', 1)
check('sans screenshot-basic : message clair', not ok and msg:find('screenshot%-basic'))
states['screenshot-basic'] = 'started'
ok, msg = cb('gs_lives:players', 3)
check('joueur sans rang : refusé', not ok and msg:find('Réservé'))
duty[1] = false
ok, msg = cb('gs_lives:players', 1)
check('staff hors mode staff : refusé', not ok and msg:find('mode staff'))
duty[1] = true
local list
ok, list = cb('gs_lives:players', 1)
check('liste des joueurs (sans soi-même), nom de personnage', ok and #list == 2 and list[1].id == 2 and list[1].name == 'Joueur Deux')
net('gs_lives:server:frame', 3, 2)
check('capture demandée par un non-staff : ignorée', #shots == 0)
net('gs_lives:server:frame', 1, 2)
net('gs_lives:server:frame', 1, 2)
check('une seule capture à la fois par fenêtre', #shots == 1 and shots[1].target == 2 and shots[1].opts.encoding == 'jpg')
check('visionnage journalisé', #logs == 1 and logs[1]:find('regarde'))
W.clientEvents = {}
shots[1].fn(nil, 'data:image/jpeg;base64,AAAA')
local ev = lastClientEvent('gs_lives:client:frame')
check('image renvoyée au seul staff qui regarde', ev and ev.target == 1 and ev.args[1] == 2 and ev.args[2]:find('^data:image'))
net('gs_lives:server:frame', 1, 2)
check('fenêtre suivante : nouvelle capture, pas de 2e ligne de journal', #shots == 2 and #logs == 1)
net('gs_lives:server:frame', 1, 1)
check('se regarder soi-même : ignoré', #shots == 2)

io.write(('lives staff : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
