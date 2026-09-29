-- Tests gs_builder : permission staff, validation (modèle, position, distance), limite, modif, suppression, planque.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local stash = {}
provide('gs_gangs', {
    SetStash = function(g, c) if g == 'ballas' then stash[g] = c return true end return false end,
    ListGangs = function() return { { name = 'ballas', label = 'Ballas' } } end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_builder', { R .. 'gs_builder/shared/config.lua' })
local rows, nextId = {}, 0
Store = {
    init = function() end, all = function() return {} end,
    insert = function(o) nextId = nextId + 1 rows[nextId] = o return nextId end,
    update = function(id, o) rows[id] = o end,
    delete = function(id) rows[id] = nil end,
    hides = function() return {} end,
    hideInsert = function(h) nextId = nextId + 1 rows[nextId] = h return nextId end,
    hideDelete = function(id) rows[id] = nil end,
}
loadResource('gs_builder', { R .. 'gs_builder/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local here = vec3(100.0, 100.0, 30.0)
local obj = function(t) local o = { model = 'prop_bench_01a', x = 101.0, y = 100.0, z = 30.0, rx = 0.0, ry = 0.0, rz = 90.0 } for k, v in pairs(t or {}) do o[k] = v end return o end

join(1, 'CID1', 'Admin', here); W.players[1].aces = { ['gs.builder'] = true }
join(2, 'CID2', 'Joueur', here)

local ok, id = cb('gs_builder:place', 2, obj()); step()
check('joueur sans permission refusé', not ok and nextId == 0)
check('canUse', cb('gs_builder:canUse', 1) == true and cb('gs_builder:canUse', 2) == false)
ok, id = cb('gs_builder:place', 1, obj()); step()
check('objet placé', ok and Builder.objects[id] and Builder.count == 1)
check('diffusé à tous', lastClientEvent('gs_builder:client:set', -1).args[1].id == id)
for name, bad in pairs({
    ['modèle injection'] = obj({ model = "prop'; DROP TABLE" }),
    ['modèle vide'] = obj({ model = '' }),
    ['position NaN'] = obj({ x = 0 / 0 }),
    ['position texte'] = obj({ y = 'abc' }),
    ['trop loin'] = obj({ x = 900.0 }),
    ['position énorme'] = obj({ z = 1e9 }),
}) do
    ok = cb('gs_builder:place', 1, bad); step()
    check('refusé : ' .. name, not ok)
end
ok = cb('gs_builder:place', 1, 'pas une table'); step()
check('refusé : données invalides', not ok)
ok = cb('gs_builder:place', 1, obj({ rz = 450.0 })); step()
check('rotation normalisée', ok and Builder.objects[nextId].rz == 90.0)

-- Modification : le modèle ne peut pas être changé par le client
ok = cb('gs_builder:update', 1, id, obj({ model = 'prop_bomb', x = 102.0 })); step()
check('déplacé, modèle conservé', ok and Builder.objects[id].x == 102.0 and Builder.objects[id].model == 'prop_bench_01a')
ok = cb('gs_builder:update', 2, id, obj()); step()
check('modif sans permission refusée', not ok)
ok = cb('gs_builder:update', 1, 999, obj()); step()
check('objet inconnu', not ok)

-- Limite
Config.MaxObjects = Builder.count
ok = cb('gs_builder:place', 1, obj()); step()
check('limite d\'objets', not ok)
Config.MaxObjects = 3000

-- Suppression
ok = cb('gs_builder:delete', 2, id); step()
check('suppression sans permission refusée', not ok and Builder.objects[id])
ok = cb('gs_builder:delete', 1, id); step()
check('supprimé + diffusé', ok and not Builder.objects[id] and lastClientEvent('gs_builder:client:remove', -1).args[1] == id)

-- Planque de gang à la position du staff
ok = cb('gs_builder:setStash', 1, 'ballas'); step()
check('planque placée à la position du staff', ok and stash.ballas and #(stash.ballas - here) < 0.01)
ok = cb('gs_builder:setStash', 1, 'inconnu'); step()
check('gang inconnu', not ok)
ok = cb('gs_builder:setStash', 2, 'ballas'); step()
check('planque : permission requise', not ok)

-- Objets de la map d'origine retirés (poubelle…)
ok = cb('gs_builder:hide', 2, { hash = 123456, x = 101.0, y = 100.0, z = 30.0 }); step()
check('retrait map : permission requise', not ok and Builder.hideCount == 0)
ok = cb('gs_builder:hide', 1, { hash = 1.5, x = 101.0, y = 100.0, z = 30.0 }); step()
check('retrait map : hash non entier refusé', not ok)
ok = cb('gs_builder:hide', 1, { hash = -1234567, x = 900.0, y = 100.0, z = 30.0 }); step()
check('retrait map : trop loin', not ok)
ok = cb('gs_builder:hide', 1, { hash = -1234567, x = 101.0, y = 100.0, z = 30.0 }); step()
local hev = lastClientEvent('gs_builder:client:hide', -1)
check('retrait map : diffusé à tous', ok and Builder.hideCount == 1 and hev and hev.args[1].hash == -1234567)
local hid = hev.args[1].id
check('retrait map : listé', #cb('gs_builder:hides', 2) == 1)
ok = cb('gs_builder:unhide', 1, hid); step()
check('objet de la map remis', ok and Builder.hideCount == 0 and lastClientEvent('gs_builder:client:unhide', -1).args[1].id == hid)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
