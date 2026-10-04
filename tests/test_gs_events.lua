-- Tests gs_events : calendrier (dont chevauchement du nouvel an), événement staff prioritaire, expiration, multiplicateurs,
-- commande réservée, effet sur l'XP et la roue.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_events', { R .. 'gs_events/shared/config.lua', R .. 'gs_events/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

check('printemps : rien', Events.active('04-15') == nil)
check('été : actif', Events.active('07-14').id == 'summer')
check('Halloween : bornes incluses', Events.active('10-24').id == 'halloween' and Events.active('11-01').id == 'halloween' and Events.active('11-02') == nil)
check('fêtes : à cheval sur le nouvel an', Events.active('12-31').id == 'xmas' and Events.active('01-01').id == 'xmas' and Events.active('01-03') == nil)

local realDate = os.date
local fakeT = { wday = 3, hour = 12, min = 0, yday = 100 } -- mardi midi : aucun rendez-vous fixe
os.date = function(fmt, t) if fmt == '%m-%d' then return '04-15' end if fmt == '*t' and not t then return fakeT end return realDate(fmt, t) end
check('hors événement : XP ×1', getExport('gs_events', 'GetXpMultiplier')() == 1.0 and getExport('gs_events', 'GetBonus')('wheel') == 0)

join(1, 'CID1', 'Staff', vec3(0.0, 0.0, 0.0)) join(2, 'CID2', 'Joueur', vec3(0.0, 0.0, 0.0))
W.players[1].aces = { ['gs.events.manage'] = true }
W.commands.gsevent(2, { 'start', 'double_xp', '30' })
check('commande réservée au staff', Events.manual == nil)
W.commands.gsevent(1, { 'start', 'inconnu', '30' })
check('événement inconnu refusé', Events.manual == nil)
W.commands.gsevent(1, { 'start', 'double_xp', '2' })
check('durée trop courte refusée', Events.manual == nil)
W.commands.gsevent(1, { 'start', 'double_xp', '30' })
check('événement staff lancé : XP ×2', Events.manual and getExport('gs_events', 'GetXpMultiplier')() == 2.0)
check('annonce à tous les joueurs', W.notes[1] and W.notes[2] and W.notes[2].msg:find('double XP') or W.notes[2].msg:find('Soirée'))
check('publié pour les clients', GlobalState.gsEvent and GlobalState.gsEvent.id == 'double_xp')
W.commands.gsevent(1, { 'start', 'lucky', '30' })
check('bonus roue de l\'événement staff', getExport('gs_events', 'GetBonus')('wheel') == 2)
advance(31 * 60000)
os.time = (function(f) return function(t) if t then return f(t) end return f() + 31 * 60 end end)(os.time)
check('événement staff expiré', Events.active('04-15') == nil)
W.commands.gsevent(1, { 'start', 'lucky', '30' })
W.commands.gsevent(1, { 'stop' })
check('arrêt manuel', Events.manual == nil)
-- V9 · Rendez-vous fixes
check('mardi midi : pas de rendez-vous', Events.weekly({ wday = 3, hour = 12, min = 0 }) == nil)
check('vendredi 21 h 30 : courses', Events.weekly({ wday = 6, hour = 21, min = 30 }).id == 'fri_races')
check('vendredi 23 h 30 : fini (borne exclue)', Events.weekly({ wday = 6, hour = 23, min = 30 }) == nil)
check('samedi 22 h : nuit des combats', Events.weekly({ wday = 7, hour = 22, min = 0 }).id == 'sat_fight')
Events.manual = nil
fakeT = { wday = 4, hour = 21, min = 10, yday = 101 }
check('rendez-vous en cours = événement actif (XP)', Events.active().id == 'wed_jobs' and getExport('gs_events', 'GetXpMultiplier')() == 1.25)
local w, ahead = Events.remind({ wday = 6, hour = 20, min = 30, yday = 102 })
check('rappel 30 min avant', w and w.id == 'fri_races' and ahead == 30)
check('un seul rappel', Events.remind({ wday = 6, hour = 20, min = 30, yday = 102 }) == nil)
w, ahead = Events.remind({ wday = 6, hour = 21, min = 0, yday = 102 })
check('annonce au début', w and ahead == 0)
fakeT = { wday = 3, hour = 12, min = 0, yday = 100 }

os.date = function(fmt, t) if fmt == '*t' and not t then return fakeT end return realDate(fmt, t) end -- mardi midi : pas de rendez-vous fixe pendant la suite

-- Effets sur gs_casino (roue) : 1 + bonus
loadResource('gs_casino', { R .. 'gs_casino/shared/config.lua' })
local bonus = 0
provide('gs_events', { GetBonus = function() return bonus end, GetXpMultiplier = function() return 1.0 end })
local db = {}
Store = { init = function() end, used = function(cid, k, d) local r = db[cid .. k] return (r and r.day == d) and r.count or 0 end,
    bump = function(cid, k, d) local r = db[cid .. k] if r and r.day == d then r.count = r.count + 1 else db[cid .. k] = { day = d, count = 1 } end end }
provide('gs_security', getExport and { RateLimit = function() return true end, InRange = function() return true end, LogStaff = function() end } or nil)
loadResource('gs_casino', { R .. 'gs_casino/server/main.lua' })
check('sans événement : 1 tour', Casino.wheelAllowed() == 1)
bonus = 1
check('avec événement : 2 tours', Casino.wheelAllowed() == 2)


io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
