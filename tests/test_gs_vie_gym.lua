-- Tests gs_vie · V12.64 · Salle de sport : au bon endroit, durée réelle vérifiée, exercices DIFFÉRENTS, séance dans le temps
-- imparti, bonus d'endurance gardé (KVP) et renvoyé à la reconnexion.
dofile('tests/mock.lua')
local t0 = os.time()
os.time = function() return t0 + W.now // 1000 end -- l'horloge des séances suit le temps simulé
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
provide('gs_security', { RateLimit = function() return true end, InRange = getExport('gs_security', 'InRange') })
loadResource('gs_vie', { R .. 'gs_vie/shared/config.lua', R .. 'gs_vie/server/gym.lua' })
local G = Config.Gym

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
local function rep(src, kind)
    local ok, d = cb('gs_vie:gymBegin', src, kind)
    if not ok then return false, d end
    advance(G.duration)
    return cb('gs_vie:gymFinish', src)
end

join(1, 'CID1', 'Sportif', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_vie:gymBegin', 1, 'pushups')
check('hors d\'une salle : refusé', not ok and msg:find('salle'))
tp(1, G.places[1].coords)
check('exercice inconnu : refusé', not cb('gs_vie:gymBegin', 1, 'triche'))
ok = cb('gs_vie:gymBegin', 1, 'pushups')
check('début d\'exercice à la salle', ok)
check('un exercice à la fois', not cb('gs_vie:gymBegin', 1, 'situps'))
ok, msg = cb('gs_vie:gymFinish', 1)
check('fini trop tôt : refusé', not ok and msg:find('interrompu'))
ok, msg = rep(1, 'pushups')
check('1er exercice compté', ok and msg:find('1/' .. G.session))
ok, msg = rep(1, 'pushups')
check('même exercice : pas compté deux fois', ok and msg:find('déjà fait'))
local st = cb('gs_vie:gymStatus', 1)
check('statut : 1 exercice, pas encore de bonus', st.count == 1 and st.bonus == 0 and st.done.pushups)
cb('gs_vie:gymBegin', 1, 'situps')
tp(1, vec3(0.0, 0.0, 0.0))
advance(G.duration)
ok, msg = cb('gs_vie:gymFinish', 1)
check('quitter la salle pendant l\'exercice : rien', not ok and msg:find('quitté'))
tp(1, G.places[1].coords)
-- séance trop lente : elle repart de zéro
advance(G.window * 1000 + 1000)
st = cb('gs_vie:gymStatus', 1)
check('séance trop longue : elle repart de zéro', st.count == 0)
for i = 1, G.session - 1 do rep(1, G.exercises[i].id) end
W.clientEvents = {}
ok, msg = rep(1, G.exercises[G.session].id)
local ev = lastClientEvent('gs_vie:client:gymBonus', 1)
check('séance complète : bonus d\'endurance envoyé', ok and msg:find('Séance terminée') and ev and ev.args[1] == G.hours * 3600)
check('bonus gardé (KVP)', Gym.bonusLeft('CID1') > 0)
W.clientEvents = {}
TriggerEvent('gs_bridge:server:playerLoaded', 1)
check('reconnexion : le bonus revient', lastClientEvent('gs_vie:client:gymBonus', 1) ~= nil)
-- V12.64 · musculation de la prison : chaque série compte pour la séance (tractions comprises), jamais depuis la salle
join(2, 'CID2', 'Détenu', vec3(1700.0, 2541.0, 45.5))
local credit = getExport('gs_vie', 'GymCredit')
check('tractions : pas depuis le menu de la salle', not cb('gs_vie:gymBegin', 2, 'chinups'))
check('prison : série inconnue ignorée', credit(2, 'Ménage') == false)
credit(2, 'Pompes') credit(2, 'Tractions')
W.clientEvents = {}
check('prison : 3e série différente = séance terminée, bonus', credit(2, 'Abdos') == true and lastClientEvent('gs_vie:client:gymBonus', 2) ~= nil)
W.players[1].vehicle = 9
check('en véhicule : refusé', not cb('gs_vie:gymBegin', 1, 'yoga'))
io.write(('salle de sport : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
