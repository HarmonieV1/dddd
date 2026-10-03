-- gs_roadside : collection des rencontres (par personnage) et PNJ amis (auto-stoppeurs aidés).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_roadside` (
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `n` INT UNSIGNED NOT NULL DEFAULT 1,
        PRIMARY KEY (`citizenid`, `kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.add(cid, kind)
    MySQL.insert('INSERT INTO `gs_roadside` (`citizenid`, `kind`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `n` = `n` + 1', { cid, kind })
end

function Store.list(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `kind`, `n` FROM `gs_roadside` WHERE `citizenid` = ?', { cid }) or {}) do out[r.kind] = r.n end
    return out
end
