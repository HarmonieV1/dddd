Store = {}

-- Colonnes ajoutées après la 1re version (serveurs déjà installés) : ADD COLUMN IF NOT EXISTS (MariaDB).
local EXTRA_COLUMNS = {
    "`daily_date` VARCHAR(10) NOT NULL DEFAULT ''",
    "`daily` VARCHAR(255) NOT NULL DEFAULT ''",
    "`daily_total` INT UNSIGNED NOT NULL DEFAULT 0",
    "`streak` INT UNSIGNED NOT NULL DEFAULT 0",
    "`last_login` VARCHAR(10) NOT NULL DEFAULT ''",
    "`badges` VARCHAR(255) NOT NULL DEFAULT ''",
}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_progress` (
        `citizenid` VARCHAR(50) NOT NULL,
        `xp` INT UNSIGNED NOT NULL DEFAULT 0,
        `packages` VARCHAR(255) NOT NULL DEFAULT '',
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for _, col in ipairs(EXTRA_COLUMNS) do
        MySQL.query.await('ALTER TABLE `gs_progress` ADD COLUMN IF NOT EXISTS ' .. col) -- sql-safe : constante du fichier
    end
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_quests_done` (
        `citizenid` VARCHAR(50) NOT NULL,
        `quest` VARCHAR(50) NOT NULL,
        `done_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `quest`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

local function set(str)
    local t = {}
    for v in (str or ''):gmatch('[^,]+') do t[tonumber(v) or v] = true end
    return t
end

local function list(t)
    local l = {}
    for k in pairs(t) do l[#l + 1] = tostring(k) end
    table.sort(l)
    return table.concat(l, ',')
end

--- { xp, packages, done, dailyDate, daily = { [id] = n }, dailyTotal, streak, lastLogin, badges }
function Store.load(cid)
    local row = MySQL.single.await('SELECT * FROM gs_progress WHERE citizenid = ?', { cid }) or {}
    local p = {
        xp = row.xp or 0, packages = set(row.packages), done = {}, dailyDate = row.daily_date or '', daily = {},
        dailyTotal = row.daily_total or 0, streak = row.streak or 0, lastLogin = row.last_login or '', badges = set(row.badges),
    }
    for id, n in (row.daily or ''):gmatch('([%w_]+):(%d+)') do p.daily[id] = tonumber(n) end
    for _, r in ipairs(MySQL.query.await('SELECT quest FROM gs_quests_done WHERE citizenid = ?', { cid }) or {}) do p.done[r.quest] = true end
    return p
end

function Store.save(cid, p)
    local daily = {}
    for id, n in pairs(p.daily) do daily[#daily + 1] = id .. ':' .. n end
    MySQL.prepare([[INSERT INTO gs_progress (citizenid, xp, packages, daily_date, daily, daily_total, streak, last_login, badges)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), packages = VALUES(packages),
        daily_date = VALUES(daily_date), daily = VALUES(daily), daily_total = VALUES(daily_total), streak = VALUES(streak),
        last_login = VALUES(last_login), badges = VALUES(badges)]],
        { cid, p.xp, list(p.packages), p.dailyDate, table.concat(daily, ','), p.dailyTotal, p.streak, p.lastLogin, list(p.badges) })
end

function Store.markDone(cid, quest)
    MySQL.prepare('INSERT IGNORE INTO gs_quests_done (citizenid, quest) VALUES (?, ?)', { cid, quest })
end
