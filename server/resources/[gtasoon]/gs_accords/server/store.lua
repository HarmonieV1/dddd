-- gs_accords : contrats signés (table gs_accords).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_accords` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(12) NOT NULL,
        `a_cid` VARCHAR(64) NOT NULL, `a_name` VARCHAR(80) NOT NULL,
        `b_cid` VARCHAR(64) NOT NULL, `b_name` VARCHAR(80) NOT NULL,
        `amount` INT UNSIGNED NOT NULL DEFAULT 0, `principal` INT UNSIGNED NOT NULL DEFAULT 0,
        `total` SMALLINT UNSIGNED NOT NULL DEFAULT 0, `paid` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `every_days` SMALLINT UNSIGNED NOT NULL DEFAULT 7, `next_at` INT UNSIGNED NOT NULL DEFAULT 0,
        `missed` SMALLINT UNSIGNED NOT NULL DEFAULT 0, `held` INT UNSIGNED NOT NULL DEFAULT 0,
        `status` VARCHAR(12) NOT NULL DEFAULT 'active', `terms` VARCHAR(255) NOT NULL DEFAULT '',
        `created_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`), KEY `a` (`a_cid`), KEY `b` (`b_cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.active() return MySQL.query.await("SELECT * FROM gs_accords WHERE status IN ('active', 'dispute')") or {} end
function Store.insert(c)
    return MySQL.insert.await([[INSERT INTO gs_accords (kind, a_cid, a_name, b_cid, b_name, amount, principal, total, paid, every_days,
        next_at, missed, held, status, terms, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, 0, 0, 'active', ?, ?)]],
        { c.kind, c.a_cid, c.a_name, c.b_cid, c.b_name, c.amount, c.principal, c.total, c.every_days, c.next_at, c.terms, c.created_at })
end
function Store.save(c)
    MySQL.update('UPDATE gs_accords SET paid = ?, next_at = ?, missed = ?, held = ?, status = ?, amount = ? WHERE id = ?',
        { c.paid, c.next_at, c.missed, c.held, c.status, c.amount, c.id })
end
