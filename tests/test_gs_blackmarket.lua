-- Tests gs_blackmarket : accès (gang / réputation / police), planque, horaires, rareté, stock, 1 arme par jour,
-- paiement sale ou liquide, plafond des armureries légales.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local gangOf, rep, duty, hour, owner = { [1] = 'ballas' }, { [2] = 20 }, { [3] = 'police' }, 23, nil
provide('gs_gangs', { GetGang = function(src) return gangOf[src], 1 end, GetTerritoryAt = function() return 'davis' end,
    GetTerritoryOwner = function() return owner end })
provide('gs_reputation', { Get = function(src) return { street = rep[src] or 0 } end, Add = function() end })
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_weather', { GetGameTime = function() return hour end, GetEvent = function() end })
provide('gs_wanted', { GetHeat = function() return 0 end, ReportCrime = function() return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_blackmarket', { R .. 'gs_blackmarket/shared/config.lua', R .. 'gs_blackmarket/server/fake.lua', R .. 'gs_blackmarket/server/main.lua', R .. 'gs_blackmarket/server/legal.lua' })
local crows, cnext = {}, 0
CStore = { init = function() end, all = function() return {} end, insert = function(c) cnext = cnext + 1 crows[cnext] = c return cnext end,
    setTaker = function(id, t) if crows[id] then crows[id].taker = t end end, delete = function(id) crows[id] = nil end }
loadResource('gs_blackmarket', { R .. 'gs_blackmarket/server/contracts.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local loc = Market.location()
local here = vec3(loc.x, loc.y, loc.z)
join(1, 'CID1', 'Ballas', here); join(2, 'CID2', 'Voyou', here); join(3, 'CID3', 'Flic', here); join(4, 'CID4', 'Inconnu', here)
local function idx(item) for i, e in ipairs(Config.Catalog) do if e.item == item then return i end end end

check('accès gang', Market.access(1))
check('accès réputation', Market.access(2))
check('police refusée', not Market.access(3))
check('inconnu refusé', not Market.access(4))
check('where : planque du jour', cb('gs_blackmarket:where', 1).x == loc.x and cb('gs_blackmarket:where', 4) == nil)

local list = cb('gs_blackmarket:catalog', 2); step()
local gangOnlyVisible = false
for _, e in ipairs(list) do if Config.Catalog[e.index].gangOnly then gangOnlyVisible = true end end
check('catalogue sans armes de gang pour un non-gang', list and not gangOnlyVisible)
hour = 12
check('fermé le jour', cb('gs_blackmarket:catalog', 1) == nil)
step()
hour = 23

local a9 = idx('ammo-9')
W.players[1].items.black_money = 100
local ok, msg = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('pas assez d\'argent sale', not ok)
W.players[1].items.black_money = 10000
local p0 = Market.price(a9)
ok = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('achat munitions : paquet de 20', ok and W.players[1].items['ammo-9'] == 20 and W.players[1].items.black_money == 10000 - p0)
check('rareté : le prix monte', Market.price(a9) > p0)
owner = 'ballas'
check('remise de gang sur son territoire', Market.price(a9, 'ballas') < Market.price(a9))
owner = nil

local pistol = idx('WEAPON_PISTOL')
ok = cb('gs_blackmarket:buy', 1, pistol, 'dirty'); step()
check('arme achetée', ok and W.players[1].items.WEAPON_PISTOL == 1)
ok, msg = cb('gs_blackmarket:buy', 1, idx('WEAPON_SNSPISTOL'), 'dirty'); step()
check('une arme par jour', not ok and msg:find('arme'))
ok = cb('gs_blackmarket:buy', 2, idx('WEAPON_MICROSMG'), 'dirty'); step()
check('arme de gang refusée hors gang', not ok)

W.players[2].money.cash = 1000
local cashPrice = math.floor(Market.price(idx('lockpick')) * Config.CashMarkup)
ok = cb('gs_blackmarket:buy', 2, idx('lockpick'), 'cash'); step()
check('paiement liquide majoré', ok and W.players[2].money.cash == 1000 - cashPrice)

Market.sold[a9] = Config.Catalog[a9].stock
ok, msg = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('rupture de stock', not ok and msg:find('stock'))
tp(1, vec3(0.0, 0.0, 0.0))
Market.sold[a9] = 0
ok = cb('gs_blackmarket:buy', 1, a9, 'dirty'); step()
check('loin du contact : refusé', not ok)

-- Armurerie légale : 120 munitions / jour, 1 arme / jour
check('légal : 100 munitions ok', Legal.check(4, 'ammo-9', 100))
ok, msg = Legal.check(4, 'ammo-9', 30)
check('légal : plafond journalier', not ok and msg:find('120'))
check('légal : couteau libre', Legal.check(4, 'WEAPON_KNIFE', 1) == true)
check('légal : 1re arme ok, 2e refusée', Legal.check(4, 'WEAPON_PISTOL', 1) == true and not Legal.check(4, 'WEAPON_PISTOL', 1))
-- V11.5 : un achat qui ne peut pas aboutir (pas d'argent, inventaire plein) ne consomme pas le plafond
W.players[4].items.money = 10
check('légal : sans argent, l\'achat ne compte pas', Legal.affordable(4, 'ammo-9', 10, 'money', 500) == false)
W.players[4].items.money = 1000
check('légal : argent et place → achat possible', Legal.affordable(4, 'ammo-9', 10, 'money', 500) == true)
W.players[4].full = true
check('légal : inventaire plein → pas d\'achat', Legal.affordable(4, 'ammo-9', 10, 'money', 500) == false)
W.players[4].full = nil

-- V11.5 : permis de port d'arme au comptoir → carte PPA dans l'inventaire
local desk = Config.Permit.desks[1]
join(5, 'CID5', 'Citoyen', vec3(desk.x, desk.y, desk.z)); W.players[5].money.bank = 10000; W.players[5].licences = { driver = true }
ok, msg = Legal.permit(5)
check('PPA : délivré, 5 000 $ payés, carte remise', ok and W.players[5].licences.weapon == true and W.players[5].money.bank == 5000 and W.players[5].items.weaponlicense == 1)
ok = Legal.permit(5)
check('PPA : déjà délivré', not ok)
join(6, 'CID6', 'Sans permis', vec3(desk.x, desk.y, desk.z)); W.players[6].money.bank = 10000
ok, msg = Legal.permit(6)
check('PPA : permis de conduire exigé', not ok and msg:find('permis de conduire'))

-- V12 · Faux papiers : identité inventée à l'achat, présentation 10 min, visible des voisins
local meta = Fake.metadata(1, 'driver')
check('faux permis : identité inventée', meta.fake == 'driver' and meta.fakeName:find(' ') and meta.fakeBirth:match('^%d%d/%d%d/%d%d%d%d$'))
local slots = { [3] = { name = 'gs_fake_driver', metadata = meta } }
provide('ox_inventory', { GetSlot = function(src, slot) return slots[slot] end })
check('présenter : papier introuvable refusé', not Fake.present(1, 'gs_fake_driver', 9))
tp(1, here) tp(2, vec3(here.x + 1.0, here.y, here.z))
ok, msg = Fake.present(1, 'gs_fake_driver', 3)
local f = Player(1).state.gsFake
check('présenter : état public posé 10 min, voisin prévenu', ok and f and f.name == meta.fakeName and f.kinds.driver and f.untilTs > os.time() + 500
    and W.notes[2] and W.notes[2].msg:find(meta.fakeName, 1, true))
slots[4] = { name = 'gs_fake_id', metadata = Fake.metadata(1, 'id') }
slots[4].metadata.fakeName = meta.fakeName
Fake.present(1, 'gs_fake_id', 4)
check('deux papiers au même nom : cumulés', Player(1).state.gsFake.kinds.id and Player(1).state.gsFake.kinds.driver)
local fakeIdx = idx('gs_fake_id')
W.players[1].items.black_money = 100000
hour = 23 tp(1, here)
ok = cb('gs_blackmarket:buy', 1, fakeIdx, 'dirty'); step()
check('faux papier acheté au marché noir', ok and W.players[1].items.gs_fake_id == 1)

-- Contrats entre joueurs ------------------------------------------------------------------------------------
W.players[1].items.black_money = 1000
ok, msg = cb('gs_contracts:post', 1, 'vol', 'Voler une Sultan', 'Parking Legion', 5000); step()
check('contrat : argent sale insuffisant', not ok)
W.players[1].items.black_money = 10000
ok = cb('gs_contracts:post', 1, 'inconnu', 'x', '', 5000); step()
check('contrat : type invalide', not ok)
ok = cb('gs_contracts:post', 4, 'vol', 'x', '', 5000); step()
check('contrat : sans accès refusé', not ok)
ok, msg = cb('gs_contracts:post', 1, 'vol', 'Voler une Sultan', 'Parking Legion', 5000); step()
check('contrat publié, récompense + 5 % bloqués', ok and W.players[1].items.black_money == 10000 - 5250)
local cidc = next(Contracts.list)
ok = cb('gs_contracts:take', 1, cidc); step()
check('pas son propre contrat', not ok)
local l2 = cb('gs_contracts:list', 2); step()
check('liste visible (réputation)', l2 and #l2 == 1 and not l2[1].mine)
ok = cb('gs_contracts:close', 1, cidc, 'done'); step()
check('validation impossible sans preneur', not ok)
ok = cb('gs_contracts:take', 2, cidc); step()
check('contrat accepté', ok and Contracts.list[cidc].taker == 'CID2')
ok = cb('gs_contracts:close', 1, cidc, 'cancel'); step()
check('annulation impossible une fois pris', not ok)
local b2 = W.players[2].items.black_money or 0
ok = cb('gs_contracts:close', 2, cidc, 'done'); step()
check('seul le commanditaire valide', not ok)
ok = cb('gs_contracts:close', 1, cidc, 'done'); step()
check('validé : preneur payé', ok and W.players[2].items.black_money == b2 + 5000 and Contracts.list[cidc] == nil)
ok = cb('gs_contracts:post', 1, 'livraison', 'Colis', '', 1000); step()
local c2 = next(Contracts.list)
local b1 = W.players[1].items.black_money
ok = cb('gs_contracts:close', 1, c2, 'cancel'); step()
check('annulé : remboursé sans commission', ok and W.players[1].items.black_money == b1 + 1000)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
