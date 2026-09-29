-- Tests gs_harvest : récolte (outil, point, durée réelle, butin, casse d'outil), chasse (gibier du serveur seulement,
-- mort, couteau, distance), revente (acheteur, distance, tout l'inventaire concerné), repeuplement de la zone.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local crimes = {}
provide('gs_wanted', { ReportCrime = function(_, t) crimes[#crimes + 1] = t return true end })
loadResource('gs_harvest', { R .. 'gs_harvest/shared/config.lua', R .. 'gs_harvest/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local mine = Config.Activities.mining

join(1, 'CID1', 'Mineur', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_harvest:begin', 1, 'mining'); step()
check('trop loin du point', not ok)
tp(1, mine.spots[2])
ok, msg = cb('gs_harvest:begin', 1, 'mining'); step()
check('sans pioche : refusé', not ok and msg:find('pickaxe'))
W.players[1].items.pickaxe = 1
ok = cb('gs_harvest:begin', 1, 'inconnu'); step()
check('activité inconnue', not ok)
ok, msg = cb('gs_harvest:begin', 1, 'mining')
check('début : durée renvoyée', ok and msg >= mine.duration[1])
ok = cb('gs_harvest:finish', 1)
check('fin trop tôt : refusée', not ok and not Harvest.pending[1])
cb('gs_harvest:begin', 1, 'mining'); advance(mine.duration[2])
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_harvest:finish', 1); step()
check('éloigné pendant la récolte', not ok)
tp(1, mine.spots[2])
fixRandom(0.0)
cb('gs_harvest:begin', 1, 'mining'); advance(mine.duration[2])
ok, msg = cb('gs_harvest:finish', 1); step()
check('butin : pierre + outil cassé (tirage 0)', ok and W.players[1].items.stone == mine.loot[1][3][1] and W.players[1].items.pickaxe == 0 and msg:find('cassé'))
fixRandom(0.99)
W.players[1].items.pickaxe = 1
cb('gs_harvest:begin', 1, 'mining'); advance(mine.duration[2])
ok = cb('gs_harvest:finish', 1); step()
check('butin rare (or), outil intact', ok and (W.players[1].items.gold_ore or 0) >= 1 and W.players[1].items.pickaxe == 1)
fixRandom(nil)

-- Ferme : sans outil
local farm = Config.Activities.farming
tp(1, farm.spots[1])
ok = cb('gs_harvest:begin', 1, 'farming'); advance(farm.duration[2])
local ok2 = cb('gs_harvest:finish', 1); step()
check('ferme : pas d\'outil requis', ok and ok2)

-- Chasse
local H = Config.Hunting
W.nextEntity = W.nextEntity + 1
local deer = W.nextEntity
W.entities[deer] = { type = 1, pos = vec3(-600.0, 5000.0, 140.0), health = 200 }
Harvest.animals[deer] = 'a_c_deer'
W.nextEntity = W.nextEntity + 1
local wild = W.nextEntity
W.entities[wild] = { type = 1, pos = vec3(-600.0, 5000.0, 140.0), health = 0 }
tp(1, vec3(-600.0, 5001.0, 140.0))
ok, msg = cb('gs_harvest:skin', 1, deer); step()
check('dépecer un animal vivant : refusé', not ok and msg:find('vivant'))
W.entities[deer].health = 0
ok = cb('gs_harvest:skin', 1, wild); step()
check('animal hors zone de chasse : refusé', not ok)
ok, msg = cb('gs_harvest:skin', 1, deer); step()
check('sans couteau : refusé', not ok and msg:find('couteau'))
W.players[1].items.huntingknife = 1
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_harvest:skin', 1, deer); step()
check('dépecer à distance : refusé', not ok)
tp(1, vec3(-600.0, 5001.0, 140.0))
ok = cb('gs_harvest:skin', 1, deer); step()
check('dépecé : viande + cuir, carcasse supprimée', ok and W.players[1].items.meat >= 2 and W.players[1].items.leather == 1 and not W.entities[deer] and not Harvest.animals[deer])

-- Repeuplement : seulement si un joueur est dans le coin, jusqu'au max
local spawned = 0
Harvest.spawnAnimal = function(model) spawned = spawned + 1 W.nextEntity = W.nextEntity + 1 W.entities[W.nextEntity] = { type = 1, pos = H.center } Harvest.animals[W.nextEntity] = model end
tp(1, vec3(0.0, 0.0, 0.0))
Harvest.huntTick()
check('personne dans la zone : pas d\'animal créé', spawned == 0)
tp(1, H.center)
for _ = 1, H.max + 3 do Harvest.huntTick() end
check('zone repeuplée jusqu\'au max', spawned == H.max)

-- Revente
local fonderie = Config.Buyers[2]
ok = cb('gs_harvest:sell', 1, 2); step()
check('revente à distance : refusée', not ok)
tp(1, fonderie.coords)
local cash = W.players[1].money.cash
W.players[1].items.iron_ore = 3
ok, msg = cb('gs_harvest:sell', 1, 2); step()
check('revente : pierre, fer, or vendus', ok and W.players[1].items.stone == 0 and W.players[1].items.iron_ore == 0 and W.players[1].money.cash > cash)
ok = cb('gs_harvest:sell', 1, 2); step()
check('plus rien à vendre', not ok)
ok = cb('gs_harvest:sell', 1, 99); step()
check('acheteur inconnu', not ok)

check('dépecer sans permis = braconnage signalé', crimes[1] == 'poaching')

-- Permis de chasse au pavillon
W.players[1].money.cash, W.players[1].money.bank = 0, 0
ok = cb('gs_harvest:buyLicence', 1); step()
check('permis : trop loin', not ok)
tp(1, H.lodge)
ok, msg = cb('gs_harvest:buyLicence', 1); step()
check('permis : pas assez d\'argent', not ok and msg:find('%$'))
W.players[1].money.bank = 1000
ok = cb('gs_harvest:buyLicence', 1); step()
check('permis acheté (banque)', ok and W.players[1].licences.hunting and W.players[1].money.bank == 1000 - H.licencePrice)
ok = cb('gs_harvest:buyLicence', 1); step()
check('déjà titulaire', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
