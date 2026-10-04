-- Tests gs_economy : prix, offre/demande, retour à l'équilibre, événements, arbitrage, anti-abus.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
provide('gs_weather', { GetEvent = function() return nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_economy', { R .. 'gs_economy/shared/config.lua', R .. 'gs_economy/shared/pricing.lua' })
local saved
Store = { load = function() return { water = 0.5, inconnu = 3 } end, save = function(m) saved = m end }
loadResource('gs_economy', { R .. 'gs_economy/server/regulars.lua', R .. 'gs_economy/server/main.lua' })
Config.Items.introuvable = { label = 'X', base = 1, min = 1, max = 1, volume = 1 }
table.insert(Config.Shops[1].items, 'introuvable')
Market.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

check('item absent d\'ox_inventory retiré', Config.Items.introuvable == nil)
for _, i in ipairs(Config.Shops[1].items) do check('retiré du commerce aussi', i ~= 'introuvable') end

-- Config cohérente ----------------------------------------------------------------------------------
for _, list in ipairs({ Config.Shops, Config.Resellers }) do
    for _, place in ipairs(list) do
        for _, item in ipairs(place.items) do check('item configuré : ' .. item, Config.Items[item] ~= nil) end
    end
end
for id, mults in pairs(Config.EventMultipliers) do
    for item in pairs(mults) do check(('événement %s → item %s connu'):format(id, item), Config.Items[item] ~= nil) end
end

-- Chargement ------------------------------------------------------------------------------------------
check('pression chargée', Market.pressure.water == 0.5)
check('item inconnu en BDD ignoré', Market.pressure.inconnu == nil)
Market.pressure.water = nil

-- Prix ------------------------------------------------------------------------------------------------
check('prix de base', Market.buyPrice('water') == Config.Items.water.base)
Market.push('water', Config.Items.water.volume)
check('demande → prix monte', Market.buyPrice('water') > Config.Items.water.base)
Market.pressure.water = 1000
check('plafond max', Market.buyPrice('water') == math.floor(Config.Items.water.base * Config.Items.water.max + 0.5))
Market.pressure.water = -1000
check('plancher min', Market.buyPrice('water') == math.max(1, math.floor(Config.Items.water.base * Config.Items.water.min + 0.5)))
Market.pressure.water = 2
for _ = 1, 100 do Market.tick() end
check('retour à l\'équilibre', Market.pressure.water == nil and Market.buyPrice('water') == Config.Items.water.base)

-- Pas d'arbitrage : revente toujours < achat, quelle que soit la pression -------------------------------
local okArb = true
for item, def in pairs(Config.Items) do
    if def.buy ~= false then
        for p = -5, 5, 0.25 do
            for _, ev in ipairs({ 1.0, 1.6 }) do
                if Pricing.sellPrice(item, p, ev) >= Pricing.buyPrice(item, p, ev) then okArb = false end
            end
        end
    end
end
check('revente toujours strictement sous l\'achat', okArb)

-- Événements météo -------------------------------------------------------------------------------------
local before = Market.buyPrice('water')
TriggerEvent('gs_weather:server:eventStarted', 'heatwave')
check('canicule : eau plus chère', Market.buyPrice('water') > before)
TriggerEvent('gs_weather:server:eventEnded', 'heatwave')
check('fin de canicule : prix normal', Market.buyPrice('water') == before)

-- Achat ------------------------------------------------------------------------------------------------
local shop = Config.Shops[1]
join(1, 'CID1', 'Client Un', shop.coords)
W.players[1].money.cash = 100
local ok, msg = cb('gs_economy:buy', 1, 1, 'water', 3); step()
check('achat ok', ok and W.players[1].money.cash == 100 - 3 * Config.Items.water.base)
check('demande enregistrée', (Market.pressure.water or 0) > 0)
ok = cb('gs_economy:buy', 1, 1, 'water', 0); step()
check('quantité 0 refusée', not ok)
ok = cb('gs_economy:buy', 1, 1, 'water', 2.5); step()
check('quantité décimale refusée', not ok)
ok = cb('gs_economy:buy', 1, 1, 'water', Config.MaxQuantity + 1); step()
check('quantité max', not ok)
ok = cb('gs_economy:buy', 1, 1, 'repairkit', 1); step()
check('item absent du commerce refusé', not ok)
ok = cb('gs_economy:buy', 1, 1, 'scrapmetal', 1); step()
check('item revente seule non achetable', not ok)
W.players[1].money.cash, W.players[1].money.bank = 0, 0
ok = cb('gs_economy:buy', 1, 1, 'burger', 1); step()
check('sans argent refusé', not ok)
W.players[1].money.bank = 500
ok = cb('gs_economy:buy', 1, 1, 'burger', 1); step()
check('paiement banque si pas de cash', ok and W.players[1].money.bank < 500)
W.players[1].full = true
local bank = W.players[1].money.bank
ok = cb('gs_economy:buy', 1, 1, 'burger', 1); step()
check('inventaire plein : refusé sans débit', not ok and W.players[1].money.bank == bank)
W.players[1].full = nil
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_economy:buy', 1, 1, 'water', 1); step()
check('trop loin refusé', not ok)

-- Revente -----------------------------------------------------------------------------------------------
local yard = Config.Resellers[1]
tp(1, yard.coords)
W.players[1].items.scrapmetal = 50
W.players[1].money.cash = 0
ok = cb('gs_economy:sell', 1, 1, 'scrapmetal', 10); step()
check('revente ok', ok and W.players[1].items.scrapmetal == 40 and W.players[1].money.cash > 0)
check('offre enregistrée', (Market.pressure.scrapmetal or 0) < 0)
ok = cb('gs_economy:sell', 1, 1, 'scrapmetal', 20); step()
check('marché inondé : prix de revente baisse', Market.sellPrice('scrapmetal') < Config.Items.scrapmetal.base)
ok = cb('gs_economy:sell', 1, 1, 'scrapmetal', 20); step()
ok = cb('gs_economy:sell', 1, 1, 'scrapmetal', 5); step()
check('revente refusée sans stock', not ok and W.players[1].items.scrapmetal == 0)
ok = cb('gs_economy:sell', 1, 1, 'water', 1); step()
check('item non racheté ici refusé', not ok)

-- Rate-limit ----------------------------------------------------------------------------------------------
W.players[1].items.scrapmetal = 50
local count = 0
for _ = 1, 10 do if cb('gs_economy:sell', 1, 1, 'scrapmetal', 1) then count = count + 1 end end
check('rate-limit : 5 reventes / 10 s', count == 5)

-- Sauvegarde ------------------------------------------------------------------------------------------------
TriggerEvent('onResourceStop', 'gs_jobs') -- GetCurrentResourceName() du mock
check('sauvegarde à l\'arrêt', saved ~= nil and saved.scrapmetal ~= nil)
Market.pressure.water = nil
saved = nil
Market.dirty = true
TriggerEvent('onResourceStop', 'gs_jobs')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
