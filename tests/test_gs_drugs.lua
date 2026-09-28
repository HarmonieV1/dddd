-- Tests gs_drugs : récolte / transformation (durée, zone, matière), vente à un PNJ réel (1 fois / PNJ),
-- saturation du quartier, météo, nuit, territoires, police à proximité, signalements, items manquants.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police, reports = {}, 0
provide('gs_jobs', {
    GetOnDutyPlayers = function() return police end,
    IsOnDutyAs = function(src) for _, p in ipairs(police) do if p == src then return true end end return false end,
})
provide('gs_wanted', { ReportCrime = function() reports = reports + 1 return true end })
local hour, weather, gang, owner, influence = 14, 'CLEAR', nil, nil, 0
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end, GetWeather = function() return weather end })
provide('gs_gangs', {
    GetGang = function() return gang end, GetTerritoryAt = function() return 'grove' end,
    GetTerritoryOwner = function() return owner end, AddInfluence = function(_, _, n) influence = influence + n return true end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_drugs', { R .. 'gs_drugs/shared/config.lua', R .. 'gs_drugs/server/main.lua' })
Drugs.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local weed = Config.Drugs.weed

check('drogue activée si les items existent', Drugs.enabled.weed)
join(1, 'CID1', 'Dealer', weed.harvest.center)
join(9, 'CID9', 'Agent', vec3(9000.0, 9000.0, 0.0))

-- Récolte ------------------------------------------------------------------------------------------------
fixRandom(0.0)
local ok, dur = cb('gs_drugs:begin', 1, 'weed', 'harvest')
check('récolte lancée', ok and dur == weed.harvest.duration)
ok = cb('gs_drugs:finish', 1)
check('récolte non sautable', not ok and (W.players[1].items.weed_leaf or 0) == 0)
step()
cb('gs_drugs:begin', 1, 'weed', 'harvest'); advance(weed.harvest.duration)
ok = cb('gs_drugs:finish', 1)
check('feuille récoltée', ok and W.players[1].items.weed_leaf == 1)
ok = cb('gs_drugs:begin', 1, 'weed', 'cuisine'); step()
check('étape inconnue refusée', not ok)
ok = cb('gs_drugs:begin', 1, 'coke', 'harvest'); step()
check('drogue inconnue refusée', not ok)
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_drugs:begin', 1, 'weed', 'harvest'); step()
check('hors du champ : refusé', not ok)

-- Transformation --------------------------------------------------------------------------------------------
tp(1, weed.process.center)
ok, dur = cb('gs_drugs:begin', 1, 'weed', 'process'); step()
check('pas assez de feuilles : refusé', not ok)
W.players[1].items.weed_leaf = 7
cb('gs_drugs:begin', 1, 'weed', 'process'); advance(weed.process.duration)
ok = cb('gs_drugs:finish', 1)
check('transformation : 3 feuilles → 1 sachet', ok and W.players[1].items.weed_leaf == 4 and W.players[1].items.weed_bag == 1)
step()

-- Vente --------------------------------------------------------------------------------------------------------
W.players[1].items.weed_bag = 20
local street = vec3(200.0, -800.0, 30.0)
tp(1, street)
spawnPeds(street, 12)
local peds = {}
for id, e in pairs(W.entities) do if e.type == 1 then peds[#peds + 1] = id end end
table.sort(peds)
local function sellTo(i) local r1, r2 = cb('gs_drugs:sell', 1, peds[i]) advance(7000) return r1, r2 end

-- les PNJ sont alignés à x+1..x+12 : on se place à côté de chacun
local function at(i) tp(1, W.entities[peds[i]].pos) end
-- Tirage favorable : jamais de refus (random() haut), prix minimum et quantité 1 (bornes basses)
local realRandom = math.random
local function favorable() math.random = function(a, b) if a == nil then return 0.99 end if b == nil then return 1 end return a end end
at(1)
favorable()
W.players[1].money.cash = 0
ok, msg = sellTo(1)
check('vente réussie', ok and W.players[1].items.weed_bag == 19)
check('payé en argent sale au prix minimum', W.players[1].items.black_money == weed.sell.price[1])
check('vente signalable (témoins)', reports >= 1)
ok = sellTo(1)
check('même PNJ : une seule fois', not ok)
at(1)
ok = cb('gs_drugs:sell', 1, peds[12]); advance(7000)
check('PNJ trop loin : refusé', not ok)
ok = cb('gs_drugs:sell', 1, 42424); advance(7000)
check('entité inexistante refusée', not ok)
ok = cb('gs_drugs:sell', 1, 1001); advance(7000)
check('impossible de « vendre » à un joueur', not ok)

-- Saturation : chaque vente fait baisser le prix dans le quartier
local sat = Drugs.saturation('grove')
check('saturation après 1 vente', math.abs(sat - (1 - Config.Sell.saturationStep)) < 1e-9)
for _ = 1, 30 do table.insert(Drugs.sales.grove, os.time()) end
check('saturation plafonnée', Drugs.saturation('grove') == Config.Sell.saturationFloor)
advance((Config.Sell.saturationWindow + 10) * 1000)
check('le marché se remet en une heure', Drugs.saturation('grove') == 1.0)

-- Nuit + territoire tenu par son gang
hour, gang, owner = 23, 'ballas', 'ballas'
local before = W.players[1].items.black_money
at(4)
sellTo(4)
local expected = math.floor(weed.sell.price[1] * Config.Sell.nightBonus * Config.Sell.ownTerritory)
check('bonus nuit × territoire', W.players[1].items.black_money - before == expected)
check('influence du gang', influence >= Config.Sell.influence)
-- territoire rival
owner = 'vagos'; hour = 14
before = W.players[1].items.black_money
local satBefore = Drugs.saturation('grove')
at(5); sellTo(5)
check('malus territoire rival (et saturation de la vente précédente)',
    W.players[1].items.black_money - before == math.floor(weed.sell.price[1] * satBefore * Config.Sell.rivalTerritory))

-- Refus : tirage défavorable, puis police proche
fixRandom(0.0)
at(6)
ok, msg = sellTo(6)
check('refus possible (et signalement)', not ok and msg:find('téléphone'))
favorable()
police = { 9 }
tp(9, street)
at(7)
ok = sellTo(7)
check('policier en service à proximité : refus systématique', not ok)
police = {}
fixRandom()

-- Rate-limit
at(8)
cb('gs_drugs:sell', 1, peds[8])
at(9)
ok, msg = cb('gs_drugs:sell', 1, peds[9])
check('rate-limit des ventes', not ok and msg:find('Doucement'))

-- Items manquants → drogue désactivée
Config.Drugs.coke = { harvest = { item = 'introuvable' }, process = { output = 'x' }, sell = { item = 'y' } }
Drugs.init()
check('item manquant : drogue désactivée', not Drugs.enabled.coke)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
