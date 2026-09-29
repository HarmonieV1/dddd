-- gs_civil : mariages en cours (un personnage = au plus un conjoint).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_civil_marriages` (
        `a` VARCHAR(50) NOT NULL,
        `b` VARCHAR(50) NOT NULL,
        `a_name` VARCHAR(100) NOT NULL,
        `b_name` VARCHAR(100) NOT NULL,
        `since` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`a`), UNIQUE KEY `uniq_b` (`b`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- { cid, name } du conjoint, ou nil
function Store.spouse(cid)
    local r = MySQL.single.await('SELECT a, b, a_name, b_name FROM gs_civil_marriages WHERE a = ? OR b = ?', { cid, cid })
    if not r then return nil end
    if r.a == cid then return { cid = r.b, name = r.b_name } end
    return { cid = r.a, name = r.a_name }
end

function Store.marry(a, b, aName, bName) MySQL.query.await('INSERT INTO gs_civil_marriages (a, b, a_name, b_name) VALUES (?, ?, ?, ?)', { a, b, aName, bName }) end
function Store.divorce(cid) return MySQL.update.await('DELETE FROM gs_civil_marriages WHERE a = ? OR b = ?', { cid, cid }) > 0 end
