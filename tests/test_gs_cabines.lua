-- Tests gs_cabines (V12.60) : appel anonyme à la police (central, zone floue, sans nom), tuyau Weazel (direct ou messagerie),
-- vérifications serveur (à côté de la cabine, à pied, pièce payée, délai, aucun policier = pas facturé).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = { police = {}, weazel = {} }
provide('gs_jobs', { GetOnDutyPlayers = function(job) return duty[job] or {} end })
local booths = {}
provide('gs_phone', { BoothCall = function(src, number) if number ~= '555-0001' then return false, 'Numéro injoignable.' end booths[#booths + 1] = { src, number } return true, 7 end })
local realState = GetResourceState
function GetResourceState(r) if r == 'gs_jobs' or r == 'gs_phone' then return 'started' end return realState and realState(r) or 'missing' end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_cabines', { R .. 'gs_cabines/shared/config.lua', R .. 'gs_cabines/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end

local booth = { x = 200.0, y = -900.0, z = 30.0, street = 'Strawberry Ave' }
join(1, 'CID1', 'Appelant', vec3(201.0, -900.0, 30.0))
join(2, 'COP2', 'Agent', vec3(0.0, 0.0, 0.0))
join(3, 'PRESS3', 'Journaliste', vec3(0.0, 0.0, 0.0))
W.players[1].money.cash = 10
local ok, msg = cb('gs_cabines:call', 1, 'police', 'Une bagarre devant le bar', booth)
check('aucun policier en service : pas de facture', not ok and msg:find('aucun policier') and W.players[1].money.cash == 10)
duty.police = { 2 }
W.clientEvents = {}
ok = cb('gs_cabines:call', 1, 'police', 'Une bagarre devant le bar', booth)
local ev = lastClientEvent('gs_wanted:client:dispatch', 2)
check('appel police : alerte au central, pièce payée', ok and ev ~= nil and W.players[1].money.cash == 10 - Config.Price)
local r = ev and ev.args[1]
check('anonyme : « appel anonyme », message, aucun nom', r and r.witnesses == 0 and r.desc[1]:find('bagarre') and not tostring(r.label):find('Appelant'))
check('zone floue autour de la cabine (jamais au mètre près)', r and r.radius == math.floor(Config.Blur) and #(r.coords - vec3(booth.x, booth.y, booth.z)) <= Config.Blur)
ok, msg = cb('gs_cabines:call', 1, 'police', 'Encore un appel', booth)
check('un appel toutes les 5 min', not ok and msg:find('occupée'))
advance(Config.Cooldown * 1000 + 1000)
tp(1, vec3(260.0, -900.0, 30.0))
ok, msg = cb('gs_cabines:call', 1, 'press', 'Un tuyau sur le maire', booth)
check('loin de la cabine : refusé', not ok and msg:find('Approche'))
tp(1, vec3(201.0, -900.0, 30.0))
ok, msg = cb('gs_cabines:call', 1, 'press', 'Un tuyau sur le maire', booth)
check('Weazel sans journaliste : messagerie', ok and msg:find('Messagerie') and #Cabines.tips == 1)
duty.weazel = { 3 }
local okT, tips = cb('gs_cabines:tips', 3)
check('/tuyaux : le journaliste en service écoute la messagerie (puis vidée)', okT and #tips == 1 and tips[1].text:find('maire') and #Cabines.tips == 0)
check('/tuyaux refusé hors rédaction', not cb('gs_cabines:tips', 1))
advance(Config.Cooldown * 1000 + 1000)
W.clientEvents = {}
ok = cb('gs_cabines:call', 1, 'press', 'Deux voitures volées au port', booth)
check('Weazel avec journaliste : tuyau en direct', ok and lastClientEvent('gs_cabines:client:tip', 3) ~= nil)
advance(Config.Cooldown * 1000 + 1000)
W.players[1].money.cash = 0
ok, msg = cb('gs_cabines:call', 1, 'press', 'Sans pièce dans la poche', booth)
check('sans pièce : refusé', not ok and msg:find('pièces'))
W.players[1].money.cash = 5
ok, msg = cb('gs_cabines:call', 1, 'press', 'abc', booth)
check('message trop court : refusé', not ok)

-- V12.61 · Appel vers un numéro (masqué) et écoute police
W.players[1].money.cash = 10
local okN, err = cb('gs_cabines:number', 1, '555-9999', booth)
check('numéro injoignable : pas facturé', not okN and err:find('injoignable') and W.players[1].money.cash == 10)
okN = cb('gs_cabines:number', 1, '555-0001', booth)
check('appel masqué vers un numéro : passé, 1 $', okN and #booths == 1 and W.players[1].money.cash == 9)
okN, err = cb('gs_cabines:number', 1, '555-0001', booth)
check('rappel immédiat : refusé (délai)', not okN and err:find('Attends'))
W.players[2].job = { name = 'police', grade = 1, onduty = true }
tp(2, vec3(201.0, -900.0, 30.0))
local okT, m = cb('gs_cabines:tap', 2, 'on', booth)
check('écoute : grade insuffisant refusé', not okT and m:find('grade'))
W.players[2].job.grade = 3
okT = cb('gs_cabines:tap', 2, 'on', booth)
check('écoute posée (policier grade 3 en service, à côté)', okT)
advance(Config.NumberCooldown * 1000 + 1000)
W.clientEvents = {}
cb('gs_cabines:number', 1, '555-0001', booth)
local tapEv = lastClientEvent('gs_cabines:client:tapped', 2)
check('cabine sur écoute : le central reçoit l\'appel (destinataire, genre), jamais le nom', tapEv and tapEv.args[1].what:find('555%-0001') and tapEv.args[1].gender and not tostring(tapEv.args[1].what):find('Appelant'))
okT = cb('gs_cabines:tap', 2, 'off', booth)
advance(Config.NumberCooldown * 1000 + 1000)
W.clientEvents = {}
cb('gs_cabines:number', 1, '555-0001', booth)
check('écoute retirée : plus d\'alerte', okT and lastClientEvent('gs_cabines:client:tapped', 2) == nil)

io.write(('cabines : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
