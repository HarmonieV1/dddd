Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_police_records` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `charge` VARCHAR(120) NOT NULL,
        `fine` INT UNSIGNED NOT NULL DEFAULT 0,
        `jail` INT UNSIGNED NOT NULL DEFAULT 0,
        `officer` VARCHAR(100) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_police_jail` (
        `citizenid` VARCHAR(50) NOT NULL,
        `until_ts` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(120) NOT NULL DEFAULT '',
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.addRecord(cid, charge, fine, jail, officer)
    MySQL.insert('INSERT INTO gs_police_records (citizenid, charge, fine, jail, officer) VALUES (?, ?, ?, ?, ?)', { cid, charge, fine, jail, officer })
end

function Store.records(cid)
    return MySQL.query.await([[SELECT charge, fine, jail, officer, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date
        FROM gs_police_records WHERE citizenid = ? ORDER BY id DESC LIMIT 25]], { cid }) or {}
end

function Store.jailSet(cid, untilTs, reason) MySQL.prepare('REPLACE INTO gs_police_jail (citizenid, until_ts, reason) VALUES (?, ?, ?)', { cid, untilTs, reason }) end
function Store.jailGet(cid) return MySQL.single.await('SELECT until_ts, reason FROM gs_police_jail WHERE citizenid = ?', { cid }) end
function Store.jailClear(cid) MySQL.prepare('DELETE FROM gs_police_jail WHERE citizenid = ?', { cid }) end
