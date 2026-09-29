-- gs_insurance : contrats par véhicule (id player_vehicles) + lecture des véhicules du joueur.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_insurance` (
        `vehicle_id` INT UNSIGNED NOT NULL,
        `expires_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`vehicle_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.all() return MySQL.query.await('SELECT vehicle_id, expires_at FROM gs_insurance WHERE expires_at > UNIX_TIMESTAMP()') or {} end
function Store.set(id, ts) MySQL.query.await('REPLACE INTO gs_insurance (vehicle_id, expires_at) VALUES (?, ?)', { id, ts }) end

--- Véhicules possédés : { { id, model, plate } } [API] player_vehicles (qbx_vehicles)
function Store.vehicles(cid)
    return MySQL.query.await('SELECT id, vehicle AS model, plate FROM player_vehicles WHERE citizenid = ? ORDER BY id LIMIT 30', { cid }) or {}
end

function Store.owns(cid, id)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE id = ? AND citizenid = ?', { id, cid }) ~= nil
end
