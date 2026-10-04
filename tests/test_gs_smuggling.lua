-- Tests gs_smuggling (V8) : conditions (contact, nuit, gang / réputation, délai, places), bateau obligatoire,
-- distances, livraison (argent sale), délai dépassé, radar côtier et garde-côtes.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local hour, gangOf, reported, cops = 23, {}, {}, {}
provide('gs_weather', { GetGameTime = function() return hour end })
provide('gs_gangs', { GetGang = function(src) return gangOf[src] end })
provide('gs_reputation', { Get = function() return { street = 0 } end, Add = function() end })
provide('gs_wanted', { ReportCrime = function(_, crime) reported[#reported + 1] = crime return true end })
provide('gs_jobs', { GetOnDutyPlayers = function() return cops end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_smuggling', { R .. 'gs_smuggling/shared/config.lua', R .. 'gs_smuggling/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local C = Config.Contact
join(1, 'CID1', 'Marin', vec3(C.x, C.y, C.z))
check('inconnu de la rue : refusé', not Smuggling.take(1))
gangOf[1] = 'lostmc'
hour = 14
check('en plein jour : refusé', not Smuggling.take(1))
hour = 23
fixRandom(0.0)
local ok, d = Smuggling.take(1)
check('cargaison confiée', ok and d.pickup and d.drop)
check('une seule à la fois', not Smuggling.take(1))
local pick = Config.Pickups[d.pickup]
tp(1, pick)
check('chargement : bateau obligatoire', not Smuggling.load(1))
local boat = CreateVehicleServerSetter(0, 'boat', pick.x, pick.y, pick.z)
W.entities[boat].vtype = 'boat'
W.players[1].vehicle = boat
check('chargé (radar : alerte + garde-côtes sans police)', Smuggling.load(1) == true and reported[1] == 'smuggling'
    and lastClientEvent('gs_smuggling:client:coastguard', 1) ~= nil)
check('mauvaise plage : refusé', not Smuggling.deliver(1))
tp(1, Config.Drops[d.drop])
W.players[1].vehicle = nil
local cash = W.players[1].money.cash
check('livré : payé en argent sale', Smuggling.deliver(1) == true and (W.players[1].items.black_money or 0) > 0)
tp(1, vec3(C.x, C.y, C.z))
check('délai entre deux cargaisons', not Smuggling.take(1))
advance(Config.Cooldown * 60000 + 1000)
ok, d = Smuggling.take(1)
check('nouvelle cargaison après le délai', ok)
tp(1, Config.Pickups[d.pickup]) W.players[1].vehicle = boat Smuggling.load(1)
advance(Config.Timeout * 60000 + 1000)
tp(1, Config.Drops[d.drop])
check('trop tard : perdue', not Smuggling.deliver(1) and Smuggling.runs[1] == nil)
fixRandom()

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
