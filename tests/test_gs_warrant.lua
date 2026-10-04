-- Tests gs_justice · mandat de perquisition (V10.1) : allées et venues → signalement police, demande, juge (ou juge de
-- permanence), perquisition sur place (coffre ouvert, occupants prévenus), fin du mandat.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, opened = {}, {}
provide('gs_jobs', {
    IsOnDutyAs = function(src, job) return duty[src] == job end,
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end,
})
provide('gs_police', {})
provide('ox_inventory', { forceOpenInventory = function(src, t, data) opened[#opened + 1] = { src = src, data = data } end })
provide('gs_gangs', { GetGang = function(src) return src == 5 and 'ballas' or nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_justice', { R .. 'gs_justice/shared/config.lua', R .. 'gs_justice/server/warrant.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local W = Config.Warrant
local stash = vec3(100.0, -1900.0, 21.0)
join(1, 'CID1', 'Agent', vec3(0.0, 0.0, 0.0)) duty[1] = 'police'
join(2, 'CID2', 'Juge', vec3(0.0, 0.0, 0.0))
join(5, 'CID5', 'Ballas', stash)
local notes = {}
for i = 1, W.threshold - 1 do TriggerEvent('gs_justice:server:visit', 'gang:ballas', 'Planque des Ballas', stash, 'gs_gang_ballas', { gang = 'ballas' }) end
check('quelques visites : rien', not Warrant.places['gang:ballas'].suspect)
local ok = cb('gs_justice:warrant', 1, 'request', 'gang:ballas')
check('pas de mandat sans signalement', not ok)
TriggerEvent('gs_justice:server:visit', 'gang:ballas', 'Planque des Ballas', stash, 'gs_gang_ballas', { gang = 'ballas' })
check('trop d\'allées et venues : signalé', Warrant.places['gang:ballas'].suspect)
local l = cb('gs_justice:warrant', 1, 'list')
check('la police voit le signalement', l and #l.places == 1 and l.places[1].key == 'gang:ballas')
check('un civil ne voit rien', cb('gs_justice:warrant', 5, 'list') == nil)
advance(3000)
ok = cb('gs_justice:warrant', 1, 'raid', 'gang:ballas')
check('perquisition sans mandat : refusée', not ok)
-- juge en service
duty[2] = 'judge'
advance(3000)
ok = cb('gs_justice:warrant', 1, 'request', 'gang:ballas')
check('demande transmise au juge', ok and Warrant.requests['gang:ballas'])
advance(3000)
ok = cb('gs_justice:warrant', 1, 'decide', 'gang:ballas', true)
check('un policier ne s\'accorde pas le mandat', not ok)
advance(3000)
ok = cb('gs_justice:warrant', 2, 'decide', 'gang:ballas', true)
check('le juge accorde', ok and Warrant.places['gang:ballas'].warrant)
advance(3000)
ok = cb('gs_justice:warrant', 1, 'raid', 'gang:ballas')
check('perquisition loin : refusée', not ok)
tp(1, stash) advance(3000)
ok = cb('gs_justice:warrant', 1, 'raid', 'gang:ballas')
check('perquisition sur place : coffre ouvert au policier', ok and opened[1] and opened[1].src == 1 and opened[1].data == 'gs_gang_ballas')
-- fin du mandat
Warrant.places['gang:ballas'].warrant.untilAt = os.time() - 1
Warrant.tick()
check('mandat expiré : affaire close', not Warrant.places['gang:ballas'].suspect and not Warrant.places['gang:ballas'].warrant)
-- juge de permanence
duty[2] = nil
for _ = 1, W.threshold do TriggerEvent('gs_justice:server:visit', 'hideout:CID9', 'Chambre au Pink Cage', vec3(313.0, -198.0, 54.0), { id = 'gs_hideout', owner = 'CID9' }, { cid = 'CID9' }) end
advance(3000)
ok = cb('gs_justice:warrant', 1, 'request', 'hideout:CID9')
Warrant.tick()
check('pas encore de mandat automatique', not Warrant.places['hideout:CID9'].warrant)
Warrant.requests['hideout:CID9'].at = os.time() - W.autoMinutes * 60
Warrant.tick()
check('sans juge : le juge de permanence accorde', Warrant.places['hideout:CID9'].warrant ~= nil)
tp(1, vec3(313.0, -198.0, 54.0)) advance(3000)
ok = cb('gs_justice:warrant', 1, 'raid', 'hideout:CID9')
check('chambre de motel : coffre personnel du locataire', ok and opened[2].data.owner == 'CID9')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
