-- gs_social (serveur) : Vibe 2. Profils publics, abonnements, badge vérifié (modération), classements de la semaine.
-- Jamais de citizenid envoyé aux clients : tout passe par le pseudo.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Vibe2 = { top = nil, topAt = 0 }

local function guard(src, key, max, window)
    return Security:RateLimit(src, 'gs_social:' .. key, max, window) and Bridge:IsLoaded(src)
end

lib.callback.register('gs_social:profile', function(src, handle)
    if not guard(src, 'profile', 10, 10000) then return nil end
    if not Neon.validHandle(handle) then return nil end
    local cid = Store.findByHandle(handle)
    if not cid then return nil end
    local me = Bridge:GetIdentifier(src)
    local posts = {}
    for i, p in ipairs(Store.profilePosts(cid, 10)) do posts[i] = { id = p.id, handle = p.handle, content = p.content, likes = p.likes, time = p.time } end
    return { handle = handle, badge = Neon.badge(handle), verified = Neon.verified[handle] == true,
             followers = Neon.followers[handle] or 0, following = me ~= nil and me ~= cid and Store.isFollowing(me, cid),
             mine = me == cid, posts = posts }
end)

lib.callback.register('gs_social:follow', function(src, handle)
    if not guard(src, 'follow', 6, 10000) then return false, 'Doucement.' end
    local me, myHandle = Bridge:GetIdentifier(src), Neon.handleOf(src)
    if not me or not myHandle then return false, 'Crée d\'abord ton profil.' end
    if not Neon.validHandle(handle) then return false, 'Profil introuvable.' end
    local target = Store.findByHandle(handle)
    if not target then return false, 'Profil introuvable.' end
    if target == me then return false, 'Tu ne peux pas t\'abonner à toi-même.' end
    local on = not Store.isFollowing(me, target)
    Store.setFollow(me, target, on)
    Neon.followers[handle] = math.max(0, (Neon.followers[handle] or 0) + (on and 1 or -1))
    if on then
        local s = Bridge:GetSourceByIdentifier(target)
        if s then Bridge:Notify(s, ('@%s s\'est abonné à toi sur Vibe'):format(myHandle), 'inform') end
    end
    return true, { following = on, followers = Neon.followers[handle] }
end)

lib.callback.register('gs_social:verify', function(src, handle)
    if not guard(src, 'verify', 5, 10000) then return false, 'Doucement.' end
    if not Neon.canModerate(src) then return false, 'Réservé à la modération.' end
    if not Neon.validHandle(handle) or not Store.findByHandle(handle) then return false, 'Profil introuvable.' end
    local on = not Neon.verified[handle]
    Neon.verified[handle] = on or nil
    Store.setVerified(handle, on)
    Security:LogStaff(('[Vibe] %s : badge vérifié %s pour @%s'):format(GetPlayerName(src) or '?', on and 'donné' or 'retiré', handle))
    return true, on
end)

--- Flash info (journaliste en service) : post avec badge presse + bandeau pour toute la ville. Cooldown partagé.
Vibe2.lastFlash = 0
lib.callback.register('gs_social:flash', function(src, content)
    if not guard(src, 'flash', 2, 30000) then return false, 'Doucement.' end
    if not Neon.isPress(src) then return false, 'Réservé aux journalistes en service.' end
    local handle = Neon.handleOf(src)
    if not handle then return false, 'Crée d\'abord ton profil Vibe.' end
    content = Neon.clean(content)
    if not content then return false, 'Flash vide.' end
    local wait = Vibe2.lastFlash + Config.FlashCooldown - os.time()
    if Vibe2.lastFlash > 0 and wait > 0 then return false, ('Prochain flash possible dans %d s.'):format(wait) end
    local cid = Bridge:GetIdentifier(src)
    local id = Store.insertPost(cid, handle, content)
    if not id then return false, 'Erreur, réessaie.' end
    Vibe2.lastFlash = os.time()
    local post = { id = id, cid = cid, handle = handle, content = content, likes = 0, time = os.time(), likedBy = {}, press = true, flash = true }
    table.insert(Neon.feed, 1, post)
    Neon.feed[Config.FeedSize + 1] = nil
    TriggerClientEvent('gs_social:client:new', -1, { id = id, handle = handle, content = content, likes = 0, time = post.time, badge = 'press', flash = true })
    TriggerClientEvent('gs_social:client:flash', -1, handle, content)
    Security:LogStaff(('[Vibe] FLASH INFO @%s : %s'):format(handle, content), 'social', true)
    return true, 'Flash info publié.'
end)

--- Classements de la semaine (cache court : requêtes groupées, pas à chaque ouverture).
lib.callback.register('gs_social:top', function(src)
    if not guard(src, 'top', 5, 10000) then return nil end
    if not Vibe2.top or os.time() - Vibe2.topAt >= Config.TopCacheSeconds then
        local posts, creators = Store.weekTop(Config.TopSize)
        local fol = {}
        for h, n in pairs(Neon.followers) do if n > 0 then fol[#fol + 1] = { handle = h, followers = n } end end
        table.sort(fol, function(a, b) return a.followers > b.followers or (a.followers == b.followers and a.handle < b.handle) end)
        for i = #fol, Config.TopSize + 1, -1 do fol[i] = nil end
        local out = { posts = {}, creators = {}, followers = fol,
            races = GetResourceState('gs_races') == 'started' and exports.gs_races:GetTop(3) or {} }
        for i, p in ipairs(posts) do out.posts[i] = { id = p.id, handle = p.handle, content = p.content, likes = p.likes, time = p.time, badge = Neon.badge(p.handle) } end
        for i, c in ipairs(creators) do out.creators[i] = { handle = c.handle, likes = tonumber(c.likes) or 0, posts = tonumber(c.posts) or 0, badge = Neon.badge(c.handle) } end
        for _, f in ipairs(fol) do f.badge = Neon.badge(f.handle) end
        Vibe2.top, Vibe2.topAt = out, os.time()
    end
    return Vibe2.top
end)

function Vibe2.init()
    Store.initV2()
    for _, r in ipairs(Store.loadVerified()) do Neon.verified[r.handle] = true end
    for _, r in ipairs(Store.loadFollowerCounts()) do Neon.followers[r.handle] = tonumber(r.n) or 0 end
end

CreateThread(function()
    while not Neon.feed do Wait(100) end
    Vibe2.init()
end)
