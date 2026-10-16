-- Tests gs_world : vols Cayo Perico (comptoir, véhicule, paiement, destination).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local staffLevel = {}
provide('gs_admin', { GetStaffLevel = function(src) return staffLevel[src] or 0 end })
local heat, cooled = {}, {}
provide('gs_wanted', { GetHeat = function(src) return heat[src] or 0 end, CoolHeat = function(src, n) cooled[src] = (cooled[src] or 0) + n end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
SetResourceKvp('gs_world:islandChoice', 'cayo') -- vols de Cayo testés d'abord (V12.63 : sinon l'alternance du jour décide)
loadResource('gs_world', { R .. 'gs_world/shared/config.lua', R .. 'gs_world/server/main.lua' })
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local F = Config.Island.flight

join(1, 'CID1', 'Voyageur', vec3(0.0, 0.0, 0.0))
local ok = cb('gs_world:fly', 1, 'mainland'); step()
check('loin du comptoir', not ok)
tp(1, F.mainland.counter)
ok = cb('gs_world:fly', 1, 'lune'); step()
check('vol inconnu', not ok)
F.price = 350 -- tarif testé, même si le vol est gratuit par défaut
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('sans argent', not ok and W.players[1].pos == F.mainland.counter)
W.players[1].money.bank = 1000
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('V12.40 : pas de carte bancaire pour Cayo', not ok and W.players[1].money.bank == 1000)
W.players[1].items.black_money = 400
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('V12.40 : argent sale accepté', ok and W.players[1].items.black_money == 400 - F.price and W.players[1].money.bank == 1000)
tp(1, F.mainland.counter)
W.players[1].money.cash = 1000
W.players[1].vehicle = 5
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('en véhicule : refusé', not ok)
W.players[1].vehicle = nil
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('arrivée sur l\'île, billet payé en liquide', ok and W.players[1].money.cash == 1000 - F.price and W.players[1].money.bank == 1000 and #(W.players[1].pos - F.island.arrival) < 1)
tp(1, F.island.counter)
ok = cb('gs_world:fly', 1, 'island'); step()
check('retour à LS', ok and #(W.players[1].pos - F.mainland.arrival) < 1)
F.price = 0
W.players[1].money.bank = 0
tp(1, F.mainland.counter)
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('vol gratuit (accès libre)', ok and #(W.players[1].pos - F.island.arrival) < 1)

-- V12.63 · Journée North Yankton (n° 191) -----------------------------------------------------------------------------
local Y = Config.Yankton
check('démarrage : destination choisie par le staff (Cayo)', GlobalState.gsIslandMode == 'cayo')
local function localMidnight(t) local d = os.date('*t', t) return t - d.hour * 3600 - d.min * 60 - d.sec end
local noon = localMidnight(1792152000) + 12 * 3600 -- un jour d'octobre 2026, midi (heure du serveur)
local tomorrow = localMidnight(noon + 86400)
check('alternance : un jour Cayo, le lendemain North Yankton', World.autoMode(noon) ~= World.autoMode(noon + 86400))
check('le jour de jeu commence à 6 h (5 h 59 = encore la veille)', World.autoMode(tomorrow + 5 * 3600 + 59 * 60) == World.autoMode(noon)
    and World.autoMode(tomorrow + 6 * 3600 + 60) == World.autoMode(noon + 86400))
Y.alternate = false
check('alternance coupée : Cayo tous les jours', World.autoMode(noon) == 'cayo' and World.autoMode(noon + 86400) == 'cayo')
Y.alternate = true

join(2, 'CID2', 'Sur Cayo', vec3(4500.0, -4520.0, 5.0))
join(3, 'CID3', 'En ville', vec3(200.0, -800.0, 30.0))
join(4, 'CID4', 'Admin', vec3(0.0, 0.0, 0.0))
check('joueur : choix refusé', not cb('gs_world:setIslandMode', 3, 'yankton') and cb('gs_world:islandInfo', 3) == nil)
step()
staffLevel[4] = Y.staffLevel
tp(1, F.mainland.counter) -- le voyageur des tests de Cayo est rentré
W.clientEvents = {}
local okm, msg = cb('gs_world:setIslandMode', 4, 'yankton'); step()
check('staff : North Yankton forcé, choix gardé', okm and GlobalState.gsIslandMode == 'yankton' and GetResourceKvpString('gs_world:islandChoice') == 'yankton' and msg:find('North Yankton'))
check('joueur sur l\'île rapatrié avant la bascule, celui en ville non', lastClientEvent('gs_world:client:evacuate', 2) ~= nil and lastClientEvent('gs_world:client:evacuate', 3) == nil and msg:find('1 joueur'))
check('tout le monde est prévenu', lastClientEvent('ox_lib:notify', -1) ~= nil)
local info = cb('gs_world:islandInfo', 4); step()
check('infos staff : destination et demain', info and info.mode == 'yankton' and info.choice == 'yankton' and (info.tomorrow == 'cayo' or info.tomorrow == 'yankton'))
check('soirée plage de Cayo refusée un jour North Yankton', World.party(600) == false and GlobalState.gsCayoParty == nil)

tp(1, F.mainland.counter)
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('vol du jour : arrivée à North Yankton', ok and #(W.players[1].pos - Y.flight.island.arrival) < 1)
tp(1, F.island.counter)
ok = cb('gs_world:fly', 1, 'island'); step()
check('comptoir de Cayo fermé un jour North Yankton', not ok)
tp(1, Y.flight.island.counter)
ok = cb('gs_world:fly', 1, 'island'); step()
check('retour de North Yankton à LS', ok and #(W.players[1].pos - F.mainland.arrival) < 1)

okm = cb('gs_world:setIslandMode', 4, 'auto'); step()
check('alternance remise : destination du jour', okm and World.choice() == 'auto' and GlobalState.gsIslandMode == World.autoMode())
okm = cb('gs_world:setIslandMode', 4, 'cayo'); step()
check('retour à Cayo : soirée plage possible', okm and GlobalState.gsIslandMode == 'cayo' and World.party(600) == true and GlobalState.gsCayoParty ~= nil)
World.party(0)
check('choix inconnu refusé', not cb('gs_world:setIslandMode', 4, 'lune'))

-- Sur place : café de Ludendorff et « se mettre au vert » (jours North Yankton seulement)
do
    local C = Y.cafe
    join(6, 'CID6', 'Frileux', C.coords)
    W.players[6].money.cash = 20
    GlobalState.gsIslandMode = 'cayo'
    check('café fermé un jour Cayo', not cb('gs_world:cafe', 6, 1))
    step()
    GlobalState.gsIslandMode = 'yankton'
    local okc = cb('gs_world:cafe', 6, 1); step()
    check('café : boisson chaude payée en liquide', okc and W.players[6].items[C.items[1].item] == 1 and W.players[6].money.cash == 20 - C.items[1].price)
    heat[6] = 40
    heat[3] = 40 -- en ville : rien
    check('se mettre au vert : seulement les recherchés sur place', World.coolOff() == 1 and cooled[6] == Y.coolPerMinute and cooled[3] == nil)
    GlobalState.gsIslandMode = 'cayo'
    check('jour Cayo : pas de mise au vert', World.coolOff() == 0)
end

-- Déconnecté sur l'île, revenu le jour de l'autre île : reprise à l'aéroport (pas dans le ciel de Cayo / sous North Yankton)
tp(1, F.mainland.counter)
ok = cb('gs_world:fly', 1, 'mainland'); step()
check('séjour noté : Cayo', ok and GetResourceKvpString('gs_world:trip:CID1') == 'cayo')
World.trips = {} -- comme après un redémarrage
SetResourceKvp('gs_world:islandChoice', 'yankton') GlobalState.gsIslandMode = 'yankton'
W.clientEvents = {}
TriggerEvent('gs_bridge:server:playerLoaded', 1)
local evac = 0
for _, e in ipairs(W.clientEvents) do if e.name == 'gs_world:client:evacuate' and e.target == 1 then evac = evac + 1 end end
check('revenu un jour North Yankton : ramené à l\'aéroport (une seule fois)', evac == 1)
join(5, 'CID5', 'Venu en bateau', vec3(3400.0, -4800.0, 110.0))
W.clientEvents = {}
World.track(5)
check('arrivé sans le vol (bateau) : séjour noté, pas rapatrié', GetResourceKvpString('gs_world:trip:CID5') == 'yankton' and lastClientEvent('gs_world:client:evacuate', 5) == nil)
World.track(5)
check('même île : jamais rapatrié', lastClientEvent('gs_world:client:evacuate', 5) == nil)
tp(5, vec3(200.0, -800.0, 30.0))
World.loadedAt[5] = os.time()
World.track(5)
check('hors de l\'île juste après la connexion : séjour gardé (choix du point d\'apparition)', GetResourceKvpString('gs_world:trip:CID5') == 'yankton')
World.loadedAt[5] = os.time() - 700
World.track(5)
check('hors de l\'île ensuite : séjour terminé', GetResourceKvpString('gs_world:trip:CID5') == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
