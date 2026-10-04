-- gs_insurance : contrats par véhicule (id player_vehicles) + lecture des véhicules du joueur.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_insurance` (
        `vehicle_id` INT UNSIGNED NOT NULL,
        `expires_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`vehicle_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_insurance_claims` (
        `vehicle_id` INT UNSIGNED NOT NULL,
        `plate` VARCHAR(16) NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `amount` INT UNSIGNED NOT NULL,
        `status` VARCHAR(12) NOT NULL,
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`vehicle_id`), KEY `plate` (`plate`)
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

-- V9 · déclarations de vol ----------------------------------------------------------------------------------------
function Store.claims() return MySQL.query.await("SELECT vehicle_id AS id, plate, citizenid AS cid, amount, status, at FROM gs_insurance_claims WHERE status <> 'closed'") or {} end
function Store.saveClaim(c)
    MySQL.query.await('REPLACE INTO gs_insurance_claims (vehicle_id, plate, citizenid, amount, status, at) VALUES (?, ?, ?, ?, ?, ?)', { c.id, c.plate, c.cid, c.amount, c.status, c.at })
end
--- citizenid du propriétaire actuel d'une plaque [API] player_vehicles
function Store.ownerOf(plate) return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE TRIM(plate) = ? LIMIT 1', { plate }) end
