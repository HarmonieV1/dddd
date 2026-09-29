-- Contrats : persistés (la récompense bloquée ne doit jamais disparaître au redémarrage).
CStore = {}

function CStore.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_contracts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(16) NOT NULL,
        `title` VARCHAR(80) NOT NULL,
        `details` VARCHAR(400) NOT NULL DEFAULT '',
        `reward` INT UNSIGNED NOT NULL,
        `poster` VARCHAR(50) NOT NULL,
        `taker` VARCHAR(50) NULL,
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function CStore.all() return MySQL.query.await('SELECT id, kind, title, details, reward, poster, taker, created FROM gs_contracts') or {} end
function CStore.insert(c)
    return MySQL.insert.await('INSERT INTO gs_contracts (kind, title, details, reward, poster, created) VALUES (?, ?, ?, ?, ?, ?)',
        { c.kind, c.title, c.details, c.reward, c.poster, c.created })
end
function CStore.setTaker(id, taker) MySQL.update('UPDATE gs_contracts SET taker = ? WHERE id = ?', { taker, id }) end
function CStore.delete(id) MySQL.update('DELETE FROM gs_contracts WHERE id = ?', { id }) end
