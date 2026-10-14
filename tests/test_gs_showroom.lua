-- Tests gs_showroom (V12.40, V12.41 : achat sorti avec clés, staff) : véhicules d'exposition posés par le staff, modèle changé par le vendeur, essai, achat.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local rows, starts, nextId = {}, {}, 0
MySQL = {
    ready = function(f) f() end,
    query = { await = function(sql) if sql:find('FROM gs_showroom_slots') then return {} end if sql:find('FROM gs_showroom_starts') then return {} end return {} end },
    insert = { await = function(sql, p) nextId = nextId + 1 rows[nextId] = p return nextId end },
    update = { await = function(sql, p) if sql:find('REPLACE INTO gs_showroom_starts') then starts[p[1]] = p end return 1 end },
}
local levels, duty, society = {}, {}, {}
provide('gs_admin', { GetStaffLevel = function(src) return levels[src] or 0 end })
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end,
    AddSocietyMoney = function(job, n) society[job] = (society[job] or 0) + n return true end })
provide('qbx_core', { GetVehiclesByName = function() return {
    sultan = { name = 'Sultan', brand = 'Karin', price = 40000, category = 'sports' },
    police = { name = 'Police', price = 1, category = 'emergency' },
} end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_showroom', { R .. 'gs_showroom/shared/config.lua', R .. 'gs_showroom/server/main.lua' })
local positions = {}
function GetEntityCoords(ent) if ent and ent > 1000 and ent < 2000 then return W.players[ent - 1000].pos end return W.entities[ent] and vec3(W.entities[ent].x or 0, W.entities[ent].y or 0, W.entities[ent].z or 0) or vec3(0, 0, 0) end
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local spot = vec3(100.0, 200.0, 30.0)

join(1, 'CID1', 'Admin', spot)
join(2, 'CID2', 'Client', spot)
join(3, 'CID3', 'Vendeur', spot)
local ok, msg = cb('gs_showroom:staff', 1, 'add', { dealer = 'patoche', model = 'sultan' }); step()
check('non staff : refusé', not ok)
levels[1] = 4
ok, msg = cb('gs_showroom:staff', 1, 'add', { dealer = 'patoche', model = 'police' }); step()
check('véhicule de service : pas exposable', not ok)
ok, msg = cb('gs_showroom:staff', 1, 'add', { dealer = 'nulle_part', model = 'sultan' }); step()
check('concession inconnue', not ok)
ok, msg = cb('gs_showroom:staff', 1, 'add', { dealer = 'patoche', model = 'sultan' }); step()
check('véhicule exposé à la position du staff', ok and Showroom.slots[1] and Showroom.slots[1].model == 'sultan' and Showroom.slots[1].x == spot.x)
check('publié pour les joueurs', GlobalState.gsShowroom and #GlobalState.gsShowroom.slots == 1)

ok, msg = cb('gs_showroom:setModel', 2, 1, 'sultan'); step()
check('client : ne peut pas changer le modèle', not ok)
duty[3] = 'cardealer'
ok = cb('gs_showroom:setModel', 3, 1, 'police'); step()
check('vendeur : modèle exclu refusé', not ok)
ok = cb('gs_showroom:setModel', 3, 1, 'sultan'); step()
check('vendeur en service : modèle changé', ok)
tp(3, vec3(900.0, 900.0, 30.0))
ok = cb('gs_showroom:setModel', 3, 1, 'sultan'); step()
check('vendeur loin : refusé', not ok)
tp(1, vec3(900.0, 900.0, 30.0))
ok = cb('gs_showroom:setModel', 1, 1, 'sultan'); step()
check('V12.41 : staff change le modèle de loin (F11)', ok)
ok = cb('gs_showroom:staff', 1, 'move', { id = 1 }); step()
check('V12.41 : emplacement replacé à la position du staff', ok and Showroom.slots[1].x == 900.0)
tp(1, spot)
cb('gs_showroom:staff', 1, 'move', { id = 1 }); step()
check('client : pas staff', cb('gs_showroom:me', 2) == false and cb('gs_showroom:me', 1) == true)

ok, msg = cb('gs_showroom:test', 2, 1); step()
check('essai refusé sans départ posé', not ok and msg:find('départ'))
cb('gs_showroom:staff', 1, 'start', { dealer = 'patoche' }); step()
tp(2, vec3(500.0, 500.0, 30.0))
ok = cb('gs_showroom:test', 2, 1); step()
check('essai : il faut être à côté', not ok)
tp(2, spot)
ok, msg = cb('gs_showroom:test', 2, 1); step()
check('essai lancé', ok and Showroom.testing[2] ~= nil)
local testVeh = Showroom.testing[2] and Showroom.testing[2].veh
ok = cb('gs_showroom:test', 2, 1); step()
check('un seul essai à la fois', not ok)
tp(2, vec3(150.0, 250.0, 30.0))
cb('gs_showroom:stopTest', 2); step()
check('fin d\'essai : véhicule retiré, joueur ramené', Showroom.testing[2] == nil and not DoesEntityExist(testVeh) and #(W.players[2].pos - spot) < 0.1)

W.players[2].money.bank, W.players[2].money.cash = 1000, 0
ok, msg = cb('gs_showroom:buy', 2, 1); step()
check('achat refusé sans argent', not ok and W.players[2].money.bank == 1000)
W.players[2].money.bank = 50000
ok, msg = cb('gs_showroom:buy', 2, 1); step()
check('achat : payé, véhicule à son nom', ok and W.players[2].money.bank == 10000 and (W.players[2].vehicles or 0) == 1)
check('V12.41 : sorti au départ des essais, plaque annoncée', W.players[2].lastOut and W.players[2].lastOut.x == spot.x and msg:find('GS000001') and msg:find('clés'))
check('commission à la caisse de la concession', society.cardealer == 4000)
ok = cb('gs_showroom:staff', 1, 'remove', { id = 1 }); step()
check('emplacement retiré', ok and Showroom.slots[1] == nil and #GlobalState.gsShowroom.slots == 0)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
