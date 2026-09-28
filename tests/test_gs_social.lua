-- Tests gs_social (Néon) : pseudos, posts nettoyés, cooldown, likes, suppression, confidentialité, miroir Discord.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local mirrored = {}
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
provide('gs_security', {
    RateLimit = getExport('gs_security', 'RateLimit'),
    LogStaff = function(msg, channel, strict) mirrored[#mirrored + 1] = { msg = msg, channel = channel, strict = strict } end,
})
loadResource('gs_social', { R .. 'gs_social/shared/config.lua' })
local profiles, posts, nextId = {}, {}, 0
Store = {
    init = function() end,
    loadFeed = function() return {}, {} end,
    getHandle = function(cid) return profiles[cid] end,
    createProfile = function(cid, h)
        if profiles[cid] then return false end
        for _, v in pairs(profiles) do if v == h then return false end end
        profiles[cid] = h
        return true
    end,
    insertPost = function(cid, h, c) nextId = nextId + 1 posts[nextId] = { cid = cid, handle = h, content = c } return nextId end,
    deletePost = function(id) posts[id].deleted = true end,
    setLike = function() end,
}
loadResource('gs_social', { R .. 'gs_social/server/main.lua' })
Neon.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end

join(1, 'CID1', 'Vice Lucia', vec3(0.0, 0.0, 0.0))
join(2, 'CID2', 'Jason Neon', vec3(0.0, 0.0, 0.0))
join(3, 'CID3', 'Modo Staff', vec3(0.0, 0.0, 0.0))
W.players[3].aces = { ['gs.social.moderate'] = true }

-- Pseudos --------------------------------------------------------------------------------------------
local ok = cb('gs_social:post', 1, 'salut'); step()
check('post refusé sans pseudo', not ok)
for _, bad in ipairs({ 'ab', 'un_pseudo_beaucoup_trop_long', 'pas bon', '<script>', 'é_accent', 42 }) do
    ok = cb('gs_social:setHandle', 1, bad); step()
    check('pseudo invalide refusé : ' .. tostring(bad), not ok)
end
ok = cb('gs_social:setHandle', 1, 'vice_lucia'); step()
check('pseudo créé', ok and profiles.CID1 == 'vice_lucia')
ok = cb('gs_social:setHandle', 1, 'autre'); step()
check('pseudo définitif', not ok and profiles.CID1 == 'vice_lucia')
ok = cb('gs_social:setHandle', 2, 'vice_lucia'); step()
check('pseudo déjà pris', not ok)
cb('gs_social:setHandle', 2, 'jason'); step()
cb('gs_social:setHandle', 3, 'modo'); step()

-- Nettoyage ------------------------------------------------------------------------------------------
check('liens remplacés', Neon.clean('go sur https://arnaque.com/x maintenant') == 'go sur [lien] maintenant')
check('invitation discord remplacée', not Neon.clean('rejoins discord.gg/abc'):find('discord.gg'))
check('balises retirées', not Neon.clean('<img src=x onerror=alert(1)>'):find('[<>]'))
check('espaces seuls = vide', Neon.clean('   \n\t ') == nil)
check('longueur max', #Neon.clean(('a'):rep(1000)) == Config.MaxLength)
check('mentions conservées', Neon.clean('salut @jason') == 'salut @jason')

-- Publication ------------------------------------------------------------------------------------------
W.clientEvents = {}
ok = cb('gs_social:post', 1, 'Coucher de soleil sur Vespucci @jason')
check('post publié', ok and Neon.feed[1].content:find('Vespucci') ~= nil)
check('diffusé à tous', lastClientEvent('gs_social:client:new', -1) ~= nil)
check('aucun citizenid envoyé aux clients', lastClientEvent('gs_social:client:new', -1).args[1].cid == nil)
check('mention notifiée', W.notes[2] and W.notes[2].msg:find('vice_lucia') ~= nil)
check('miroir Discord sans repli staff', mirrored[#mirrored].channel == 'social' and mirrored[#mirrored].strict == true)
ok = cb('gs_social:post', 1, 'spam')
check('cooldown entre deux posts', not ok and #Neon.feed == 1)
step()

-- Likes ----------------------------------------------------------------------------------------------------
local id = Neon.feed[1].id
local _, liked = cb('gs_social:like', 2, id)
check('like', liked == true and Neon.feed[1].likes == 1)
_, liked = cb('gs_social:like', 2, id)
check('unlike', liked == false and Neon.feed[1].likes == 0)
cb('gs_social:like', 2, id)
local view = cb('gs_social:open', 2)
check('fil : like visible pour moi', view.feed[1].liked == true)
check('fil : pas de citizenid', view.feed[1].cid == nil)
check('like sur post inexistant refusé', not cb('gs_social:like', 2, 9999))
step()

-- Suppression --------------------------------------------------------------------------------------------------
ok = cb('gs_social:delete', 2, id); step()
check('impossible de supprimer le post d\'un autre', not ok and #Neon.feed == 1)
ok = cb('gs_social:delete', 3, id); step()
check('modérateur peut supprimer', ok and #Neon.feed == 0 and posts[id].deleted)
check('suppression diffusée', lastClientEvent('gs_social:client:removed', -1).args[1] == id)
cb('gs_social:post', 2, 'mon post')
local mine = Neon.feed[1].id
step()
ok = cb('gs_social:delete', 2, mine)
check('auteur peut supprimer son post', ok and #Neon.feed == 0)
step()

-- Taille du fil ----------------------------------------------------------------------------------------------------
for i = 1, Config.FeedSize + 10 do
    cb('gs_social:post', 1, 'post ' .. i)
    advance(Config.PostCooldown + 1)
end
check('fil borné en mémoire', #Neon.feed == Config.FeedSize and Neon.feed[1].content == 'post ' .. (Config.FeedSize + 10))

-- Signalement ---------------------------------------------------------------------------------------------------
check('signalement', cb('gs_social:report', 2, Neon.feed[1].id) == true)
check('signalement : staff reçoit le citizenid', mirrored[#mirrored].msg:find('CID1') ~= nil and mirrored[#mirrored].channel == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
