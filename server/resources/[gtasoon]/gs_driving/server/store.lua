-- gs_driving : état du permis par personnage. status : 0 rien, 1 code obtenu, 2 permis (examen ou ancien personnage).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_driving` (
        `citizenid` VARCHAR(50) NOT NULL,
        `status` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.get(cid) return MySQL.scalar.await('SELECT status FROM gs_driving WHERE citizenid = ?', { cid }) end
function Store.set(cid, status) MySQL.query.await('REPLACE INTO gs_driving (citizenid, status) VALUES (?, ?)', { cid, status }) end
function Store.hasVehicle(cid) return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? LIMIT 1', { cid }) ~= nil end
