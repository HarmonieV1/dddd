-- Tests gs_security · pots de miel (V12.4) : un piège déclenché par un CLIENT sanctionne, le reste jamais.
-- Les noms de pièges ne sont JAMAIS écrits ici en clair : tests/check_honeypot.py interdit qu'ils apparaissent
-- ailleurs que dans honeypot.lua. On les relit donc depuis GSSec.Honeypot.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'

local dropped, bans, notes = {}, {}, {}
function DropPlayer(src, reason) dropped[src] = reason end
function PerformHttpRequest() end
local mode = 'ban'
GetConvar = function(k, d) if k == 'gs_honeypot' then return mode end return d end

-- gs_admin simulé : AutoBan refuse le staff (comme le vrai), NotifyStaff trace
local staff = { [2] = true }
local autoBanBroken = false
provide('gs_admin', {
    AutoBan = function(src, reason, days)
        if autoBanBroken then error('base de données indisponible') end
        if staff[src] then return false, 'Staff : signalé, pas banni.' end
        bans[#bans + 1] = { src = src, reason = reason, days = days }
        return true
    end,
    NotifyStaff = function(msg) notes[#notes + 1] = msg return true end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua', R .. 'gs_security/server/honeypot.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function reset() dropped, bans, notes = {}, {}, {} end

local H = GSSec.Honeypot
check('pièges exposés pour les tests', H and #H.events == 23 and #H.callbacks == 4)
local registered = 0
for _, ev in ipairs(H.events) do if W.handlers[ev] and #W.handlers[ev] > 0 then registered = registered + 1 end end
check('les 23 events sont enregistrés', registered == 23)
local cbs = 0
for _, c in ipairs(H.callbacks) do if W.callbacks[c] then cbs = cbs + 1 end end
check('les 4 callbacks sont enregistrés', cbs == 4)

join(4, 'CID4', 'Tricheur', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Modo', vec3(0.0, 0.0, 0.0))

-- Mode ban (défaut)
net(H.events[1], 4)
check('ban : event piégé → bannissement définitif', #bans == 1 and bans[1].src == 4 and bans[1].days == 0)
check('ban : motif = nom du piège', bans[1] and bans[1].reason:find(H.events[1], 1, true) ~= nil)
check('ban : staff prévenu', #notes == 1 and notes[1]:find('Tricheur', 1, true) ~= nil)
check('ban : pas de double expulsion (AutoBan s\'en charge)', dropped[4] == nil)

reset()
local r = cb(H.callbacks[1], 4)
check('ban : callback piégé → bannissement + réponse false', r == false and #bans == 1 and bans[1].src == 4)

-- Staff : jamais banni, jamais expulsé, mais signalé
reset()
net(H.events[5], 2)
check('staff : pas banni', #bans == 0)
check('staff : pas expulsé', dropped[2] == nil)
check('staff : signalé quand même', #notes == 1)

-- Déclenché côté serveur : on ne sanctionne pas à l'aveugle
reset()
net(H.events[2], '')
net(H.events[2], 0)
check('serveur : aucune sanction', #bans == 0 and next(dropped) == nil and #notes == 0)

-- Mode kick
reset(); mode = 'kick'
net(H.events[3], 4)
check('kick : expulsé, pas banni', dropped[4] ~= nil and #bans == 0)

-- Mode log
reset(); mode = 'log'
net(H.events[4], 4)
check('log : ni ban ni expulsion', #bans == 0 and next(dropped) == nil)
check('log : staff prévenu quand même', #notes == 1)

-- gs_admin en panne : on expulse au minimum (le tricheur ne reste pas en ville)
reset(); mode = 'ban'; autoBanBroken = true
net(H.events[6], 4)
check('AutoBan en erreur → expulsion de secours', dropped[4] ~= nil)
autoBanBroken = false

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
