-- Tests gs_nightcity (V10.2) : marché ouvert seulement la nuit (heure du jeu, 22 h → 5 h), sur place, liquide, menu fixe.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local hour = 23
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_nightcity', { R .. 'gs_nightcity/shared/config.lua', R .. 'gs_nightcity/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local m = Config.Markets[1].coords
join(1, 'CID1', 'Noctambule', vec3(m.x, m.y, m.z)) W.players[1].money.cash = 100
join(2, 'CID2', 'Loin', vec3(0.0, 0.0, 0.0)) W.players[2].money.cash = 100
local function step() advance(11000) end
check('23 h : nuit ; 4 h : nuit ; 12 h : jour', NightCity.isNight(23) and NightCity.isNight(4) and not NightCity.isNight(12))
local ok = cb('gs_nightcity:buy', 1, 1, 'coffee', 2) step()
check('la nuit : achat', ok and W.players[1].items.coffee == 2 and W.players[1].money.cash == 70)
ok = cb('gs_nightcity:buy', 2, 1, 'coffee', 1) step()
check('loin du stand : refusé', not ok)
ok = cb('gs_nightcity:buy', 1, 1, 'WEAPON_PISTOL', 1) step()
check('hors menu : refusé', not ok)
hour = 14
ok = cb('gs_nightcity:buy', 1, 1, 'coffee', 1) step()
check('le jour : fermé', not ok)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
