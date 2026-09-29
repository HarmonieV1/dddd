-- Persistance Vibe (ex-Néon).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_social_profiles` (
        `citizenid` VARCHAR(50) NOT NULL,
        `handle` VARCHAR(20) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`),
        UNIQUE KEY `uniq_handle` (`handle`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_social_posts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `handle` VARCHAR(20) NOT NULL,
        `content` VARCHAR(320) NOT NULL,
        `likes` INT UNSIGNED NOT NULL DEFAULT 0,
        `deleted` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_feed` (`deleted`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_social_likes` (
        `post_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        PRIMARY KEY (`post_id`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.loadFeed(limit)
    local posts = MySQL.query.await([[SELECT id, citizenid, handle, content, likes, UNIX_TIMESTAMP(created_at) AS time
        FROM gs_social_posts WHERE deleted = 0 ORDER BY id DESC LIMIT ?]], { limit }) or {}
    local likes = {}
    if #posts > 0 then
        for _, row in ipairs(MySQL.query.await('SELECT post_id, citizenid FROM gs_social_likes WHERE post_id >= ?',
            { posts[#posts].id }) or {}) do
            likes[row.post_id] = likes[row.post_id] or {}
            likes[row.post_id][row.citizenid] = true
        end
    end
    return posts, likes
end

function Store.getHandle(cid)
    return MySQL.scalar.await('SELECT handle FROM gs_social_profiles WHERE citizenid = ?', { cid })
end

function Store.findByHandle(handle)
    return MySQL.scalar.await('SELECT citizenid FROM gs_social_profiles WHERE handle = ?', { handle })
end

--- false si le pseudo est pris (clé unique) ou si le perso a déjà un profil.
function Store.createProfile(cid, handle)
    return MySQL.update.await('INSERT IGNORE INTO gs_social_profiles (citizenid, handle) VALUES (?, ?)', { cid, handle }) > 0
end

function Store.insertPost(cid, handle, content)
    return MySQL.insert.await('INSERT INTO gs_social_posts (citizenid, handle, content) VALUES (?, ?, ?)', { cid, handle, content })
end

function Store.deletePost(id)
    MySQL.update('UPDATE gs_social_posts SET deleted = 1 WHERE id = ?', { id })
end

function Store.setLike(id, cid, liked, total)
    if liked then
        MySQL.update('INSERT IGNORE INTO gs_social_likes (post_id, citizenid) VALUES (?, ?)', { id, cid })
    else
        MySQL.update('DELETE FROM gs_social_likes WHERE post_id = ? AND citizenid = ?', { id, cid })
    end
    MySQL.update('UPDATE gs_social_posts SET likes = ? WHERE id = ?', { total, id })
end
