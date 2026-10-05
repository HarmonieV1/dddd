-- Tests gs_justice · les jurés de Los Santos (V11.2) : tirage (pas de parties, pas de police / juge / avocat en service),
-- minimum de jurés, votes, décision qui lie le juge, indemnité, mention au verdict, repos des jurés.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, juryEvents = {}, {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end, CreateBill = function() return true end })
provide('gs_police', { Jail = function() return true end, AddRecord = function() return true end, GetRecords = function() return {} end,
    CloseWarrants = function() return 1 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_justice', { R .. 'gs_justice/shared/config.lua' })
local cases, nextId = {}, 0
Store = { init = function() end,
    open = function(cid, name, charge) nextId = nextId + 1 cases[nextId] = { id = nextId, defendant = cid, defendant_name = name, charge = charge, status = 'open' } return nextId end,
    get = function(id) return cases[id] end, close = function(id, st, v) cases[id].status, cases[id].verdict = st, v end, list = function() return {} end }
loadResource('gs_justice', { R .. 'gs_justice/server/main.lua', R .. 'gs_justice/server/jury.lua' })
AddEventHandler('gs_justice:server:jury', function(id, g, t) juryEvents[#juryEvents + 1] = { id, g, t } end)
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local C = Config.Court
join(1, 'JUGE', 'Juge', C); join(2, 'PREV', 'Prévenu', C); duty[1] = 'judge'
local id = Store.open('PREV', 'Prévenu', 'Braquage')
join(3, 'C3', 'Citoyen 3', C); join(4, 'C4', 'Citoyen 4', C)
check('moins de 3 citoyens : pas de jury', not Jury.summon(1, id))
join(5, 'C5', 'Citoyen 5', C); join(6, 'C6', 'Policier', C); duty[6] = 'police'
join(7, 'C7', 'Citoyen 7', C); join(8, 'C8', 'Citoyen 8', C); join(9, 'C9', 'Citoyen 9', C)
check('un non-juge ne convoque pas', not Jury.summon(3, id))
local ok = Jury.summon(1, id)
local s = Jury.sessions[id]
check('jury convoqué (5 citoyens)', ok and s and s.n == 5)
check('ni le prévenu, ni le juge, ni le policier en service', not s.jurors[1] and not s.jurors[2] and not s.jurors[6])
check('pendant la délibération, pas de verdict', not Justice.verdict(1, id, 'acquit'))
local list = {}
for j in pairs(s.jurors) do list[#list + 1] = j end
table.sort(list)
check('un non-juré ne vote pas', not Jury.vote(2, id, true))
Jury.vote(list[1], id, true); Jury.vote(list[2], id, true); Jury.vote(list[3], id, false)
check('pas de double vote', not Jury.vote(list[1], id, false))
local before = W.players[list[1]].money.bank
Jury.vote(list[4], id, true); Jury.vote(list[5], id, false)
check('tous ont voté : délibération close', Jury.sessions[id] == nil and Jury.results[id].guilty == 3 and Jury.results[id].total == 5)
check('indemnité versée', W.players[list[1]].money.bank == before + Config.Jury.fee)
check('événement pour le fil de la ville', juryEvents[1] and juryEvents[1][2] == 3)
check('le jury lie le juge : relaxe refusée', not Justice.verdict(1, id, 'acquit'))
local ok2, text = Justice.verdict(1, id, 'guilty', 500, 0)
check('coupable : le juge fixe la peine, verdict « jury 3-2 »', ok2 and cases[id].verdict:find('jury 3-2', 1, true) ~= nil)
local id2 = Store.open('PREV', 'Prévenu', 'Recel')
local ok3 = Jury.summon(1, id2)
check('les jurés qui ont servi se reposent (2 h) : plus assez de citoyens', not ok3)
advance((Config.Jury.cooldown + 1) * 1000)
check('après le repos, nouveau jury possible', Jury.summon(1, id2))
advance((Config.Jury.seconds + 1) * 1000)
Jury.close(id2) -- ce que fait la boucle de 5 s à l'échéance
check('personne n\'a voté : le juge juge seul', Jury.results[id2] == nil and Justice.verdict(1, id2, 'acquit'))
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
