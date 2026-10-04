-- Tests gs_security · anti-triche (V9) : alertes seulement ; staff exempté ; téléportations répétées vs intérieur isolé ;
-- vitesse à pied / en voiture ; chute libre ignorée ; armes interdites ; gains d'argent ; rafales d'entités.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
joaat = function(s) return 'h:' .. s end -- hachage distinct par nom (le mock utilise la longueur)
GetHashKey = joaat
local staff, notified = {}, {}
provide('gs_admin', { GetStaffLevel = function(src) return staff[src] or 0 end, NotifyStaff = function(m) notified[#notified + 1] = m return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua', R .. 'gs_security/server/watch.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function alerts(kind) local n = 0 for _, a in ipairs(Watch.alerts) do if not kind or a.kind == kind then n = n + 1 end end return n end
local function move(src, x, y, z) tp(src, vec3(x, y, z or 30.0)) advance(Watch.config.sample) Watch.check(src) end

join(1, 'CID1', 'Tricheur', vec3(0.0, 0.0, 30.0))
join(2, 'CID2', 'Staff', vec3(0.0, 0.0, 30.0))
join(3, 'CID3', 'Joueur', vec3(0.0, 0.0, 30.0))
staff[2] = 1
Watch.check(1) Watch.check(2) Watch.check(3)

-- Intérieur : entrer / sortir = 2 sauts isolés, pas d'alerte
move(3, 2000.0, 0.0) move(3, 0.0, 0.0)
check('entrer / sortir d\'un intérieur : pas d\'alerte', alerts() == 0)
-- Tricheur : sauts répétés
move(1, 1000.0, 0.0) move(1, 2000.0, 0.0) move(1, 3000.0, 0.0) move(1, 4000.0, 0.0)
check('téléportations répétées : alerte', alerts('téléportations répétées') == 1 and notified[1] ~= nil)
move(1, 5000.0, 0.0)
check('pas de spam d\'alertes (une par 5 min)', alerts('téléportations répétées') == 1)
-- Staff : vol libre / TP autant qu'il veut
for i = 1, 6 do move(2, i * 1000.0, 0.0) end
check('staff exempté (vol libre, TP)', #Watch.alerts == 1)
-- Vitesse à pied
Watch.flags[1] = nil
local x = 0.0
for _ = 1, 4 do x = x + 60.0 move(1, x, 5000.0) end
check('vitesse à pied impossible : alerte', alerts('vitesse à pied') == 1)
-- Chute libre (parachute) : ignorée
local z = 1500.0
tp(3, vec3(0.0, 0.0, z)) Watch.check(3)
for _ = 1, 4 do z = z - 100.0 x = x + 50.0 move(3, x, 0.0, z) end
check('chute libre : pas d\'alerte', alerts('vitesse à pied') == 1)
-- TP autorisé par une ressource (prison, hôpital)
Watch.allow(3, 10)
move(3, -3000.0, 0.0)
check('TP serveur autorisé : pas de mesure', Watch.last[3] == nil)
-- Arme interdite
W.players[1].weapon = joaat('WEAPON_RPG')
Watch.flags[1] = nil
move(1, x, 5000.0)
check('arme interdite : alerte', alerts('arme interdite') == 1)
W.players[1].weapon = nil
-- Argent
Watch.onMoney(3, 100000, 'add', 'vente véhicule')
check('gros gain isolé : pas d\'alerte', alerts('gain d\'argent anormal') == 0)
Watch.onMoney(3, 200000, 'add', 'job')
check('gains cumulés anormaux : alerte', alerts('gain d\'argent anormal') == 1)
Watch.onMoney(1, 900000, 'add', 'staff')
check('don du staff : ignoré', alerts('gain d\'argent anormal') == 1)
Watch.onMoney(2, 900000, 'add', 'job')
check('staff exempté (argent)', alerts('gain d\'argent anormal') == 1)
-- Entités
local blocked = false
for _ = 1, Watch.config.entities + 5 do if not Watch.onEntity(3) then blocked = true end end
check('rafale d\'entités : bloquée + alerte', blocked and alerts('rafale d\'entités') == 1)
local okStaff = true
for _ = 1, Watch.config.entities + 5 do okStaff = Watch.onEntity(2) and okStaff end
check('staff : jamais bloqué', okStaff)
check('alertes consultables par le staff (F11)', #getExport('gs_security', 'GetAlerts')() == #Watch.alerts)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
