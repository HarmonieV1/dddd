-- gs_memoire : événements par lieu (persistés), jamais d'identité de joueur (seulement le genre et une phrase publique).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_memoire_events` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `cell` VARCHAR(24) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `text` VARCHAR(120) NOT NULL DEFAULT '',
        `at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`), KEY `cell` (`cell`), KEY `at` (`at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.add(e)
    MySQL.insert('INSERT INTO gs_memoire_events (cell, x, y, z, kind, text, at) VALUES (?, ?, ?, ?, ?, ?, ?)', { e.cell, e.x, e.y, e.z, e.kind, e.text, e.at })
end

--- Événements récents (moins de `days` jours), les plus anciens d'abord
function Store.recent(days)
    return MySQL.query.await('SELECT cell, x, y, z, kind, text, at FROM gs_memoire_events WHERE at > ? ORDER BY at ASC LIMIT 5000', { os.time() - days * 86400 }) or {}
end
