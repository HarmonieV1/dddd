-- Tests gs_services : secours IA seulement sans EMS, joueur à terre, durée vérifiée, paiement banque → liquide → gratuit.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local ems = {}
provide('gs_jobs', { GetOnDutyPlayers = function() return ems end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_services', { R .. 'gs_services/shared/config.lua', R .. 'gs_services/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end
local fee = Config.Medic.fee

join(1, 'CID1', 'Blessé', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_services:callMedic', 1); step()
check('debout : pas de secours', not ok)
W.players[1].downed = true
ems = { 7 }
check('EMS en service : secours IA indisponible', cb('gs_services:medicStatus', 1).available == false)
ok = cb('gs_services:callMedic', 1); step()
check('EMS en service : appel refusé', not ok)
ems = {}
check('sans EMS : disponible', cb('gs_services:medicStatus', 1).available == true)
W.players[1].money.bank = 1000
ok, msg = cb('gs_services:callMedic', 1)
check('appel accepté', ok and msg == Config.Medic.seconds)
ok = cb('gs_services:medicDone', 1); step()
check('trop tôt : refusé', not ok and W.players[1].downed)
advance(Config.Medic.seconds * 1000)
ok = cb('gs_services:medicDone', 1); step()
check('réanimé + payé en banque', ok and not W.players[1].downed and W.players[1].money.bank == 1000 - fee)
ok = cb('gs_services:medicDone', 1); step()
check('pas deux fois', not ok)

W.players[1].downed = true
ok, msg = cb('gs_services:callMedic', 1); step()
check('délai entre deux appels', not ok and msg:find('peu'))
advance(Config.Medic.cooldown * 1000)
W.players[1].money.bank, W.players[1].money.cash = 10, fee
ok = cb('gs_services:callMedic', 1)
advance(Config.Medic.seconds * 1000)
ok, msg = cb('gs_services:medicDone', 1); step()
check('banque vide : payé en liquide', ok and W.players[1].money.cash == 0 and W.players[1].money.bank == 10)

W.players[1].downed = true
advance(Config.Medic.cooldown * 1000)
cb('gs_services:callMedic', 1)
advance(Config.Medic.seconds * 1000)
ok, msg = cb('gs_services:medicDone', 1); step()
check('sans argent : soigné gratuitement, pas de dette', ok and msg:find('gratuitement') and W.players[1].money.bank == 10)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
