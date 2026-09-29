-- gs_casino : compteur quotidien par personnage (roue, tickets).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_casino_daily` (
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `day` VARCHAR(10) NOT NULL,
        `count` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Nombre d'utilisations aujourd'hui (0 si autre jour ou jamais).
function Store.used(cid, kind, day)
    local row = MySQL.single.await('SELECT `day`, `count` FROM `gs_casino_daily` WHERE `citizenid` = ? AND `kind` = ?', { cid, kind })
    if not row or row.day ~= day then return 0 end
    return row.count
end

function Store.bump(cid, kind, day)
    MySQL.query.await([[INSERT INTO `gs_casino_daily` (`citizenid`, `kind`, `day`, `count`) VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `count` = IF(`day` = VALUES(`day`), `count` + 1, 1), `day` = VALUES(`day`)]], { cid, kind, day })
end
