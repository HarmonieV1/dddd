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
check('caisse lancée (V12.7 : « Braquage de commerce »)', ok and reports[#reports].crime == 'shop_robbery')
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

-- V12.63 · Braquage PARTAGÉ (backtest : « à deux, pas synchronisé ») : un complice rejoint, peur commune, butin unique
do
    Stickup.playerCd, Stickup.zoneCd, Stickup.hour = {}, {}, {}
    join(3, 'CID3', 'Complice', shop); W.players[3].weapon = joaat('WEAPON_PISTOL')
    local nRep = #reports
    local okA = cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
    local okB, how = cb('gs_stickup:begin', 3, 'register', 'shop1'); step()
    check('à deux : le complice rejoint, un seul signalement', okA and okB and how == 'join' and #reports == nRep + 1 and GlobalState.gsStickups.shop1.n == 2)
    Stickup.live.shop1.members[1].last = GetGameTimer() - 1000
    Stickup.live.shop1.members[3].last = GetGameTimer() - 1000
    local r1 = Stickup.aim(1, 'shop1', true, 3)
    local r2 = Stickup.aim(3, 'shop1', true, 3)
    check('à deux : la peur est commune (chacun la fait monter)', r1 and r2 and r2.fear > r1.fear and r2.n == 2)
    check('à deux : fin refusée tant que la peur commune n\'est pas à 100', not cb('gs_stickup:finish', 1))
    Stickup.live.shop1.fear = 100
    advance(9000)
    W.drops = {}
    W.clientEvents = {}
    local okF, msgF = cb('gs_stickup:finish', 1); step()
    check('à deux : butin unique en sacs, le complice est prévenu et a aussi son cooldown', okF and #W.drops >= 1 and lastClientEvent('gs_stickup:client:shared', 3) ~= nil
        and Stickup.playerCd[3] and Stickup.playerCd[3].register > os.time() and Stickup.live.shop1 == nil and Stickup.pending[3] == nil)
    Stickup.playerCd, Stickup.zoneCd = {}, {}
    cb('gs_stickup:begin', 1, 'register', 'shop1'); step()
    cb('gs_stickup:begin', 3, 'register', 'shop1'); step()
    net('gs_stickup:server:cancel', 1); step()
    check('à deux : un complice qui lâche, l\'autre continue', Stickup.live.shop1 and Stickup.live.shop1.members[3] and not Stickup.live.shop1.members[1])
    net('gs_stickup:server:cancel', 3); step()
    check('à deux : plus personne = braquage terminé', Stickup.live.shop1 == nil)
end

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

-- V12.63 · Avis du commerçant en vitrine (n° 157) : caméra qui filme = avis 24 h, deux détails au plus, jamais le nom
do
    provide('gs_wanted', { ReportCrime = function() return true end, Describe = function() return 'veste rouge, casquette noire, tatouage au cou, Solo' end })
    local realState = GetResourceState
    GetResourceState = function(r) if r == 'gs_wanted' then return 'started' end return realState and realState(r) or 'missing' end
    local realRandom = math.random
    math.random = function(a, b) if a == nil then return 0.99 end return realRandom(a, b) end
    check('caméra qui n\'a rien filmé : pas d\'avis', Stickup.notice(1, 'shop1', Stickup.zones().shop1) == false)
    math.random = function(a, b) if a == nil then return 0.1 end return realRandom(a, b) end
    check('caméra qui a filmé : avis en vitrine', Stickup.notice(1, 'shop1', Stickup.zones().shop1) == true)
    local n = (GlobalState.gsShopNotices or {})[1]
    check('avis : deux détails flous, jamais le nom', n and n.label == 'Supérette' and n.desc == 'veste rouge, casquette noire' and not n.desc:find('Solo'))
    advance((Config.ShopNotice.hours * 3600 + 60) * 1000)
    Stickup.publishNotices()
    check('avis retiré au bout de 24 h', #(GlobalState.gsShopNotices or {}) == 0)
    math.random = realRandom
    GetResourceState = realState
end
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
