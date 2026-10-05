-- Tests gs_places (V10.2) : coiffeur payé au comptoir seulement (liquide puis banque), vendeurs déclarés pour les braquages.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
MySQL = { query = { await = function() return {} end }, insert = { await = function() return 1 end } }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_places', { R .. 'gs_places/shared/config.lua', R .. 'gs_places/shared/stores.lua', R .. 'gs_places/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local barber
for _, s in ipairs(AppearanceStores) do if s[1] == 'barber' then barber = s[2] break end end
join(1, 'CID1', 'Client', vec3(barber.x, barber.y, barber.z)) W.players[1].money.cash = 1000
join(2, 'CID2', 'Loin', vec3(0.0, 0.0, 0.0)) W.players[2].money.cash = 1000
local ok = cb('gs_places:barber', 2) advance(11000)
check('coiffeur : hors du salon refusé', not ok and W.players[2].money.cash == 1000)
ok = cb('gs_places:barber', 1) advance(11000)
check('coiffeur : payé en liquide', ok and W.players[1].money.cash == 1000 - Config.Barber.price)
W.players[1].money.cash, W.players[1].money.bank = 0, 500
ok = cb('gs_places:barber', 1) advance(11000)
check('coiffeur : sinon banque', ok and W.players[1].money.bank == 500 - Config.Barber.price)
W.players[1].money.bank = 0
ok = cb('gs_places:barber', 1) advance(11000)
check('coiffeur : sans argent refusé', not ok)
local vendors = getExport('gs_places', 'GetVendors')()
check('vendeurs déclarés (coiffeurs, vêtements, tatoueurs)', #vendors == #AppearanceStores and vendors[1].coords ~= nil)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
