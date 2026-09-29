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
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_police_warrants` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `reason` VARCHAR(200) NOT NULL,
        `officer` VARCHAR(100) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`, `active`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_police_reports` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `title` VARCHAR(100) NOT NULL,
        `body` TEXT NOT NULL,
        `officer` VARCHAR(100) NOT NULL,
        `officer_cid` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
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

-- Dossiers : mandats, rapports, recherche par nom ---------------------------------------------------------------
--- Citoyens (connectés ou non) dont « prénom nom » contient `term` (déjà nettoyé, % et _ échappés par l'appelant).
function Store.searchCitizens(term)
    return MySQL.query.await([[SELECT citizenid,
        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname,
        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.birthdate')) AS birthdate FROM players
        WHERE CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
        LIMIT 8]], { '%' .. term .. '%' }) or {}
end

function Store.addWarrant(cid, name, reason, officer, officerCid)
    return MySQL.insert.await('INSERT INTO gs_police_warrants (citizenid, name, reason, officer, officer_cid) VALUES (?, ?, ?, ?, ?)',
        { cid, name, reason, officer, officerCid })
end
function Store.hasWarrant(cid) return MySQL.scalar.await('SELECT 1 FROM gs_police_warrants WHERE citizenid = ? AND active = 1 LIMIT 1', { cid }) ~= nil end
function Store.warrantsOf(cid)
    return MySQL.query.await([[SELECT id, reason, officer, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date FROM gs_police_warrants
        WHERE citizenid = ? AND active = 1 ORDER BY id DESC]], { cid }) or {}
end
function Store.activeWarrants()
    return MySQL.query.await([[SELECT id, name, reason, officer, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date FROM gs_police_warrants
        WHERE active = 1 ORDER BY id DESC LIMIT 30]]) or {}
end
function Store.countOfficerWarrants(officerCid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM gs_police_warrants WHERE officer_cid = ? AND active = 1', { officerCid }) or 0
end
function Store.closeWarrant(id) return MySQL.update.await('UPDATE gs_police_warrants SET active = 0 WHERE id = ? AND active = 1', { id }) > 0 end

function Store.addReport(title, body, officer, officerCid)
    return MySQL.insert.await('INSERT INTO gs_police_reports (title, body, officer, officer_cid) VALUES (?, ?, ?, ?)', { title, body, officer, officerCid })
end
function Store.reports()
    return MySQL.query.await([[SELECT id, title, officer, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date FROM gs_police_reports
        ORDER BY id DESC LIMIT 30]]) or {}
end
function Store.report(id)
    return MySQL.single.await([[SELECT id, title, body, officer, officer_cid, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date
        FROM gs_police_reports WHERE id = ?]], { id })
end
function Store.deleteReport(id) return MySQL.update.await('DELETE FROM gs_police_reports WHERE id = ?', { id }) > 0 end
