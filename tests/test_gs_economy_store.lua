-- Test du vrai Store.save de gs_economy avec un MySQL simulé.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_economy', { R .. 'gs_economy/shared/config.lua' })
local rows
MySQL = { prepare = function(_, r) rows = r end }
dofile(R .. 'gs_economy/server/store.lua')
Store.save({ water = 0.4 })
local byItem, n = {}, 0
for _, r in ipairs(rows) do byItem[r[1]] = r[2] n = n + 1 end
local items = 0
for _ in pairs(Config.Items) do items = items + 1 end
local ok = n == items and byItem.water == 0.4 and byItem.burger == 0
io.write(ok and '\n1 réussi, 0 échoué\n' or '\nÉCHEC : Store.save doit écrire tous les items\n')
os.exit(ok and 0 or 1)
