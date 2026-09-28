-- Persistance staff : journal, notes, avertissements, jail (par licence = compte, pas par personnage).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_log` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `staff` VARCHAR(100) NOT NULL,
        `action` VARCHAR(32) NOT NULL,
        `target` VARCHAR(100) NULL,
        `details` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_date` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_notes` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `license` VARCHAR(64) NOT NULL,
        `kind` ENUM('note', 'warn') NOT NULL,
        `text` VARCHAR(255) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_license` (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_jail` (
        `license` VARCHAR(64) NOT NULL,
        `until_ts` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(255) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.log(staff, action, target, details)
    MySQL.insert('INSERT INTO gs_admin_log (staff, action, target, details) VALUES (?, ?, ?, ?)', { staff, action, target, details })
end

function Store.recentLogs(limit)
    return MySQL.query.await([[SELECT staff, action, target, details, UNIX_TIMESTAMP(created_at) AS time
        FROM gs_admin_log ORDER BY id DESC LIMIT ?]], { limit }) or {}
end

function Store.addNote(license, kind, text, staff)
    MySQL.insert('INSERT INTO gs_admin_notes (license, kind, text, staff) VALUES (?, ?, ?, ?)', { license, kind, text, staff })
end

function Store.notes(license)
    return MySQL.query.await([[SELECT kind, text, staff, UNIX_TIMESTAMP(created_at) AS time
        FROM gs_admin_notes WHERE license = ? ORDER BY id DESC LIMIT 50]], { license }) or {}
end

function Store.jailGet(license)
    return MySQL.single.await('SELECT until_ts, reason FROM gs_admin_jail WHERE license = ?', { license })
end

function Store.jailSet(license, untilTs, reason, staff)
    MySQL.update.await('REPLACE INTO gs_admin_jail (license, until_ts, reason, staff) VALUES (?, ?, ?, ?)', { license, untilTs, reason, staff })
end

function Store.jailClear(license)
    MySQL.update('DELETE FROM gs_admin_jail WHERE license = ?', { license })
end
