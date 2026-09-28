-- Tests gs_gangs : création staff, recrutement avec consentement, hiérarchie, caisse, territoires (influence,
-- police, déclin, prise de contrôle), chaleur de quartier, racket.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return job == 'police' and duty[src] == true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua' })
local gangs, members, money = {}, {}, {}
Store = {
    init = function() end, gangs = function() return {} end, territories = function() return {} end, saveTerritories = function() end,
    createGang = function(n, l, c) if gangs[n] then return false end gangs[n] = { label = l, color = c } money[n] = 0 return true end,
    deleteGang = function(n) gangs[n] = nil for cid, m in pairs(members) do if m.gang == n then members[cid] = nil end end end,
    setStash = function() end,
    addMoney = function(n, a) money[n] = (money[n] or 0) + a return true end,
    removeMoney = function(n, a) if (money[n] or 0) < a then return false end money[n] = money[n] - a return true end,
    money = function(n) return money[n] or 0 end,
    member = function(cid) local m = members[cid] return m and { gang = m.gang, grade = m.grade } end,
    members = function(g) local l = {} for cid, m in pairs(members) do if m.gang == g then l[#l + 1] = { citizenid = cid, grade = m.grade, name = m.name } end end return l end,
    countMembers = function(g) local n = 0 for _, m in pairs(members) do if m.gang == g then n = n + 1 end end return n end,
    addMember = function(cid, g, grade, name) if members[cid] then return false end members[cid] = { gang = g, grade = grade, name = name } return true end,
    setGrade = function(cid, grade) members[cid].grade = grade end,
    removeMember = function(cid) local had = members[cid] ~= nil members[cid] = nil return had end,
}
loadResource('gs_gangs', { R .. 'gs_gangs/server/main.lua' })
Gangs.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end
local grove = Config.Territories.grove.center
local far = vec3(5000.0, 5000.0, 0.0)

join(1, 'CID1', 'Chef Ballas', grove)
join(2, 'CID2', 'Recrue Un', grove)
join(3, 'CID3', 'Chef Vagos', far)
join(4, 'CID4', 'Agent LSPD', far)
join(5, 'CID5', 'Bras Droit', grove)

-- Création staff ----------------------------------------------------------------------------------------
W.commands.gsgang(0, { action = 'create', a = 'ballas', b = '27', c = 'Ballas' })
W.commands.gsgang(0, { action = 'create', a = 'vagos', b = '46', c = 'Los Vagos' })
check('gangs créés', Gangs.list.ballas and Gangs.list.vagos)
W.commands.gsgang(0, { action = 'create', a = 'ballas', b = '1', c = 'Doublon' })
check('nom unique', Gangs.list.ballas.label == 'Ballas')
W.commands.gsgang(0, { action = 'create', a = 'nom invalide', b = '1', c = 'X' })
check('nom invalide refusé', Gangs.list['nom invalide'] == nil)
W.commands.gsgang(0, { action = 'add', a = '1', b = 'ballas', c = '3' })
W.commands.gsgang(0, { action = 'add', a = '3', b = 'vagos', c = '3' })
W.commands.gsgang(0, { action = 'add', a = '5', b = 'ballas', c = '2' })
check('chefs ajoutés + gang framework synchronisé', Gangs.online[1].grade == 3 and W.players[1].gang.name == 'ballas')

-- Recrutement --------------------------------------------------------------------------------------------
local ok = cb('gs_gangs:invite', 2, 1)
check('une recrue sans gang ne recrute pas', not ok)
step()
ok = cb('gs_gangs:invite', 1, 2)
check('proposition envoyée', ok and lastClientEvent('gs_gangs:client:invite', 2) ~= nil)
net('gs_gangs:server:answer', 2, true)
check('recrue ajoutée au grade 0', Gangs.online[2].gang == 'ballas' and Gangs.online[2].grade == 0)
step()
ok = cb('gs_gangs:invite', 3, 2)
check('déjà dans un gang', not ok)
step()

-- Hiérarchie -----------------------------------------------------------------------------------------------
ok = cb('gs_gangs:manage', 5, 'kick', 'CID1')
check('bras droit ne peut pas exclure le chef', not ok and Gangs.online[1].gang == 'ballas')
step()
ok = cb('gs_gangs:manage', 5, 'grade', 'CID2', 2)
check('bras droit ne peut pas nommer à son grade', not ok)
step()
ok = cb('gs_gangs:manage', 5, 'grade', 'CID2', 1)
check('bras droit promeut la recrue', ok and Gangs.online[2].grade == 1)
step()
ok = cb('gs_gangs:manage', 3, 'kick', 'CID2')
check('chef d\'un autre gang : refusé', not ok)
step()
net('gs_gangs:server:leave', 1)
check('le chef ne peut pas quitter', Gangs.online[1].gang == 'ballas')
step()

-- Caisse -----------------------------------------------------------------------------------------------------
W.players[2].money.cash = 500
ok = cb('gs_gangs:bank', 2, 'deposit', 300)
check('dépôt par un membre', ok and money.ballas == 300 and W.players[2].money.cash == 200)
step()
ok = cb('gs_gangs:bank', 2, 'withdraw', 100)
check('retrait réservé au chef', not ok and money.ballas == 300)
step()
ok = cb('gs_gangs:bank', 1, 'withdraw', 1000)
check('retrait > caisse refusé', not ok)
step()
ok = cb('gs_gangs:bank', 1, 'withdraw', 100)
check('retrait par le chef', ok and money.ballas == 200 and W.players[1].money.cash == 100)
step()
ok = cb('gs_gangs:bank', 1, 'withdraw', -50)
check('montant négatif refusé', not ok)
step()

-- Territoires ----------------------------------------------------------------------------------------------------
-- 3 Ballas à Grove : +3 par tick (plafond 4)
for _ = 1, 16 do Gangs.tick() end
local t = Gangs.territories.grove
check('influence par présence', t.influence.ballas == 48)
check('pas encore propriétaire sous le seuil', t.owner == nil)
Gangs.tick()
check('Ballas prennent Grove', t.owner == 'ballas' and GlobalState.gsTerritories.grove.owner == 'Ballas')
check('notification de prise', W.notes[1] and W.notes[1].msg:find('Grove'))
-- La police arrive : 3 agents annulent la présence et font baisser l'influence
duty[4] = true
tp(4, grove)
local before = t.influence.ballas
Gangs.tick()
check('présence policière freine l\'influence', t.influence.ballas == math.min(100, before + 3 - 1))
-- Les Vagos débarquent à Grove pendant que les Ballas partent
tp(1, far); tp(2, far); tp(5, far); tp(4, far)
tp(3, grove)
for _ = 1, 60 do Gangs.tick() end
check('Ballas absents : déclin', (t.influence.ballas or 0) < before)
check('Vagos reprennent Grove', t.owner == 'vagos')

-- Racket ---------------------------------------------------------------------------------------------------------
local vagosBefore = money.vagos
Gangs.payRacket()
check('racket versé au propriétaire', money.vagos == vagosBefore + math.floor(Config.Territory.racketPerHour * Config.Territory.tickMinutes / 60))

-- Chaleur de quartier + crimes ------------------------------------------------------------------------------------
local infl = t.influence.vagos
TriggerEvent('gs_wanted:server:reported', 3, 'gunshot', 15)
check('crime signalé : chaleur du quartier', GlobalState.gsTerritories.grove.heat == 1)
check('crime signalé : influence du gang de l\'auteur', t.influence.vagos == math.min(100, infl + Config.Territory.crimeBonus))
advance((Config.Territory.heatWindow + 10) * 1000)
Gangs.tick()
check('chaleur retombe après une heure', GlobalState.gsTerritories.grove.heat == 0)

-- Suppression -----------------------------------------------------------------------------------------------------
W.commands.gsgang(0, { action = 'delete', a = 'vagos' })
check('gang supprimé : quartier libéré et membre désaffecté', t.owner == nil and Gangs.online[3].gang == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
