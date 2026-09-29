-- Tests gs_civil : demande (guichet, déjà marié), accord / refus / expiration, frais, officiant, divorce.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local agents = {}
provide('gs_jobs', { GetOnDutyPlayers = function() return agents end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_civil', { R .. 'gs_civil/shared/config.lua' })
local m = {}
Store = { init = function() end,
    spouse = function(cid) for _, r in ipairs(m) do if r.a == cid then return { cid = r.b, name = r.bn } elseif r.b == cid then return { cid = r.a, name = r.an } end end end,
    marry = function(a, b, an, bn) m[#m + 1] = { a = a, b = b, an = an, bn = bn } end,
    divorce = function(cid) for i, r in ipairs(m) do if r.a == cid or r.b == cid then table.remove(m, i) return true end end return false end }
loadResource('gs_civil', { R .. 'gs_civil/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end
local D = Config.Desk

join(1, 'A', 'Alice', D) join(2, 'B', 'Bob', vec3(0.0, 0.0, 0.0)) join(3, 'C', 'Agent Mairie', D) join(4, 'D', 'Dora', D)
for _, s in ipairs({ 1, 2, 4 }) do W.players[s].money.bank = 5000 end
local ok = cb('gs_civil:propose', 1, 2); step()
check('partenaire absent du guichet', not ok)
tp(2, D)
ok = cb('gs_civil:propose', 1, 2); step()
check('demande envoyée', ok and lastClientEvent('gs_civil:client:proposal', 2) ~= nil)
ok = cb('gs_civil:answer', 2, false); step()
check('refus', ok and #m == 0)
cb('gs_civil:propose', 1, 2); step()
advance((Config.ProposalTimeout + 5) * 1000)
ok = cb('gs_civil:answer', 2, true); step()
check('demande expirée', not ok and #m == 0)
agents[1] = 3
cb('gs_civil:propose', 1, 2); step()
ok = cb('gs_civil:answer', 2, true); step()
check('mariage : frais payés par les deux, officiant prévenu', ok and #m == 1 and W.players[1].money.bank == 5000 - Config.MarriageFee
    and W.players[2].money.bank == 5000 - Config.MarriageFee and W.notes[3] and W.notes[3].msg:find('célébré'))
check('conjoint (export)', getExport('gs_civil', 'GetSpouseName')('A') == 'Bob')
ok = cb('gs_civil:propose', 4, 1); step()
check('déjà marié(e)', not ok)
ok = cb('gs_civil:divorce', 4); step()
check('divorce sans être marié', not ok)
ok = cb('gs_civil:divorce', 2); step()
check('divorce : frais, conjoint prévenu', ok and #m == 0 and W.players[2].money.bank == 5000 - Config.MarriageFee - Config.DivorceFee and W.notes[1].msg:find('divorce'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
