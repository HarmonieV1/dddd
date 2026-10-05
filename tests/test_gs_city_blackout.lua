-- Tests gs_city · black-out de quartier (V11.2) : sabotage (outil, distance, police, caméras, tension), un seul à la fois,
-- délai de 2 h, réparation payée mais jamais au saboteur, retour automatique du courant.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local blinded, crimes, news = {}, {}, {}
provide('gs_cctv', { BlindArea = function(x, y, r, m) blinded[#blinded + 1] = { x, y, r, m } return 2 end })
provide('gs_wanted', { ReportCrime = function(src, kind, c) crimes[#crimes + 1] = kind return true end })
provide('gs_social', { Newsroom = function(kind, text) news[#news + 1] = text return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/blackout.lua' })
local passed, failed = 0, 0
local function addItem(src, item, n) W.players[src].items[item] = (W.players[src].items[item] or 0) + n end
local function itemCount(src, item) return W.players[src].items[item] or 0 end
local function moneyOf(src, acc) return W.players[src].money[acc] end
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local tr = Config.Blackout.transformers.south.coords
join(1, 'CID1', 'Saboteur', tr)
join(2, 'CID2', 'Electricien', tr)
join(3, 'CID3', 'Loin', vec3(tr.x + 500.0, tr.y, tr.z))
check('sans outil : refusé', not Blackout.sabotage(1, 'south'))
addItem(1, Config.Blackout.item, 2); addItem(3, Config.Blackout.item, 1)
check('trop loin : refusé', not Blackout.sabotage(3, 'south'))
local ok = Blackout.sabotage(1, 'south')
check('sabotage réussi', ok and Blackout.isOn('south') and (GlobalState.gsBlackout or {}).south ~= nil)
check('outil consommé', itemCount(1, Config.Blackout.item) == 1)
check('caméras du quartier aveuglées + police prévenue', #blinded == 1 and crimes[1] == 'racket')
check('brève Weazel', news[1] and news[1]:find('Panne de courant', 1, true) ~= nil)
check('tension du quartier en hausse', (City.heat.south or 0) > 0)
check('déjà dans le noir : refusé', not Blackout.sabotage(1, 'south'))
check('le saboteur ne peut pas réparer', not Blackout.repair(1, 'south'))
local before = moneyOf(2, 'bank')
check('réparation payée par la mairie', Blackout.repair(2, 'south') and moneyOf(2, 'bank') > before and not Blackout.isOn('south'))
check('délai de 2 h avant un nouveau sabotage', not Blackout.sabotage(1, 'south'))
Blackout.last.east = nil
local etr = Config.Blackout.transformers.east.coords
join(4, 'CID4', 'Autre', etr); addItem(4, Config.Blackout.item, 1)
Blackout.sabotage(4, 'east')
advance((Config.Blackout.minutes * 60 + 31) * 1000)
for id, t2 in pairs(Blackout.active) do if t2 <= os.time() then Blackout.restore(id) end end -- ce que fait la boucle de 30 s
check('retour automatique du courant', not Blackout.isOn('east'))
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
