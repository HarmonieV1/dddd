-- Tests gs_reputation : gains par activité, likes (+/−), bornes, paliers, effets (remise, bonus rue, salutation),
-- sauvegarde différée, remise appliquée par gs_economy.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_reputation', { R .. 'gs_reputation/shared/config.lua' })
local saved = {}
Store = { init = function() end, load = function(cid) return saved[cid] and { street = saved[cid].street, legal = saved[cid].legal, media = saved[cid].media } or { street = 0, legal = 0, media = 0 } end,
    save = function(cid, r) saved[cid] = { street = r.street, legal = r.legal, media = r.media } end }
loadResource('gs_reputation', { R .. 'gs_reputation/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local get = getExport('gs_reputation', 'Get')

join(1, 'CID1', 'Marchand', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_quests:server:activity', 1, 'job_mission')
TriggerEvent('gs_quests:server:activity', 1, 'heist')
TriggerEvent('gs_quests:server:activity', 1, 'inconnue')
check('gains : légale +5, rue +10', get(1).legal == 5 and get(1).street == 10)
TriggerEvent('gs_social:server:liked', 'CID1', true) TriggerEvent('gs_social:server:liked', 'CID1', true) TriggerEvent('gs_social:server:liked', 'CID1', false)
check('likes : +1 +1 −1', get(1).media == 1)
TriggerEvent('gs_social:server:liked', 'CID1', false) TriggerEvent('gs_social:server:liked', 'CID1', false)
check('jamais sous 0', get(1).media == 0)
Rep.add('CID1', 'legal', 5000)
check('plafond 1000', get(1).legal == Config.Max)
Rep.add('CID1', 'hack', 50)
check('jauge inconnue ignorée', get(1).hack == nil)
check('paliers', Rep.tier(0) == 'Inconnu' and Rep.tier(300) == 'Respecté' and Rep.tier(950) == 'Légende')
check('remise max à 900+', getExport('gs_reputation', 'GetDiscount')(1) == 0.10)
check('salutation (légale ≥ 300)', getExport('gs_reputation', 'ShouldGreet')(1) == true)
Rep.add('CID1', 'street', 290)
check('bonus rue à 300', getExport('gs_reputation', 'GetStreetBonus')(1) == 0.05)
check('pas encore sauvegardé', saved.CID1 == nil)
Rep.flush()
check('sauvegarde différée', saved.CID1 and saved.CID1.legal == Config.Max)
local r = cb('gs_reputation:get', 1)
check('menu : jauges + effets', r and r.legal.tier == 'Légende' and r.discount == 0.10)

-- Remise dans gs_economy
provide('gs_reputation', { GetDiscount = function() return 0.10 end, ShouldGreet = function() return true end, GetStreetBonus = function() return 0 end })
loadResource('gs_economy', { R .. 'gs_economy/shared/config.lua', R .. 'gs_economy/shared/pricing.lua' })
Store = { init = function() end, load = function() return {} end, save = function() end }
loadResource('gs_economy', { R .. 'gs_economy/server/regulars.lua', R .. 'gs_economy/server/main.lua' })
local shop = Config.Shops[1]
join(2, 'CID2', 'Client Fidèle', shop.coords)
W.players[2].money.cash = 1000
local q = cb('gs_economy:quote', 2, 'buy', 1)
local base = Market.buyPrice('water')
local wq
for _, x in ipairs(q) do if x.item == 'water' then wq = x end end
check('devis : remise appliquée + salutation', wq.price == math.max(1, math.floor(base * 0.9 + 0.5)) and q.greet == 'Client')
local ok = cb('gs_economy:buy', 2, 1, 'water', 2)
check('achat au prix remisé', ok and W.players[2].money.cash == 1000 - 2 * wq.price)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
