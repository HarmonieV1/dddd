-- gs_carnet : compteur et historique des véhicules de joueurs.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_carnet` (
        `plate` VARCHAR(12) NOT NULL,
        `km` DOUBLE NOT NULL DEFAULT 0,
        `owner` VARCHAR(50) NOT NULL DEFAULT '',
        `owners` INT UNSIGNED NOT NULL DEFAULT 1,
        `color` INT NOT NULL DEFAULT -1,
        PRIMARY KEY (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_carnet_events` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `plate` VARCHAR(12) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `text` VARCHAR(160) NOT NULL,
        `police` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.get(plate) return MySQL.single.await('SELECT * FROM gs_carnet WHERE plate = ?', { plate }) end
function Store.save(r)
    MySQL.query('INSERT INTO gs_carnet (plate, km, owner, owners, color) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE km = VALUES(km), owner = VALUES(owner), owners = VALUES(owners), color = VALUES(color)',
        { r.plate, r.km, r.owner, r.owners, r.color })
end
function Store.event(plate, kind, text, police)
    MySQL.insert('INSERT INTO gs_carnet_events (plate, kind, text, police) VALUES (?, ?, ?, ?)', { plate, kind, text, police and 1 or 0 })
end
function Store.events(plate, police, keep)
    return MySQL.query.await(('SELECT kind, text, police, DATE_FORMAT(created_at, "%%d/%%m %%H:%%i") AS date FROM gs_carnet_events WHERE plate = ? %s ORDER BY id DESC LIMIT ?')
        :format(police and '' or 'AND police = 0'), { plate, keep }) or {}
end
