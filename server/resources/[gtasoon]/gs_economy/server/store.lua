-- Persistance de la pression du marché (survit aux restarts).
Store = {}

function Store.load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_economy` (
        `item` VARCHAR(50) NOT NULL,
        `pressure` DOUBLE NOT NULL DEFAULT 0,
        PRIMARY KEY (`item`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local map = {}
    for _, row in ipairs(MySQL.query.await('SELECT item, pressure FROM gs_economy') or {}) do
        map[row.item] = row.pressure
    end
    return map
end

--- Sauvegarde TOUS les items configurés (0 = équilibre) pour ne pas recharger une vieille pression.
function Store.save(map)
    local rows = {}
    for item in pairs(Config.Items) do rows[#rows + 1] = { item, map[item] or 0 } end
    if #rows == 0 then return end
    MySQL.prepare('INSERT INTO gs_economy (item, pressure) VALUES (?, ?) ON DUPLICATE KEY UPDATE pressure = VALUES(pressure)', rows)
end
