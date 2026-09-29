-- Tests gs_blackmarket : accès (gang / réputation / police), planque, horaires, rareté, stock, 1 arme par jour,
-- paiement sale ou liquide, plafond des armureries légales.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local gangOf, rep, duty, hour, owner = { [1] = 'ballas' }, { [2] = 20 }, { [3] = 'police' }, 23, nil
provide('gs_gangs', { GetGang = function(src) return gangOf[src], 1 end, GetTerritoryAt = function() return 'davis' end,
    GetTerritoryOwner = function() return owner end })
provide('gs_reputation', { Get = function(src) return { street = rep[src] or 0 } end, Add = function() end })
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_weather', { GetGameTime = function() return hour end, GetEvent = function() end })
provide('gs_wanted', { GetHeat = function() return 0 end, ReportCrime = function() return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_blackmarket', { R .. 'gs_blackmarket/shared/config.lua', R .. 'gs_blackmarket/server/main.lua', R .. 'gs_blackmarket/server/legal.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local loc = Market.location()
local here = vec3(loc.x, loc.y, loc.z)
join(1, 'CID1', 'Ballas', here); join(2, 'CID2', 'Voyou', here); join(3, 'CID3', 'Flic', here); join(4, 'CID4', 'Inconnu', here)
local function idx(item) for i, e in ipairs(Config.Catalog) do if e.item == item then return i end end end

check('accès gang', Market.access(1))
check('accès réputation', Market.access(2))
check('police refusée', not Market.access(3))
check('inconnu refusé', not Market.access(4))
check('where : planque du jour', cb('gs_blackmarket:where', 1).x == loc.x and cb('gs_blackmarket:where', 4) == nil)

local list = cb('gs_blackmarket:catalog', 2); step()
local gangOnlyVisible = false
for _, e in ipairs(list) do if Config.Catalog[e.index].gangOnly then gangOnlyVisible = true end end
check('catalogue sans armes de gang pour un non-gang', list and not gangOnlyVisible)
hour = 12
check('fermé le jour', cb('gs_blackmarket:catalog', 1) == nil)
step()
hour = 23

local a9 = idx('ammo-9')
W.players[1].items.black_money = 100
local ok, msg = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('pas assez d\'argent sale', not ok)
W.players[1].items.black_money = 10000
local p0 = Market.price(a9)
ok = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('achat munitions : paquet de 20', ok and W.players[1].items['ammo-9'] == 20 and W.players[1].items.black_money == 10000 - p0)
check('rareté : le prix monte', Market.price(a9) > p0)
owner = 'ballas'
check('remise de gang sur son territoire', Market.price(a9, 'ballas') < Market.price(a9))
owner = nil

local pistol = idx('WEAPON_PISTOL')
ok = cb('gs_blackmarket:buy', 1, pistol, 'dirty'); step()
check('arme achetée', ok and W.players[1].items.WEAPON_PISTOL == 1)
ok, msg = cb('gs_blackmarket:buy', 1, idx('WEAPON_SNSPISTOL'), 'dirty'); step()
check('une arme par jour', not ok and msg:find('arme'))
ok = cb('gs_blackmarket:buy', 2, idx('WEAPON_MICROSMG'), 'dirty'); step()
check('arme de gang refusée hors gang', not ok)

W.players[2].money.cash = 1000
local cashPrice = math.floor(Market.price(idx('lockpick')) * Config.CashMarkup)
ok = cb('gs_blackmarket:buy', 2, idx('lockpick'), 'cash'); step()
check('paiement liquide majoré', ok and W.players[2].money.cash == 1000 - cashPrice)

Market.sold[a9] = Config.Catalog[a9].stock
ok, msg = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('rupture de stock', not ok and msg:find('stock'))
tp(1, vec3(0.0, 0.0, 0.0))
Market.sold[a9] = 0
ok = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('loin du contact : refusé', not ok)

-- Armurerie légale : 120 munitions / jour, 1 arme / jour
check('légal : 100 munitions ok', Legal.check(4, 'ammo-9', 100))
ok, msg = Legal.check(4, 'ammo-9', 30)
check('légal : plafond journalier', not ok and msg:find('120'))
check('légal : couteau libre', Legal.check(4, 'WEAPON_KNIFE', 1) == true)
check('légal : 1re arme ok, 2e refusée', Legal.check(4, 'WEAPON_PISTOL', 1) == true and not Legal.check(4, 'WEAPON_PISTOL', 1))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
