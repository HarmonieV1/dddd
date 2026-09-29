-- Tests gs_quests : niveaux, disponibilité (genre, prérequis, niveau, nuit), étapes vérifiées côté serveur,
-- chrono, ramassage, livraison, récompenses, abandon / déconnexion, paquets cachés, XP externe.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local hour = 12
provide('gs_weather', { GetGameTime = function() return hour, 0 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_quests', { R .. 'gs_quests/shared/config.lua', R .. 'gs_quests/shared/quests.lua' })
local db = {}
Store = {
    init = function() end,
    load = function(cid) return db[cid] and { xp = db[cid].xp, packages = db[cid].packages, done = db[cid].done } or { xp = 0, packages = {}, done = {} } end,
    save = function(cid, p) db[cid] = db[cid] or { done = {} } db[cid].xp, db[cid].packages = p.xp, p.packages end,
    markDone = function(cid, q) db[cid] = db[cid] or { xp = 0, packages = {}, done = {} } db[cid].done[q] = true end,
}
loadResource('gs_quests', { R .. 'gs_quests/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end
local function at(c) return vec3(c.x, c.y, c.z) end
local Q = {}
for _, q in ipairs(Quests) do Q[q.id] = q end

-- Niveaux
local lvl, floor, nextXp = Progress.levelOf(0)
check('niveau 1 à 0 XP', lvl == 1 and floor == 0 and nextXp == Config.StepXP(1))
lvl = Progress.levelOf(Config.StepXP(1))
check('niveau 2 pile au seuil', lvl == 2)
check('niveau max borné', Progress.levelOf(10 ^ 9) == Config.MaxLevel)

join(1, 'CID1', 'Tony', at(Characters.guide.coords)); W.players[1].gender = 'male'
join(2, 'CID2', 'Lucia', at(Characters.guide.coords)); W.players[2].gender = 'female'

-- Disponibilité
local s = cb('gs_quests:state', 1); step()
local function info(st, id) for _, i in ipairs(st.quests) do if i.id == id then return i end end end
check('welcome dispo', info(s, 'welcome').available)
check('chaîne Sal verrouillée avant welcome', not info(s, 'sal_pizza').available)
local ok, msg = cb('gs_quests:start', 1, 'sal_pizza'); step()
check('prérequis vérifié côté serveur', not ok)
ok = cb('gs_quests:start', 1, 'inconnue'); step()
check('quête inconnue', not ok)

-- Welcome : étapes goto vérifiées
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_quests:start', 1, 'welcome'); step()
check('démarrage refusé loin du personnage', not ok)
tp(1, at(Characters.guide.coords))
ok = cb('gs_quests:start', 1, 'welcome'); step()
check('welcome démarrée', ok and Progress.active[1].step == 1)
ok = cb('gs_quests:start', 1, 'welcome'); step()
check('une quête à la fois', not ok)
ok = cb('gs_quests:advance', 1); step()
check('étape goto : pas encore arrivé', not ok and Progress.active[1].step == 1)
tp(1, Q.welcome.steps[1].coords)
ok = cb('gs_quests:advance', 1); step()
check('étape 1 validée', ok and Progress.active[1].step == 2)
tp(1, Q.welcome.steps[2].coords)
cb('gs_quests:advance', 1); step()
tp(1, at(Characters.guide.coords))
ok = cb('gs_quests:advance', 1); step()
check('welcome terminée : argent + XP + marquée', ok and not Progress.active[1] and W.players[1].money.cash == 250
    and Progress.players[1].xp == 150 and db.CID1.done.welcome)
check('annonce client', lastClientEvent('gs_quests:client:completed', 1).args[1] == 'welcome')
ok = cb('gs_quests:start', 1, 'welcome'); step()
check('pas deux fois', not ok)

-- Genre
s = cb('gs_quests:state', 1); step()
check('homme : chaîne Sal dispo, pas Rosa', info(s, 'sal_pizza').available and not info(s, 'rosa_look').available)
Progress.players[2].done.welcome = true
tp(2, at(Characters.sal.coords))
ok, msg = cb('gs_quests:start', 2, 'sal_pizza'); step()
check('femme : chaîne Sal refusée', not ok)

-- Sal pizza : item + véhicule prêtés, chrono
tp(1, at(Characters.sal.coords))
ok = cb('gs_quests:start', 1, 'sal_pizza'); step()
local a = Progress.active[1]
check('pizza donnée + scooter prêté', ok and W.players[1].items.gs_parcel == 1 and a.veh and W.entities[a.veh].model == 'faggio')
check('chrono lancé', a.deadline ~= nil)
advance(250 * 1000)
tp(1, Q.sal_pizza.steps[1].coords)
local veh = a.veh
ok, msg = cb('gs_quests:advance', 1); step()
check('trop lent : échec, pizza et scooter repris', not ok and msg:find('Trop lent') and not Progress.active[1]
    and (W.players[1].items.gs_parcel or 0) == 0 and not W.entities[veh])
tp(1, at(Characters.sal.coords))
cb('gs_quests:start', 1, 'sal_pizza'); step()
tp(1, Q.sal_pizza.steps[1].coords)
ok = cb('gs_quests:advance', 1); step()
check('livrée à temps : item retiré', ok and Progress.active[1].step == 2 and W.players[1].items.gs_parcel == 0)
tp(1, at(Characters.sal.coords))
ok = cb('gs_quests:advance', 1); step()
check('sal_pizza terminée', ok and Progress.players[1].done.sal_pizza)

-- Recouvrement : ramassage point par point
cb('gs_quests:start', 1, 'sal_debt'); step()
tp(1, at(Characters.lenny.coords))
cb('gs_quests:advance', 1); step()
local pts = Q.sal_debt.steps[2].points
ok = cb('gs_quests:advance', 1, 1); step()
check('ramassage : trop loin du point', not ok)
tp(1, pts[1])
ok = cb('gs_quests:advance', 1, 1); step()
check('1er ramassage', ok and W.players[1].items.gs_envelope == 1 and Progress.active[1].step == 2)
ok = cb('gs_quests:advance', 1, 1); step()
check('pas deux fois le même point', not ok and W.players[1].items.gs_envelope == 1)
ok = cb('gs_quests:advance', 1, 99); step()
check('point inconnu', not ok)
for i = 2, 3 do tp(1, pts[i]) cb('gs_quests:advance', 1, i) step() end
check('tous ramassés : étape suivante', Progress.active[1].step == 3 and W.players[1].items.gs_envelope == 3)
W.players[1].items.gs_envelope = 2
tp(1, at(Characters.sal.coords))
ok = cb('gs_quests:advance', 1); step()
check('livraison incomplète refusée', not ok and Progress.active[1].step == 3)
W.players[1].items.gs_envelope = 3
ok = cb('gs_quests:advance', 1); step()
check('recouvrement terminé', ok and Progress.players[1].done.sal_debt)

-- Offre : il faut arriver en véhicule
cb('gs_quests:start', 1, 'sal_offer'); step()
tp(1, Q.sal_offer.steps[1].coords)
ok, msg = cb('gs_quests:advance', 1); step()
check('à pied : refusé', not ok and msg:find('véhicule'))
W.players[1].vehicle = 42
ok = cb('gs_quests:advance', 1); step()
check('en véhicule : validé', ok and Progress.active[1].step == 2)
W.players[1].vehicle = nil

-- Abandon
ok = cb('gs_quests:abandon', 1); step()
check('abandon', ok and not Progress.active[1] and not Progress.players[1].done.sal_offer)

-- Nuit
Progress.players[2].done.rosa_look, Progress.players[2].done.rosa_gossip = true, true
tp(2, at(Characters.rosa.coords))
ok, msg = cb('gs_quests:start', 2, 'rosa_neon'); step()
check('Nuit Néon refusée le jour', not ok and msg:find('soir'))
hour = 22
ok = cb('gs_quests:start', 2, 'rosa_neon'); step()
check('Nuit Néon ok la nuit, décapotable prêtée', ok and W.entities[Progress.active[2].veh].model == 'issi2')
veh = Progress.active[2].veh
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('déconnexion : quête abandonnée, véhicule repris', not Progress.active[2] and not W.entities[veh])

-- Niveau minimum (la Voix : niveau 3)
tp(1, at(Characters.voice.coords))
local saved = Progress.players[1].xp
Progress.players[1].xp = 0
ok, msg = cb('gs_quests:start', 1, 'voice'); step()
check('niveau requis', not ok and msg:find('Niveau'))
Progress.players[1].xp = saved
ok = cb('gs_quests:start', 1, 'voice'); step()
check('niveau atteint : la Voix décroche', ok)
cb('gs_quests:abandon', 1); step()

-- XP externe + passage de niveau avec bonus
local bank = W.players[1].money.bank
local xpBefore = Progress.players[1].xp
local levelBefore = Progress.levelOf(xpBefore)
local target = Progress.levelOf(xpBefore + 2000)
exports.gs_quests:AddXP(1, 2000, 'test')
check('XP ajoutée + bonus de niveaux en banque', Progress.players[1].xp == xpBefore + 2000 and W.players[1].money.bank > bank)
local e = lastClientEvent('gs_quests:client:xp', 1).args[1]
check('annonce niveau supérieur', e.levelUp and e.level == target and target > levelBefore)
check('XP négative / énorme refusée', exports.gs_quests:AddXP(1, -50) == nil and exports.gs_quests:AddXP(1, 10 ^ 7) == nil)
check('Reward par activité', exports.gs_quests:Reward(1, 'heist') ~= nil and exports.gs_quests:GetLevel(1) >= target)

-- Paquets cachés
local p1 = Config.Packages.points[1]
ok = cb('gs_quests:package', 1, 1); step()
check('paquet : trop loin', not ok)
tp(1, p1)
ok = cb('gs_quests:package', 1, 1); step()
check('paquet trouvé', ok and Progress.players[1].packages[1])
ok = cb('gs_quests:package', 1, 1); step()
check('paquet déjà trouvé', not ok)
for i = 2, #Config.Packages.points - 1 do Progress.players[1].packages[i] = true end
local cash = W.players[1].money.bank
local last = #Config.Packages.points
tp(1, Config.Packages.points[last])
ok, msg = cb('gs_quests:package', 1, last); step()
check('tous les paquets : bonus', ok and msg:find('TOUS') and W.players[1].money.bank >= cash + Config.Packages.allCash)

-- Persistance
TriggerEvent('gs_bridge:server:playerUnloaded', 1)
join(1, 'CID1', 'Tony', p1)
check('reconnexion : XP, quêtes et paquets conservés', Progress.players[1].xp == db.CID1.xp and Progress.players[1].done.sal_debt
    and Progress.players[1].packages[1])

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
