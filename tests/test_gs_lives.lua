-- Tests gs_lives (V12.60) : staff en mode staff seulement, message clair sans screenshot-basic, une capture à la fois par
-- fenêtre, image renvoyée au seul membre du staff qui regarde, visionnage journalisé une fois.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local levels, duty, shots, states, logs = { [1] = 2 }, { [1] = true }, {}, { gs_admin = 'started', ['screenshot-basic'] = 'missing' }, {}
local reported = {}
provide('gs_admin', { GetStaffLevel = function(s) return levels[s] or 0 end, IsOnDuty = function(s) return duty[s] == true end,
    ReportedPlayers = function() return reported end })
function GetResourceState(r) return states[r] or 'started' end
function TriggerLatentClientEvent(name, target, _, ...) TriggerClientEvent(name, target, ...) end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local sec = { RateLimit = getExport('gs_security', 'RateLimit'), Sanitize = getExport('gs_security', 'Sanitize'), InRange = getExport('gs_security', 'InRange') }
sec.LogStaff = function(msg) logs[#logs + 1] = msg end
provide('gs_security', sec)
function SetTimeout() end -- le filet de 10 s (joueur muet) ne se déclenche pas pendant le test
loadResource('gs_lives', { R .. 'gs_lives/shared/config.lua', R .. 'gs_lives/server/main.lua' })
-- V12.63 : la capture est demandée AU JOUEUR (événement gs_lives:client:capture) qui la renvoie par gs_lives:server:shot
local realTCE = TriggerClientEvent
function TriggerClientEvent(name, target, ...)
    if name == 'gs_lives:client:capture' then
        local id, q = ...
        shots[#shots + 1] = { target = target, id = id, opts = { encoding = 'jpg', quality = q }, fn = function(_, data) net('gs_lives:server:shot', target, id, data) end }
        return
    end
    return realTCE(name, target, ...)
end

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
check('liste des joueurs (soi-même compris, pour tester), nom de personnage', ok and #list == 3 and list[2].id == 2 and list[2].name == 'Joueur Deux' and list[1].name:find('toi : test', 1, true))
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
advance(1100) -- l'image d'il y a moins d'1 s est partagée, pas recapturée
net('gs_lives:server:frame', 1, 2)
check('fenêtre suivante : nouvelle capture, pas de 2e ligne de journal', #shots == 2 and #logs == 1)
net('gs_lives:server:frame', 1, 1)
check('se regarder soi-même : autorisé (test sans second joueur)', #shots == 3 and shots[3].target == 1)
-- V12.62 · deux membres du staff regardent le même joueur : une seule capture, l'image part aux deux
join(4, 'STAFF4', 'Modo Deux', vec3(1.0, 0.0, 0.0)) levels[4], duty[4] = 2, true
net('gs_lives:server:frame', 4, 2)
check('2e staff sur le même joueur : pas de 2e capture en cours', #shots == 3)
W.clientEvents = {}
shots[2].fn(nil, 'data:image/jpeg;base64,BBBB')
local to1, to4 = false, false
for _, e in ipairs(W.clientEvents) do if e.name == 'gs_lives:client:frame' then if e.target == 1 then to1 = true elseif e.target == 4 then to4 = true end end end
check('image envoyée aux deux membres du staff', to1 and to4)

-- V12.62 · Replay 30 s : seulement pour les joueurs liés à un ticket ouvert, effacé à la fermeture
shots = {}
advance(Config.Replay.every + 1) -- pas de fenêtre Lives sur ce joueur à l'instant
Lives.replayTick()
check('replay : aucun ticket, aucune capture', #shots == 0)
reported = { [2] = 7 }
Lives.replayTick()
check('replay : capture du joueur du ticket', #shots == 1 and shots[1].target == 2 and shots[1].opts.quality == Config.Replay.quality)
Lives.replayTick()
check('replay : une capture à la fois', #shots == 1)
for i = 1, Config.Replay.frames + 3 do
    shots[#shots].fn(nil, 'data:image/jpeg;base64,F' .. i)
    advance(Config.Replay.every + 1)
    Lives.replayTick()
end
check('replay : mémoire bornée', #Lives.replay[2].frames == Config.Replay.frames and Lives.replay[2].frames[Config.Replay.frames]:find('F' .. (Config.Replay.frames + 3)))
local _, l2 = cb('gs_lives:players', 1)
check('liste : ticket et bouton replay', l2[2].ticket == 7 and l2[2].replay == true)
W.clientEvents = {}
net('gs_lives:server:replay', 3, 2)
check('replay demandé par un non-staff : ignoré', not lastClientEvent('gs_lives:client:replay'))
net('gs_lives:server:replay', 1, 2)
local rv = lastClientEvent('gs_lives:client:replay')
check('replay envoyé au staff et journalisé', rv and rv.target == 1 and #rv.args[2] == Config.Replay.frames and logs[#logs]:find('revoit'))
reported = {}
Lives.replayTick()
check('ticket fermé : images effacées', Lives.replay[2] == nil)
for i = 1, 600 do Lives.views[#Lives.views + 1] = i end
Lives.watching[1] = nil
net('gs_lives:server:frame', 1, 3)
check('journal des visionnages borné', #Lives.views <= 500)

-- V12.63 · sécurité de la réponse : seulement le joueur visé, une vraie image, une demande en cours ; message si personne ne répond
advance(5000)
shots = {}
Lives.pending, Lives.busy = {}, {} -- le délai de 8 s (SetTimeout) ne tourne pas en test : on repart de zéro
net('gs_lives:server:frame', 1, 3)
local sid = shots[1] and shots[1].id
W.clientEvents = {}
net('gs_lives:server:shot', 2, sid, 'data:image/jpeg;base64,FAUX')
check('réponse d\'un autre joueur que la cible : ignorée', not lastClientEvent('gs_lives:client:frame'))
net('gs_lives:server:shot', 3, sid, 'https://exemple.invalid/x.png')
check('réponse qui n\'est pas une image JPEG : refusée', not lastClientEvent('gs_lives:client:frame') and lastClientEvent('gs_lives:client:frameError'))
local got
Lives.capture(3, 0.4, function(ok, data) got = { ok, data } end)
net('gs_lives:server:shot', 3, shots[#shots].id, 'data:image/jpeg;base64,OK')
check('export Capture (appli staff) : image reçue', got and got[1] == true and got[2]:find('OK'))

-- V12.63 · capture impossible chez le joueur : la raison arrive au staff (et seulement depuis le joueur visé)
local failed2
advance(1100) -- au-delà de l'image partagée (< 1 s)
Lives.capture(3, 0.4, function(ok, data) failed2 = { ok, data } end)
local fid = shots[#shots].id
net('gs_lives:server:shotFail', 2, fid, 'pirate')
check('échec signalé par un autre joueur : ignoré', failed2 == nil)
net('gs_lives:server:shotFail', 3, fid, 'screenshot-basic n\'a pas répondu')
check('échec chez le joueur : raison transmise', failed2 and failed2[1] == false and failed2[2]:find('pas répondu', 1, true))
io.write(('lives staff : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
