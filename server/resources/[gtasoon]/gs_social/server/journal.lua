-- gs_social (serveur) : journal Weazel News joué par les joueurs. Les journalistes en service écrivent des articles
-- (titre + texte) ; chaque publication est annoncée à toute la ville, relayée dans Vibe, et rapporte à la rédaction.
-- Tout le monde les lit avec /journal. La rédaction automatique (brèves) reste dans Vibe (vibe2.lua).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Journal = { last = {}, paid = { day = nil, n = 0 } } -- last[cid] = os.time() du dernier article

JournalStore = JournalStore or {
    init = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_news` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `author` VARCHAR(40) NOT NULL,
            `title` VARCHAR(90) NOT NULL,
            `body` TEXT NOT NULL,
            `created` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`), KEY `created` (`created`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    insert = function(cid, author, title, body, now)
        return MySQL.insert.await('INSERT INTO gs_news (citizenid, author, title, body, created) VALUES (?, ?, ?, ?, ?)', { cid, author, title, body, now })
    end,
    list = function(limit)
        return MySQL.query.await('SELECT id, author, title, created FROM gs_news ORDER BY id DESC LIMIT ?', { limit }) or {}
    end,
    get = function(id)
        return MySQL.single.await('SELECT id, author, title, body, created FROM gs_news WHERE id = ?', { id })
    end,
}

--- Texte d'article : balises retirées, liens bloqués comme dans Vibe, retours à la ligne gardés (3 au plus d'affilée).
function Journal.clean(text, max, keepLines)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('\r', ''):gsub('[<>]', '')
    text = keepLines and text:gsub('[%z\1-\9\11-\31]', ' ') or text:gsub('%c', ' ')
    if Config.BlockLinks then
        text = text:gsub('https?://%S+', '[lien]'):gsub('[%w%.%-]+%.gg/%S+', '[lien]'):gsub('www%.%S+', '[lien]')
    end
    text = text:gsub('\n\n\n+', '\n\n'):gsub('[ \t]+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #text > max then text = text:sub(1, max) end
    return text
end

local function authorOf(src)
    local h = Neon.handleOf(src)
    if h then return '@' .. h, h end
    local ci = Bridge:GetCharInfo(src) or {}
    return ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), nil
end

lib.callback.register('gs_social:journal:list', function(src)
    if not Security:RateLimit(src, 'gs_social:journal', 6, 10000) then return nil end
    local out = {}
    for i, a in ipairs(JournalStore.list(Config.Journal.list)) do out[i] = { id = a.id, title = a.title, author = a.author, date = os.date('%d/%m %H:%M', a.created) } end
    return { press = Neon.isPress(src), articles = out }
end)

lib.callback.register('gs_social:journal:read', function(src, id)
    if not Security:RateLimit(src, 'gs_social:journal', 6, 10000) then return nil end
    local a = tonumber(id) and JournalStore.get(tonumber(id))
    if not a then return nil end
    return { title = a.title, author = a.author, body = a.body, date = os.date('%d/%m %H:%M', a.created) }
end)

lib.callback.register('gs_social:journal:publish', function(src, title, body)
    if not Security:RateLimit(src, 'gs_social:journal:publish', 2, 30000) then return false, 'Doucement.' end
    if not Neon.isPress(src) then return false, 'Réservé aux journalistes de Weazel News en service.' end
    local J = Config.Journal
    title, body = Journal.clean(title, J.titleMax, false), Journal.clean(body, J.bodyMax, true)
    if not title or #title < J.titleMin then return false, ('Titre trop court (%d caractères minimum).'):format(J.titleMin) end
    if not body or #body < J.bodyMin then return false, ('Article trop court (%d caractères minimum).'):format(J.bodyMin) end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false, 'Personnage introuvable.' end
    local now = os.time()
    local wait = (Journal.last[cid] or 0) + J.cooldown - now
    if Journal.last[cid] and wait > 0 then return false, ('Prochain article possible dans %d min.'):format(math.ceil(wait / 60)) end
    local author, handle = authorOf(src)
    local id = JournalStore.insert(cid, author, title, body, now)
    if not id then return false, 'Erreur, réessaie.' end
    Journal.last[cid] = now

    -- Relais dans Vibe (compte du journaliste, badge presse) + annonce à toute la ville
    if handle then
        local teaser = ('📰 %s — à lire dans /journal'):format(title)
        local pid = Store.insertPost(cid, handle, teaser)
        if pid then
            local post = { id = pid, cid = cid, handle = handle, content = teaser, likes = 0, time = now, likedBy = {}, press = true }
            table.insert(Neon.feed, 1, post)
            Neon.feed[Config.FeedSize + 1] = nil
            TriggerClientEvent('gs_social:client:new', -1, { id = pid, handle = handle, content = teaser, likes = 0, time = now, badge = 'press' })
        end
    end
    TriggerClientEvent('ox_lib:notify', -1, { title = 'Weazel News · ' .. author, description = title .. '\n/journal pour lire', icon = 'newspaper', duration = 9000 })

    -- Paie de la rédaction (société weazel) : plafond journalier partagé
    local day, paid = os.date('%Y-%m-%d'), nil
    if Journal.paid.day ~= day then Journal.paid = { day = day, n = 0 } end
    if Journal.paid.n < J.paidPerDay and GetResourceState('gs_jobs') == 'started' then
        local ok = pcall(function() return exports.gs_jobs:AddSocietyMoney(Config.PressJob, J.pay, true) end)
        if ok then Journal.paid.n = Journal.paid.n + 1 paid = J.pay end
    end
    Security:LogStaff(('[Journal] article #%d de %s : %s'):format(id, author, title), 'social', true)
    return true, paid and ('Article publié. La rédaction touche %d $.'):format(paid) or 'Article publié (plafond de paie du jour atteint).'
end)

CreateThread(function() JournalStore.init() end)
