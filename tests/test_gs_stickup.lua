-- Tests gs_stickup : arme requise, police exclue, zones, durée réelle, cooldowns, plafonds, signalement systématique.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local reports, duty = {}, {}
provide('gs_wanted', { ReportCrime = function(src, crime, coords, opts) reports[#reports + 1] = { src = src, crime = crime, alarm = opts and opts.alarm } return true end })
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_economy', { GetClerks = function() return { { id = 'shop1', label = 'Supérette', coords = vec4(24.47, -1346.62, 29.5, 271.0) } } end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_stickup', { R .. 'gs_stickup/shared/config.lua', R .. 'gs_stickup/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local shop = vec3(25.0, -1347.0, 29.5)
join(1, 'CID1', 'Solo', vec3(200.0, 200.0, 30.0))
join(2, 'CID2', 'Agent', vec3(200.0, 200.0, 30.0)); duty[2] = 'police'
W.players[2].weapon = joaat('WEAPON_PISTOL')

local ok, msg = cb('gs_stickup:begin', 1, 'street'); step()
check('sans arme : refusé', not ok and msg:find('arme'))
W.players[1].weapon = joaat('WEAPON_PISTOL')
ok = cb('gs_stickup:begin', 2, 'street'); step()
check('policier en service : refusé', not ok)
ok = cb('gs_stickup:begin', 1, 'nimporte'); step()
check('type inconnu', not ok)

ok = cb('gs_stickup:begin', 1, 'street'); step()
check('racket lancé + signalé', ok and #reports == 1 and reports[1].crime == 'mugging')
Stickup.pending[1].startAt = W.now
ok, msg = cb('gs_stickup:finish', 1)
check('trop rapide refusé', not ok and msg == 'Trop rapide.')
ok = cb('gs_stickup:begin', 1, 'street'); step()
advance(5000)
local cash = W.players[1].money.cash
ok, msg = cb('gs_stickup:finish', 1); step()
check('racket payé en liquide', ok and W.players[1].money.cash > cash and W.players[1].money.cash - cash <= 140)
ok, msg = cb('gs_stickup:begin', 1, 'street'); step()
check('cooldown joueur', not ok and msg:find('oublier'))

-- Caisse : zone vérifiée, cooldown de zone, argent sale
ok = cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
check('caisse : trop loin', not ok)
tp(1, shop)
ok = cb('gs_stickup:begin', 1, 'register', 'inconnue'); step()
check('caisse : zone inconnue', not ok)
ok = cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
check('caisse lancée', ok and reports[#reports].crime == 'store_robbery')
advance(9000)
ok, msg = cb('gs_stickup:finish', 1); step()
local bagged = 0
for _, d in ipairs(W.drops or {}) do for _, it in ipairs(d.items) do if it[1] == 'black_money' then bagged = bagged + it[2] end end end
check('caisse : argent sale en sacs au sol, pas en poche', ok and bagged >= 280 and (W.players[1].items.black_money or 0) == 0
    and #W.drops >= Config.Bags.min and #W.drops <= Config.Bags.max and msg:find('sac'))
Stickup.playerCd[1] = nil
ok, msg = cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
check('caisse vidée : cooldown de zone', not ok and msg:find('vidée'))

-- Abandon : cooldown court
Stickup.zoneCd = {}
ok = cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
net('gs_stickup:server:cancel', 1); step()
check('abandon : plus en cours', Stickup.pending[1] == nil and Stickup.playerCd[1].register > os.time())

-- Plafonds anti-farm
Stickup.playerCd[1], Stickup.zoneCd = nil, {}
Stickup.hour[1] = { os.time(), os.time(), os.time(), os.time(), os.time(), os.time() }
ok, msg = cb('gs_stickup:begin', 1, 'street'); step()
check('plafond horaire', not ok and msg:find('heure'))
Stickup.hour[1] = {}
Stickup.day.CID1.amount = Config.MaxPerDay
ok, msg = cb('gs_stickup:begin', 1, 'street'); step()
check('plafond journalier', not ok)
check('zones : caisse + guichets', Stickup.zones().shop1 and Stickup.zones().fleeca_legion.kind == 'teller')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
