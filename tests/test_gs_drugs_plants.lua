-- Tests plantations gs_drugs : planter (matériel, distance, espacement, limite, intérieur), croissance (eau, engrais,
-- sécheresse), récolte par n'importe qui quand c'est mûr (vol signalé), destruction (propriétaire / police), graines.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police, reports = {}, 0
provide('gs_jobs', {
    GetOnDutyPlayers = function() return police end,
    IsOnDutyAs = function(src) for _, p in ipairs(police) do if p == src then return true end end return false end,
})
provide('gs_wanted', { ReportCrime = function() reports = reports + 1 return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local rows, nextId = {}, 0
PlantStore = {
    init = function() end, all = function() return {} end,
    insert = function(owner) nextId = nextId + 1 rows[nextId] = owner return nextId end,
    update = function() end, delete = function(id) rows[id] = nil end,
}
loadResource('gs_drugs', { R .. 'gs_drugs/shared/config.lua', R .. 'gs_drugs/server/plants.lua' })
local P = Config.Plants

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local function count() local n = 0 for _ in pairs(Plants.list) do n = n + 1 end return n end
local here = vec3(100.0, 100.0, 30.0)
local function at(dx, dy) return { x = here.x + dx, y = here.y + (dy or 0.0), z = here.z } end

join(1, 'CID1', 'Jardinier', here)
local ok, msg = cb('gs_drugs:plant', 1, at(0.5)); step()
check('sans graine : refusé', not ok)
W.players[1].items.weed_seed = 10
ok, msg = cb('gs_drugs:plant', 1, at(0.5)); step()
check('sans pot : refusé, graine gardée', not ok and msg:find('pot') and W.players[1].items.weed_seed == 10)
W.players[1].items.plant_pot = 10
ok = cb('gs_drugs:plant', 1, at(10.0)); step()
check('trop loin du joueur : refusé', not ok)
ok = cb('gs_drugs:plant', 1, { x = here.x, y = here.y, z = -40.0 }); step()
check('intérieur (sous la map) : refusé', not ok)
ok = cb('gs_drugs:plant', 1, 'nimporte'); step()
check('coords invalides : refusé', not ok)
ok, msg = cb('gs_drugs:plant', 1, at(0.5)); step()
check('planté : graine + pot consommés', ok and count() == 1 and W.players[1].items.weed_seed == 9 and W.players[1].items.plant_pot == 9)
local id = next(Plants.list)
check('publié pour les clients (stade 1)', GlobalState.gsPlants[tostring(id)] and GlobalState.gsPlants[tostring(id)].s == 1)
ok, msg = cb('gs_drugs:plant', 1, at(1.0)); step()
check('espacement minimum', not ok and msg:find('près'))
local spots = { { -1.5, 0 }, { 2.0, 0 }, { 0, 2.0 }, { 0, -2.0 }, { -1.5, -2.0 }, { 2.0, 2.0 } }
for i = 1, P.maxPerPlayer - 1 do cb('gs_drugs:plant', 1, at(spots[i][1], spots[i][2])); step() end
check('plants créés jusqu\'à la limite', count() == P.maxPerPlayer)
ok, msg = cb('gs_drugs:plant', 1, at(-1.5, 2.0)); step()
check('limite par joueur', not ok and msg:find('Maximum'))

-- Croissance
local plant = Plants.list[id]
Plants.tick()
check('sans eau : ne pousse pas, dépérit', plant.growth == 0 and plant.health < 100)
ok = cb('gs_drugs:plantAction', 1, id, 'water'); step()
check('arroser sans eau : refusé', not ok)
W.players[1].items.water = 3
ok = cb('gs_drugs:plantAction', 1, id, 'water'); step()
check('arrosé', ok and plant.water == 100 and W.players[1].items.water == 2)
ok = cb('gs_drugs:plantAction', 1, id, 'water'); step()
check('déjà humide', not ok)
W.players[1].items.fertilizer = 1
ok = cb('gs_drugs:plantAction', 1, id, 'fertilize'); step()
check('engrais', ok and plant.fert and W.players[1].items.fertilizer == 0)
Plants.tick()
check('pousse plus vite avec engrais', math.abs(plant.growth - 100 / P.growMinutes * P.fertilizerBoost) < 0.01)
ok, msg = cb('gs_drugs:plantAction', 1, id, 'harvest'); step()
check('récolte trop tôt', not ok)
plant.growth, plant.water = 99.9, 100
Plants.tick()
check('mûr : stade 3 publié', plant.growth == 100 and GlobalState.gsPlants[tostring(id)].s == 3 and GlobalState.gsPlants[tostring(id)].r)

-- Vol par un autre joueur (plant mûr)
join(2, 'CID2', 'Voleur', vec3(200.0, 200.0, 30.0))
ok = cb('gs_drugs:plantAction', 2, id, 'harvest'); step()
check('récolte à distance : refusée', not ok)
tp(2, here)
fixRandom(0.0)
ok, msg = cb('gs_drugs:plantAction', 2, id, 'harvest'); step()
check('vol de récolte : feuilles + graine, signalé', ok and W.players[2].items.weed_leaf == P.harvest.amount[1]
    and W.players[2].items.weed_seed == P.harvest.seeds[1] and reports == 1 and not Plants.list[id])
fixRandom(nil)

-- Destruction
local other = next(Plants.list)
ok, msg = cb('gs_drugs:plantAction', 2, other, 'destroy'); step()
check('un inconnu ne peut pas arracher', not ok)
police[1] = 2
ok, msg = cb('gs_drugs:plantAction', 2, other, 'destroy'); step()
check('police : saisie + prime', ok and not Plants.list[other] and W.players[2].money.bank == P.policeReward)
police[1] = nil
local mine = next(Plants.list)
ok = cb('gs_drugs:plantAction', 1, mine, 'destroy'); step()
check('le propriétaire arrache le sien', ok and not Plants.list[mine])
ok = cb('gs_drugs:plantAction', 1, mine, 'harvest'); step()
check('plant disparu', not ok)

-- Sécheresse : mort
local last = next(Plants.list)
Plants.list[last].water = 0
for _ = 1, P.dryDeathMinutes do Plants.tick() end
check('sans eau trop longtemps : mort', not Plants.list[last])

-- Vendeur de graines
W.players[1].money.cash = 1000
ok = cb('gs_drugs:buySeeds', 1, 2); step()
check('graines : trop loin', not ok)
tp(1, vec3(P.seedShop.coords.x, P.seedShop.coords.y, P.seedShop.coords.z))
ok = cb('gs_drugs:buySeeds', 1, 50); step()
check('graines : quantité bornée', not ok)
local seeds = W.players[1].items.weed_seed
ok = cb('gs_drugs:buySeeds', 1, 2); step()
check('graines achetées en liquide', ok and W.players[1].items.weed_seed == seeds + 2 and W.players[1].money.cash == 1000 - 2 * P.seedShop.price)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
