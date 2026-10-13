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
    -- V12.39 · virements vers un joueur déconnecté : gardés ici, versés à sa prochaine connexion
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_phone_pending` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `amount` INT UNSIGNED NOT NULL,
        `sender` VARCHAR(12) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Personnage propriétaire d'un numéro (même déconnecté), ou nil.
function Store.ownerOf(number)
    return MySQL.scalar.await('SELECT citizenid FROM gs_phone_numbers WHERE number = ?', { number })
end

function Store.addPending(cid, amount, sender)
    return MySQL.insert.await('INSERT INTO gs_phone_pending (citizenid, amount, sender) VALUES (?, ?, ?)', { cid, amount, sender }) ~= nil
end

--- Virements en attente d'un personnage : chaque ligne n'est rendue qu'une fois (supprimée avant d'être versée).
function Store.takePending(cid)
    local rows = MySQL.query.await('SELECT id, amount, sender FROM gs_phone_pending WHERE citizenid = ?', { cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if MySQL.update.await('DELETE FROM gs_phone_pending WHERE id = ?', { r.id }) > 0 then out[#out + 1] = r end
    end
    return out
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
