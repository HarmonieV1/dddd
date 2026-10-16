-- Tests V12.63 · Trêve entre gangs (n° 152) : proposée / acceptée par des cadres, bloque les guerres, rompue par une mise à terre
-- (détection serveur) : influence perdue partout, annonce.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police = {}
provide('gs_jobs', { IsOnDutyAs = function() return false end, GetOnDutyPlayers = function() return police end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua', R .. 'gs_gangs/shared/blocks.lua' })
local members, money = {}, { ballas = 20000, vagos = 20000 }
Store = {
    init = function() end, gangs = function() return {} end, territories = function() return {} end, saveTerritories = function() end,
    addMoney = function(n, a) money[n] = (money[n] or 0) + a return true end,
    removeMoney = function(n, a) if (money[n] or 0) < a then return false end money[n] = money[n] - a return true end,
    money = function(n) return money[n] or 0 end,
    member = function(cid) local m = members[cid] return m and { gang = m.gang, grade = m.grade } end,
    members = function() return {} end, countMembers = function() return 0 end, setStash = function() end,
}
loadResource('gs_gangs', { R .. 'gs_gangs/server/main.lua', R .. 'gs_gangs/server/wars.lua', R .. 'gs_gangs/server/truce.lua' })
Config.DefaultGangs = {}
Gangs.init()
function DoesEntityExist() return true end
function NetworkGetEntityOwner(ent) return ent - 1000 end
function GetPlayerFromStateBagName(bag) return tonumber(bag:match('player:(%d+)')) end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local grove = Config.Territories.grove.center
local W_ = Config.Wars

Gangs.list.ballas = { label = 'Ballas', color = 27 }
Gangs.list.vagos = { label = 'Vagos', color = 46 }
local function joinGang(src, cid, gang, grade, pos)
    join(src, cid, cid, pos or grove)
    Gangs.online[src] = { cid = cid, gang = gang, grade = grade }
end
joinGang(1, 'B1', 'ballas', 3)
joinGang(2, 'B2', 'ballas', 0)
joinGang(3, 'V1', 'vagos', 3)
joinGang(4, 'V2', 'vagos', 0)
Gangs.territories.grove.owner = 'vagos'

local news = {}
provide('gs_social', { Newsroom = function(_, text) news[#news + 1] = text end })
local realState = GetResourceState
GetResourceState = function(r) if r == 'gs_social' then return 'started' end return realState and realState(r) or 'missing' end

local ok, msg = cb('gs_gangs:truce', 2, 'offer', 'vagos')
check('une recrue ne propose pas de trêve', not ok)
ok = cb('gs_gangs:truce', 1, 'offer', 'ballas')
check('pas de trêve avec soi-même', not ok)
ok, msg = cb('gs_gangs:truce', 1, 'offer', 'vagos')
check('trêve proposée par un cadre', ok)
local okL, d = cb('gs_gangs:truce', 3, 'list')
check('le gang visé voit la proposition', okL and d.offer and d.offer.gang == 'ballas' and d.canManage)
ok = cb('gs_gangs:truce', 4, 'accept', 'ballas')
check('une recrue n\'accepte pas', not ok)
ok, msg = cb('gs_gangs:truce', 3, 'accept', 'ballas')
check('trêve signée', ok and Truce.active('ballas', 'vagos') and Truce.active('vagos', 'ballas'))
police[1] = 9 join(9, 'P9', 'Agent', grove)
ok, msg = Wars.declare(1, 'grove')
check('pas de guerre pendant la trêve', not ok and msg:find('trêve'))
Gangs.territories.grove.influence.ballas = 40
Gangs.territories.davis.influence.ballas = 30
Gangs.territories.davis.influence.vagos = 0
TriggerEvent('weaponDamageEvent', 1, { hitGlobalId = 1000 + 4 })
check('mise à terre d\'un gang ami : trêve rompue', Truce.onDowned(4) == true and not Truce.active('ballas', 'vagos'))
check('rompue : le gang fautif perd de l\'influence partout', Gangs.territories.grove.influence.ballas == 40 - Config.Truce.penalty and Gangs.territories.davis.influence.ballas == 30 - Config.Truce.penalty)
check('rompue : Weazel l\'annonce', news[#news] and news[#news]:find('Trêve rompue'))
check('sans trêve, une mise à terre ne fait rien de plus', Truce.onDowned(4) == false)
io.write(('trêves de gangs : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
