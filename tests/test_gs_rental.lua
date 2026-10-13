-- Tests gs_rental : distance, paiement liquide puis banque, une location à la fois, place occupée, retour, échéance.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function GetPedInVehicleSeat(veh) return W.entities[veh].driver and GetPlayerPed(W.entities[veh].driver) or 0 end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_rental', { R .. 'gs_rental/shared/config.lua', R .. 'gs_rental/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local P1 = Config.Points[1]
local counter = P1.coords

join(1, 'CID1', 'Loueur', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_rental:rent', 1, 1, 1); step()
check('trop loin du comptoir', not ok)
tp(1, counter)
ok = cb('gs_rental:rent', 1, 1, 4); step()
check('sans argent : refusé', not ok and msg ~= nil)
W.players[1].money.bank = 200
ok, msg = cb('gs_rental:rent', 1, 1, 4); step()
check('payé par la banque', ok and W.players[1].money.bank == 200 - Config.Vehicles[4].price)
local r = Rental.active[1]
check('véhicule créé, joueur au volant', r and W.entities[r.veh].model == 'panto' and W.entities[r.veh].driver == 1)
check('plaque LOC', W.entities[r.veh].plate:sub(1, 3) == 'LOC')
ok = cb('gs_rental:rent', 1, 1, 1); step()
check('une seule location à la fois', not ok)
ok = cb('gs_rental:rent', 1, 99, 1); step()
check('comptoir inconnu', not ok)

-- Place occupée pour un 2e joueur
join(2, 'CID2', 'Second', counter); W.players[2].money.cash = 50
ok, msg = cb('gs_rental:rent', 2, 1, 1); step()
check('place occupée', not ok and msg:find('occupée'))

-- Retour : véhicule trop loin puis ramené
W.entities[r.veh].pos = vec3(500.0, 500.0, 30.0)
ok = cb('gs_rental:return', 1, 1); step()
check('retour refusé si véhicule loin', not ok and Rental.active[1])
W.entities[r.veh].pos = counter
ok = cb('gs_rental:return', 1, 1); step()
check('véhicule rendu et supprimé', ok and not Rental.active[1] and not W.entities[r.veh])

-- Liquide en priorité, échéance
ok = cb('gs_rental:rent', 2, 1, 1); step()
check('payé en liquide', ok and W.players[2].money.cash == 50 - Config.Vehicles[1].price)
local veh = Rental.active[2].veh
W.entities[veh].driver = 2
advance((Config.Vehicles[1].minutes - Config.WarnBefore + 1) * 60000)
Rental.tick()
check('avertissement avant la fin', Rental.active[2].warned and W.notes[2].type == 'warning')
advance(Config.WarnBefore * 60000)
Rental.tick()
check('échu mais conducteur à bord : délai de grâce', Rental.active[2] ~= nil)
W.entities[veh].driver = nil
Rental.tick()
check('échu et vide : récupéré', not Rental.active[2] and not W.entities[veh])

-- Déconnexion
ok = cb('gs_rental:rent', 2, 1, 1); step()
veh = Rental.active[2] and Rental.active[2].veh
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('déconnexion : véhicule retiré', veh and not W.entities[veh] and not Rental.active[2])

-- V12.37 · Points de location : forme (label « Location… », coords + spawn à côté, kind vélo/voiture ou bateau), maillage
-- « retour en ville » (≥ 11 points terrestres, 2 pontons, pas deux points à moins de 100 m), Sandy Shores sorti du poste de
-- police, location possible sur un nouveau point (bateau refusé là) -------------------------------------------------------------
do
    local sheriffSandy = vec3(1853.0, 3686.0, 34.3) -- hall du poste du shérif de Sandy Shores (ancien emplacement du point)
    local land, boats, okShape, okSpread = 0, 0, true, true
    for i, p in ipairs(Config.Points) do
        if type(p.label) ~= 'string' or not p.label:find('^Location') or not p.coords or not p.spawn or type(p.spawn.w) ~= 'number'
            or (p.kind ~= nil and p.kind ~= 'boat') or #(p.spawn - p.coords) > 30.0 then okShape = false end
        if p.kind == 'boat' then boats = boats + 1 else land = land + 1 end
        for j = 1, i - 1 do if #(Config.Points[j].coords - p.coords) < 100.0 then okSpread = false end end
    end
    check('points : label « Location… », spawn à moins de 30 m du comptoir, kind vélo/voiture ou bateau', okShape)
    check('points : au moins 11 points terrestres (retour en ville) et 2 pontons', land >= 11 and boats >= 2)
    check('points : jamais deux points à moins de 100 m', okSpread)
    local sandy
    for _, p in ipairs(Config.Points) do if p.label:find('Sandy') then sandy = p end end
    check('Sandy Shores : hors du poste de police (> 60 m du hall du shérif)', sandy ~= nil and #(sandy.coords - sheriffSandy) > 60.0)
    local last = #Config.Points
    check('dernier point : terrestre (les nouveaux points sont ajoutés en fin de liste)', Config.Points[last].kind == nil)
    join(3, 'CID3', 'Voyageur', Config.Points[last].coords); W.players[3].money.cash = 100
    ok = cb('gs_rental:rent', 3, last, 6); step()
    check('nouveau point : bateau refusé sur un point terrestre', not ok)
    ok = cb('gs_rental:rent', 3, last, 1); step()
    check('nouveau point : vélo loué', ok == true and Rental.active[3] ~= nil and W.players[3].money.cash == 100 - Config.Vehicles[1].price)
    TriggerEvent('gs_bridge:server:playerUnloaded', 3)
    check('nouveau point : déconnexion nettoie', not Rental.active[3])
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
