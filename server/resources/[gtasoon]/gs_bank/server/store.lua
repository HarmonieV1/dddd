-- gs_bank : historique des opérations et total retiré par jour.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_bank_tx` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `amount` INT NOT NULL,
        `balance` BIGINT NOT NULL,
        `place` VARCHAR(30) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_bank_daily` (
        `citizenid` VARCHAR(50) NOT NULL,
        `day` VARCHAR(10) NOT NULL,
        `withdrawn` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.addTx(cid, kind, amount, balance, place)
    MySQL.insert('INSERT INTO gs_bank_tx (citizenid, kind, amount, balance, place) VALUES (?, ?, ?, ?, ?)', { cid, kind, amount, balance, place })
end

function Store.history(cid, limit)
    return MySQL.query.await([[SELECT kind, amount, balance, place, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date
        FROM gs_bank_tx WHERE citizenid = ? ORDER BY id DESC LIMIT ?]], { cid, limit }) or {}
end

function Store.withdrawn(cid, day)
    local row = MySQL.single.await('SELECT `day`, `withdrawn` FROM gs_bank_daily WHERE citizenid = ?', { cid })
    return (row and row.day == day) and row.withdrawn or 0
end

function Store.addWithdrawn(cid, day, amount)
    MySQL.query.await([[INSERT INTO gs_bank_daily (citizenid, day, withdrawn) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE withdrawn = IF(day = VALUES(day), withdrawn + VALUES(withdrawn), VALUES(withdrawn)), day = VALUES(day)]], { cid, day, amount })
end
