Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_builder_objects` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `model` VARCHAR(64) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `rx` FLOAT NOT NULL DEFAULT 0, `ry` FLOAT NOT NULL DEFAULT 0, `rz` FLOAT NOT NULL DEFAULT 0,
        `created_by` VARCHAR(100) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.all() return MySQL.query.await('SELECT id, model, x, y, z, rx, ry, rz FROM gs_builder_objects') or {} end

function Store.insert(o, by)
    return MySQL.insert.await('INSERT INTO gs_builder_objects (model, x, y, z, rx, ry, rz, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { o.model, o.x, o.y, o.z, o.rx, o.ry, o.rz, by })
end

function Store.update(id, o)
    MySQL.update('UPDATE gs_builder_objects SET x = ?, y = ?, z = ?, rx = ?, ry = ?, rz = ? WHERE id = ?', { o.x, o.y, o.z, o.rx, o.ry, o.rz, id })
end

function Store.delete(id) MySQL.update('DELETE FROM gs_builder_objects WHERE id = ?', { id }) end
