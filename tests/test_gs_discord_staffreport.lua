-- Tests gs_discord · rapport staff de fin de soirée (V12.61) : pic de joueurs, tickets / sanctions / alertes (gs_admin),
-- Lives, crimes, morts RP ; envoi au seul salon staff, une fois par jour à l'heure dite ; compteurs remis à zéro.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local convars = { gs_webhook_staff = 'https://discord.com/api/web' .. 'hooks/1/abc' }
function GetConvar(k, d) return convars[k] or d end
function GetConvarInt(k, d) return tonumber(convars[k]) or d end
local reqs = {}
function PerformHttpRequest(url, cb, method, data) reqs[#reqs + 1] = { url = url, method = method, data = data } if cb then cb(204, '') end end
local sent = {}
json.encode = function(t) sent[#sent + 1] = t return 'x' end
provide('gs_admin', { NightStats = function() return { tickets = 3, openTickets = 1, sanctions = { ['kick'] = 1 }, staff = { 'Modo' }, alerts = 2 } end })
provide('gs_lives', { ViewsSince = function() return 4 end })
function GetResourceState() return 'started' end
loadResource('gs_discord', { R .. 'gs_discord/shared/config.lua', R .. 'gs_discord/server/staffreport.lua' })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end

join(1, 'A', 'Un', vec3(0.0, 0.0, 0.0)); join(2, 'B', 'Deux', vec3(0.0, 0.0, 0.0))
StaffReport.sample()
check('pic de joueurs retenu', StaffReport.peak == 2)
TriggerEvent('gs_wanted:server:reported', 1, 'stabbing')
TriggerEvent('gs_cimetiere:server:buried', 'Jean Dupont', '')
local e = StaffReport.embed()
local txt = ''
for _, f in ipairs(e.fields) do txt = txt .. f.name .. ':' .. f.value .. '\n' end
check('rapport : tickets, sanctions, alertes, Lives, crimes, morts RP, staff', txt:find('3 ouvert') and txt:find('1 kick') and txt:find('Anti') == nil
    and txt:find('Lives ouverts:4') and txt:find('Crimes signalés:1') and txt:find('Jean Dupont') and txt:find('Modo'))
check('pas l\'heure : rien n\'est envoyé', StaffReport.tick({ hour = 22, min = 0 }) == false and #reqs == 0)
check('4 h : envoyé au salon staff', StaffReport.tick({ hour = 4, min = 1 }) == true and #reqs == 1 and reqs[1].url == convars.gs_webhook_staff)
check('une seule fois par jour', StaffReport.tick({ hour = 4, min = 30 }) == false and #reqs == 1)
check('compteurs remis à zéro', StaffReport.crimes == 0 and #StaffReport.deaths == 0)
convars.gs_webhook_staff, StaffReport.sentDay = nil, nil
check('sans webhook staff : rien (jamais un salon public)', StaffReport.send() == false and #reqs == 1)

io.write(('rapport staff : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
