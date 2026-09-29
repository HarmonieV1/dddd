-- gs_business : prix fixés par les patrons et livre de comptes.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_business_prices` (
        `business` VARCHAR(30) NOT NULL, `item` VARCHAR(50) NOT NULL, `price` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`business`, `item`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_business_ledger` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `business` VARCHAR(30) NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `item` VARCHAR(50) NOT NULL DEFAULT '',
        `qty` INT UNSIGNED NOT NULL DEFAULT 0,
        `amount` INT NOT NULL DEFAULT 0,
        `who` VARCHAR(100) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_biz` (`business`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.prices()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT business, item, price FROM gs_business_prices') or {}) do
        out[r.business] = out[r.business] or {}
        out[r.business][r.item] = r.price
    end
    return out
end
function Store.setPrice(biz, item, price) MySQL.query.await('REPLACE INTO gs_business_prices (business, item, price) VALUES (?, ?, ?)', { biz, item, price }) end
function Store.log(biz, kind, item, qty, amount, who)
    MySQL.insert('INSERT INTO gs_business_ledger (business, kind, item, qty, amount, who) VALUES (?, ?, ?, ?, ?, ?)', { biz, kind, item, qty, amount, who })
end
function Store.ledger(biz, limit)
    return MySQL.query.await([[SELECT kind, item, qty, amount, who, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date FROM gs_business_ledger
        WHERE business = ? ORDER BY id DESC LIMIT ?]], { biz, limit }) or {}
end
function Store.todaySales(biz)
    return MySQL.scalar.await([[SELECT COALESCE(SUM(amount), 0) FROM gs_business_ledger WHERE business = ? AND kind = 'sale'
        AND created_at >= CURDATE()]], { biz }) or 0
end
