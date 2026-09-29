-- Tests gs_market : lecture des indices, relevé, variation 24 h, historique, sources absentes.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local price, fuel = 1.0, 60
provide('gs_economy', { GetPriceIndex = function() return price end, GetBuyPrice = function() return fuel end, GetSellPrice = function() return 30 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_market', { R .. 'gs_market/shared/config.lua' })
local rows, housing = {}, nil
Store = { init = function() end, add = function(ts, r) for id, v in pairs(r) do rows[#rows + 1] = { ts = ts, idx = id, value = v } end end,
    history = function(since) local l = {} for _, r in ipairs(rows) do if r.ts >= since then l[#l + 1] = r end end return l end,
    purge = function() end, housing = function() return housing end, wealth = function() return 12500000 end }
loadResource('gs_market', { R .. 'gs_market/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

local v = Market.read()
check('lecture : prix 100 pts, carburant, métaux, richesse en M$', v.prices == 100 and v.fuel == 60 and v.metals == 30 and v.wealth == 12.5)
check('immobilier absent (qbx_properties vide) : ignoré', v.housing == nil)
local t0 = 1000000
Market.snapshot(t0)
price, fuel, housing = 1.2, 90, 250000
Market.snapshot(t0 + 86400)
local d = Market.data(t0 + 86400 + 60)
local byId = {}
for _, x in ipairs(d) do byId[x.id] = x end
check('indice des prix : +20 % sur 24 h', math.abs(byId.prices.change - 20) < 0.01 and byId.prices.value == 120)
check('carburant : +50 %', math.abs(byId.fuel.change - 50) < 0.01)
check('historique pour le graphique', #byId.prices.history == 3)
check('immobilier apparu : pas de variation encore', byId.housing and byId.housing.value == 250000)
join(1, 'CID1', 'Trader', vec3(0.0, 0.0, 0.0))
local c = cb('gs_market:data', 1)
check('callback : indices servis', c and #c >= 4)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
