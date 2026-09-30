-- Tests gs_races : départ (ligne, volant), chrono solo, points dans l'ordre (position, vitesse crédible), record personnel,
-- course à mise (cagnotte, barème, remboursement si < 2 pilotes ou hors ligne), abandon, classement.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local reports = 0
provide('gs_social', { GetHandle = function() return nil end, Newsroom = function() return true end })
provide('gs_wanted', { ReportCrime = function() reports = reports + 1 return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_races', { R .. 'gs_races/shared/config.lua' })
local best, times = {}, {}
Store = {
    init = function() end,
    record = function(c, cid, name, ms) local k = c .. cid if best[k] and best[k] <= ms then return false end best[k] = ms times[c] = times[c] or {} times[c][cid] = { name = name, ms = ms } return true end,
    top = function(c) local l = {} for _, r in pairs(times[c] or {}) do l[#l + 1] = r end table.sort(l, function(a, b) return a.ms < b.ms end) return l end,
}
function GetPedInVehicleSeat(veh, seat) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end
loadResource('gs_races', { R .. 'gs_races/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local C = Config.Circuits.sprint
local pts = C.points

local function driver(src, cid, pos)
    join(src, cid, cid .. ' Pilote', pos)
    local veh = CreateVehicleServerSetter(0, 'automobile', pos.x, pos.y, pos.z)
    W.entities[veh].driver = src
    W.players[src].vehicle = veh
    return veh
end
local function drive(src, pos) tp(src, pos) end
local function runAll(src, seconds)
    for i = 2, #pts do
        advance((seconds * 1000) / (#pts - 1))
        drive(src, pts[i])
        local ok, idx, res = cb('gs_races:checkpoint', src); advance(6000)
        if i == #pts then return ok, res end
    end
end

driver(1, 'CID1', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_races:start', 1, 'sprint', 'solo'); step()
check('loin de la ligne : refusé', not ok)
tp(1, pts[1])
ok = cb('gs_races:start', 1, 'inconnu', 'solo'); step()
check('circuit inconnu', not ok)
ok = cb('gs_races:start', 1, 'sprint', 'nimporte'); step()
check('mode inconnu', not ok)
W.players[1].vehicle = nil
ok = cb('gs_races:start', 1, 'sprint', 'solo'); step()
check('à pied : refusé', not ok)
local veh1 = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.players[1].vehicle = veh1
W.entities[veh1].driver = 2 -- passager
ok = cb('gs_races:start', 1, 'sprint', 'solo'); step()
check('passager : refusé', not ok)
W.entities[veh1].driver = 1

ok = cb('gs_races:start', 1, 'sprint', 'solo')
check('chrono solo lancé', ok and Races.runs[1] and Races.runs[1].lobby.solo)
ok = cb('gs_races:checkpoint', 1)
check('avant le départ : rien', not ok)
advance((Config.Countdown + 1) * 1000)
drive(1, pts[4])
ok = cb('gs_races:checkpoint', 1); advance(6000)
check('sauter des points : refusé', not ok)
drive(1, pts[2])
ok = cb('gs_races:checkpoint', 1)
check('point 2 validé', ok and Races.runs[1].cp == 2)
drive(1, pts[3]) advance(100) -- 250 m en 0,1 s : téléportation
ok = cb('gs_races:checkpoint', 1)
check('trajet impossible : course annulée', not ok and Races.runs[1] == nil)
step() step()

-- Chrono valide (les distances entre points sont longues : 20 min de jeu suffisent)
Races.solo[1] = nil
tp(1, pts[1])
cb('gs_races:start', 1, 'sprint', 'solo'); advance((Config.Countdown + 1) * 1000)
local fin
ok, fin = runAll(1, 400)
check('arrivée : temps enregistré', ok and fin and fin.ms >= 390000 and best['sprintCID1'] == fin.ms)
check('classement : nom affiché sans nom complet', times.sprint.CID1.name:find('Pilote') or times.sprint.CID1.name:find('CID1'))
local t1 = fin.ms

-- Record personnel seulement si meilleur
Races.solo[1] = nil
tp(1, pts[1])
cb('gs_races:start', 1, 'sprint', 'solo'); advance((Config.Countdown + 1) * 1000)
ok, fin = runAll(1, 800)
check('temps moins bon : pas de record', ok and best['sprintCID1'] == t1)

-- Course à mise
local v2 = driver(2, 'CID2', pts[1]); W.players[2].money.cash = 2000
local v3 = driver(3, 'CID3', pts[1]); W.players[3].money.cash = 2000
join(4, 'CID4', 'Fauché', pts[1]); W.players[4].vehicle = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[W.players[4].vehicle].driver = 4
ok = cb('gs_races:start', 4, 'sprint', 'group'); step()
check('mise : pas assez de liquide', not ok)
tp(1, vec3(0.0, 0.0, 0.0))
fixRandom(0.0)
ok = cb('gs_races:start', 2, 'sprint', 'group'); step()
fixRandom(nil)
check('inscription : mise prélevée, police alertée', ok and W.players[2].money.cash == 2000 - Config.Entry and reports == 1)
ok = cb('gs_races:start', 3, 'sprint', 'group'); step()
local lobby = Races.runs[2].lobby
check('2e pilote rejoint le même lobby, cagnotte', ok and #lobby.players == 2 and lobby.pot == 2 * Config.Entry)
Races.tick()
check('avant l\'échéance : pas de départ', lobby.state == 'open')
lobby.startAt = os.time() - 1
Races.tick()
check('départ à 2 pilotes', lobby.state == 'running' and Races.runs[2].cp == 1)
advance((Config.Countdown + 1) * 1000)
local ok2, res2 = runAll(2, 300)
check('1er : 70 % de 90 % de la cagnotte', ok2 and res2.position == 1 and res2.prize == math.floor(2 * Config.Entry * Config.PotKeep * 0.7)
    and W.players[2].money.cash == 2000 - Config.Entry + res2.prize)
local ok3, res3 = runAll(3, 340)
check('2e : 30 %', ok3 and res3.position == 2 and res3.prize == math.floor(2 * Config.Entry * Config.PotKeep * 0.3))
check('lobby fini : nettoyé', next(Races.lobbies) == nil)

-- Un seul inscrit : remboursé
tp(2, pts[1]) W.players[2].money.cash = 1000
cb('gs_races:start', 2, 'sprint', 'group'); step()
Races.lobbies[next(Races.lobbies)].startAt = os.time() - 1
Races.tick()
check('un seul pilote : remboursé, course annulée', W.players[2].money.cash == 1000 and next(Races.lobbies) == nil and Races.runs[2] == nil)

-- Inscrit parti de la ligne : remboursé, l'autre aussi (moins de 2)
tp(2, pts[1]) tp(3, pts[1]) W.players[2].money.cash, W.players[3].money.cash = 1000, 1000
cb('gs_races:start', 2, 'sprint', 'group'); step()
cb('gs_races:start', 3, 'sprint', 'group'); step()
tp(3, vec3(50.0, 50.0, 0.0))
Races.lobbies[next(Races.lobbies)].startAt = os.time() - 1
Races.tick()
check('pilote hors ligne : mises remboursées', W.players[2].money.cash == 1000 and W.players[3].money.cash == 1000 and next(Races.lobbies) == nil)

-- Abandon avant le départ : remboursé
tp(2, pts[1])
cb('gs_races:start', 2, 'sprint', 'group'); step()
ok = cb('gs_races:cancel', 2); step()
check('abandon avant départ : remboursé', ok and W.players[2].money.cash == 1000 and next(Races.lobbies) == nil)

-- Classement
local top = getExport('gs_races', 'GetTop')(3)
check('classement Vibe : temps formatés', top[1].id and #top >= 1)
local list = cb('gs_races:list', 1)
check('menu : circuits avec meilleurs temps', list and #list.circuits == 3)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
