-- Tests tendances Vibe : seuil d'auteurs distincts, fenêtre de temps, cooldown, effets (rassemblement + présence XP,
-- promo commerces, courses gratuites), fin du rassemblement.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local promo, free, xp = nil, nil, 0
provide('gs_economy', { SetPromo = function(f, s) promo = { f, s } return true end })
provide('gs_races', { SetFreeEntry = function(s) free = s return true end })
provide('gs_quests', { AddXP = function(_, n) xp = xp + n return 1 end, GetTitle = function() return nil end })
provide('gs_jobs', { IsOnDutyAs = function() return false end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_social', { R .. 'gs_social/shared/config.lua', R .. 'gs_social/server/trends.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local T = Config.Trends

for i = 1, T.promo.authors - 1 do Trends.onPost('C' .. i, 'Qui veut des soldes ? #promo') end
check('sous le seuil : rien', promo == nil)
Trends.onPost('C1', 'encore #promo #PROMO')
check('même auteur : ne compte qu\'une fois', promo == nil)
advance((Config.TrendWindow + 10) * 1000)
Trends.onPost('C9', '#promo')
check('fenêtre dépassée : anciens posts oubliés', promo == nil)
for i = 10, 10 + T.promo.authors - 2 do Trends.onPost('C' .. i, 'Les prix ! #Promo') end
check('seuil atteint : promo lancée', promo and promo[1] == T.promo.factor and promo[2] == T.promo.duration)
promo = nil
for i = 20, 20 + T.promo.authors do Trends.onPost('C' .. i, '#promo') end
check('cooldown : pas de 2e promo', promo == nil)

for i = 1, T.course.authors do Trends.onPost('R' .. i, 'Qui est chaud ? #course') end
check('#course : mise gratuite', free == T.course.duration)

join(1, 'CID1', 'Fêtard', vec3(0.0, 0.0, 0.0))
for i = 1, T.rassemblement.authors do Trends.onPost('G' .. i, 'On se retrouve ? #rassemblement') end
local g = Trends.gathering
check('#rassemblement : point publié pour tous', g and GlobalState.gsVibeGathering and GlobalState.gsVibeGathering.label == g.label)
local ok = cb('gs_social:attend', 1)
check('loin du point : pas compté', not ok)
tp(1, g.coords.coords)
ok = cb('gs_social:attend', 1); advance(11000)
check('présent : XP', ok and xp == T.rassemblement.xp)
ok = cb('gs_social:attend', 1); advance(11000)
check('présence comptée une fois', not ok and xp == T.rassemblement.xp)
advance((T.rassemblement.duration + 60) * 1000)
Trends.tick()
check('fin : point retiré', GlobalState.gsVibeGathering == nil and Trends.gathering == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
