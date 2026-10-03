-- gs_onboarding : règlement accepté (par licence Rockstar) et liste blanche.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_rules_accept` (
        `license` VARCHAR(60) NOT NULL,
        `version` INT UNSIGNED NOT NULL,
        `accepted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_whitelist` (
        `license` VARCHAR(60) NOT NULL,
        `added_by` VARCHAR(60) NOT NULL DEFAULT '',
        `note` VARCHAR(100) NOT NULL DEFAULT '',
        `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_mentors` (
        `newbie` VARCHAR(50) NOT NULL,
        `mentor` VARCHAR(50) NOT NULL,
        `newbie_name` VARCHAR(80) NOT NULL,
        `mentor_name` VARCHAR(80) NOT NULL,
        `started` INT UNSIGNED NOT NULL,
        `days` INT UNSIGNED NOT NULL DEFAULT 1,
        `last_day` CHAR(10) NOT NULL DEFAULT '',
        `rewarded` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `mentor_paid` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`newbie`), KEY `mentor` (`mentor`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_retouche` (
        `citizenid` VARCHAR(50) NOT NULL,
        `used_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Retouche du personnage (une fois) : déjà utilisée ? / marquer utilisée / rendre (staff)
function Store.retoucheUsed(cid) return MySQL.scalar.await('SELECT 1 FROM gs_retouche WHERE citizenid = ?', { cid }) ~= nil end
function Store.useRetouche(cid) MySQL.query.await('INSERT IGNORE INTO gs_retouche (citizenid) VALUES (?)', { cid }) end
function Store.resetRetouche(cid) MySQL.query.await('DELETE FROM gs_retouche WHERE citizenid = ?', { cid }) end

function Store.rulesVersion(license) return MySQL.scalar.await('SELECT version FROM gs_rules_accept WHERE license = ?', { license }) or 0 end
function Store.acceptRules(license, v) MySQL.query.await('REPLACE INTO gs_rules_accept (license, version) VALUES (?, ?)', { license, v }) end
function Store.isWhitelisted(license) return MySQL.scalar.await('SELECT 1 FROM gs_whitelist WHERE license = ?', { license }) ~= nil end
function Store.addWhitelist(license, by, note) MySQL.query.await('REPLACE INTO gs_whitelist (license, added_by, note) VALUES (?, ?, ?)', { license, by, note or '' }) end
function Store.removeWhitelist(license) return MySQL.update.await('DELETE FROM gs_whitelist WHERE license = ?', { license }) > 0 end

-- V8 · Mentors
function Store.mentorOf(newbie) return MySQL.single.await('SELECT * FROM gs_mentors WHERE newbie = ?', { newbie }) end
function Store.menteesOf(mentor) return MySQL.query.await('SELECT * FROM gs_mentors WHERE mentor = ?', { mentor }) or {} end
function Store.pair(newbie, mentor, nname, mname, started, day)
    MySQL.insert.await('INSERT INTO gs_mentors (newbie, mentor, newbie_name, mentor_name, started, last_day) VALUES (?, ?, ?, ?, ?, ?)',
        { newbie, mentor, nname, mname, started, day })
end
function Store.mentorDay(newbie, days, day) MySQL.update.await('UPDATE gs_mentors SET days = ?, last_day = ? WHERE newbie = ?', { days, day, newbie }) end
function Store.mentorRewarded(newbie) MySQL.update.await('UPDATE gs_mentors SET rewarded = 1 WHERE newbie = ?', { newbie }) end
function Store.mentorPaid(newbie) MySQL.update.await('UPDATE gs_mentors SET mentor_paid = 1 WHERE newbie = ?', { newbie }) end
