-- Tests gs_duo : formation avec consentement, unicité, contrats à deux, anti-solo/anti-TP, XP, chaleur partagée.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local heatAdded = {}
local reported = 0
provide('gs_wanted', {
    ReportCrime = function() reported = reported + 1 return true end,
    AddHeat = function(src, n) heatAdded[src] = (heatAdded[src] or 0) + n end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_duo', { R .. 'gs_duo/shared/config.lua' })
local rows, nextId = {}, 0
Store = {
    init = function() end,
    find = function(cid) for _, r in pairs(rows) do if r.a == cid or r.b == cid then return { id = r.id, a = r.a, b = r.b, name = r.name, xp = r.xp } end end end,
    create = function(a, b, name) nextId = nextId + 1 rows[nextId] = { id = nextId, a = a, b = b, name = name, xp = 0 } return nextId end,
    delete = function(id) rows[id] = nil end,
    setXp = function(id, xp) if rows[id] then rows[id].xp = xp end end,
    rename = function(id, name) rows[id].name = name end,
}
loadResource('gs_duo', { R .. 'gs_duo/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end

local here = vec3(100.0, 100.0, 30.0)
join(1, 'CID1', 'Jason Vice', here)
join(2, 'CID2', 'Lucia Neon', here)
join(3, 'CID3', 'Solo Loup', here)

-- Formation --------------------------------------------------------------------------------------
local ok = cb('gs_duo:invite', 1, 1); step()
check('pas de duo avec soi-même', not ok)
tp(2, vec3(900.0, 900.0, 30.0))
ok = cb('gs_duo:invite', 1, 2); step()
check('invitation refusée à distance', not ok)
tp(2, here)
ok = cb('gs_duo:invite', 1, 2); step()
check('invitation envoyée', ok and lastClientEvent('gs_duo:client:invite', 2) ~= nil)
net('gs_duo:server:answer', 2, false); step()
check('refus : pas de duo', Duo.online[1].duoId == nil)
cb('gs_duo:invite', 1, 2); step()
advance(Config.InviteTimeout * 1000 + 1000)
net('gs_duo:server:answer', 2, true); step()
check('invitation expirée', Duo.online[1].duoId == nil)
cb('gs_duo:invite', 1, 2); step()
net('gs_duo:server:answer', 2, true); step()
check('duo formé', Duo.online[1].duoId ~= nil and Duo.online[1].duoId == Duo.online[2].duoId)
check('nom auto', Duo.byId[Duo.online[1].duoId].name == 'Jason & Lucia')
check('partenaire trouvé', Duo.partner(1) == 2 and Duo.partner(2) == 1)
net('gs_duo:server:answer', 2, true); step()
check('réponse non rejouable', nextId == 1)
ok = cb('gs_duo:invite', 3, 1); step()
check('impossible d\'inviter quelqu\'un déjà en duo', not ok)

-- Renommage ------------------------------------------------------------------------------------------
ok = cb('gs_duo:rename', 1, '<b>@everyone</b> Vice Kings')
check('renommage nettoyé', ok and not Duo.byId[1].name:find('[<>@]'))
ok = cb('gs_duo:rename', 3, 'Solo')
check('renommage refusé sans duo', not ok)

-- Positions : seulement au partenaire ------------------------------------------------------------------
W.clientEvents = {}
Duo.pushPositions()
check('position envoyée aux deux membres', lastClientEvent('gs_duo:client:partner', 1) and lastClientEvent('gs_duo:client:partner', 2))
check('jamais aux autres', lastClientEvent('gs_duo:client:partner', 3) == nil)

-- Contrat à deux ------------------------------------------------------------------------------------------
tp(2, vec3(900.0, 900.0, 30.0))
ok = cb('gs_duo:contractStart', 1); step()
check('contrat refusé si partenaire loin', not ok)
tp(2, here)
ok = cb('gs_duo:contractStart', 1); step()
check('contrat lancé', ok and Duo.contracts[1] ~= nil)
local s1 = lastClientEvent('gs_duo:client:contractStep', 2).args[1]
check('étape envoyée aux deux', lastClientEvent('gs_duo:client:contractStep', 1) ~= nil)
check('1re étape loin du départ', #(s1.coords - here) >= Config.Contract.minStepDistance)
tp(1, s1.coords)
advance(600000)
ok = cb('gs_duo:contractStep', 1); step()
check('seul sur l\'étape : refusé', not ok)
tp(2, s1.coords)
ok = cb('gs_duo:contractStep', 1); step()
check('à deux : marchandise récupérée', ok and Duo.contracts[1].index == 2)
check('vol signalé à gs_wanted', reported == 1)
local s2 = lastClientEvent('gs_duo:client:contractStep', 1).args[1]
tp(1, s2.coords); tp(2, s2.coords)
ok, msg = cb('gs_duo:contractStep', 1)
check('téléportation : contrat annulé', not ok and Duo.contracts[1] == nil)
advance(Config.Contract.cooldown * 1000 + 1000); step()

tp(1, here); tp(2, here)
cb('gs_duo:contractStart', 1); step()
local c = Duo.contracts[1]
advance(600000)
tp(1, c.steps[1]); tp(2, c.steps[1])
cb('gs_duo:contractStep', 2); step()
advance(600000)
tp(1, c.steps[2]); tp(2, c.steps[2])
W.players[1].money.cash, W.players[2].money.cash = 0, 0
local xpBefore = Duo.byId[1].xp
ok = cb('gs_duo:contractStep', 1); step()
check('contrat réussi', ok and Duo.contracts[1] == nil)
check('les deux sont payés, même montant', W.players[1].money.cash > 0 and W.players[1].money.cash == W.players[2].money.cash)
check('XP gagnée', Duo.byId[1].xp == xpBefore + Config.Contract.xp)
ok = cb('gs_duo:contractStart', 1); step()
check('cooldown entre deux contrats', not ok)

-- Niveaux ------------------------------------------------------------------------------------------------
check('niveau 1 au départ', Duo.level(0) == 1)
check('niveau max', Duo.level(99999) == #Config.Levels)
for i = 2, #Config.Levels do check('seuils croissants ' .. i, Config.Levels[i].xp > Config.Levels[i - 1].xp) end

-- Chaleur partagée ----------------------------------------------------------------------------------------
TriggerEvent('gs_wanted:server:reported', 1, 'gunshot', 20)
check('complice proche prend une part', heatAdded[2] == math.floor(20 * Config.Levels[Duo.level(Duo.byId[1].xp)].heatShare))
tp(2, vec3(3000.0, 3000.0, 0.0))
heatAdded[2] = nil
TriggerEvent('gs_wanted:server:reported', 1, 'gunshot', 20)
check('complice loin : rien', heatAdded[2] == nil)
tp(2, here)

-- XP ensemble -----------------------------------------------------------------------------------------------
tp(1, here); tp(2, vec3(here.x + 500.0, here.y, here.z))
xpBefore = Duo.byId[1].xp
Duo.togetherTick()
check('pas d\'XP si éloignés', Duo.byId[1].xp == xpBefore)
tp(2, here)
Duo.togetherTick()
check('XP ensemble une seule fois par duo', Duo.byId[1].xp == xpBefore + Config.TogetherXp)

-- Déconnexion pendant un contrat --------------------------------------------------------------------------------
advance(Config.Contract.cooldown * 1000 + 1000); step()
cb('gs_duo:contractStart', 1); step()
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('contrat annulé si partenaire déco', Duo.contracts[1] == nil and lastClientEvent('gs_duo:client:contractEnd', 1) ~= nil)
join(2, 'CID2', 'Lucia Neon', here)
check('duo rechargé à la reconnexion', Duo.online[2].duoId == 1 and Duo.partner(1) == 2)

TriggerEvent('gs_bridge:server:playerUnloaded', 1)
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('duo hors ligne libéré de la mémoire', Duo.byId[1] == nil)
join(1, 'CID1', 'Jason Vice', here)
join(2, 'CID2', 'Lucia Neon', here)
check('et rechargé depuis la BDD', Duo.byId[1] ~= nil and Duo.byId[1].xp == rows[1].xp and Duo.partner(1) == 2)

-- Rupture + cooldown ----------------------------------------------------------------------------------------------
net('gs_duo:server:leave', 1); step()
check('duo dissous', Duo.online[1].duoId == nil and Duo.online[2].duoId == nil and rows[1] == nil)
ok = cb('gs_duo:invite', 1, 3); step()
check('pas de nouveau duo juste après une rupture', not ok)
ok = cb('gs_duo:invite', 3, 1); step()
net('gs_duo:server:answer', 1, true); step()
check('ni en acceptant', Duo.online[1].duoId == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
