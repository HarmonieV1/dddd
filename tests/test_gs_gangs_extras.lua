-- Tests gs_gangs (extras) : tags (limite, distance, bombe, influence, effacement), garage du gang, receleur.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function SetVehicleColours(veh, a) W.entities[veh].paint = a end
provide('gs_jobs', { IsOnDutyAs = function() return false end })
local hour = 23
provide('gs_weather', { GetGameTime = function() return hour, 0 end })
local reports = 0
provide('gs_wanted', { ReportCrime = function() reports = reports + 1 return true end })
provide('gs_drugs', { GetSellables = function() return { { id = 'weed', label = 'Cannabis', item = 'weed_bag', price = { 70, 120 } } } end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua' })
Config.DefaultGangs = {}
local gangs, members = {}, {}
Store = {
    init = function() end, gangs = function() return { { name = 'ballas', label = 'Ballas', color = 27 }, { name = 'vagos', label = 'Vagos', color = 46 } } end,
    territories = function() return {} end, saveTerritories = function() end,
    createGang = function() return true end, setStash = function() end, deleteGang = function() end,
    addMoney = function() return true end, removeMoney = function() return true end, money = function() return 0 end,
    member = function(cid) return members[cid] end, members = function() return {} end, countMembers = function() return 0 end,
    addMember = function(cid, g, grade) members[cid] = { gang = g, grade = grade } return true end,
    setGrade = function() end, removeMember = function(cid) members[cid] = nil return true end,
}
local tagRows, nextTag = {}, 0
TagsStore = {
    init = function() end, all = function() return {} end,
    insert = function(g, c) nextTag = nextTag + 1 tagRows[nextTag] = g return nextTag end,
    delete = function(id) tagRows[id] = nil end,
}
loadResource('gs_gangs', { R .. 'gs_gangs/server/main.lua', R .. 'gs_gangs/server/extras.lua' })
Gangs.init()
Extras.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local grove = Config.Territories.grove.center
members.CID1 = { gang = 'ballas', grade = 3 }
members.CID2 = { gang = 'vagos', grade = 0 }
join(1, 'CID1', 'Ballas Chef', grove)
join(2, 'CID2', 'Vagos Recrue', grove)
join(3, 'CID3', 'Civil', grove)

-- Tags
local function spot(dx) return { x = grove.x + dx, y = grove.y, z = grove.z } end
local ok, msg = cb('gs_gangs:tag', 3, spot(1)); step()
check('civil : pas de tag', not ok)
ok, msg = cb('gs_gangs:tag', 1, spot(1)); step()
check('bombe requise', not ok and msg:find('bombe'))
W.players[1].items.spraycan = 3
ok = cb('gs_gangs:tag', 1, spot(40)); step()
check('mur trop loin', not ok)
ok = cb('gs_gangs:tag', 1, spot(1)); step()
check('tag posé, bombe utilisée, publié', ok and W.players[1].items.spraycan == 2 and #GlobalState.gsTags == 1 and GlobalState.gsTags[1].label == 'Ballas')
check('influence gagnée', Gangs.territories.grove.influence.ballas == Config.Tags.influence)
tp(1, vec3(grove.x + 10.0, grove.y, grove.z))
ok, msg = cb('gs_gangs:tag', 1, spot(11)); step()
check('trop près d\'un autre tag', not ok and msg:find('côté'))
Config.Tags.maxPerGang = 1
tp(1, vec3(grove.x + 60.0, grove.y, grove.z))
ok = cb('gs_gangs:tag', 1, spot(61)); step()
check('limite par gang', not ok)
Config.Tags.maxPerGang = 15
-- Effacement par un rival
local id = GlobalState.gsTags[1].id
tp(2, vec3(grove.x + 1.0, grove.y, grove.z))
ok = cb('gs_gangs:eraseTag', 2, id); step()
check('tag effacé par un rival, influence retirée', ok and #GlobalState.gsTags == 0 and Gangs.territories.grove.influence.ballas == 0)
check('gang prévenu', W.notes[1] and W.notes[1].msg:find('effacé'))

-- Garage
tp(1, grove)
ok = cb('gs_gangs:garage', 1, 1); step()
check('garage : trop loin', not ok)
local g = Config.GangGarages.ballas.garage
tp(1, vec3(g.x, g.y, g.z))
ok = cb('gs_gangs:garage', 1, 1); step()
local veh = Extras.vehicles[1]
check('véhicule du gang sorti aux couleurs', ok and veh and W.entities[veh].paint == Config.GangGarages.ballas.paint)
ok = cb('gs_gangs:garage', 1, 2); step()
check('un seul véhicule à la fois', not ok)
ok = cb('gs_gangs:garageStore', 1); step()
check('véhicule rangé', ok and not W.entities[veh])
ok = cb('gs_gangs:garage', 3, 1); step()
check('civil : pas de garage', not ok)

-- Receleur
local f = Extras.fenceLocation()
tp(2, f)
check('receleur : grade requis', cb('gs_gangs:fenceInfo', 2) == nil)
tp(1, f)
local info = cb('gs_gangs:fenceInfo', 1); step()
check('receleur : lieu donné au chef', info and info.open)
W.players[1].items.weed_bag = 5
ok, msg = cb('gs_gangs:fenceSell', 1, 'weed'); step()
check('quantité minimum', not ok and msg:find('au moins'))
W.players[1].items.weed_bag = 80
fixRandom(0.0)
ok = cb('gs_gangs:fenceSell', 1, 'weed'); step()
fixRandom()
local unit = math.floor(95 * Config.Fence.bonus)
check('vente en gros plafonnée, argent sale', ok and W.players[1].items.weed_bag == 80 - Config.Fence.maxQty
    and W.players[1].items.black_money == unit * Config.Fence.maxQty and reports == 1)
hour = 14
ok, msg = cb('gs_gangs:fenceSell', 1, 'weed'); step()
check('fermé le jour', not ok and msg:find('nuit'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
