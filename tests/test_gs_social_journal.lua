-- Tests journal Weazel News (/journal) : réservé aux journalistes en service, titre / texte nettoyés (balises, liens),
-- délai entre deux articles, relais Vibe + annonce, paie de la rédaction plafonnée par jour, lecture pour tous.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local press, society = {}, 0
provide('gs_jobs', { IsOnDutyAs = function(src, job) return job == 'weazel' and press[src] == true end,
    AddSocietyMoney = function(job, amount) if job == 'weazel' then society = society + amount end return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_social', { R .. 'gs_social/shared/config.lua' })
local profiles, vibePosts = { CID1 = 'lucia' }, 0
Store = {
    init = function() end, initV2 = function() end, loadFeed = function() return {}, {} end,
    getHandle = function(cid) return profiles[cid] end,
    findByHandle = function(h) for c, v in pairs(profiles) do if v == h then return c end end end,
    loadVerified = function() return {} end, loadFollowerCounts = function() return {} end,
    insertPost = function() vibePosts = vibePosts + 1 return vibePosts end,
}
local rows = {}
JournalStore = {
    init = function() end,
    insert = function(cid, author, title, body, now) rows[#rows + 1] = { id = #rows + 1, citizenid = cid, author = author, title = title, body = body, created = now } return #rows end,
    list = function(limit) local o = {} for i = #rows, math.max(1, #rows - limit + 1), -1 do o[#o + 1] = rows[i] end return o end,
    get = function(id) return rows[id] end,
}
loadResource('gs_social', { R .. 'gs_social/server/main.lua', R .. 'gs_social/server/vibe2.lua', R .. 'gs_social/server/journal.lua' })
Neon.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end
local body = 'Hier soir, une course poursuite a traversé Vespucci. Les témoins racontent une scène digne d\'un film.'

join(1, 'CID1', 'Lucia', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Jason', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_social:journal:publish', 1, 'Course poursuite à Vespucci', body); step()
check('hors service : refusé', not ok and msg:find('service'))
press[1], press[2] = true, true
ok = cb('gs_social:journal:publish', 1, 'Nul', body); step()
check('titre trop court', not ok)
ok = cb('gs_social:journal:publish', 1, 'Course poursuite à Vespucci', 'Trop court.'); step()
check('article trop court', not ok)
ok, msg = cb('gs_social:journal:publish', 1, '<b>Course poursuite</b> à Vespucci', body .. '\n\n\n\nPlus d\'infos : https://arnaque.gg/x'); step()
check('article publié', ok and #rows == 1)
check('balises retirées du titre', rows[1].title == 'bCourse poursuite/b à Vespucci')
check('lien bloqué, paragraphes gardés', rows[1].body:find('[lien]', 1, true) and rows[1].body:find('\n\n', 1, true) and not rows[1].body:find('\n\n\n', 1, true))
check('auteur = pseudo Vibe', rows[1].author == '@lucia')
check('relais dans Vibe', vibePosts == 1)
check('rédaction payée', society == Config.Journal.pay and msg:find(tostring(Config.Journal.pay)))
ok, msg = cb('gs_social:journal:publish', 1, 'Deuxième article du jour', body); step()
check('délai entre deux articles', not ok and msg:find('min'))
ok = cb('gs_social:journal:publish', 2, 'Le point de vue de Jason', body); step()
check('autre journaliste sans profil Vibe : publié sous son nom', ok and rows[2].author ~= nil and not rows[2].author:find('^@'))
check('pas de relais Vibe sans profil', vibePosts == 1)

-- Plafond de paie journalier
Journal.paid.n = Config.Journal.paidPerDay
advance(Config.Journal.cooldown * 1000 + 1000)
local before = society
ok, msg = cb('gs_social:journal:publish', 1, 'Troisième article', body); step()
check('plafond atteint : publié sans paie', ok and society == before and msg:find('plafond'))

-- Lecture pour tous
press[1], press[2] = false, false
local l = cb('gs_social:journal:list', 2); step()
check('liste pour un non-journaliste', l and not l.press and #l.articles == 3 and l.articles[1].title == 'Troisième article')
check('dates formatées côté serveur', type(l.articles[1].date) == 'string')
local a = cb('gs_social:journal:read', 2, 1); step()
check('lecture d\'un article', a and a.title:find('Course poursuite') and a.body:find('Vespucci'))
check('article inconnu', cb('gs_social:journal:read', 2, 99) == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
