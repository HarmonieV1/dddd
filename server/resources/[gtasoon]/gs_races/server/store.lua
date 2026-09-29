-- gs_races : meilleurs temps par circuit et par personnage.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_race_times` (
        `circuit` VARCHAR(30) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(40) NOT NULL,
        `ms` INT UNSIGNED NOT NULL,
        `set_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`circuit`, `citizenid`), KEY `idx_rank` (`circuit`, `ms`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Enregistre le temps s'il améliore le meilleur du personnage. Retourne true si c'est un record personnel.
function Store.record(circuit, cid, name, ms)
    local best = MySQL.scalar.await('SELECT ms FROM gs_race_times WHERE circuit = ? AND citizenid = ?', { circuit, cid })
    if best and best <= ms then return false end
    MySQL.query.await([[INSERT INTO gs_race_times (circuit, citizenid, name, ms) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE ms = VALUES(ms), name = VALUES(name), set_at = NOW()]], { circuit, cid, name, ms })
    return true
end

function Store.top(circuit, limit)
    return MySQL.query.await('SELECT name, ms FROM gs_race_times WHERE circuit = ? ORDER BY ms ASC LIMIT ?', { circuit, limit }) or {}
end

function Store.rank(circuit, ms)
    return (MySQL.scalar.await('SELECT COUNT(*) FROM gs_race_times WHERE circuit = ? AND ms < ?', { circuit, ms }) or 0) + 1
end
