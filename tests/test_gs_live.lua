-- Tests gs_social · Direct Weazel (V10.1) : déclenché par une grosse poursuite seulement, un direct à la fois + délai,
-- hélicoptère envoyé aux joueurs proches, journalistes sur place payés (plafond), fins : semé, interpellé, disparu.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local heat, duty, radio = {}, {}, {}
provide('gs_wanted', { GetHeat = function(src) return heat[src] or 0 end })
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_rumors', { Zone = function() return 'Vinewood' end })
provide('gs_lsradio', { Say = function(t) radio[#radio + 1] = t end })
loadResource('gs_social', { R .. 'gs_social/shared/config.lua', R .. 'gs_social/server/live.lua' })
local L = Config.Live
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

join(1, 'CID1', 'Suspect', vec3(0.0, 0.0, 30.0))
join(2, 'CID2', 'Journaliste', vec3(50.0, 0.0, 30.0)) duty[2] = 'weazel'
join(3, 'CID3', 'Loin', vec3(3000.0, 0.0, 30.0))
join(4, 'CID4', 'Témoin', vec3(100.0, 0.0, 30.0))

TriggerEvent('gs_wanted:server:reported', 1, 'speeding', 10, vec3(0.0, 0.0, 30.0))
check('petit délit : pas de direct', Live.current == nil)
heat[1] = 60
TriggerEvent('gs_wanted:server:reported', 1, 'shooting', 60, vec3(0.0, 0.0, 30.0))
check('grosse poursuite : direct', Live.current and Live.current.src == 1)
check('bandeau pour toute la ville, radio', lastClientEvent('gs_social:client:weazel', -1) ~= nil and #radio == 1)
check('hélicoptère : joueurs proches seulement', Live.current.seen[2] and Live.current.seen[4] and not Live.current.seen[3])
TriggerEvent('gs_wanted:server:reported', 4, 'shooting', 90, vec3(0.0, 0.0, 30.0))
check('un seul direct à la fois', Live.current.src == 1)

local cash, cash4 = W.players[2].money.cash, W.players[4].money.cash
for _ = 1, 30 do Live.tick() end
check('journaliste sur place : payé, plafonné', W.players[2].money.cash - cash == L.pressMax)
check('témoin non journaliste : rien', W.players[4].money.cash == cash4)
heat[1] = 0
Live.tick()
check('suspect a semé la police : fin du direct', Live.current == nil and #radio == 2 and radio[2]:find('semé', 1, true))

heat[4] = 90
TriggerEvent('gs_wanted:server:reported', 4, 'shooting', 90, vec3(0.0, 0.0, 30.0))
check('délai entre deux directs', Live.current == nil)
Live.last = os.time() - L.cooldown - 1
TriggerEvent('gs_wanted:server:reported', 4, 'shooting', 90, vec3(0.0, 0.0, 30.0))
TriggerEvent('gs_police:server:jailed', 4, 10, 2)
check('interpellé : fin « interpellé »', Live.current == nil and radio[#radio]:find('interpellé', 1, true))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
