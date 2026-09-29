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
end

function Store.rulesVersion(license) return MySQL.scalar.await('SELECT version FROM gs_rules_accept WHERE license = ?', { license }) or 0 end
function Store.acceptRules(license, v) MySQL.query.await('REPLACE INTO gs_rules_accept (license, version) VALUES (?, ?)', { license, v }) end
function Store.isWhitelisted(license) return MySQL.scalar.await('SELECT 1 FROM gs_whitelist WHERE license = ?', { license }) ~= nil end
function Store.addWhitelist(license, by, note) MySQL.query.await('REPLACE INTO gs_whitelist (license, added_by, note) VALUES (?, ?, ?)', { license, by, note or '' }) end
function Store.removeWhitelist(license) return MySQL.update.await('DELETE FROM gs_whitelist WHERE license = ?', { license }) > 0 end
