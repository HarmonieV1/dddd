-- gs_reputation : jauges par personnage.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_reputation` (
        `citizenid` VARCHAR(50) NOT NULL,
        `street` INT UNSIGNED NOT NULL DEFAULT 0, `legal` INT UNSIGNED NOT NULL DEFAULT 0, `media` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.load(cid)
    local r = MySQL.single.await('SELECT street, legal, media FROM gs_reputation WHERE citizenid = ?', { cid })
    return r and { street = r.street, legal = r.legal, media = r.media } or { street = 0, legal = 0, media = 0 }
end

function Store.save(cid, r)
    MySQL.query.await('REPLACE INTO gs_reputation (citizenid, street, legal, media) VALUES (?, ?, ?, ?)', { cid, r.street, r.legal, r.media })
end
