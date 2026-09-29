-- gs_roadbook : carnets terminés (meilleur temps par carnet et par personnage).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_roadbook` (
        `citizenid` VARCHAR(50) NOT NULL,
        `route` VARCHAR(30) NOT NULL,
        `name` VARCHAR(40) NOT NULL,
        `best_s` INT UNSIGNED NOT NULL,
        `photos` INT UNSIGNED NOT NULL DEFAULT 0,
        `runs` INT UNSIGNED NOT NULL DEFAULT 1,
        PRIMARY KEY (`citizenid`, `route`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.done(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT route, best_s FROM gs_roadbook WHERE citizenid = ?', { cid }) or {}) do out[r.route] = r.best_s end
    return out
end

function Store.finish(cid, route, name, seconds, photos)
    MySQL.query.await([[INSERT INTO gs_roadbook (citizenid, route, name, best_s, photos) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE best_s = LEAST(best_s, VALUES(best_s)), photos = GREATEST(photos, VALUES(photos)), runs = runs + 1, name = VALUES(name)]],
        { cid, route, name, seconds, photos })
end

--- Classement des explorateurs : carnets différents terminés, puis total des étapes photo.
function Store.explorers(limit)
    return MySQL.query.await([[SELECT name, COUNT(*) AS routes, SUM(photos) AS photos FROM gs_roadbook GROUP BY citizenid, name
        ORDER BY routes DESC, photos DESC LIMIT ?]], { limit }) or {}
end
