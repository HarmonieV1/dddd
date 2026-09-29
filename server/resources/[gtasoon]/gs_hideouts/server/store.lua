Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_hideouts` (
        `citizenid` VARCHAR(50) NOT NULL,
        `site` VARCHAR(32) NOT NULL,
        `expires` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.get(cid) return MySQL.single.await('SELECT site, expires FROM gs_hideouts WHERE citizenid = ?', { cid }) end
function Store.set(cid, site, expires)
    MySQL.update.await('REPLACE INTO gs_hideouts (citizenid, site, expires) VALUES (?, ?, ?)', { cid, site, expires })
end
