-- gs_stats : compteurs de biographie (par mois et depuis toujours), sessions et première venue (rétention).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_bio` (
        `citizenid` VARCHAR(64) NOT NULL, `period` VARCHAR(7) NOT NULL, `stat` VARCHAR(16) NOT NULL, `value` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `period`, `stat`), KEY `rank` (`period`, `stat`, `value`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_sessions` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `license` VARCHAR(64) NOT NULL,
        `start_at` INT UNSIGNED NOT NULL, `end_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`), KEY `license` (`license`), KEY `start` (`start_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_first_seen` (
        `license` VARCHAR(64) NOT NULL, `first_at` INT UNSIGNED NOT NULL, PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- rows = { { cid, period, stat, n } } : une seule requête préparée, exécutée pour toutes les lignes (oxmysql)
function Store.addMany(rows)
    if #rows == 0 then return end
    MySQL.prepare('INSERT INTO gs_bio (citizenid, period, stat, value) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE value = value + VALUES(value)', rows)
end

function Store.get(cid, period)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT stat, value FROM gs_bio WHERE citizenid = ? AND period = ?', { cid, period }) or {}) do out[r.stat] = tonumber(r.value) end
    return out
end

--- Classement : combien font mieux, sur combien
function Store.rank(period, stat, value)
    local better = MySQL.scalar.await('SELECT COUNT(*) FROM gs_bio WHERE period = ? AND stat = ? AND value > ?', { period, stat, value }) or 0
    local total = MySQL.scalar.await('SELECT COUNT(*) FROM gs_bio WHERE period = ? AND stat = ?', { period, stat }) or 0
    return better, total
end

function Store.firstSeen(license, at) MySQL.insert('INSERT IGNORE INTO gs_first_seen (license, first_at) VALUES (?, ?)', { license, at }) end
function Store.session(license, s, e) MySQL.insert('INSERT INTO gs_sessions (license, start_at, end_at) VALUES (?, ?, ?)', { license, s, e }) end
function Store.since(ts)
    return MySQL.query.await('SELECT license, first_at FROM gs_first_seen WHERE first_at >= ?', { ts }) or {},
        MySQL.query.await('SELECT license, start_at, end_at FROM gs_sessions WHERE end_at >= ?', { ts }) or {}
end
function Store.firstOf(cidLicense) return MySQL.scalar.await('SELECT first_at FROM gs_first_seen WHERE license = ?', { cidLicense }) end
