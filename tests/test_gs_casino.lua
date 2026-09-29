-- Tests gs_casino : roue 1×/jour (distance, paiement, pas de double tour), tickets (item requis, limite / jour, gains).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_casino', { R .. 'gs_casino/shared/config.lua' })
local db = {}
Store = {
    init = function() end,
    used = function(cid, kind, day) local r = db[cid .. kind] return (r and r.day == day) and r.count or 0 end,
    bump = function(cid, kind, day)
        local r = db[cid .. kind]
        if r and r.day == day then r.count = r.count + 1 else db[cid .. kind] = { day = day, count = 1 } end
    end,
}
local xp = 0
provide('gs_quests', { AddXP = function(_, n) xp = xp + n return 1 end })
loadResource('gs_casino', { R .. 'gs_casino/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

join(1, 'CID1', 'Joueur', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_casino:spin', 1); step()
check('roue : trop loin', not ok)
tp(1, Config.Wheel.stand)
fixRandom(0.0) -- 1re case : 2 500 $
local idx, label
ok, idx, label = cb('gs_casino:spin', 1); step()
check('roue : tourne et paie', ok and idx == 1 and W.players[1].money.bank == 2500)
ok, msg = cb('gs_casino:spin', 1); step()
check('roue : une fois par jour', not ok and msg:find('demain'))
local st = cb('gs_casino:status', 1)
check('statut : roue utilisée', st and st.wheel == false and st.scratchLeft == Config.Scratch.perDay)

-- Lendemain simulé : autre jour → nouveau tour ; case XP
local realToday = Casino.today
Casino.today = function() return '2099-01-01' end
fixRandom(0.15) -- tombe sur la 3e case (500 XP) avec les poids par défaut
ok, idx = cb('gs_casino:spin', 1); step()
check('roue : nouveau jour, XP donnée', ok and Config.Wheel.segments[idx].xp and xp > 0)
Casino.today = realToday

-- Case item avec sac plein → compensation en banque
join(2, 'CID2', 'Plein', Config.Wheel.stand)
W.players[2].full = true
local pick = Casino.pickSegment
Casino.pickSegment = function() return 2 end -- ticket à gratter
ok = cb('gs_casino:spin', 2); step()
check('sac plein : compensation', ok and W.players[2].money.bank == 1000)
Casino.pickSegment = pick

-- Tickets
fixRandom(nil)
ok, msg = cb('gs_casino:scratch', 1); step()
check('ticket : il en faut un', not ok)
W.players[1].items.scratch_ticket = 20
fixRandom(1.0) -- dernier palier : 10 000 $
local cash
ok, cash = cb('gs_casino:scratch', 1); step()
check('ticket : gain payé en liquide', ok and cash == 10000 and W.players[1].money.cash == 10000 and W.players[1].items.scratch_ticket == 19)
fixRandom(0.0)
ok, cash = cb('gs_casino:scratch', 1); step()
check('ticket : perdu', ok and cash == 0)
for _ = 3, Config.Scratch.perDay do cb('gs_casino:scratch', 1); step() end
ok, msg = cb('gs_casino:scratch', 1); step()
check('ticket : limite par jour', not ok and msg:find('Limite') and W.players[1].items.scratch_ticket == 20 - Config.Scratch.perDay)
fixRandom(nil)

-- Rentabilité : gain moyen d'un ticket < prix en supérette (100 $)
local ev = 0
for _, p in ipairs(Config.Scratch.prizes) do ev = ev + p.cash * p.chance / 1000 end
check('ticket : gain moyen < 100 $', ev < 100)
local total = 0
for _, p in ipairs(Config.Scratch.prizes) do total = total + p.chance end
check('ticket : chances = 1000', total == 1000)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
