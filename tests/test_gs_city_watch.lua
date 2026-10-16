-- Tests V12.63 · Voisins vigilants (n° 173) : adhésion hors gang dans le quartier où l'on est, tension qui retombe plus
-- vite et témoins plus prompts avec des bénévoles connectés (plafonnés), alerte sans position, changement limité.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
-- Mini JSON pour les tables { d = '...', at = n } de l'adhésion (le mock renvoie toujours '{}')
json.encode = function(t) return ('{"d":%q,"at":%d}'):format(t.d, t.at) end
json.decode = function(s) local d, at = s:match('^{"d":"(.-)","at":(%-?%d+)}$') if not d then error('json') end return { d = d, at = tonumber(at) } end
local gangOf = {}
provide('gs_gangs', { GetGang = function(src) return gangOf[src] end })
provide('gs_wanted', { CrimeLabel = function(t) return t == 'robbery' and 'Braquage' or nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/watch.lua' })
local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
local function step() advance(11000) end
local WC = Config.Watch
local south, vesp = Config.Districts[2], Config.Districts[4]
local at = function(d) return vec3(d.center.x, d.center.y, 30.0) end
join(1, 'CID1', 'Riveraine', at(south))
join(2, 'CID2', 'Gangster', at(south))
join(3, 'CID3', 'Suspect', at(south))
gangOf[2] = 'ballas'
local base = exports.gs_city:ReportFactor(at(south))

local ok, msg = cb('gs_city:watchJoin', 2, true); step()
check('membre de gang refusé', not ok and msg:find('gang'))
tp(1, vec3(9000.0, 9000.0, 0.0))
ok, msg = cb('gs_city:watchJoin', 1, true); step()
check('hors quartier : refusé', not ok and msg:find('quartier'))
tp(1, at(south))
ok = cb('gs_city:watchJoin', 1, true); step()
check('adhésion au quartier où l\'on est', ok and Watch.get('CID1').d == south.id and Watch.count[south.id] == 1)
local info = cb('gs_city:watchInfo', 1); step()
check('infos /voisins', info and info.mine == south.label and info.count == 1 and not info.gang)
check('témoins plus prompts avec un bénévole', math.abs(exports.gs_city:ReportFactor(at(south)) - base * (1 + WC.reportPerMember)) < 1e-9)
check('rien ne change ailleurs', exports.gs_city:ReportFactor(at(vesp)) == 1.0)

-- Tension qui retombe plus vite
City.heat[south.id], City.heat[vesp.id] = 50, 50
City.decay()
check('tension : baisse renforcée dans le quartier du bénévole', City.heat[south.id] == 50 - Config.DecayPerMinute - WC.decayPerMember
    and City.heat[vesp.id] == 50 - Config.DecayPerMinute)
for i = 10, 10 + WC.maxMembers + 3 do join(i, 'CIDX' .. i, 'Voisin', at(south)) cb('gs_city:watchJoin', i, true) step() end
check('effet plafonné', Watch.reportFactor(south.id) == 1 + math.min(WC.maxReport, WC.maxMembers * WC.reportPerMember)
    and Watch.decayBonus(south.id) == WC.maxMembers * WC.decayPerMember)
for i = 10, 10 + WC.maxMembers + 3 do W.players[i] = nil end
Watch.refresh()

-- Alerte sans position
W.clientEvents = {}
TriggerEvent('gs_wanted:server:reported', 3, 'robbery', 30, at(south))
local ev = lastClientEvent('ox_lib:notify', 1)
check('bénévole prévenu du délit, sans position', ev and ev.args[1].description:find('braquage') and not ev.args[1].description:find('%d%d%d'))
check('le suspect et le gangster ne le sont pas', not lastClientEvent('ox_lib:notify', 3) and not lastClientEvent('ox_lib:notify', 2))
W.clientEvents = {}
TriggerEvent('gs_wanted:server:reported', 3, 'robbery', 30, at(south))
check('pas de spam (une alerte par période)', not lastClientEvent('ox_lib:notify', 1))
Watch.notified[1] = os.time() - WC.notifySeconds
W.clientEvents = {}
TriggerEvent('gs_wanted:server:reported', 3, 'robbery', 30, at(vesp))
check('délit dans un autre quartier : pas d\'alerte', not lastClientEvent('ox_lib:notify', 1))

-- Changer / quitter
tp(1, at(vesp))
ok, msg = cb('gs_city:watchJoin', 1, true); step()
check('changement de quartier limité', not ok and msg:find('récemment'))
ok = cb('gs_city:watchJoin', 1, false); step()
check('quitter son groupe', ok and Watch.get('CID1') == nil and (Watch.count[south.id] or 0) == 0)
Watch.cache.CID1 = nil
check('départ conservé après reconnexion', Watch.get('CID1') == nil)
SetResourceKvp('watch:CID1', json.encode({ d = '', at = os.time() - WC.changeHours * 3600 - 1 }))
Watch.cache.CID1 = nil
ok = cb('gs_city:watchJoin', 1, true); step()
check('rejoindre un autre quartier après le délai', ok and Watch.get('CID1').d == vesp.id)

io.write(('voisins vigilants : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
