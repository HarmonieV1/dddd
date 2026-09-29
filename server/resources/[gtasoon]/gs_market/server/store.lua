-- gs_market : historique des indices + lectures (biens immobiliers qbx_properties, masse monétaire Qbox).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_market_history` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `ts` INT UNSIGNED NOT NULL,
        `idx` VARCHAR(20) NOT NULL,
        `value` DOUBLE NOT NULL,
        PRIMARY KEY (`id`), KEY `idx_ts` (`idx`, `ts`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.add(ts, rows)
    for id, v in pairs(rows) do MySQL.insert.await('INSERT INTO gs_market_history (ts, idx, value) VALUES (?, ?, ?)', { ts, id, v }) end
end

function Store.history(sinceTs)
    return MySQL.query.await('SELECT ts, idx, value FROM gs_market_history WHERE ts >= ? ORDER BY ts ASC', { sinceTs }) or {}
end

function Store.purge(beforeTs) MySQL.update('DELETE FROM gs_market_history WHERE ts < ?', { beforeTs }) end

--- Prix moyen des biens (qbx_properties) ; nil si la table n'existe pas encore. [API] table properties
function Store.housing()
    local ok, v = pcall(function() return MySQL.scalar.await('SELECT AVG(price) FROM properties WHERE price > 0') end)
    return ok and tonumber(v) or nil
end

--- Liquide + banque de tous les personnages. [API] table players (Qbox)
function Store.wealth()
    return MySQL.scalar.await([[SELECT COALESCE(SUM(CAST(JSON_EXTRACT(money, '$.cash') AS SIGNED) + CAST(JSON_EXTRACT(money, '$.bank') AS SIGNED)), 0)
        FROM players]]) or 0
end
