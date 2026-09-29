-- gs_social (serveur) : Néon. Le fil vit en mémoire (lecture instantanée), la BDD fait foi au démarrage.
-- Les clients ne reçoivent jamais de citizenid : seulement pseudo, contenu, likes, date.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Neon = {
    feed = {},      -- posts du plus récent au plus ancien : { id, cid, handle, content, likes, time, likedBy = {} }
    handles = {},   -- [src] = pseudo (cache)
}

local function findPost(id)
    for i, p in ipairs(Neon.feed) do if p.id == id then return p, i end end
end

--- Titre de progression (gs_quests) de l'auteur : à jour s'il est connecté, sinon celui du moment du post.
local function titleOf(p)
    if GetResourceState('gs_quests') ~= 'started' then return p.title end
    local src = Bridge:GetSourceByIdentifier(p.cid)
    return src and exports.gs_quests:GetTitle(src) or p.title
end

local function publicView(p, cid)
    return { id = p.id, handle = p.handle, content = p.content, likes = p.likes, time = p.time,
             liked = cid ~= nil and p.likedBy[cid] == true, title = titleOf(p) }
end

local function canModerate(src) return IsPlayerAceAllowed(src, Config.ModerateAce) end

--- Nettoie un post : caractères de contrôle, balises, liens / invitations (pub, phishing).
function Neon.clean(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%c', ' '):gsub('[<>]', '')
    if Config.BlockLinks then
        text = text:gsub('https?://%S+', '[lien]'):gsub('[%w%.%-]+%.gg/%S+', '[lien]'):gsub('www%.%S+', '[lien]')
    end
    text = text:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s%s+', ' ')
    if text == '' then return nil end
    return text:sub(1, Config.MaxLength)
end

function Neon.validHandle(h)
    return type(h) == 'string' and #h >= Config.HandleMin and #h <= Config.HandleMax and h:match('^[%w_]+$') ~= nil
end

local function handleOf(src)
    if Neon.handles[src] == nil then
        local cid = Bridge:GetIdentifier(src)
        Neon.handles[src] = cid and Store.getHandle(cid) or false
    end
    return Neon.handles[src] or nil
end

local function guard(src, key, max, window)
    return Security:RateLimit(src, 'gs_social:' .. key, max, window) and Bridge:IsLoaded(src)
end

lib.callback.register('gs_social:open', function(src)
    if not guard(src, 'open', 5, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    local feed = {}
    for i, p in ipairs(Neon.feed) do feed[i] = publicView(p, cid) end
    local title = GetResourceState('gs_quests') == 'started' and exports.gs_quests:GetTitle(src) or nil
    return { handle = handleOf(src), title = title, feed = feed, canModerate = canModerate(src), maxLength = Config.MaxLength }
end)

lib.callback.register('gs_social:setHandle', function(src, handle)
    if not guard(src, 'handle', 3, 30000) then return false, 'Doucement.' end
    if handleOf(src) then return false, 'Tu as déjà un pseudo.' end
    if not Neon.validHandle(handle) then
        return false, ('Pseudo : %d à %d lettres, chiffres ou _.'):format(Config.HandleMin, Config.HandleMax)
    end
    local cid = Bridge:GetIdentifier(src)
    if not cid or not Store.createProfile(cid, handle) then return false, 'Pseudo déjà pris.' end
    Neon.handles[src] = handle
    return true, handle
end)

lib.callback.register('gs_social:post', function(src, content)
    if not guard(src, 'post', 1, Config.PostCooldown) then return false, 'Attends un peu avant de reposter.' end
    local handle, cid = handleOf(src), Bridge:GetIdentifier(src)
    if not handle or not cid then return false, 'Choisis d\'abord un pseudo.' end
    content = Neon.clean(content)
    if not content then return false, 'Post vide.' end

    local id = Store.insertPost(cid, handle, content)
    if not id then return false, 'Erreur, réessaie.' end
    local post = { id = id, cid = cid, handle = handle, content = content, likes = 0, time = os.time(), likedBy = {} }
    post.title = titleOf(post)
    table.insert(Neon.feed, 1, post)
    Neon.feed[Config.FeedSize + 1] = nil
    TriggerClientEvent('gs_social:client:new', -1, publicView(post))

    -- Mentions : notification aux personnes citées (en ligne)
    local notified = {}
    for mention in content:gmatch('@([%w_]+)') do
        if not notified[mention] then
            notified[mention] = true
            for s, h in pairs(Neon.handles) do
                if h == mention and s ~= src then Bridge:Notify(s, ('@%s t\'a mentionné sur Néon'):format(handle), 'inform') end
            end
        end
    end
    if Config.MirrorToDiscord then Security:LogStaff(('**@%s** · %s'):format(handle, content), 'social', true) end
    return true
end)

lib.callback.register('gs_social:like', function(src, id)
    if not guard(src, 'like', 10, 10000) then return false end
    local cid, post = Bridge:GetIdentifier(src), findPost(tonumber(id))
    if not cid or not post then return false end
    local liked = not post.likedBy[cid]
    post.likedBy[cid] = liked or nil
    post.likes = math.max(0, post.likes + (liked and 1 or -1))
    Store.setLike(post.id, cid, liked, post.likes)
    TriggerClientEvent('gs_social:client:likes', -1, post.id, post.likes)
    return true, liked
end)

lib.callback.register('gs_social:delete', function(src, id)
    if not guard(src, 'delete', 5, 10000) then return false end
    local cid = Bridge:GetIdentifier(src)
    local post, index = findPost(tonumber(id))
    if not post then return false end
    local mod = canModerate(src)
    if post.cid ~= cid and not mod then return false end
    table.remove(Neon.feed, index)
    Store.deletePost(post.id)
    TriggerClientEvent('gs_social:client:removed', -1, post.id)
    if post.cid ~= cid then
        Security:LogStaff(('[Néon] post #%d de @%s supprimé par %s : %s'):format(post.id, post.handle, GetPlayerName(src) or '?', post.content))
    end
    return true
end)

lib.callback.register('gs_social:report', function(src, id)
    if not guard(src, 'report', 3, 60000) then return false end
    local post = findPost(tonumber(id))
    if not post then return false end
    Security:LogStaff(('[Néon] SIGNALEMENT par %s : post #%d de @%s (%s) : %s'):format(
        GetPlayerName(src) or '?', post.id, post.handle, post.cid, post.content))
    return true
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Neon.handles[src] = nil end)

exports('GetHandle', function(src) return handleOf(src) end)

function Neon.init()
    Store.init()
    local posts, likes = Store.loadFeed(Config.FeedSize)
    Neon.feed = {}
    for _, p in ipairs(posts) do
        Neon.feed[#Neon.feed + 1] = { id = p.id, cid = p.citizenid, handle = p.handle, content = p.content,
            likes = p.likes, time = p.time, likedBy = likes[p.id] or {} }
    end
end

CreateThread(Neon.init)
