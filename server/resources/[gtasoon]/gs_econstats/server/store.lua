-- gs_econstats : cumuls par jour et par source, masse monétaire du jour, fortunes (lecture des comptes Qbox).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_econ_daily` (
        `day` VARCHAR(10) NOT NULL,
        `reason` VARCHAR(40) NOT NULL,
        `created` BIGINT NOT NULL DEFAULT 0,
        `destroyed` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`day`, `reason`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_econ_supply` (
        `day` VARCHAR(10) NOT NULL,
        `supply` BIGINT NOT NULL,
        `price_index` FLOAT NOT NULL DEFAULT 1,
        PRIMARY KEY (`day`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- rows = { { day, reason, created, destroyed } }
function Store.add(rows)
    for _, r in ipairs(rows) do
        MySQL.query.await([[INSERT INTO gs_econ_daily (day, reason, created, destroyed) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE created = created + VALUES(created), destroyed = destroyed + VALUES(destroyed)]], { r[1], r[2], r[3], r[4] })
    end
end

function Store.day(day)
    return MySQL.query.await('SELECT reason, created, destroyed FROM gs_econ_daily WHERE day = ? ORDER BY created + destroyed DESC', { day }) or {}
end

--- Masse monétaire actuelle (liquide + banque de tous les personnages). [API] table players de Qbox (money en JSON)
function Store.supply()
    return MySQL.scalar.await([[SELECT COALESCE(SUM(CAST(JSON_EXTRACT(money, '$.cash') AS SIGNED) + CAST(JSON_EXTRACT(money, '$.bank') AS SIGNED)), 0)
        FROM players]]) or 0
end

function Store.saveSupply(day, supply, index)
    MySQL.query.await('REPLACE INTO gs_econ_supply (day, supply, price_index) VALUES (?, ?, ?)', { day, supply, index })
end

function Store.supplyHistory(limit)
    return MySQL.query.await('SELECT day, supply, price_index FROM gs_econ_supply ORDER BY day DESC LIMIT ?', { limit }) or {}
end

function Store.richest(limit)
    return MySQL.query.await([[SELECT JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname,
        CAST(JSON_EXTRACT(money, '$.cash') AS SIGNED) + CAST(JSON_EXTRACT(money, '$.bank') AS SIGNED) AS total
        FROM players ORDER BY total DESC LIMIT ?]], { limit }) or {}
end
