-- Tests Vibe 2 : profils publics (sans citizenid), abonnements, badge vérifié (modération), influenceur, classements.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
provide('gs_races', { GetTop = function() return { { id = 'sprint', label = 'Sprint', top = { { name = 'Jason N.', time = '6:41.220' } } } } end })
local press = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return job == 'weazel' and press[src] == true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_social', { R .. 'gs_social/shared/config.lua' })
local profiles, follows, verified = { CID1 = 'lucia', CID2 = 'jason' }, {}, {}
local weekQueries = 0
Store = {
    init = function() end, initV2 = function() end,
    loadFeed = function() return {}, {} end,
    getHandle = function(cid) return profiles[cid] end,
    findByHandle = function(h) for c, v in pairs(profiles) do if v == h then return c end end end,
    loadVerified = function() return {} end, loadFollowerCounts = function() return {} end,
    isFollowing = function(a, b) return follows[a .. '>' .. b] == true end,
    setFollow = function(a, b, on) follows[a .. '>' .. b] = on or nil end,
    setVerified = function(h, on) verified[h] = on end,
    profilePosts = function() return { { id = 1, handle = 'jason', content = 'yo', likes = 3, time = 0 } } end,
    insertPost = function() return 99 end,
    weekTop = function() weekQueries = weekQueries + 1 return { { id = 1, handle = 'jason', content = 'yo', likes = 3, time = 0 } },
        { { handle = 'jason', likes = 3, posts = 1 } } end,
}
loadResource('gs_social', { R .. 'gs_social/server/main.lua', R .. 'gs_social/server/vibe2.lua' })
Neon.init()
Vibe2.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

join(1, 'CID1', 'Lucia', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Jason', vec3(0.0, 0.0, 0.0))
join(3, 'CID3', 'Sans Profil', vec3(0.0, 0.0, 0.0))
join(4, 'CID4', 'Modo', vec3(0.0, 0.0, 0.0))
W.players[4].aces = { ['gs.social.moderate'] = true }

local p = cb('gs_social:profile', 1, 'jason'); step()
check('profil public : pseudo, abonnés, posts', p and p.handle == 'jason' and p.followers == 0 and #p.posts == 1 and not p.mine)
local leak = false
for k, v in pairs(p) do if type(v) == 'string' and v:find('CID') then leak = true end end
check('profil : aucun citizenid envoyé', not leak)
check('profil inconnu', cb('gs_social:profile', 1, 'personne') == nil)
check('pseudo invalide', cb('gs_social:profile', 1, '<script>') == nil)

local ok, r = cb('gs_social:follow', 3, 'jason'); step()
check('abonnement sans profil : refusé', not ok)
ok = cb('gs_social:follow', 1, 'lucia'); step()
check('pas d\'abonnement à soi-même', not ok)
ok, r = cb('gs_social:follow', 1, 'jason'); step()
check('abonné + notification', ok and r.following and r.followers == 1 and W.notes[2] and W.notes[2].msg:find('lucia'))
check('profil : suivi', cb('gs_social:profile', 1, 'jason').following == true)
ok, r = cb('gs_social:follow', 1, 'jason'); step()
check('désabonné', ok and not r.following and r.followers == 0)

-- Influenceur
Neon.followers.jason = Config.InfluencerFollowers
check('badge influenceur au seuil', Neon.badge('jason') == 'influencer')
Neon.followers.jason = 0

-- Vérifié
ok = cb('gs_social:verify', 1, 'jason'); step()
check('vérification réservée à la modération', not ok)
ok, r = cb('gs_social:verify', 4, 'jason'); step()
check('badge vérifié posé', ok and r == true and verified.jason and Neon.badge('jason') == 'verified')
ok, r = cb('gs_social:verify', 4, 'jason'); step()
check('badge vérifié retiré', ok and r == false and Neon.badge('jason') == nil)

-- Classements
Neon.followers.jason, Neon.followers.lucia = 4, 9
local top = cb('gs_social:top', 1); step()
check('top : posts, créateurs, abonnés triés', top and #top.posts == 1 and top.creators[1].handle == 'jason'
    and top.followers[1].handle == 'lucia' and top.followers[2].handle == 'jason')
cb('gs_social:top', 2); step()
check('top : cache (une seule requête)', weekQueries == 1)
check('top : classement des courses', top.races and top.races[1].top[1].time == '6:41.220')

-- Presse : flash info réservé aux journalistes en service, cooldown partagé
local okf, msgf = cb('gs_social:flash', 1, 'Explosion au port !'); advance(31000)
check('flash : réservé à la presse', not okf)
press[1] = true
okf = cb('gs_social:flash', 1, 'Explosion au port !'); advance(31000)
check('flash publié : badge presse + annonce à tous', okf and Neon.feed[1].flash and Neon.feed[1].press and lastClientEvent('gs_social:client:flash', -1) ~= nil)
press[2] = true
okf, msgf = cb('gs_social:flash', 2, 'Encore ?'); advance(31000)
check('flash : cooldown partagé par la rédaction', not okf and msgf:find('Prochain'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
