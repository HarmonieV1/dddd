Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_progress` (
        `citizenid` VARCHAR(50) NOT NULL,
        `xp` INT UNSIGNED NOT NULL DEFAULT 0,
        `packages` VARCHAR(255) NOT NULL DEFAULT '',
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_quests_done` (
        `citizenid` VARCHAR(50) NOT NULL,
        `quest` VARCHAR(50) NOT NULL,
        `done_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `quest`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- { xp, packages = { [index] = true }, done = { [questId] = true } }
function Store.load(cid)
    local row = MySQL.single.await('SELECT xp, packages FROM gs_progress WHERE citizenid = ?', { cid })
    local p = { xp = row and row.xp or 0, packages = {}, done = {} }
    for n in ((row and row.packages) or ''):gmatch('%d+') do p.packages[tonumber(n)] = true end
    for _, r in ipairs(MySQL.query.await('SELECT quest FROM gs_quests_done WHERE citizenid = ?', { cid }) or {}) do p.done[r.quest] = true end
    return p
end

function Store.save(cid, p)
    local list = {}
    for n in pairs(p.packages) do list[#list + 1] = n end
    table.sort(list)
    MySQL.prepare('INSERT INTO gs_progress (citizenid, xp, packages) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), packages = VALUES(packages)',
        { cid, p.xp, table.concat(list, ',') })
end

function Store.markDone(cid, quest)
    MySQL.prepare('INSERT IGNORE INTO gs_quests_done (citizenid, quest) VALUES (?, ?)', { cid, quest })
end
