-- Tests gs_heists : conditions (arme, police, distance, cooldown), alarme / signalement, durée non sautable,
-- butin et bonus (nuit, duo, territoire), fin de braquage, argent sale.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police, reports = {}, {}
provide('gs_jobs', {
    GetOnDutyPlayers = function() return police end,
    IsOnDutyAs = function(src) for _, p in ipairs(police) do if p == src then return true end end return false end,
})
provide('gs_wanted', { ReportCrime = function(src, crime, _, opts) reports[#reports + 1] = { src = src, crime = crime, alarm = opts and opts.alarm } return true end })
local hour, event, duoBonus, gang, owner, influence = 14, nil, 1.0, nil, nil, 0
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end, GetEvent = function() return event end })
provide('gs_duo', { GetPayBonus = function() return duoBonus end })
provide('gs_gangs', {
    GetGang = function() return gang end, GetTerritoryAt = function() return 'grove' end,
    GetTerritoryOwner = function() return owner end, AddInfluence = function(_, _, n) influence = influence + n return true end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_heists', { R .. 'gs_heists/shared/config.lua', R .. 'gs_heists/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local store = Config.Sites.store_strawberry
local jewelry = Config.Sites.jewelry

join(1, 'CID1', 'Braqueur', store.points[1])
join(9, 'CID9', 'Agent', vec3(0.0, 0.0, 0.0))

local ok, msg = cb('gs_heists:begin', 1, 'store_strawberry', 1); step()
check('sans arme : refusé', not ok and msg:find('arme'))
W.players[1].weapon = GetHashKey('WEAPON_PISTOL')
ok, msg = cb('gs_heists:begin', 1, 'store_strawberry', 1); step()
check('pas assez de police : refusé', not ok and msg:find('policiers'))
police = { 9 }
ok = cb('gs_heists:begin', 9, 'store_strawberry', 1); step()
check('policier en service ne braque pas', not ok)
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_heists:begin', 1, 'store_strawberry', 1); step()
check('trop loin : refusé', not ok)
tp(1, store.points[1])
ok = cb('gs_heists:begin', 1, 'store_strawberry', 9); step()
check('point inexistant refusé', not ok)

-- Braquage normal
fixRandom(0.0)
ok, msg = cb('gs_heists:begin', 1, 'store_strawberry', 1)
check('braquage lancé', ok and msg == store.action)
check('crime signalé avec alarme', #reports == 1 and reports[1].crime == 'store_robbery' and reports[1].alarm == true)
ok = cb('gs_heists:finish', 1)
check('barre de progression non sautable', not ok)
ok = cb('gs_heists:begin', 1, 'store_strawberry', 1); step()
advance(store.action)
W.players[1].money.cash = 0
ok, msg = cb('gs_heists:finish', 1)
check('butin versé en argent sale', ok and W.players[1].items.black_money == store.reward[1] and W.players[1].money.cash == 0)
check('caisse vidée → braquage fini + cooldown', Heists.sessions.store_strawberry == nil and Heists.cooldowns.store_strawberry)
step()
ok, msg = cb('gs_heists:begin', 1, 'store_strawberry', 1); step()
check('cooldown : refusé', not ok and msg:find('récemment'))
fixRandom()

-- Bijouterie : plusieurs vitrines, bonus nuit + duo + territoire, argent sale
police = { 9, 10, 11 }
tp(1, jewelry.points[1])
ok = cb('gs_heists:begin', 1, 'jewelry', 1); step()
check('3 policiers requis pour la bijouterie', ok)
Heists.pending[1] = nil; Heists.sessions.jewelry = nil
hour, duoBonus, gang, owner = 23, 1.2, 'ballas', 'ballas'
W.players[1].items = {}
fixRandom(0.0)
ok = cb('gs_heists:begin', 1, 'jewelry', 1)
advance(jewelry.action)
ok, msg = cb('gs_heists:finish', 1)
local expected = math.floor(jewelry.reward[1] * Config.Bonus.night * 1.2 * Config.Bonus.ownTerritory)
check('bonus nuit × duo × territoire', ok and W.players[1].items.black_money == expected)
check('argent sale donné', msg:find('argent sale') ~= nil)
check('influence gagnée pour le gang', influence == Config.Bonus.influence)
check('bijouterie pas finie : il reste des vitrines', Heists.sessions.jewelry ~= nil and msg:find('encore'))
step()
ok = cb('gs_heists:begin', 1, 'jewelry', 1); step()
check('vitrine déjà vidée', not ok)
tp(1, jewelry.points[2])
ok = cb('gs_heists:begin', 1, 'jewelry', 2)
tp(1, vec3(0.0, 0.0, 0.0))
advance(jewelry.action)
ok, msg = cb('gs_heists:finish', 1); step()
check('s\'éloigner pendant l\'action annule', not ok)
fixRandom()

-- Timeout de session
advance(Config.SessionTimeout * 1000 + 1000)
tp(1, jewelry.points[3])
ok = cb('gs_heists:begin', 1, 'jewelry', 3); step()
check('session expirée → cooldown', not ok and Heists.cooldowns.jewelry)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
