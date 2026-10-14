-- Tests gs_harvest : récolte (outil, nœud, durée réelle, butin, casse d'outil, épuisement / repousse), chasse (gibier du serveur seulement,
-- mort, couteau, distance), revente (acheteur, distance, tout l'inventaire concerné), repeuplement de la zone.
-- V12.36 : ferraille (scène en phases valide, sans outil, pièces variées + trouvaille, carcasse dépouillée, repousse), PNJ des points
-- (acheteurs, vestiaires : modèle, cap, scénario valides).
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
local ok, msg = cb('gs_harvest:begin', 1, 'mining', 2); step()
check('trop loin du point', not ok)
tp(1, mine.spots[2])
ok, msg = cb('gs_harvest:begin', 1, 'mining', 2); step()
check('sans pioche : refusé (nom en français)', not ok and msg:find('pioche') and not msg:find('pickaxe'))
W.players[1].items.pickaxe = 1
ok = cb('gs_harvest:begin', 1, 'inconnu'); step()
check('activité inconnue', not ok)
ok = cb('gs_harvest:begin', 1, 'mining', 99); step()
check('nœud inconnu', not ok)
ok, msg = cb('gs_harvest:begin', 1, 'mining', 2)
check('début : durée renvoyée', ok and msg >= mine.duration[1])
ok = cb('gs_harvest:finish', 1)
check('fin trop tôt : refusée', not ok and not Harvest.pending[1])
cb('gs_harvest:begin', 1, 'mining', 2); advance(mine.duration[2])
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_harvest:finish', 1); step()
check('éloigné pendant la récolte', not ok)
tp(1, mine.spots[2])
fixRandom(0.0)
cb('gs_harvest:begin', 1, 'mining', 2); advance(mine.duration[2])
ok, msg = cb('gs_harvest:finish', 1); step()
check('butin : pierre + outil cassé (tirage 0), nom en français', ok and W.players[1].items.stone == mine.loot[1][3][1] and W.players[1].items.pickaxe == 0 and msg:find('cassé') and msg:find('pierre'))
fixRandom(0.99)
W.players[1].items.pickaxe = 1
cb('gs_harvest:begin', 1, 'mining', 2); advance(mine.duration[2])
ok = cb('gs_harvest:finish', 1); step()
check('butin rare (or), outil intact', ok and (W.players[1].items.gold_ore or 0) >= 1 and W.players[1].items.pickaxe == 1)
fixRandom(nil)

-- Épuisement : le nœud 2 a déjà donné 2 fois ; la 3e l'épuise (perNode = 3), il revient après Config.Regrow
W.players[1].items.pickaxe = 50 -- l'outil peut casser au hasard (3 %) : réserve pour que le test ne dépende pas du tirage
cb('gs_harvest:begin', 1, 'mining', 2); advance(mine.duration[2])
local okE, msgE, infoE = cb('gs_harvest:finish', 1); step()
check('3e récolte : nœud épuisé', okE and infoE.depleted and infoE.node == 2 and msgE:find('épuisé'))
check('revente indiquée', infoE.sell and infoE.sell:find('Cypress'))
ok, msg = cb('gs_harvest:begin', 1, 'mining', 2); step()
check('nœud épuisé : refusé', not ok and msg:find('Épuisé'))
check('liste des nœuds épuisés', cb('gs_harvest:depleted', 1, 'mining')[2] ~= nil)
tp(1, mine.spots[3])
ok = cb('gs_harvest:begin', 1, 'mining', 3); advance(mine.duration[2])
check('nœud voisin : autorisé', ok and cb('gs_harvest:finish', 1)); step()
advance(Config.Regrow * 1000)
tp(1, mine.spots[2])
ok = cb('gs_harvest:begin', 1, 'mining', 2); advance(mine.duration[2])
check('repousse : nœud de nouveau disponible', ok and cb('gs_harvest:finish', 1)); step()
check('hauteur approximative tolérée (sol recalé chez le client)', (function()
    W.players[1].pos = vec3(mine.spots[2].x, mine.spots[2].y, mine.spots[2].z + 6.0)
    local o = cb('gs_harvest:begin', 1, 'mining', 2); step(); cb('gs_harvest:finish', 1) Harvest.pending[1] = nil
    return o
end)())

-- Ferme : sans outil
local farm = Config.Activities.farming
tp(1, farm.spots[1])
ok = cb('gs_harvest:begin', 1, 'farming', 1); advance(farm.duration[2])
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

-- Revente (marché de Grapeseed : légumes)
local market = Config.Buyers[3]
ok = cb('gs_harvest:sell', 1, 3); step()
check('revente à distance : refusée', not ok)
tp(1, market.coords)
local cash = W.players[1].money.cash
W.players[1].items.tomato = 3
ok, msg = cb('gs_harvest:sell', 1, 3); step()
check('revente : légumes vendus', ok and W.players[1].items.tomato == 0 and W.players[1].money.cash > cash)
ok = cb('gs_harvest:sell', 1, 3); step()
check('plus rien à vendre', not ok)
ok = cb('gs_harvest:sell', 1, 99); step()
check('acheteur inconnu', not ok)

check('dépecer sans permis = braconnage signalé', crimes[1] == 'poaching')
for _, b in ipairs(Config.Buyers) do
    for id, a in pairs(Config.Activities) do
        for _, c in ipairs(a.spots) do
            check(('acheteur %s loin de la récolte (%s)'):format(b.label, id), #(b.coords - c) > 150.0)
        end
    end
end

-- Permis de chasse (Ammu-Nation de Paleto)
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

-- V12.36 · Ferraille : vraie scène (config) ---------------------------------------------------------------------
local scrap = Config.Activities.scrapyard
check('ferraille : sans outil à acheter (la casse prête ses clés)', scrap.tool == nil)
check('ferraille : les phases couvrent toute la durée fixée par le serveur', (function()
    local s = 0
    for _, ph in ipairs(scrap.phases) do s = s + ph.share end
    return #scrap.phases >= 2 and math.abs(s - 1.0) < 0.001
end)())
check('ferraille : chaque phase a un texte français et une animation (dictionnaire + clip)', (function()
    for _, ph in ipairs(scrap.phases) do
        if type(ph.label) ~= 'string' or ph.label == '' or not ph.label:find('…') then return false end
        if type(ph.anim) ~= 'table' or type(ph.anim.dict) ~= 'string' or ph.anim.dict == '' or type(ph.anim.clip) ~= 'string' or ph.anim.clip == '' then return false end
    end
    return true
end)())
check('ferraille : fouille accroupie puis dévissage à genoux, clé à molette en main', scrap.phases[1].label:find('Fouille') and scrap.phases[2].label:find('Dévissage')
    and scrap.phases[2].handProp and scrap.phases[2].handProp.model == 'prop_tool_wrench' and scrap.phases[2].handProp.bone == 57005)
check('ferraille : objets variés par nœud (carcasse, bloc moteur, tas) + repli', scrap.prop ~= nil and #scrap.props >= 3 and (function()
    local carcass = false
    for _, m in ipairs(scrap.props) do
        if type(m) ~= 'string' or m == '' then return false end
        if m:find('carwreck') then carcass = true end
    end
    return carcass
end)())
check('ferraille : la carcasse dépouillée reste visible (keepWhenDepleted)', scrap.keepWhenDepleted == true and scrap.depletedMsg:find('carcasse'))
check('ferraille : chaque pièce a ses trouvailles (textes RP)', (function()
    for _, l in ipairs(scrap.loot) do
        if type(l.finds) ~= 'table' or #l.finds == 0 then return false end
        for _, f in ipairs(l.finds) do if type(f) ~= 'string' or f == '' then return false end end
    end
    return true
end)())

-- V12.36 · Ferraille : récolte serveur (pièces variées, carcasse dépouillée au 3e passage, repousse) ------------------
W.players[1].items.scrapmetal, W.players[1].items.copper = 0, 0
tp(1, scrap.spots[1])
ok, msg = cb('gs_harvest:begin', 1, 'scrapyard', 1)
check('ferraille : début accepté sans outil, durée dans la plage', ok and msg >= scrap.duration[1] and msg <= scrap.duration[2])
advance(scrap.duration[2])
fixRandom(0.0)
local okS, msgS, infoS = cb('gs_harvest:finish', 1); step()
check('ferraille : tirage bas = ferraille + trouvaille décrite', okS and W.players[1].items.scrapmetal >= 2 and msgS:find('ferraille') and msgS:find(scrap.loot[1].finds[1], 1, true))
check('ferraille : revente indiquée (ferrailleur)', infoS and infoS.sell and infoS.sell:find('Ferrailleur'))
fixRandom(0.99)
cb('gs_harvest:begin', 1, 'scrapyard', 1); advance(scrap.duration[2])
okS, msgS = cb('gs_harvest:finish', 1); step()
check('ferraille : tirage haut = cuivre (pièces variées)', okS and W.players[1].items.copper >= 1 and msgS:find('cuivre'))
fixRandom(nil)
cb('gs_harvest:begin', 1, 'scrapyard', 1); advance(scrap.duration[2])
okS, msgS, infoS = cb('gs_harvest:finish', 1); step()
check('ferraille : 3e passage = carcasse dépouillée (message RP, nœud signalé au client)', okS and infoS.depleted and infoS.node == 1 and msgS:find('carcasse'))
ok, msg = cb('gs_harvest:begin', 1, 'scrapyard', 1); step()
check('ferraille : carcasse dépouillée refusée', not ok and msg:find('Épuisé'))
check('ferraille : liste des carcasses dépouillées', cb('gs_harvest:depleted', 1, 'scrapyard')[1] ~= nil)
advance(Config.Regrow * 1000)
ok = cb('gs_harvest:begin', 1, 'scrapyard', 1); step()
check('ferraille : repousse après Config.Regrow', ok)
Harvest.pending[1] = nil

-- V12.36 · PNJ aux points (gs_markers) : acheteurs et vestiaires ------------------------------------------------------
local function validPed(p)
    return type(p) == 'table' and type(p.model) == 'string' and p.model ~= '' and type(p.heading) == 'number'
        and p.heading >= 0 and p.heading < 360 and (p.scenario == nil or (type(p.scenario) == 'string' and p.scenario ~= ''))
end
for _, b in ipairs(Config.Buyers) do check('PNJ acheteur valide : ' .. b.label, validPed(b.ped)) end
for id, a in pairs(Config.Activities) do
    if a.outfit ~= false then check('PNJ du vestiaire valide : ' .. id, validPed(a.lockerPed)) end
end
check('portée des PNJ : générique dans gs_markers, plus de réglage propre à gs_harvest', Config.BuyerPedRange == nil)

-- V12.45 · props de récolte BzZz : céréales et tabac (légal, vendus au marché), pavot (illégal, signalé, receleur sans blip)
do
    local before = #crimes
    local cer = Config.Activities.cereals
    tp(1, cer.spots[1]) step()
    local okC = cb('gs_harvest:begin', 1, 'cereals', 1); advance(cer.duration[2])
    local okC2 = cb('gs_harvest:finish', 1); step()
    local got = (W.players[1].items.barley or 0) + (W.players[1].items.hops or 0) + (W.players[1].items.corn or 0)
    check('V12.45 : céréales récoltées (orge / houblon / maïs), rien de signalé', okC and okC2 and got > 0 and #crimes == before)
    local pop = Config.Activities.poppy
    tp(1, pop.spots[1]) step()
    local okP = cb('gs_harvest:begin', 1, 'poppy', 1); advance(pop.duration[2])
    local okP2 = cb('gs_harvest:finish', 1); step()
    check('V12.45 : pavot récolté et signalé (culture illicite)', okP and okP2 and (W.players[1].items.poppy_resin or 0) > 0 and crimes[#crimes] == 'drug_cultivation')
    check('V12.45 : pavot sans blip, receleur sans blip', pop.blip == false and (function() for _, b in ipairs(Config.Buyers) do if b.items.poppy_resin then return b.blip == false end end end)())
    local market for _, b in ipairs(Config.Buyers) do if b.items.barley then market = b end end
    check('V12.45 : orge, houblon, maïs, tabac rachetés au marché de Grapeseed', market and market.items.hops and market.items.corn and market.items.tobacco_leaf)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
