-- Tests gs_auction (V10.1) : dépôt de saisie (police, sur place, pas d'armes), véhicule abandonné (pas d'urgence),
-- enchères fermées hors créneau, mise minimum, surenchère (remboursement), clôture (lot au gagnant, recette police,
-- invendus moins chers), livraison à la connexion pour un gagnant hors ligne.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local jstore = {}
json.encode = function(t) jstore[#jstore + 1] = t return 'J' .. #jstore end
json.decode = function(s) if s == '[]' then return {} end return jstore[tonumber(s:sub(2))] end
local duty, society = {}, {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end,
    AddSocietyMoney = function(job, n) society[job] = (society[job] or 0) + n return true end })
provide('gs_social', { Newsroom = function() return true end })
provide('ox_inventory', { Items = function(name) return { label = 'Montre en or' } end })
provide('qbx_core', { GetVehiclesByHash = function() return {
    [111] = { model = 'sultan', name = 'Sultan', category = 'sports' },
    [222] = { model = 'police', name = 'Police', category = 'emergency' } } end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_auction', { R .. 'gs_auction/shared/config.lua', R .. 'gs_auction/server/main.lua' })
Auction.lots = {}
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

join(1, 'CID1', 'Agent', Config.Point) duty[1] = 'police'
join(2, 'CID2', 'Acheteur A', vec3(0.0, 0.0, 0.0)) W.players[2].money.bank = 100000
join(3, 'CID3', 'Acheteur B', vec3(0.0, 0.0, 0.0)) W.players[3].money.bank = 100000
W.players[1].items.goldwatch = 3 W.players[1].items.WEAPON_PISTOL = 1

local ok = cb('gs_auction:deposit', 2, 'goldwatch', 1, 100); step()
check('civil : ne dépose pas', not ok)
ok = cb('gs_auction:deposit', 1, 'WEAPON_PISTOL', 1, 100); step()
check('arme : refusée', not ok)
ok = cb('gs_auction:deposit', 1, 'goldwatch', 2, 200); step()
check('saisie déposée (retirée de l\'inventaire)', ok and #Auction.lots == 1 and W.players[1].items.goldwatch == 1)
TriggerEvent('gs_police:server:impounded', 222, 'LSPD 01')
check('véhicule d\'urgence : pas mis en vente', #Auction.lots == 1)
TriggerEvent('gs_police:server:impounded', 111, 'ABC 123 ')
check('véhicule abandonné : mis en vente à 25 %', #Auction.lots == 2 and Auction.lots[2].start == 10000 and Auction.lots[2].model == 'sultan')

Auction.window = function() return false end
ok = cb('gs_auction:bid', 2, 1, 500); step()
check('hors créneau : fermé', not ok)
Auction.window = function() return true end
ok = cb('gs_auction:bid', 2, 1, 150); step()
check('sous la mise de départ : refusé', not ok)
ok = cb('gs_auction:bid', 2, 1, 300); step()
check('enchère : argent bloqué', ok and W.players[2].money.bank == 99700)
ok = cb('gs_auction:bid', 2, 1, 400); step()
check('déjà en tête : refusé', not ok)
ok = cb('gs_auction:bid', 3, 1, 301); step()
check('surenchère trop faible : refusée', not ok)
ok = cb('gs_auction:bid', 3, 1, 400); step()
check('surenchère : l\'ancien est remboursé', ok and W.players[2].money.bank == 100000 and W.players[3].money.bank == 99600)
cb('gs_auction:bid', 2, 2, 10000); step()
W.players[2] = nil -- le gagnant du véhicule se déconnecte
Auction.window = function() return false end
Auction.tick()
check('clôture : saisie au gagnant', W.players[3].items.goldwatch == 2)
check('clôture : recette à la police', society.police == 10400)
check('plus de lots vendus en salle', #Auction.lots == 0)
join(2, 'CID2', 'Acheteur A', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_bridge:server:playerLoaded', 2)
check('gagnant hors ligne : véhicule livré à la connexion', (W.players[2].vehicles or 0) == 1)

-- Invendu : remis moins cher
ok = cb('gs_auction:deposit', 1, 'goldwatch', 1, 1000); step()
Auction.window = function() return true end Auction.tick()
Auction.lots[1].bid = nil
Auction.window = function() return false end
Auction.settle()
check('invendu : remis à 80 %', #Auction.lots == 1 and Auction.lots[1].start == 800)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
