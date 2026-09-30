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
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_roadtrip_month` (
        `citizenid` VARCHAR(50) NOT NULL,
        `month` CHAR(7) NOT NULL,
        `name` VARCHAR(40) NOT NULL,
        `seconds` INT UNSIGNED NOT NULL,
        `convoy` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `month`), KEY `month` (`month`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Road trip du mois : déjà fait ce mois-ci ?
function Store.monthDone(cid, month)
    return MySQL.scalar.await('SELECT 1 FROM gs_roadtrip_month WHERE citizenid = ? AND month = ?', { cid, month }) ~= nil
end

function Store.monthFinish(cid, month, name, seconds, convoy)
    MySQL.insert.await('INSERT IGNORE INTO gs_roadtrip_month (citizenid, month, name, seconds, convoy) VALUES (?, ?, ?, ?, ?)',
        { cid, month, name, seconds, convoy })
end

--- Classement du mois : les plus rapides.
function Store.monthTop(month, limit)
    return MySQL.query.await('SELECT name, seconds, convoy FROM gs_roadtrip_month WHERE month = ? ORDER BY seconds ASC LIMIT ?', { month, limit }) or {}
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
