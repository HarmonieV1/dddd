-- Tests gs_business · la doublure (V9) : patron seulement, commerces listés seulement, apparence de la base,
-- visible sans employé en service, meilleure part de la recette, braquage (arme, portée, délai, caisse), expiration.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, society, crimes = {}, { bar = 20000 }, {}
provide('gs_jobs', {
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end,
    IsOnDutyAs = function(src, job) return duty[src] == job end,
    AddSocietyMoney = function(job, n) society[job] = (society[job] or 0) + n return true end,
    RemoveSocietyMoney = function(job, n) if (society[job] or 0) < n then return false end society[job] = society[job] - n return true end,
    GetSocietyMoney = function(job) return society[job] or 0 end,
})
provide('gs_wanted', { ReportCrime = function(_, t) crimes[#crimes + 1] = t return true end })
local skins = { CID3 = { model = 'mp_f_freemode_01', skin = '{"hair":1}' } }
MySQL = { single = { await = function(_, p) return skins[p[1]] end } }
json.encode = function(t) return t and 'x' or '' end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_business', { R .. 'gs_business/shared/config.lua' })
local ledger = {}
Store = { init = function() end, prices = function() return {} end, setPrice = function() end,
    log = function(b, k, i, q, a) ledger[#ledger + 1] = { kind = k, amount = a } end, ledger = function() return ledger end, todaySales = function() return 0 end }
loadResource('gs_business', { R .. 'gs_business/server/main.lua', R .. 'gs_business/server/double.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end
local B = Config.Businesses.bar
join(1, 'CID1', 'Client', B.register) W.players[1].money.cash = 5000
join(2, 'CID2', 'Barman', B.register, { name = 'bar', grade = 1, onduty = false })
join(3, 'CID3', 'Patronne', B.register, { name = 'bar', grade = 2, onduty = false, isboss = true })

local ok = cb('gs_business:double', 2, 'set', 'bar'); step()
check('un simple employé ne pose pas de doublure', not ok)
ok = cb('gs_business:double', 3, 'set', 'garage'); step()
check('commerce non listé : pas de doublure', not ok)
local m = cb('gs_business:menu', 3, 'bar'); step()
check('le patron (même hors service) voit l\'option', m.canDouble and not m.hasDouble)
ok = cb('gs_business:double', 3, 'set', 'bar'); step()
check('doublure posée avec l\'apparence de la patronne', ok and Double.list.bar.model == 'mp_f_freemode_01' and GlobalState.gsDoubles.bar and GlobalState.gsDoubles.bar.name == 'Patronne')
m = cb('gs_business:menu', 1, 'bar'); step()
check('le client est servi par la doublure', m.double == 'Patronne')
local before = society.bar
local beer = math.ceil(B.npc.beer * Config.SelfServiceMarkup)
cb('gs_business:buy', 1, 'bar', 'beer', 2); step()
check('meilleure part de la recette avec la doublure', society.bar - before == math.floor(2 * beer * Config.Double.share))
duty[2] = 'bar'
Double.publish()
check('un employé prend son service : la doublure s\'efface', GlobalState.gsDoubles.bar == nil and not Double.active('bar'))
duty[2] = nil
Double.publish()
-- Braquage
tp(1, B.craft)
ok = cb('gs_business:double', 1, 'rob', 'bar'); step()
check('sans arme : refusé', not ok)
W.players[1].weapon = joaat('WEAPON_PISTOL') + 1000
before = society.bar
ok = cb('gs_business:double', 1, 'rob', 'bar'); step()
local take = math.min(Config.Double.rob.max, math.floor(before * Config.Double.rob.pct))
check('braquage : pris dans la caisse, crime signalé', ok and society.bar == before - take and crimes[1] == 'store_robbery')
ok = cb('gs_business:double', 1, 'rob', 'bar'); step()
check('une fois toutes les 2 h', not ok)
Double.robbed.bar = nil
tp(3, B.craft) W.players[3].weapon = joaat('WEAPON_PISTOL') + 1000
ok = cb('gs_business:double', 3, 'rob', 'bar'); step()
check('on ne braque pas sa propre doublure', not ok)
-- Retrait et expiration
ok = cb('gs_business:double', 1, 'clear', 'bar'); step()
check('seul le patron la retire', not ok)
Double.list.bar.untilAt = os.time() - 1
check('doublure expirée', not Double.active('bar') and Double.list.bar == nil)
cb('gs_business:double', 3, 'set', 'bar'); step()
ok = cb('gs_business:double', 3, 'clear', 'bar'); step()
check('le patron reprend sa place', ok and Double.list.bar == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
