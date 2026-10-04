-- Tests gs_faitsdivers (V10) : jamais sans police, jamais si les joueurs commettent des crimes, plafond d'affaires,
-- services prévenus (EMS seulement si utile), traitement sur place (police clôt, EMS constate), classement après délai.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = {}
local news, standing = {}, {}
provide('gs_jobs', {
    GetOnDutyPlayers = function(job) local l = {} for s, j in pairs(duty) do if j == job then l[#l + 1] = s end end return l end,
    IsOnDutyAs = function(src, job) return duty[src] == job end,
})
provide('gs_social', { Newsroom = function(_, t) news[#news + 1] = t end })
provide('gs_city', { AddStanding = function(_, d) standing[#standing + 1] = d end })
provide('gs_rumors', { Add = function() end, Zone = function() return 'Davis' end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_faitsdivers', { R .. 'gs_faitsdivers/shared/config.lua', R .. 'gs_faitsdivers/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function count() local n = 0 for _ in pairs(FD.open) do n = n + 1 end return n end
local sent = {}
local tce = TriggerClientEvent
TriggerClientEvent = function(n, s, ...) if n == 'gs_faitsdivers:client:new' then sent[#sent + 1] = s end return tce(n, s, ...) end
Config.Chance = 1.0

check('sans police en service : rien', FD.tick() == nil)
join(1, 'CID1', 'Agent', vec3(0.0, 0.0, 0.0), { name = 'police', grade = 1, onduty = true }) duty[1] = 'police'
join(2, 'CID2', 'Médecin', vec3(0.0, 0.0, 0.0), { name = 'ambulance', grade = 1, onduty = true }) duty[2] = 'ambulance'
TriggerEvent('gs_wanted:server:crime', 9, 'store_robbery') TriggerEvent('gs_wanted:server:crime', 9, 'bank')
check('les joueurs braquent : pas de fait divers PNJ', FD.tick() == nil)
FD.crimes = {}
local c = FD.tick()
check('ville calme + police : un fait divers', c ~= nil and count() == 1 and sent[1] ~= nil)
FD.open = {} sent = {}
local b = FD.create('burglary')
local bEms = false
for _, s in ipairs(sent) do if s == 2 then bEms = true end end
check('cambriolage : police prévenue, pas les EMS', b and not bEms)
FD.create('burglary')
check('plafond d\'affaires ouvertes', FD.tick() == nil or count() <= Config.MaxOpen)
FD.open = {} sent = {}
local body = FD.create('body')
local toEms = false
for _, s in ipairs(sent) do if s == 2 then toEms = true end end
check('corps retrouvé : EMS prévenus aussi', toEms and body.model ~= nil)
local ok = cb('gs_faitsdivers:handle', 1, body.id)
check('loin de la scène : refusé', not ok)
tp(2, body.coords) advance(6000)
ok = cb('gs_faitsdivers:handle', 2, body.id)
check('EMS sur place : constatations payées, affaire encore ouverte', ok and W.players[2].money.bank > 0 and FD.open[body.id])
advance(6000)
ok = cb('gs_faitsdivers:handle', 2, body.id)
check('pas deux fois', not ok)
tp(1, body.coords) advance(6000)
ok = cb('gs_faitsdivers:handle', 1, body.id)
check('police : affaire close, payée, brève Weazel, quartier +', ok and not FD.open[body.id] and #news == 1 and standing[#standing] == 1)
join(3, 'CID3', 'Civil', body.coords)
local hr = FD.create('hitrun')
tp(3, hr.coords) advance(6000)
ok = cb('gs_faitsdivers:handle', 3, hr.id)
check('un civil ne traite pas les affaires', not ok)
hr.at = os.time() - Config.Lifetime * 60 - 1
FD.tick()
check('délai dépassé : classée, « court toujours », quartier -', not FD.open[hr.id] and news[#news]:find('court toujours') and standing[#standing] == -2)
check('plaque relevée sur un délit de fuite', hr.plate and #hr.plate == 7)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
