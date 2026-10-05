-- Tests gs_rumors · rumeurs qui deviennent vraies (V10.2) : au comptoir seulement, payant, une voix par personne,
-- seuil de voix différentes → staff prévenu, validation / refus, la ville tranche seule, sac de billets à un seul gagnant.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local storm, staffMsg, news = 0, {}, {}
provide('gs_weather', { StartEvent = function(id) if id == 'storm' then storm = storm + 1 end return true end })
provide('gs_admin', { NotifyStaff = function(m) staffMsg[#staffMsg + 1] = m return true end, GetStaffLevel = function(src) return src == 9 and 3 or 0 end })
provide('gs_social', { Newsroom = function(_, t) news[#news + 1] = t return true end })
provide('gs_lsradio', { Say = function() end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_rumors', { R .. 'gs_rumors/shared/config.lua', R .. 'gs_rumors/server/main.lua', R .. 'gs_rumors/server/seeds.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local S = Config.Seeds
local bar = Config.Tellers[2].coords
local function step() advance(11000) end
for i = 1, 4 do join(i, 'CID' .. i, 'Client ' .. i, vec3(bar.x, bar.y, bar.z)) W.players[i].money.cash = 500 end
join(5, 'CID5', 'Loin', vec3(0.0, 0.0, 0.0)) W.players[5].money.cash = 500
join(9, 'CID9', 'Staff', vec3(0.0, 0.0, 0.0))

local ok = cb('gs_rumors:seed', 5, 'storm', 2) step()
check('loin du comptoir : refusé', not ok)
ok = cb('gs_rumors:seed', 1, 'storm', 2) step()
check('bruit lancé et payé', ok and W.players[1].money.cash == 500 - S.price)
ok = cb('gs_rumors:seed', 1, 'storm', 2) step()
check('une seule voix par personne', not ok)
cb('gs_rumors:seed', 2, 'storm', 2) step()
check('sous le seuil : rien', not Seeds.ready.storm)
cb('gs_rumors:seed', 3, 'storm', 2) step()
check('seuil atteint : staff prévenu', Seeds.ready.storm and #staffMsg == 1)
Seeds.realize('storm', 'Staff')
check('validée : la tempête arrive vraiment + brève', storm == 1 and #news >= 1)
ok = cb('gs_rumors:seed', 4, 'storm', 2) step()
check('juste après : on n\'en reparle pas', not ok)

-- Sans réponse du staff : la ville tranche
for i = 1, 3 do cb('gs_rumors:seed', i, 'stash', 2) step() end
check('sac : rumeur prête', Seeds.ready.stash ~= nil)
os.time = (function(t) return function() return t() + S.autoAfter + 1 end end)(os.time)
Seeds.tick()
check('sans staff : réalisée seule, sac caché', Seeds.stash ~= nil and GlobalState.gsRumorStash ~= nil)
local spot = Seeds.stash.coords
ok = cb('gs_rumors:stash', 5) step()
check('sac : trop loin', not ok)
tp(5, vec3(spot.x + 1.0, spot.y, spot.z))
ok = cb('gs_rumors:stash', 5) step()
check('sac : trouvé (argent sale)', ok and (W.players[5].items.black_money or 0) >= S.stash.reward[1])
tp(4, vec3(spot.x, spot.y, spot.z))
ok = cb('gs_rumors:stash', 4) step()
check('sac : un seul gagnant', not ok)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
