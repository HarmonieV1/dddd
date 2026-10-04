-- Tests gs_city · le quartier évolue (V10) : ventes → essor, crimes / tags / trafics → déclin, brèves Weazel au
-- changement de niveau, nettoyage payé (seulement en déclin, près du tas, plafonné), recette des commerces, dérive vers 0.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local news = {}
provide('gs_social', { Newsroom = function(id, text) news[#news + 1] = text end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/standing.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local south = vec3(100.0, -1750.0, 30.0)
local vesp = vec3(-1300.0, -1100.0, 10.0)

check('quartier neuf : ordinaire', getExport('gs_city', 'GetStanding')(south) == 3 and getExport('gs_city', 'SalesFactor')(south) == 1.0)
TriggerEvent('gs_jobs:server:revenue', 'bar', 1000, vesp)
check('ventes : +20 points', math.abs(Standing.value.vespucci - 20) < 0.01)
TriggerEvent('gs_jobs:server:revenue', 'bar', 1000, vesp)
check('ventes : le quartier passe « en plein essor », brève Weazel', Standing.level(Standing.value.vespucci) == 4 and news[#news]:find('essor'))
check('commerces d\'un quartier en essor : +5 % de recette', getExport('gs_city', 'SalesFactor')(vesp) == 1.05)
for _ = 1, 6 do TriggerEvent('gs_wanted:server:reported', 1, 'store_robbery', 30, south) end
check('braquages répétés : en déclin', Standing.level(Standing.value.south) == 2 and getExport('gs_city', 'SalesFactor')(south) == 0.95)
for _ = 1, 8 do TriggerEvent('gs_gangs:server:tagged', 'ballas', south, true) end
for _ = 1, 5 do TriggerEvent('gs_gangs:server:activity', 'ballas', 'fence', south, 3) end
check('tags et trafics : à l\'abandon', Standing.level(Standing.value.south) == 1 and GlobalState.gsStanding.south == 1)
local before = Standing.value.south
TriggerEvent('gs_scars:server:repaired', south)
check('vitrine réparée : le quartier remonte', Standing.value.south > before)

-- Nettoyage
join(1, 'CID1', 'Balayeur', south)
local ok = cb('gs_city:clean', 1, 100.0, -1750.0, 30.0)
check('ramasser des déchets : payé, standing +', ok and W.players[1].money.bank > 0)
advance(9000)
ok = cb('gs_city:clean', 1, 300.0, -1750.0, 30.0)
check('loin du tas : refusé', not ok)
advance(9000)
tp(1, vesp)
ok = cb('gs_city:clean', 1, vesp.x, vesp.y, vesp.z)
check('quartier propre : rien à nettoyer', not ok)
tp(1, south)
Standing.cleaned.CID1 = {}
for _ = 1, Config.Standing.cleanPerHour do table.insert(Standing.cleaned.CID1, os.time()) end
advance(9000)
ok = cb('gs_city:clean', 1, south.x, south.y, south.z)
check('plafond par heure', not ok)

-- Dérive
Standing.value.paleto = 0.5
for _ = 1, 60 do Standing.drift() end
check('retour vers 0 avec le temps', Standing.value.paleto == nil)
local st = cb('gs_city:status', 1)
local found
for _, d in ipairs(st) do if d.label == 'South Los Santos' then found = d end end
check('/quartiers et appli Ville : standing affiché', found and found.standing == 'à l\'abandon')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
