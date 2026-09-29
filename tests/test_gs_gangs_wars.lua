-- Tests guerres de territoire : déclaration (grade, quartier, effectifs, coût, cooldown), préavis, points (coup + chute
-- côté serveur, quartier, camps, cooldown victime), fin (attaquant vainqueur / défenseur), effets sur le quartier.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police = {}
provide('gs_jobs', { IsOnDutyAs = function() return false end, GetOnDutyPlayers = function() return police end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua' })
local members, money = {}, { ballas = 20000, vagos = 20000 }
Store = {
    init = function() end, gangs = function() return {} end, territories = function() return {} end, saveTerritories = function() end,
    addMoney = function(n, a) money[n] = (money[n] or 0) + a return true end,
    removeMoney = function(n, a) if (money[n] or 0) < a then return false end money[n] = money[n] - a return true end,
    money = function(n) return money[n] or 0 end,
    member = function(cid) local m = members[cid] return m and { gang = m.gang, grade = m.grade } end,
    members = function() return {} end, countMembers = function() return 0 end, setStash = function() end,
}
loadResource('gs_gangs', { R .. 'gs_gangs/server/main.lua', R .. 'gs_gangs/server/wars.lua' })
Config.DefaultGangs = {}
Gangs.init()
function DoesEntityExist() return true end
function NetworkGetEntityOwner(ent) return ent - 1000 end
function GetPlayerFromStateBagName(bag) return tonumber(bag:match('player:(%d+)')) end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local grove = Config.Territories.grove.center
local W_ = Config.Wars

Gangs.list.ballas = { label = 'Ballas', color = 27 }
Gangs.list.vagos = { label = 'Vagos', color = 46 }
local function joinGang(src, cid, gang, grade, pos)
    join(src, cid, cid, pos or grove)
    Gangs.online[src] = { cid = cid, gang = gang, grade = grade }
end
joinGang(1, 'B1', 'ballas', 3)
joinGang(2, 'B2', 'ballas', 0)
joinGang(3, 'V1', 'vagos', 3)
joinGang(4, 'V2', 'vagos', 0)
Gangs.territories.grove.owner = 'vagos'

local ok, msg = Wars.declare(2, 'grove')
check('une recrue ne déclare pas la guerre', not ok)
ok = Wars.declare(1, 'inconnu')
check('quartier inconnu', not ok)
Gangs.territories.davis.owner = 'ballas'
ok = Wars.declare(1, 'davis')
check('pas de guerre pour son propre quartier', not ok)
Gangs.territories.rancho.owner = nil
ok = Wars.declare(1, 'rancho')
check('pas de guerre pour un quartier libre', not ok)
money.ballas = 100
ok, msg = Wars.declare(1, 'grove')
check('caisse insuffisante', not ok and msg:find('caisse'))
money.ballas = 20000
Gangs.online[4] = nil
Gangs.online[3] = nil
ok, msg = Wars.declare(1, 'grove')
check('personne en face', not ok)
Gangs.online[3] = { cid = 'V1', gang = 'vagos', grade = 3 }
Gangs.online[4] = { cid = 'V2', gang = 'vagos', grade = 0 }
Gangs.online[2] = nil
ok = Wars.declare(1, 'grove')
check('pas assez de membres pour attaquer', not ok)
Gangs.online[2] = { cid = 'B2', gang = 'ballas', grade = 0 }
police[1] = 9
join(9, 'P9', 'Agent', grove)
ok, msg = Wars.declare(1, 'grove')
check('guerre déclarée : frais prélevés, police prévenue', ok and money.ballas == 20000 - W_.cost and Wars.list.grove and W.notes[9] ~= nil)
check('publié pour les clients', GlobalState.gsWars.grove and GlobalState.gsWars.grove.attacker == 'Ballas' and not GlobalState.gsWars.grove.started)
ok = Wars.declare(1, 'grove')
check('pas de seconde guerre en même temps', not ok)

-- Coups avant le début : ne comptent pas
local function hitAndDown(attacker, victim)
    TriggerEvent('weaponDamageEvent', attacker, { hitGlobalId = 1000 + victim })
    W.sbh['qbx_medical:deathState']('player:' .. victim, 'qbx_medical:deathState', 2)
end
hitAndDown(2, 4)
check('préavis : aucun point', (Wars.list.grove.score.ballas or 0) == 0)

advance(W_.notice * 1000 + 1000)
-- os.time() n'est pas simulé : on recale la guerre dans le présent
Wars.list.grove.startsAt, Wars.list.grove.endsAt = os.time() - 5, os.time() + 600
Wars.victimAt = {}
hitAndDown(2, 4)
check('chute d\'un adversaire dans le quartier = points', Wars.list.grove.score.ballas == W_.killPoints)
hitAndDown(2, 4)
check('même victime : cooldown', Wars.list.grove.score.ballas == W_.killPoints)
Wars.victimAt = {}
hitAndDown(1, 2)
check('tir ami : rien', Wars.list.grove.score.ballas == W_.killPoints and (Wars.list.grove.score.vagos or 0) == 0)
Wars.victimAt = {}
Wars.lastHit[4] = { attacker = 2, at = os.time() - W_.hitWindow - 5 }
W.sbh['qbx_medical:deathState']('player:4', 'k', 2)
check('chute sans coup récent : rien', Wars.list.grove.score.ballas == W_.killPoints)
-- Hors quartier
W.players[4].pos = vec3(5000.0, 5000.0, 0.0)
hitAndDown(2, 4)
check('hors du quartier : rien', Wars.list.grove.score.ballas == W_.killPoints)
W.players[4].pos = grove
-- Un tiers ne compte pas
joinGang(6, 'F1', 'families', 1)
Gangs.list.families = { label = 'Families', color = 25 }
Wars.victimAt = {}
hitAndDown(6, 4)
check('un gang tiers ne marque pas', Wars.list.grove.score.ballas == W_.killPoints and (Wars.list.grove.score.families or 0) == 0)
Wars.victimAt = {}
hitAndDown(3, 2)
check('les défenseurs marquent aussi', Wars.list.grove.score.vagos == W_.killPoints)
Wars.victimAt = {}
Wars.list.grove.score.vagos = 0
hitAndDown(2, 4) hitAndDown(1, 3)

-- Fin : attaquant vainqueur (6 – 0 ≥ marge 3)
Wars.list.grove.endsAt = os.time() - 1
Wars.tick()
check('fin : guerre retirée', Wars.list.grove == nil and GlobalState.gsWars.grove == nil)
check('l\'attaquant prend le quartier', Gangs.territories.grove.owner == 'ballas')
ok = Wars.declare(1, 'davis')
check('cooldown de l\'attaquant', not ok)

-- Défenseur qui tient : score égal
Gangs.territories.grove.owner = 'vagos'
Wars.cool = {}
ok = Wars.declare(1, 'grove')
check('nouvelle guerre possible après le cooldown', ok)
Wars.list.grove.startsAt, Wars.list.grove.endsAt = os.time() - 5, os.time() - 1
Wars.tick()
check('égalité : le défenseur garde le quartier', Gangs.territories.grove.owner == 'vagos')
check('répit du défenseur', (Wars.cool.vagos or 0) > os.time())

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
