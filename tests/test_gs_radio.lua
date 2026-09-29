-- Tests gs_radio : canaux métier (service), canaux de gang privés et stables, fréquences libres, bornes.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local gangOf = { [3] = 'ballas', [4] = 'vagos' }
provide('gs_gangs', {
    ListGangs = function() return { { name = 'ballas', label = 'Ballas' }, { name = 'vagos', label = 'Vagos' }, { name = 'families', label = 'Families' } } end,
    GetGang = function(src) return gangOf[src], 1 end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_radio', { R .. 'gs_radio/shared/config.lua', R .. 'gs_radio/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local here = vec3(0.0, 0.0, 30.0)
join(1, 'CID1', 'Agent', here); W.players[1].job = { name = 'police', grade = 1, onduty = true }
join(2, 'CID2', 'Civil', here)
join(3, 'CID3', 'Ballas', here)
join(4, 'CID4', 'Vagos', here)
join(5, 'CID5', 'Mecano', here); W.players[5].job = { name = 'mechanic', grade = 0, onduty = false }
Radio.refreshGangs()

check('police en service : canal 1', Radio.allowed(1, 1) and Radio.allowed(1, 3))
check('civil : canal police refusé', not Radio.allowed(2, 1) and not Radio.allowed(2, 3))
W.players[1].job.onduty = false
check('police hors service : refusé', not Radio.allowed(1, 1))
check('mécano sans service requis', Radio.allowed(5, 5) and not Radio.allowed(5, 4))
check('fréquence libre', Radio.allowed(2, 42.5) and Radio.allowed(2, 12) and not Radio.allowed(2, 11))
check('bornes', not Radio.allowed(2, 0) and not Radio.allowed(2, -3) and not Radio.allowed(2, 5000) and not Radio.allowed(2, 'abc'))

local b, v, f = Radio.gangChannels.ballas, Radio.gangChannels.vagos, Radio.gangChannels.families
check('chaque gang a un canal distinct dans la plage', b and v and f and b ~= v and v ~= f and b ~= f
    and b >= Config.GangRange[1] and b <= Config.GangRange[2])
check('gang : son canal', Radio.allowed(3, b) and Radio.allowed(4, v))
check('gang : pas celui des autres', not Radio.allowed(4, b) and not Radio.allowed(3, v) and not Radio.allowed(2, b))
local free
for ch = Config.GangRange[1], Config.GangRange[2] do if not Radio.gangOfChannel[ch] then free = ch break end end
check('canal de gang libre réservé quand même', not Radio.allowed(2, free))
Radio.refreshGangs()
check('canaux stables', Radio.gangChannels.ballas == b and Radio.gangChannels.vagos == v)

W.players[1].job.onduty = true
local p = cb('gs_radio:presets', 1)
check('présélections police', p and p[1].channel == 1 and #p == 4 and p[4].channel == 11)
p = cb('gs_radio:presets', 3)
check('présélection gang', p and #p == 1 and p[1].gang and p[1].channel == b)
check('canJoin', cb('gs_radio:canJoin', 2, 42) == true and cb('gs_radio:canJoin', 2, 1) == false)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
