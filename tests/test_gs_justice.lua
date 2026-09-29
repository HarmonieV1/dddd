-- Tests gs_justice : ouverture (juge en service, présences, avocat), verdicts (relaxe, amende, prison, bornes, présence),
-- casier, mandats clos, accès avocat avec consentement.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, bills, jailed, records, closed = {}, {}, {}, {}, {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end,
    CreateBill = function(cid, job, amount, reason) bills[#bills + 1] = { cid = cid, job = job, amount = amount } return true end })
provide('gs_police', { Jail = function(src, m) jailed[src] = m return true end,
    AddRecord = function(cid, charge, fine, jail) records[#records + 1] = { cid = cid, charge = charge, fine = fine, jail = jail } return true end,
    GetRecords = function(cid) local l = {} for _, r in ipairs(records) do if r.cid == cid then l[#l + 1] = r end end return l end,
    CloseWarrants = function(cid) closed[cid] = true return 1 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_justice', { R .. 'gs_justice/shared/config.lua' })
local cases, nextId = {}, 0
Store = { init = function() end,
    open = function(cid, name, charge, judge, lawyer) nextId = nextId + 1 cases[nextId] = { id = nextId, defendant = cid, defendant_name = name, charge = charge, judge = judge, lawyer = lawyer, status = 'open' } return nextId end,
    get = function(id) return cases[id] end, close = function(id, st, v) cases[id].status, cases[id].verdict = st, v end,
    list = function() local l = {} for _, c in pairs(cases) do l[#l + 1] = c end return l end }
loadResource('gs_justice', { R .. 'gs_justice/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local C = Config.Court
local far = vec3(3000.0, 3000.0, 0.0)

join(1, 'JUGE', 'Juge Dredd', C) join(2, 'PREV', 'Prévenu', C) join(3, 'AVO', 'Maître Avocat', C) join(4, 'CIV', 'Civil', C)
local ok, res = cb('gs_justice:open', 1, 2, 'Vol', nil); step()
check('juge hors service : refusé', not ok)
duty[1] = 'judge'
ok = cb('gs_justice:open', 1, 2, '', nil); step()
check('accusation obligatoire', not ok)
tp(2, far)
ok = cb('gs_justice:open', 1, 2, 'Vol', nil); step()
check('prévenu absent : refusé', not ok)
tp(2, C)
ok = cb('gs_justice:open', 1, 2, 'Vol', 3); step()
check('avocat hors service : refusé', not ok)
duty[3] = 'lawyer'
ok, res = cb('gs_justice:open', 1, 2, 'Vol de véhicule', 3); step()
check('affaire ouverte avec avocat', ok and cases[res].lawyer == 'Maître Avocat' and cases[res].defendant == 'PREV')
local id = res

ok = cb('gs_justice:verdict', 4, id, 'guilty', 100, 0); step()
check('verdict réservé au juge', not ok)
ok = cb('gs_justice:verdict', 1, id, 'guilty', 0, 0); step()
check('coupable sans peine : refusé', not ok)
ok = cb('gs_justice:verdict', 1, id, 'guilty', Config.MaxFine + 1, 0); step()
check('amende au-delà du maximum', not ok)
tp(2, far)
ok = cb('gs_justice:verdict', 1, id, 'guilty', 500, 10); step()
check('prison : condamné absent, refusé', not ok and cases[id].status == 'open')
tp(2, C)
ok, res = cb('gs_justice:verdict', 1, id, 'guilty', 500, 10); step()
check('verdict : amende facturée, prison, casier, mandats clos', ok and bills[1].amount == 500 and bills[1].cid == 'PREV' and jailed[2] == 10
    and records[1].jail == 10 and closed.PREV and cases[id].status == 'guilty')
ok = cb('gs_justice:verdict', 1, id, 'acquit'); step()
check('affaire déjà jugée', not ok)

_, id = cb('gs_justice:open', 1, 4, 'Tapage', nil); step()
ok = cb('gs_justice:verdict', 1, id, 'acquit'); step()
check('relaxe', ok and cases[id].status == 'acquitted' and closed.CIV)

-- Casier avec accord
ok = cb('gs_justice:requestRecords', 4, 2); step()
check('non-avocat : refusé', not ok)
ok = cb('gs_justice:requestRecords', 3, 2); step()
check('demande envoyée au client', ok and lastClientEvent('gs_justice:client:consent', 2) ~= nil)
cb('gs_justice:consent', 2, false); step()
check('refus : pas de casier transmis', lastClientEvent('gs_justice:client:records', 3) == nil)
cb('gs_justice:requestRecords', 3, 2); step()
cb('gs_justice:consent', 2, true); step()
local ev = lastClientEvent('gs_justice:client:records', 3)
check('accord : casier transmis à l\'avocat', ev and #ev.args[2] == 1)
check('consentement non sollicité : ignoré', cb('gs_justice:consent', 4, true) == false)

-- Rôle des audiences
check('civil : pas d\'accès au rôle', cb('gs_justice:cases', 4) == nil)
local d = cb('gs_justice:cases', 1)
check('juge : rôle des audiences', d and #d.cases == 2 and d.judge)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
