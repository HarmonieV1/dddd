-- Tests gs_roadside (V8) : tirage (hors ville, au volant, délai, chance), récompenses vérifiées par le serveur
-- (distance, objets, adresse), variantes dangereuses, ami de la route, shérif, vendeur, anti-abus.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local heat, reported, points = 0, {}, {}
provide('gs_wanted', { GetHeat = function() return heat end, ReportCrime = function(src, crime) reported[#reported + 1] = crime return true end })
provide('gs_driving', { RemovePoints = function(src, n) points[src] = (points[src] or 0) + n end })
provide('gs_weather', { GetGameTime = function() return 14 end, GetWeather = function() return 'CLEAR' end })
provide('gs_reputation', { Add = function() end })
local seen = {}
Store = { init = function() end, add = function(cid, k) seen[cid .. k] = (seen[cid .. k] or 0) + 1 end,
    list = function(cid) local o = {} for k, v in pairs(seen) do if k:sub(1, #cid) == cid then o[k:sub(#cid + 1)] = v end end return o end }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_roadside', { R .. 'gs_roadside/shared/config.lua', R .. 'gs_roadside/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

local route = vec3(2500.0, 3500.0, 50.0) -- désert de Senora : hors de la ville
local city = vec3(200.0, -800.0, 30.0)
join(1, 'CID1', 'Routard', route)
local car = CreateVehicleServerSetter(0, 'automobile', route.x, route.y, route.z)
local function drive(src, veh) W.players[src].vehicle = veh W.entities[veh].driver = src end
local function reset(src) Roadside.active[src] = nil Roadside.last['CID' .. src] = nil end
local function force(kind, danger)
    reset(1)
    local pick = Roadside.pick
    Roadside.pick = function() return kind end
    fixRandom(0.0)
    local d = Roadside.roll(1)
    fixRandom()
    Roadside.pick = pick
    if d then Roadside.active[1].danger = danger or nil d.danger = danger end
    return d
end

-- Tirage ------------------------------------------------------------------------------------------------------------
fixRandom(0.0)
check('à pied : pas de rencontre', Roadside.roll(1) == nil)
drive(1, car)
tp(1, city)
check('en ville : pas de rencontre', Roadside.roll(1) == nil)
tp(1, route)
fixRandom(0.99)
check('tirage défavorable : rien', Roadside.roll(1) == nil)
fixRandom(0.0)
local d = Roadside.roll(1)
check('hors ville, au volant, tirage favorable : rencontre', d ~= nil and d.token ~= nil and Config.Types[d.kind] ~= nil or (d and d.kind == 'friend'))
Roadside.active[1] = nil
check('délai entre deux rencontres', Roadside.roll(1) == nil)
fixRandom()
local counts = {}
for _ = 1, 2000 do local k = Roadside.pick() counts[k] = (counts[k] or 0) + 1 end
check('tirage pondéré : tous les types sortent', counts.hitchhiker and counts.sheriff and counts.vendor and counts.wallet and counts.animal)

-- Auto-stoppeur : déposé à la bonne ville seulement -------------------------------------------------------------------------
d = force('hitchhiker')
local place = Config.Places[d.place]
check('auto-stoppeur : destination lointaine', #(place.coords - route) >= Config.Types.hitchhiker.minDistance)
check('déposé trop tôt / ailleurs : refusé', not Roadside.finish(1, d.token, 'dropped'))
advance(60000)
tp(1, place.coords)
check('mauvais jeton : refusé', not Roadside.finish(1, 123, 'dropped'))
check('déposé à destination : payé', Roadside.finish(1, d.token, 'dropped') == true and W.players[1].money.cash > 0)
check('collection : auto-stoppeur', seen['CID1hitchhiker'] == 1)
check('scène terminée : rejouer refusé', not Roadside.finish(1, d.token, 'dropped'))
check('il se souvient de toi', Roadside.friends['CID1'] ~= nil)

-- Ami de la route
tp(1, route)
reset(1)
fixRandom(0.0)
local pick = Roadside.pick Roadside.pick = function() return 'hitchhiker' end
d = Roadside.roll(1)
Roadside.pick = pick fixRandom()
check('l\'auto-stoppeur aidé revient (ami)', d and d.kind == 'friend' and d.model == Roadside.friends['CID1'].model)
local cash = W.players[1].money.cash
check('ami : cadeau', Roadside.finish(1, d.token, 'met') == true and W.players[1].money.cash > cash)

-- Auto-stoppeur braqueur
Roadside.friends['CID1'] = nil
d = force('hitchhiker', true)
W.players[1].money.cash = 2000
check('braqueur : ne peut pas être « déposé » contre paiement', not Roadside.finish(1, d.token, 'dropped'))
check('braqueur : cash pris (plafonné)', Roadside.finish(1, d.token, 'robbed') == true and W.players[1].money.cash == 2000 - Config.Rob.max)

-- Panne : objet requis
d = force('breakdown')
check('panne : sans jerrican ni kit, refusé', not Roadside.finish(1, d.token, 'helped'))
W.players[1].items.repairkit = 1
cash = W.players[1].money.cash
check('panne : kit consommé, payé', Roadside.finish(1, d.token, 'helped') == true and W.players[1].items.repairkit == 0 and W.players[1].money.cash > cash)
d = force('breakdown', true)
check('fausse panne : pas de paiement, juste survivre', Roadside.finish(1, d.token, 'helped') == false and Roadside.finish(1, d.token, 'ambush') == true)

-- Accident / animal : bandage
d = force('accident')
check('accident : sans bandage refusé', not Roadside.finish(1, d.token, 'helped'))
W.players[1].items.bandage = 2
check('accident : premiers secours', Roadside.finish(1, d.token, 'helped') == true and W.players[1].items.bandage == 1)
d = force('animal')
check('animal soigné', Roadside.finish(1, d.token, 'helped') == true and W.players[1].items.bandage == 0)

-- Portefeuille : rendu à l'adresse ou gardé
d = force('wallet')
check('portefeuille : rendu ailleurs refusé', not Roadside.finish(1, d.token, 'returned'))
advance(60000) tp(1, Config.Places[d.place].coords)
check('portefeuille rendu à l\'adresse', Roadside.finish(1, d.token, 'returned') == true and seen['CID1wallet_returned'] == 1)
tp(1, route)
d = force('wallet')
check('portefeuille gardé', Roadside.finish(1, d.token, 'kept') == true and seen['CID1wallet_kept'] == 1)

-- Vendeur
d = force('vendor')
W.players[1].money.cash = 5
check('vendeur : pas assez de liquide', not Roadside.buy(1, d.token, 1))
W.players[1].money.cash = 500
check('vendeur : achat', Roadside.buy(1, d.token, 1) == true and W.players[1].items[Config.Vendor[1].item] == 1)
check('vendeur : article inconnu refusé', not Roadside.buy(1, d.token, 99))

-- Shérif : papiers, sans permis, fuite, recherché
d = force('sheriff')
W.players[1].money.bank = 5000
check('shérif : sans permis → amende', Roadside.finish(1, d.token, 'checked') == true and W.players[1].money.bank == 5000 - Config.Types.sheriff.fine)
d = force('sheriff')
W.players[1].licences = { driver = true }
check('shérif : en règle', Roadside.finish(1, d.token, 'checked') == true and W.players[1].money.bank == 5000 - Config.Types.sheriff.fine)
d = force('sheriff')
check('shérif : fuite → refus d\'obtempérer + points', Roadside.finish(1, d.token, 'fled') == true and reported[#reported] == 'refusal' and points[1] == Config.Types.sheriff.points)
heat = 20
d = force('sheriff')
W.clientEvents = {}
check('shérif : recherché → poursuite', d.wanted == true and Roadside.finish(1, d.token, 'checked') == true and lastClientEvent('gs_wanted:client:npcPolice', 1) ~= nil)
heat = 0

-- Ignorer : rien ne se passe
d = force('accident')
check('ignorer : aucune conséquence', Roadside.finish(1, d.token, 'ignored') == true and Roadside.active[1] == nil)
check('collection consultable', cb('gs_roadside:collection', 1).hitchhiker == 1)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
