-- Tests gs_discord · fil de la ville (V10.2) : compteurs de la journée, 6 lignes max, rien à dire = rien posté,
-- remise à zéro après l'envoi, rumeurs des joueurs (attente staff, validation, une par personne).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local posted = {}
local jstore = {}
json.encode = function(t) jstore[#jstore + 1] = t return 'J' .. #jstore end
json.decode = function(s) if s == '{}' then return {} end return jstore[tonumber(s:sub(2))] end
provide('gs_city', { HotDistricts = function() return { 'South Los Santos' } end })
loadResource('gs_discord', { R .. 'gs_discord/shared/config.lua' })
Discord = { announce = function(title, text) posted[#posted + 1] = { title = title, text = text } return true end }
loadResource('gs_discord', { R .. 'gs_discord/server/digest.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
Digest.day = os.date('%Y-%m-%d')
check('journée calme : rien à poster', Digest.text() == nil)
TriggerEvent('gs_wanted:server:reported', 1) TriggerEvent('gs_wanted:server:reported', 2)
TriggerEvent('gs_police:server:jailed', 1) TriggerEvent('gs_justice:server:verdict', 'guilty')
TriggerEvent('gs_faitsdivers:server:new', 'Cambriolage', 'Davis')
TriggerEvent('gs_rumors:server:realized', 'Un convoi passera par Paleto')
TriggerEvent('gs_wanted:server:legend', 3, 'Tony Vercetti')
local t = Digest.text()
local lines = select(2, t:gsub('\n', '\n')) + 1
check('résumé : crimes, arrestations, rumeur, légende', t:find('2 crime', 1, true) and t:find('1 arrestation', 1, true) and t:find('convoi', 1, true) and t:find('Vercetti', 1, true))
check('6 lignes max', lines <= 6)
Digest.post()
check('posté une fois, compteurs remis à zéro', #posted == 1 and Digest.text() == nil)

-- Rumeurs écrites par les joueurs
local staffMsg = {}
provide('gs_admin', { NotifyStaff = function(m) staffMsg[#staffMsg + 1] = m return true end, GetStaffLevel = function(src) return src == 9 and 3 or 0 end })
provide('gs_social', { Newsroom = function() return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_rumors', { R .. 'gs_rumors/shared/config.lua', R .. 'gs_rumors/server/main.lua', R .. 'gs_rumors/server/seeds.lua' })
local bar = Config.Tellers[1].coords
join(1, 'CID1', 'Conteur', vec3(bar.x, bar.y, bar.z)) W.players[1].money.cash = 500
join(9, 'CID9', 'Staff', vec3(0.0, 0.0, 0.0))
local ok = cb('gs_rumors:propose', 1, 'court', 1) advance(11000)
check('rumeur trop courte : refusée', not ok)
ok = cb('gs_rumors:propose', 1, 'Un camion de cigarettes aurait disparu près du port', 1) advance(11000)
check('rumeur proposée : payée, staff prévenu, pas encore publique', ok and W.players[1].money.cash == 500 - Config.Custom.price and #staffMsg == 1 and #Rumors.list == 0)
ok = cb('gs_rumors:propose', 1, 'Encore une autre histoire assez longue pour passer', 1) advance(11000)
check('une par personne (délai)', not ok)
check('un joueur ne voit pas la liste', cb('gs_rumors:pending', 1) == nil)
local list = cb('gs_rumors:pending', 9) advance(11000)
check('le staff voit la liste', #list == 1)
ok = cb('gs_rumors:decide', 1, list[1].id, true) advance(11000)
check('un joueur ne valide pas', not ok)
ok = cb('gs_rumors:decide', 9, list[1].id, true, false) advance(11000)
check('validée : les barmans la racontent', ok and #Rumors.list == 1 and #cb('gs_rumors:pending', 9) == 0)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
