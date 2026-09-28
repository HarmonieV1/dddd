-- Persistance téléphone. Tout est indexé par numéro (le numéro suit le personnage).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_phone_numbers` (
        `citizenid` VARCHAR(50) NOT NULL,
        `number` VARCHAR(12) NOT NULL,
        PRIMARY KEY (`citizenid`),
        UNIQUE KEY `uniq_number` (`number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_phone_contacts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `owner` VARCHAR(12) NOT NULL,
        `name` VARCHAR(40) NOT NULL,
        `number` VARCHAR(12) NOT NULL,
        PRIMARY KEY (`id`), KEY `idx_owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_phone_messages` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `sender` VARCHAR(12) NOT NULL,
        `receiver` VARCHAR(12) NOT NULL,
        `content` VARCHAR(320) NOT NULL,
        `is_read` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_receiver` (`receiver`, `is_read`),
        KEY `idx_pair` (`sender`, `receiver`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.getNumber(cid)
    return MySQL.scalar.await('SELECT number FROM gs_phone_numbers WHERE citizenid = ?', { cid })
end

--- false si le numéro est déjà pris (clé unique).
function Store.createNumber(cid, number)
    return MySQL.update.await('INSERT IGNORE INTO gs_phone_numbers (citizenid, number) VALUES (?, ?)', { cid, number }) > 0
end

function Store.contacts(owner)
    return MySQL.query.await('SELECT id, name, number FROM gs_phone_contacts WHERE owner = ? ORDER BY name', { owner }) or {}
end

function Store.countContacts(owner)
    return MySQL.scalar.await('SELECT COUNT(*) FROM gs_phone_contacts WHERE owner = ?', { owner }) or 0
end

function Store.addContact(owner, name, number)
    return MySQL.insert.await('INSERT INTO gs_phone_contacts (owner, name, number) VALUES (?, ?, ?)', { owner, name, number })
end

function Store.deleteContact(owner, id)
    return MySQL.update.await('DELETE FROM gs_phone_contacts WHERE id = ? AND owner = ?', { id, owner }) > 0
end

function Store.addMessage(sender, receiver, content)
    return MySQL.insert.await('INSERT INTO gs_phone_messages (sender, receiver, content) VALUES (?, ?, ?)', { sender, receiver, content })
end

--- Dernier message et non-lus par interlocuteur.
function Store.conversations(me)
    return MySQL.query.await([[
        SELECT peer, MAX(id) AS last_id, SUM(unread) AS unread FROM (
            SELECT receiver AS peer, id, 0 AS unread FROM gs_phone_messages WHERE sender = ?
            UNION ALL
            SELECT sender AS peer, id, (is_read = 0) AS unread FROM gs_phone_messages WHERE receiver = ?
        ) t GROUP BY peer ORDER BY last_id DESC LIMIT 50]], { me, me }) or {}
end

function Store.messageById(id)
    return MySQL.single.await('SELECT sender, content, UNIX_TIMESTAMP(created_at) AS time FROM gs_phone_messages WHERE id = ?', { id })
end

function Store.thread(me, peer)
    return MySQL.query.await([[SELECT id, sender, content, UNIX_TIMESTAMP(created_at) AS time FROM gs_phone_messages
        WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?) ORDER BY id DESC LIMIT 100]],
        { me, peer, peer, me }) or {}
end

function Store.markRead(me, peer)
    MySQL.update('UPDATE gs_phone_messages SET is_read = 1 WHERE receiver = ? AND sender = ? AND is_read = 0', { me, peer })
end
