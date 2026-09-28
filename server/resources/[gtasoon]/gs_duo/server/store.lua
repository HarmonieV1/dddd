-- Persistance des duos.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_duos` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `a` VARCHAR(50) NOT NULL,
        `b` VARCHAR(50) NOT NULL,
        `name` VARCHAR(32) NOT NULL DEFAULT '',
        `xp` INT UNSIGNED NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_a` (`a`),
        UNIQUE KEY `uniq_b` (`b`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.find(cid)
    return MySQL.single.await('SELECT id, a, b, name, xp FROM gs_duos WHERE a = ? OR b = ?', { cid, cid })
end

function Store.create(a, b, name)
    return MySQL.insert.await('INSERT INTO gs_duos (a, b, name) VALUES (?, ?, ?)', { a, b, name })
end

function Store.delete(id)
    MySQL.update.await('DELETE FROM gs_duos WHERE id = ?', { id })
end

function Store.setXp(id, xp)
    MySQL.update('UPDATE gs_duos SET xp = ? WHERE id = ?', { xp, id })
end

function Store.rename(id, name)
    MySQL.update('UPDATE gs_duos SET name = ? WHERE id = ?', { name, id })
end
