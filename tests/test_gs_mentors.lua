-- Tests gs_onboarding · mentors (V8) : rôles selon le niveau, disponibilité, demande / acceptation, places, GPS,
-- jours de jeu comptés, récompenses (filleul resté 7 jours), parrain payé à sa connexion.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local levels = {}
provide('gs_quests', { GetLevel = function(src) return levels[src] or 1 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_onboarding', { R .. 'gs_onboarding/shared/config.lua' })
local rows = {}
Store = {
    mentorOf = function(n) return rows[n] end,
    menteesOf = function(m) local l = {} for _, r in pairs(rows) do if r.mentor == m then l[#l + 1] = r end end return l end,
    pair = function(n, m, nn, mn, st, day) rows[n] = { newbie = n, mentor = m, newbie_name = nn, mentor_name = mn, started = st, days = 1, last_day = day, rewarded = 0, mentor_paid = 0 } end,
    mentorDay = function(n, d, day) rows[n].days, rows[n].last_day = d, day end,
    mentorRewarded = function(n) rows[n].rewarded = 1 end,
    mentorPaid = function(n) rows[n].mentor_paid = 1 end,
}
loadResource('gs_onboarding', { R .. 'gs_onboarding/server/mentors.lua' })
local M = Config.Mentor

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

join(1, 'VET', 'Vétéran', vec3(0.0, 0.0, 0.0)) levels[1] = 8
join(2, 'NEW', 'Nouveau', vec3(10.0, 0.0, 0.0)) levels[2] = 1
join(3, 'MID', 'Moyen', vec3(0.0, 0.0, 0.0)) levels[3] = 4

check('rôles : parrain / nouveau / ni l\'un ni l\'autre', Mentors.info(1).role == 'mentor' and Mentors.info(2).role == 'newbie' and Mentors.info(3).role == 'none')
check('niveau insuffisant pour parrainer', not Mentors.toggle(3))
check('parrain disponible', Mentors.toggle(1) == true and #Mentors.info(2).mentors == 1)
check('un parrain ne peut pas demander un parrain', not Mentors.ask(1, 1))
check('demande envoyée au parrain', Mentors.ask(2, 1) == true and lastClientEvent('gs_onboarding:client:mentorRequest', 1) ~= nil)
check('acceptation : binôme créé', Mentors.answer(1, true) == true and rows.NEW and rows.NEW.mentor == 'VET')
check('déjà un parrain : nouvelle demande refusée', not Mentors.ask(2, 1))
check('filleul : voit son parrain', Mentors.info(2).mentor == 'Vétéran')
check('parrain : GPS vers son filleul', Mentors.locate(1, 'NEW') == true)
check('GPS refusé à un autre', not Mentors.locate(3, 'NEW'))
check('réponse sans demande : refusée', not Mentors.answer(1, true))

-- Jours de jeu et récompense
local bank = W.players[2].money.bank
rows.NEW.last_day = '2000-01-01'
Mentors.onLoaded(2)
check('nouveau jour de jeu compté', rows.NEW.days == 2)
check('trop tôt : pas de prime', rows.NEW.rewarded == 0 and W.players[2].money.bank == bank)
advance(M.days * 86400 * 1000 + 1000)
rows.NEW.last_day = '2000-01-02'
Mentors.onLoaded(2)
check('resté 7 jours et joué 3 jours : primes', rows.NEW.rewarded == 1 and W.players[2].money.bank == bank + M.rewardNewbie
    and W.players[1].money.bank == M.rewardMentor and rows.NEW.mentor_paid == 1)
Mentors.onLoaded(2) Mentors.onLoaded(1)
check('primes versées une seule fois', W.players[2].money.bank == bank + M.rewardNewbie and W.players[1].money.bank == M.rewardMentor)

-- Parrain hors ligne au moment de la prime : payé à sa connexion
join(4, 'NEW2', 'Nouvelle', vec3(0.0, 0.0, 0.0)) levels[4] = 1
Mentors.ask(4, 1) Mentors.answer(1, true)
W.players[1] = nil
advance(M.days * 86400 * 1000 + 1000)
rows.NEW2.days = 3 rows.NEW2.last_day = '2000-01-01'
Mentors.onLoaded(4)
check('parrain absent : prime en attente', rows.NEW2.rewarded == 1 and rows.NEW2.mentor_paid == 0)
join(1, 'VET', 'Vétéran', vec3(0.0, 0.0, 0.0))
Mentors.onLoaded(1)
check('parrain payé à sa connexion', rows.NEW2.mentor_paid == 1 and W.players[1].money.bank == M.rewardMentor)

-- Places limitées
for i = 10, 9 + M.maxMentees do
    join(i, 'N' .. i, 'N' .. i, vec3(0.0, 0.0, 0.0)) levels[i] = 1
end
Mentors.available[1] = true
local accepted = 0
for i = 10, 9 + M.maxMentees do if Mentors.ask(i, 1) then if Mentors.answer(1, true) then accepted = accepted + 1 end end end
check('places de filleuls limitées', #Store.menteesOf('VET') == M.maxMentees)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
