-- Tests gs_business : carte (stock, libre-service majoré), achat (stock, paiement, caisse du job, journal), préparation
-- (employé en service, ingrédients de la réserve, durée réelle, rollback), prix du patron, comptabilité.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, society = {}, {}
provide('gs_jobs', {
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end,
    IsOnDutyAs = function(src, job) return duty[src] == job end,
    AddSocietyMoney = function(job, n) society[job] = (society[job] or 0) + n return true end,
    GetSocietyMoney = function(job) return society[job] or 0 end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_business', { R .. 'gs_business/shared/config.lua' })
local ledger, prices = {}, {}
Store = { init = function() end, prices = function() return {} end, setPrice = function(b, i, p) prices[b .. i] = p end,
    log = function(b, k, i, q, a, w) ledger[#ledger + 1] = { b = b, kind = k, item = i, qty = q, amount = a } end,
    ledger = function() return ledger end, todaySales = function() local n = 0 for _, l in ipairs(ledger) do if l.kind == 'sale' then n = n + l.amount end end return n end }
loadResource('gs_business', { R .. 'gs_business/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local B = Config.Businesses.bar
W.stashes = { [B.stash] = { vodka = 2, sprunk = 1, beer = 5 } }

join(1, 'CID1', 'Client', B.register) W.players[1].money.cash = 500
join(2, 'CID2', 'Barman', B.craft, { name = 'bar', grade = 1, onduty = true })
join(3, 'CID3', 'Patron', B.register, { name = 'bar', grade = 2, onduty = true, isboss = true })

-- Libre-service (personne en service) : barman PNJ, carte de base, stock illimité, prix majorés, 30 % pour la maison
local m = cb('gs_business:menu', 1, 'bar'); step()
local beer
for _, it in ipairs(m.items) do if it.item == 'beer' then beer = it end end
check('libre-service : prix majoré, toujours servi', not m.staffed and beer.price == math.ceil(B.npc.beer * Config.SelfServiceMarkup) and beer.stock > 0)
local ok = cb('gs_business:buy', 1, 'bar', 'beer', 2); step()
check('achat libre-service : payé, réserve intacte, part de la maison', ok and W.stashes[B.stash].beer == 5 and W.players[1].items.beer == 2
    and society.bar == math.floor(2 * beer.price * Config.NpcShare))
ok = cb('gs_business:buy', 1, 'bar', 'beer', Config.MaxQty + 1); step()
check('quantité plafonnée', not ok)
ok = cb('gs_business:buy', 1, 'bar', 'gs_cocktail', 1); step()
check('cocktail : seulement quand un barman joueur est en service', not ok)

-- Préparation
ok = cb('gs_business:craftBegin', 1, 'bar', 'gs_cocktail'); step()
check('client : pas de préparation', not ok)
duty[2] = 'bar'
ok = cb('gs_business:craftBegin', 2, 'bar', 'beer'); step()
check('produit sans recette', not ok)
local ms
ok, ms = cb('gs_business:craftBegin', 2, 'bar', 'gs_cocktail')
local okf = cb('gs_business:craftFinish', 2)
check('préparation trop rapide : refusée', ok and not okf and W.stashes[B.stash].vodka == 2)
cb('gs_business:craftBegin', 2, 'bar', 'gs_cocktail') advance(ms)
okf = cb('gs_business:craftFinish', 2); step()
check('cocktail préparé : ingrédients pris dans la réserve', okf and W.stashes[B.stash].gs_cocktail == 1 and W.stashes[B.stash].vodka == 1 and W.stashes[B.stash].sprunk == 0)
ok = cb('gs_business:craftBegin', 2, 'bar', 'gs_cocktail'); step()
check('ingrédient manquant', not ok)
W.stashes[B.stash].sprunk = 1 W.stashFull = 'gs_cocktail'
cb('gs_business:craftBegin', 2, 'bar', 'gs_cocktail') advance(ms)
okf = cb('gs_business:craftFinish', 2); step()
check('réserve pleine : ingrédients rendus', not okf and W.stashes[B.stash].vodka == 1 and W.stashes[B.stash].sprunk == 1)
W.stashFull = nil

-- Service ouvert : prix normal, prix du patron
m = cb('gs_business:menu', 1, 'bar'); step()
check('employé en service : pas de majoration', m.staffed)
ok = cb('gs_business:setPrice', 2, 'bar', 'gs_cocktail', 60); step()
check('prix : réservé au patron', not ok)
duty[3] = 'bar'
ok = cb('gs_business:setPrice', 3, 'bar', 'gs_cocktail', 5000); step()
check('prix hors bornes', not ok)
ok = cb('gs_business:setPrice', 3, 'bar', 'gs_cocktail', 60); step()
check('prix fixé', ok and prices.bargs_cocktail == 60)
local before = society.bar
ok = cb('gs_business:buy', 1, 'bar', 'gs_cocktail', 1); step()
check('achat au prix du patron', ok and society.bar == before + 60 and W.players[1].items.gs_cocktail == 1)
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_business:buy', 1, 'bar', 'beer', 1); step()
check('loin du comptoir', not ok)

-- Comptabilité
check('comptes : réservés aux employés', cb('gs_business:books', 1, 'bar') == nil)
local books = cb('gs_business:books', 2, 'bar')
check('comptes : caisse, ventes du jour, journal', books and books.balance == society.bar and books.today == society.bar and #books.ledger >= 3)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
