-- Tests gs_hideouts : location (banque, 1 par perso, 4 semaines max), entrée / sortie (monde séparé), coffre, échéance.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local buckets, rows = {}, {}
function SetPlayerRoutingBucket(src, b) buckets[src] = b end
function GetPlayerRoutingBucket(src) return buckets[src] or 0 end
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_hideouts', { R .. 'gs_hideouts/shared/config.lua' })
Store = { init = function() end, get = function(cid) return rows[cid] end, set = function(cid, site, exp) rows[cid] = { site = site, expires = exp } end }
loadResource('gs_hideouts', { R .. 'gs_hideouts/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local P = Config.Sites.pinkcage.entrance
local desk = vec3(P.x, P.y, P.z)
join(1, 'CID1', 'Nouveau', desk)
W.players[1].money.bank = 100

local ok, msg = cb('gs_hideouts:rent', 1, 'pinkcage', 1); step()
check('pas assez en banque', not ok)
W.players[1].money.bank = 5000
ok = cb('gs_hideouts:rent', 1, 'pinkcage', 9); step()
check('trop de semaines', not ok)
ok = cb('gs_hideouts:rent', 1, 'pinkcage', 2); step()
check('location 2 semaines', ok and W.players[1].money.bank == 5000 - 700 and rows.CID1.site == 'pinkcage')
ok, msg = cb('gs_hideouts:rent', 1, 'pinkcage', 3); step()
check('prolongation plafonnée à 4 semaines', not ok and msg:find('maximum'))
ok = cb('gs_hideouts:rent', 1, 'pinkcage', 2); step()
check('prolongation ok', ok and rows.CID1.expires - os.time() >= 27 * 86400)
tp(1, vec3(Config.Sites.sandy.entrance.x, Config.Sites.sandy.entrance.y, Config.Sites.sandy.entrance.z))
ok, msg = cb('gs_hideouts:rent', 1, 'sandy', 1); step()
check('une seule planque', not ok and msg:find('ailleurs'))
ok = cb('gs_hideouts:enter', 1, 'sandy'); step()
check('pas sa chambre', not ok)
tp(1, desk)
check('coffre refusé dehors', cb('gs_hideouts:stash', 1) == false)
ok = cb('gs_hideouts:enter', 1, 'pinkcage'); step()
check('entrée : monde séparé', ok and buckets[1] == Config.BucketBase + 1 and Hideouts.inside[1] == 'pinkcage')
check('coffre dedans', cb('gs_hideouts:stash', 1) == true)
ok = cb('gs_hideouts:exit', 1); step()
check('sortie : monde normal, devant la porte', ok and buckets[1] == 0 and #(W.players[1].pos - desk) < 1.0)
rows.CID1.expires = os.time() - 1
ok, msg = cb('gs_hideouts:enter', 1, 'pinkcage'); step()
check('échéance : accès coupé', not ok and msg:find('reloue'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
