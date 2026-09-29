-- gs_seasons : points et récompenses par saison et par personnage, palmarès.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_season_players` (
        `season` VARCHAR(10) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(40) NOT NULL DEFAULT '',
        `points` INT UNSIGNED NOT NULL DEFAULT 0,
        `premium` TINYINT(1) NOT NULL DEFAULT 0,
        `claimed` VARCHAR(255) NOT NULL DEFAULT '',
        `title` VARCHAR(60) NOT NULL DEFAULT '',
        PRIMARY KEY (`season`, `citizenid`), KEY `idx_rank` (`season`, `points`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_season_hall` (
        `season` VARCHAR(10) NOT NULL, `rank` TINYINT UNSIGNED NOT NULL, `name` VARCHAR(40) NOT NULL, `points` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`season`, `rank`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.get(season, cid)
    local r = MySQL.single.await('SELECT points, premium, claimed, title FROM gs_season_players WHERE season = ? AND citizenid = ?', { season, cid })
    if not r then return { points = 0, premium = false, claimed = {}, title = '' } end
    local claimed = {}
    for k in (r.claimed or ''):gmatch('[^,]+') do claimed[k] = true end
    return { points = r.points, premium = r.premium == 1 or r.premium == true, claimed = claimed, title = r.title }
end

function Store.addPoints(season, cid, name, n)
    MySQL.query.await([[INSERT INTO gs_season_players (season, citizenid, name, points) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE points = points + VALUES(points), name = VALUES(name)]], { season, cid, name, n })
end

function Store.setPremium(season, cid)
    MySQL.query.await([[INSERT INTO gs_season_players (season, citizenid, premium) VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE premium = 1]], { season, cid })
end

function Store.saveClaims(season, cid, claimed, title)
    local list = {}
    for k in pairs(claimed) do list[#list + 1] = k end
    table.sort(list)
    MySQL.query.await([[INSERT INTO gs_season_players (season, citizenid, claimed, title) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE claimed = VALUES(claimed), title = VALUES(title)]], { season, cid, table.concat(list, ','), title or '' })
end

function Store.top(season, limit)
    return MySQL.query.await('SELECT name, points FROM gs_season_players WHERE season = ? AND points > 0 ORDER BY points DESC LIMIT ?', { season, limit }) or {}
end

function Store.hallHas(season) return MySQL.scalar.await('SELECT 1 FROM gs_season_hall WHERE season = ? LIMIT 1', { season }) ~= nil end
function Store.hallAdd(season, rank, name, points) MySQL.query.await('REPLACE INTO gs_season_hall (season, `rank`, name, points) VALUES (?, ?, ?, ?)', { season, rank, name, points }) end
function Store.hall() return MySQL.query.await('SELECT season, `rank`, name, points FROM gs_season_hall ORDER BY season DESC, `rank` ASC LIMIT 30') or {} end
