-- Tests loto hebdomadaire : échéance, achat (caisse, limite, paiement), tirage (report, 3 gagnants distincts, barème),
-- gains hors ligne versés à la connexion, cagnotte reportée.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/gs_casino/'
local kept
json = { encode = function(t) kept = t return 'R' end, decode = function() return kept end }
loadResource('gs_security', { 'server/resources/[gtasoon]/gs_security/server/main.lua' })
loadResource('gs_casino', { R .. 'shared/config.lua' })
local tickets, draws, carry, pending, nextT = {}, {}, 0, {}, 0
Store = {
    init = function() end, initLotto = function() end,
    lottoBuy = function(week, cid, name, n) for _ = 1, n do nextT = nextT + 1 tickets[#tickets + 1] = { id = nextT, week = week, citizenid = cid, name = name } end end,
    lottoMine = function(week, cid) local n = 0 for _, t in ipairs(tickets) do if t.week == week and t.citizenid == cid then n = n + 1 end end return n end,
    lottoTickets = function(week) local l = {} for _, t in ipairs(tickets) do if t.week == week then l[#l + 1] = t end end return l end,
    lottoOpenWeeks = function() local seen, l = {}, {} for _, t in ipairs(tickets) do if not seen[t.week] and not draws[t.week] then seen[t.week] = true l[#l + 1] = t.week end end table.sort(l) return l end,
    lottoDone = function(week, r) draws[week] = r end, lottoLast = function() return next(draws) and 'R' or nil end,
    lottoCarry = function() return carry end, lottoSetCarry = function(n) carry = n end,
    pendingAdd = function(cid, n) pending[cid] = (pending[cid] or 0) + n end,
    pendingTake = function(cid) local n = pending[cid] or 0 pending[cid] = nil return n end,
}
loadResource('gs_casino', { R .. 'server/lotto.lua' })
local L = Config.Lotto

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

-- Échéance
local mon, sun19, sun21 = { week = '2026-41', wday = 1, hour = 12 }, { week = '2026-41', wday = 0, hour = 19 }, { week = '2026-41', wday = 0, hour = 21 }
check('semaine courante avant dimanche 20 h : pas tirable', not Lotto.due('2026-41', mon) and not Lotto.due('2026-41', sun19))
check('dimanche 20 h passé : tirable', Lotto.due('2026-41', sun21))
check('semaine passée : toujours tirable (tirage manqué)', Lotto.due('2026-40', mon))
check('semaine à venir : jamais', not Lotto.due('2026-42', sun21))

-- Achat
Lotto.clock = function() return { week = '2026-41', wday = 3, hour = 12 } end
join(1, 'CID1', 'Alice Martin', vec3(0.0, 0.0, 0.0)) W.players[1].money.cash = 2000
local ok = cb('gs_casino:lottoBuy', 1, 2); step()
check('loin de la caisse : refusé', not ok)
tp(1, L.cashier)
ok = cb('gs_casino:lottoBuy', 1, 0); step()
check('quantité invalide', not ok)
ok = cb('gs_casino:lottoBuy', 1, L.maxPerWeek + 1); step()
check('plus que la limite : refusé', not ok)
ok = cb('gs_casino:lottoBuy', 1, 4); step()
check('achat en liquide', ok and W.players[1].money.cash == 2000 - 4 * L.price and Store.lottoMine('2026-41', 'CID1') == 4)
check('nom affiché abrégé', tickets[1].name == 'Alice M.')
ok = cb('gs_casino:lottoBuy', 1, 7); step()
check('limite par semaine cumulée', not ok)
W.players[1].money.cash, W.players[1].money.bank = 0, 100
ok = cb('gs_casino:lottoBuy', 1, 1); step()
check('payé par la banque à défaut', ok and W.players[1].money.bank == 0)
W.players[1].money.cash, W.players[1].money.bank = 0, 10
ok = cb('gs_casino:lottoBuy', 1, 1); step()
check('pas assez d\'argent', not ok)
local info = cb('gs_casino:lottoInfo', 1); step()
check('info : cagnotte = 80 % des ventes', info and info.sold == 5 and info.pot == math.floor(5 * L.price * L.potShare) and info.mine == 5)

-- Sous le minimum : report
tickets = {} nextT = 0
Store.lottoBuy('2026-40', 'CID1', 'Alice M.', 2)
Lotto.clock = function() return { week = '2026-41', wday = 1, hour = 9 } end
Lotto.tick()
check('moins de 3 tickets : report de la cagnotte', draws['2026-40'] and carry == math.floor(2 * L.price * L.potShare))
local carried = carry

-- Tirage complet : 1 joueur en ligne avec 6 tickets, 2 autres, 1 hors ligne
tickets = {} nextT = 0
join(2, 'CID2', 'Bob Durand', vec3(0.0, 0.0, 0.0))
Store.lottoBuy('2026-39', 'CID1', 'Alice M.', 6)
Store.lottoBuy('2026-39', 'CID2', 'Bob D.', 2)
Store.lottoBuy('2026-39', 'CID9', 'Hors L.', 2)
local pot = carried + math.floor(10 * L.price * L.potShare)
W.players[1].money.bank, W.players[2].money.bank = 0, 0
draws = {}
Lotto.tick()
local res = kept
check('3 gagnants distincts malgré 6 tickets pour un seul joueur', #res.winners == 3 and res.winners[1].cid ~= res.winners[2].cid and res.winners[2].cid ~= res.winners[3].cid and res.winners[1].cid ~= res.winners[3].cid)
check('barème 60 / 25 / 15', res.winners[1].amount == math.floor(pot * 0.6) and res.winners[2].amount == math.floor(pot * 0.25) and res.winners[3].amount == math.floor(pot * 0.15))
local paidOnline = W.players[1].money.bank + W.players[2].money.bank
check('gains en ligne versés en banque, hors ligne mis de côté', paidOnline > 0 and (pending.CID9 or 0) > 0 and paidOnline + pending.CID9 == res.winners[1].amount + res.winners[2].amount + res.winners[3].amount)
check('reste de la cagnotte reporté (arrondis)', carry == pot - (res.winners[1].amount + res.winners[2].amount + res.winners[3].amount))
draws['2026-39'] = draws['2026-39'] -- semaine tirée
local before = kept
Lotto.tick()
check('une semaine n\'est tirée qu\'une fois', kept == before)

-- Connexion du gagnant hors ligne
join(9, 'CID9', 'Hors Ligne', vec3(0.0, 0.0, 0.0))
check('gains hors ligne versés à la connexion', (pending.CID9 or 0) == 0 and W.players[9].money.bank > 0)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
