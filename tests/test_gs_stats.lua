-- Tests gs_stats (V9) : compteurs de biographie (événements serveur, écriture groupée mois + toujours), vue Wrapped
-- (titre, classement), rétention (J+1, 7 jours, abandon à la 1re session, durée moyenne, nouveaux).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local db = {} -- db[cid][period][stat]
local writes = 0
local idents = {}
function GetPlayerIdentifiers(src) return idents[src] or {} end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_stats', { R .. 'gs_stats/shared/config.lua' })
Store = {
    init = function() end,
    addMany = function(rows) writes = writes + 1 for _, r in ipairs(rows) do
        db[r[1]] = db[r[1]] or {} db[r[1]][r[2]] = db[r[1]][r[2]] or {}
        db[r[1]][r[2]][r[3]] = (db[r[1]][r[2]][r[3]] or 0) + r[4] end end,
    get = function(cid, p) local o = {} for k, v in pairs((db[cid] or {})[p] or {}) do o[k] = v end return o end,
    rank = function(p, stat, v) local better, total = 0, 0 for _, per in pairs(db) do local x = (per[p] or {})[stat] if x then total = total + 1 if x > v then better = better + 1 end end end return better, total end,
    firstSeen = function() end, session = function() end, firstOf = function() return 0 end,
}
loadResource('gs_stats', { R .. 'gs_stats/server/bio.lua', R .. 'gs_stats/server/retention.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

join(1, 'CID1', 'Pilote', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Flic', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_carnet:server:driven', 'AAA', 1, 12.5)
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery')
TriggerEvent('gs_police:server:jailed', 1, 10, 2)
TriggerEvent('gs_fightclub:server:won', 1)
TriggerEvent('gs_roadside:server:met', 1, 'hitchhiker')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'bank', 5000, 'add', 'job')
TriggerEvent('QBCore:Server:OnMoneyChange', 1, 'crypto', 99999, 'add', 'x')
check('compteurs en mémoire', Bio.buf.CID1.meters == 12500 and Bio.buf.CID1.crimes == 1 and Bio.buf.CID1.jailed == 1 and Bio.buf.CID2.arrests == 1
    and Bio.buf.CID1.fights == 1 and Bio.buf.CID1.encounters == 1 and Bio.buf.CID1.earned == 5000)
check('monnaie hors cash / banque ignorée', Bio.buf.CID1.earned == 5000)
local n = Bio.flush()
check('écriture groupée : une requête, mois + toujours', writes == 1 and n >= 14 and db.CID1[Bio.month()].meters == 12500 and db.CID1.all.meters == 12500 and next(Bio.buf) == nil)
local v = Bio.view('CID1', Bio.month())
check('vue Wrapped : lignes formatées', #v.lines >= 6 and v.lines[1].label == 'Au volant' and v.lines[1].value == '12 km')
check('vue Wrapped : un titre', v.title == 'Poids lourd du ring' or v.title == 'Ennemi public' or v.title ~= nil)
Bio.addCid('CID2', 'minutes', 30)
local v2 = Bio.view('CID2', Bio.month())
check('les compteurs pas encore écrits comptent', v2.lines[1].value == '0 h 30')
for i = 3, 8 do db['C' .. i] = { [Bio.month()] = { meters = i * 1000 } } end
v = Bio.view('CID1', Bio.month())
check('classement : top % au volant', v.ranks[1] and v.ranks[1].stat == 'meters' and v.ranks[1].top <= 20)
check('mois dernier', Bio.lastMonth(1768478400) == '2025-12') -- 15/01/2026

-- Rétention
local D = 86400
local t = 100 * D
local firsts = {
    { license = 'A', first_at = t - 10 * D }, { license = 'B', first_at = t - 10 * D }, { license = 'C', first_at = t - 9 * D }, { license = 'N', first_at = t - 1 * D },
}
local sessions = {
    { license = 'A', start_at = t - 10 * D, end_at = t - 10 * D + 3600 }, { license = 'A', start_at = t - 9 * D, end_at = t - 9 * D + 1800 }, -- revient J+1
    { license = 'B', start_at = t - 10 * D, end_at = t - 10 * D + 300 },                                                                      -- abandon (5 min)
    { license = 'C', start_at = t - 9 * D, end_at = t - 9 * D + 2400 }, { license = 'C', start_at = t - 5 * D, end_at = t - 5 * D + 1200 },     -- revient dans la semaine
    { license = 'N', start_at = t - 1 * D, end_at = t - 1 * D + 600 },
}
local r = Retention.compute(firsts, sessions, t)
check('retour J+1 (cohortes d\'au moins 2 jours)', r.d1.of == 3 and r.d1.back == 1 and r.d1.pct == 33)
check('retour sous 7 jours (cohortes de plus de 7 j)', r.d7.of == 3 and r.d7.back == 2 and r.d7.pct == 67)
check('abandon à la 1re session', r.drop.of == 4 and r.drop.short == 2 and r.drop.pct == 50)
check('nouveaux sur 7 jours', r.new7 == 1)
check('7 jours détaillés', #r.daily == 7)
idents[1] = { 'license:abc' }
Retention.start(1)
check('session ouverte à la connexion', Retention.open[1] and Retention.open[1].license == 'license:abc')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
