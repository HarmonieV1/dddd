-- gs_justice : affaires et verdicts.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_justice_cases` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `defendant` VARCHAR(50) NOT NULL,
        `defendant_name` VARCHAR(100) NOT NULL,
        `charge` VARCHAR(200) NOT NULL,
        `judge` VARCHAR(100) NOT NULL,
        `lawyer` VARCHAR(100) NOT NULL DEFAULT '',
        `status` VARCHAR(12) NOT NULL DEFAULT 'open',
        `verdict` VARCHAR(250) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.open(cid, name, charge, judge, lawyer)
    return MySQL.insert.await('INSERT INTO gs_justice_cases (defendant, defendant_name, charge, judge, lawyer) VALUES (?, ?, ?, ?, ?)',
        { cid, name, charge, judge, lawyer or '' })
end
function Store.get(id) return MySQL.single.await('SELECT * FROM gs_justice_cases WHERE id = ?', { id }) end
function Store.close(id, status, verdict) MySQL.query.await('UPDATE gs_justice_cases SET status = ?, verdict = ? WHERE id = ?', { status, verdict, id }) end
function Store.list(limit)
    return MySQL.query.await([[SELECT id, defendant_name, charge, judge, lawyer, status, verdict, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date
        FROM gs_justice_cases ORDER BY (status = 'open') DESC, id DESC LIMIT ?]], { limit }) or {}
end
