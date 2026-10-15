-- Tests gs_cimetiere (V12.60) : tombe posée par le staff (carré ou ici), avis de décès (Weazel + Gazette), mort RP d'un joueur
-- (nom du personnage), fleurs payées et limitées, retrait, sauvegarde (KVP), jamais pour un joueur sans rang.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local kvp = {}
function SetResourceKvp(k, v) kvp[k] = v end
function GetResourceKvpString(k) return kvp[k] end
function GetEntityHeading() return 90.0 end
local levels, news, buried = { [1] = 4 }, {}, {}
provide('gs_admin', { GetStaffLevel = function(src) return levels[src] or 0 end })
provide('gs_social', { Newsroom = function(kind, text) news[#news + 1] = { kind = kind, text = text } return true end })
local realState = GetResourceState
function GetResourceState(r) if r == 'gs_admin' or r == 'gs_social' then return 'started' end return realState and realState(r) or 'missing' end
AddEventHandler('gs_cimetiere:server:buried', function(name, ep) buried[#buried + 1] = { name, ep } end)
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_cimetiere', { R .. 'gs_cimetiere/shared/config.lua', R .. 'gs_cimetiere/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end

join(1, 'STAFF1', 'Admin Test', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Lucie Martin', vec3(10.0, 0.0, 0.0))
local ok, msg = cb('gs_cimetiere:staff', 2, 'bury', { name = 'Quelqu\'un', epitaph = 'x' })
check('joueur sans rang : refusé', not ok and #(GlobalState.gsGraves or {}) == 0)
ok, msg = cb('gs_cimetiere:staff', 1, 'bury', { name = 'Jean Dupont', epitaph = 'Il aimait la route.' })
local g = (GlobalState.gsGraves or {})[1]
check('tombe posée au premier emplacement du carré', ok and g and g.name == 'Jean Dupont' and math.abs(g.x - Config.Origin.x) < 0.01)
check('avis de décès : Weazel + événement pour la Gazette', news[1] and news[1].text:find('Jean Dupont') and buried[1] and buried[1][1] == 'Jean Dupont')
check('fleurs du jour de l\'enterrement', g.flowers == true)
ok = cb('gs_cimetiere:staff', 1, 'bury', { name = 'Paul', epitaph = '' })
local g2 = GlobalState.gsGraves[2]
check('2e tombe : emplacement suivant (2,6 m plus loin)', ok and g2 and math.abs(#(vec3(g2.x, g2.y, g2.z) - vec3(g.x, g.y, g.z)) - Config.Grid.gap) < 0.01)
ok = cb('gs_cimetiere:staff', 1, 'player', { target = 2, epitaph = 'Repose en paix.' })
check('mort RP d\'un joueur : nom du personnage', ok and GlobalState.gsGraves[3].name == 'Lucie Martin')
ok = cb('gs_cimetiere:staff', 1, 'bury', { name = 'Ici', here = true })
check('tombe « ici » : à la position du staff', ok and GlobalState.gsGraves[4].x == 0.0)
-- Fleurs
tp(2, vec3(g.x, g.y, g.z))
ok, msg = cb('gs_cimetiere:flowers', 2, g.id)
check('fleurs sans liquide : refusé', not ok and msg:find('liquide'))
W.players[2].money.cash = 100
ok = cb('gs_cimetiere:flowers', 2, g.id)
check('fleurs : payées 25 $', ok and W.players[2].money.cash == 100 - Config.FlowerPrice)
ok, msg = cb('gs_cimetiere:flowers', 2, g.id)
check('fleurs : pas deux fois de suite', not ok and W.players[2].money.cash == 100 - Config.FlowerPrice)
tp(2, vec3(500.0, 0.0, 0.0))
advance(Config.FlowerCooldown * 1000 + 1000)
ok, msg = cb('gs_cimetiere:flowers', 2, g.id)
check('fleurs : il faut être à côté', not ok and msg:find('Approche'))
-- Sauvegarde et retrait
check('tombes sauvegardées (KVP)', kvp.graves ~= nil)
ok = cb('gs_cimetiere:staff', 1, 'remove', { id = g2.id })
check('retrait : la tombe disparaît', ok and #GlobalState.gsGraves == 3)
ok = cb('gs_cimetiere:staff', 1, 'bury', { name = 'Remplaçant' })
check('emplacement libéré réutilisé', ok and math.abs(GlobalState.gsGraves[#GlobalState.gsGraves].x - g2.x) < 0.01)
local long = string.rep('é', 60)
ok = cb('gs_cimetiere:staff', 1, 'bury', { name = long })
check('nom accentué coupé à 40 caractères (pas au milieu d\'un accent)', ok and utf8.len(GlobalState.gsGraves[#GlobalState.gsGraves].name) == Config.Max.name)

io.write(('cimetière : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
