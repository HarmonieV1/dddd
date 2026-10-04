-- Tests gs_fightclub (V9) : ring du jour, inscription et mise, paris mutuels, arbitrage (K.-O., arme, sortie, forfait,
-- temps écoulé), part de la maison, remboursements.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local hour = 12
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end })
loadResource('gs_fightclub', { R .. 'gs_fightclub/shared/config.lua', R .. 'gs_fightclub/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end

check('fermé en journée', FightClub.isOpen() == false)
hour = 23
check('ouvert la nuit', FightClub.isOpen() == true)
local ring = FightClub.ring()
check('un ring du jour parmi la liste', ring and ring.coords and ring.hint)
local c = ring.coords
join(1, 'CID1', 'Rocky', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Apollo', c)
join(3, 'CID3', 'Parieur', vec3(c.x + 5.0, c.y, c.z))
join(4, 'CID4', 'Parieuse', vec3(c.x + 6.0, c.y, c.z))
for i = 1, 4 do W.players[i].money.cash = 20000 W.entities[1000 + i] = { health = 200 } end
local events = {}
local tce = TriggerClientEvent
TriggerClientEvent = function(name, src, ...) events[#events + 1] = { name = name, src = src, args = { ... } } return tce(name, src, ...) end

local ok = cb('gs_fightclub:join', 1, 1000); step()
check('loin du ring : pas d\'inscription', not ok)
FightClub.scan()
local revealed = {}
for _, e in ipairs(events) do if e.name == 'gs_fightclub:client:ring' and e.args[1] then revealed[e.src] = true end end
check('adresse révélée seulement aux joueurs sur place', revealed[2] and revealed[3] and not revealed[1])
tp(1, vec3(c.x + 1.0, c.y, c.z))
ok = cb('gs_fightclub:join', 1, 777); step()
check('mise hors barème refusée', not ok)
ok = cb('gs_fightclub:join', 1, 1000); step()
check('premier combattant inscrit, mise prélevée', ok and W.players[1].money.cash == 19000 and FightClub.match.phase == 'waiting')
ok = cb('gs_fightclub:bet', 3, 'a', 500); step()
check('pas de pari sans adversaire', not ok)
ok = cb('gs_fightclub:join', 2, 5000); step()
check('le second s\'aligne sur la mise du premier', ok and W.players[2].money.cash == 19000 and FightClub.match.phase == 'betting')
ok = cb('gs_fightclub:bet', 1, 'a', 500); step()
check('un combattant ne parie pas', not ok)
ok = cb('gs_fightclub:bet', 3, 'a', 50); step()
check('pari trop petit', not ok)
ok = cb('gs_fightclub:bet', 3, 'a', 1000); step()
ok = cb('gs_fightclub:bet', 4, 'b', 3000) and ok; step()
check('paris pris', ok and W.players[3].money.cash == 19000 and W.players[4].money.cash == 17000)
ok = cb('gs_fightclub:bet', 3, 'b', 1000); step()
check('un seul pari par personne', not ok)
FightClub.match.at = os.time() - Config.Bet.window
FightClub.tick()
check('fenêtre de paris close : combat lancé', FightClub.match.phase == 'fight')
FightClub.tick()
check('personne au tapis : le combat continue', FightClub.match ~= nil)
W.entities[1001].health = 100
FightClub.tick()
-- B gagne : bourse 2 000 × 0,9 = 1 800 ; cagnotte 4 000 × 0,9 = 3 600 pour le seul parieur de B
check('K.-O. : le vainqueur touche la bourse moins la maison', FightClub.match == nil and W.players[2].money.cash == 19000 + 1800)
check('paris mutuels : le gagnant rafle la cagnotte', W.players[4].money.cash == 17000 + 3600 and W.players[3].money.cash == 19000)

-- Arme sortie = disqualifié
W.entities[1001].health = 200
cb('gs_fightclub:join', 1, 500); step()
cb('gs_fightclub:join', 2, 500); step()
FightClub.match.at = os.time() - Config.Bet.window FightClub.tick()
local before1 = W.players[1].money.cash
W.players[2].weapon = joaat('WEAPON_PISTOL')
FightClub.tick()
check('arme sortie : disqualifié, l\'autre gagne', FightClub.match == nil and W.players[1].money.cash == before1 + 900)
W.players[2].weapon = nil

-- Sortie du ring
cb('gs_fightclub:join', 1, 500); step()
cb('gs_fightclub:join', 2, 500); step()
cb('gs_fightclub:bet', 3, 'a', 200); step()
FightClub.match.at = os.time() - Config.Bet.window FightClub.tick()
tp(2, vec3(c.x + Config.Radius + 3.0, c.y, c.z))
local before3 = W.players[3].money.cash
FightClub.tick()
check('sorti du ring : perdu ; seul parieur gagnant récupère la cagnotte moins la maison', FightClub.match == nil and W.players[3].money.cash == before3 + 180)
tp(2, c)

-- Temps écoulé : tout est rendu
local cash = { W.players[1].money.cash, W.players[2].money.cash, W.players[4].money.cash }
cb('gs_fightclub:join', 1, 2500); step()
cb('gs_fightclub:join', 2, 2500); step()
cb('gs_fightclub:bet', 4, 'b', 1000); step()
FightClub.match.at = os.time() - Config.Bet.window FightClub.tick()
FightClub.match.at = os.time() - Config.MaxDuration
FightClub.tick()
check('match nul : mises et paris rendus', FightClub.match == nil and W.players[1].money.cash == cash[1] and W.players[2].money.cash == cash[2] and W.players[4].money.cash == cash[3])

-- Annulation et forfait
cb('gs_fightclub:join', 1, 500); step()
ok = cb('gs_fightclub:leave', 2); step()
check('seul l\'inscrit peut annuler', not ok)
ok = cb('gs_fightclub:leave', 1); step()
check('annulation : mise rendue', ok and FightClub.match == nil and W.players[1].money.cash == cash[1])
cb('gs_fightclub:join', 1, 500); step()
cb('gs_fightclub:join', 2, 500); step()
local before2 = W.players[2].money.cash
W.players[1] = nil
FightClub.tick()
check('combattant déconnecté : forfait', FightClub.match == nil and W.players[2].money.cash == before2 + 900)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
