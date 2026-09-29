-- Tests gs_tuning : salon, conducteur, propriété, validation de plaque (format, réservés, interdits, unicité), paiement, néons.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_tuning', { R .. 'gs_tuning/shared/config.lua' })
local db = { { id = 1, cid = 'CID1', plate = 'ABC 123' }, { id = 2, cid = 'CID2', plate = 'ZZZ 999' } }
local neon = {}
local function norm(p) return (p or ''):upper():gsub('^%s+', ''):gsub('%s+$', '') end
Store = {
    ownedByPlate = function(cid, plate) for _, v in ipairs(db) do if v.cid == cid and norm(v.plate) == norm(plate) then return v.id end end end,
    plateTaken = function(plate) for _, v in ipairs(db) do if norm(v.plate) == norm(plate) then return true end end return false end,
    setPlate = function(id, cid, plate) for _, v in ipairs(db) do if v.id == id and v.cid == cid then v.plate = plate return true end end return false end,
    setNeon = function(id, cid, rgb) neon[id] = rgb or false return true end,
}
function GetPedInVehicleSeat(veh) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end
loadResource('gs_tuning', { R .. 'gs_tuning/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(16000) end
local shop = Config.Shops[1].coords

-- Validation de plaque (pure)
local function v(t) return Tuning.validPlate(t) end
check('plaque valide', v('roadtrip') == 'ROADTRIP' or v('  vice 88 ') == 'VICE 88')
check('trop courte / trop longue', not v('A') and not v('ABCDEFGHI'))
check('caractères interdits', not v('AB-12') and not v('É12') and not v('A;B'))
check('préfixe réservé (police, staff, jobs)', not v('LSPD 1') and not v('ADMIN') and not v('TAXI 22') and not v('L S P D'))
check('mots interdits', not v('MERDE 1') and not v('X FDP') and not v('NIQUE'))
check('non-texte', not v(nil) and not v(12))

-- Joueur avec son véhicule
join(1, 'CID1', 'Proprio', vec3(0.0, 0.0, 0.0))
local car = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[car].plate, W.entities[car].driver = 'ABC 123', 1
W.players[1].vehicle = car
W.players[1].money.bank = 10000
check('hors salon : rien', cb('gs_tuning:info', 1) == nil)
local ok = cb('gs_tuning:plate', 1, 'VICE 88'); step()
check('hors salon : plaque refusée', not ok)
tp(1, shop)
local info = cb('gs_tuning:info', 1); step()
check('infos : véhicule à moi', info and info.ok and info.plate == 'ABC 123')

ok = cb('gs_tuning:plate', 1, 'ZZZ 999'); step()
check('plaque déjà prise', not ok)
ok = cb('gs_tuning:plate', 1, 'LSPD 01'); step()
check('plaque réservée', not ok and W.players[1].money.bank == 10000)
ok = cb('gs_tuning:plate', 1, 'abc 123'); step()
check('même plaque : rien à faire', not ok)
ok, msg, plate = cb('gs_tuning:plate', 1, 'vice 88'); step()
check('plaque changée : payée, base + entité mises à jour', ok and plate == 'VICE 88' and db[1].plate == 'VICE 88' and W.entities[car].plate == 'VICE 88'
    and W.players[1].money.bank == 10000 - Config.PlatePrice)

-- Néons
ok = cb('gs_tuning:neon', 1, 99); step()
check('couleur inconnue', not ok)
local ok2, m2, rgb = cb('gs_tuning:neon', 1, 2); step()
check('néons cyan posés et payés', ok2 and rgb[1] == Config.Neon[2].rgb[1] and neon[1] and W.players[1].money.bank == 10000 - Config.PlatePrice - Config.NeonPrice)
ok2 = cb('gs_tuning:neon', 1, 0); step()
check('éteindre : gratuit', ok2 and neon[1] == false and W.players[1].money.bank == 10000 - Config.PlatePrice - Config.NeonPrice)

-- Véhicule d'un autre / passager / pas d'argent
join(2, 'CID2', 'Autre', shop)
W.players[2].vehicle = car
ok = cb('gs_tuning:neon', 2, 1); step()
check('passager d\'un véhicule qui n\'est pas à lui : refusé', not ok)
W.entities[car].driver = 2
W.entities[car].plate = 'ABC 123'
ok = cb('gs_tuning:neon', 2, 1); step()
check('au volant d\'un véhicule d\'autrui : refusé', not ok)
W.players[1].money.bank, W.players[1].money.cash = 0, 100
W.entities[car].driver = 1 W.entities[car].plate = 'VICE 88'
ok = cb('gs_tuning:plate', 1, 'NEO 01'); step()
check('pas assez d\'argent', not ok and db[1].plate == 'VICE 88')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
