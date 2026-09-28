-- Persistance gangs / territoires.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gangs` (
        `name` VARCHAR(30) NOT NULL,
        `label` VARCHAR(50) NOT NULL,
        `color` TINYINT UNSIGNED NOT NULL DEFAULT 1,
        `money` BIGINT UNSIGNED NOT NULL DEFAULT 0,
        `stash_x` FLOAT NULL, `stash_y` FLOAT NULL, `stash_z` FLOAT NULL,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gang_members` (
        `citizenid` VARCHAR(50) NOT NULL,
        `gang` VARCHAR(30) NOT NULL,
        `grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        PRIMARY KEY (`citizenid`), KEY `idx_gang` (`gang`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gang_territories` (
        `id` VARCHAR(30) NOT NULL,
        `owner` VARCHAR(30) NULL,
        `influence` TEXT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.gangs() return MySQL.query.await('SELECT * FROM gs_gangs') or {} end
function Store.createGang(name, label, color)
    return MySQL.update.await('INSERT IGNORE INTO gs_gangs (name, label, color) VALUES (?, ?, ?)', { name, label, color }) > 0
end
function Store.deleteGang(name)
    MySQL.update.await('DELETE FROM gs_gang_members WHERE gang = ?', { name })
    MySQL.update.await('DELETE FROM gs_gangs WHERE name = ?', { name })
end
function Store.setStash(name, c) MySQL.update('UPDATE gs_gangs SET stash_x = ?, stash_y = ?, stash_z = ? WHERE name = ?', { c.x, c.y, c.z, name }) end
function Store.addMoney(name, n) return MySQL.update.await('UPDATE gs_gangs SET money = money + ? WHERE name = ?', { n, name }) > 0 end
function Store.removeMoney(name, n)
    return MySQL.update.await('UPDATE gs_gangs SET money = money - ? WHERE name = ? AND money >= ?', { n, name, n }) > 0
end
function Store.money(name) return MySQL.scalar.await('SELECT money FROM gs_gangs WHERE name = ?', { name }) or 0 end

function Store.member(cid) return MySQL.single.await('SELECT gang, grade FROM gs_gang_members WHERE citizenid = ?', { cid }) end
function Store.members(gang)
    return MySQL.query.await('SELECT citizenid, grade, name FROM gs_gang_members WHERE gang = ? ORDER BY grade DESC, name', { gang }) or {}
end
function Store.countMembers(gang) return MySQL.scalar.await('SELECT COUNT(*) FROM gs_gang_members WHERE gang = ?', { gang }) or 0 end
function Store.addMember(cid, gang, grade, name)
    return MySQL.update.await('INSERT IGNORE INTO gs_gang_members (citizenid, gang, grade, name) VALUES (?, ?, ?, ?)', { cid, gang, grade, name }) > 0
end
function Store.setGrade(cid, grade) MySQL.update.await('UPDATE gs_gang_members SET grade = ? WHERE citizenid = ?', { grade, cid }) end
function Store.removeMember(cid) return MySQL.update.await('DELETE FROM gs_gang_members WHERE citizenid = ?', { cid }) > 0 end

function Store.territories() return MySQL.query.await('SELECT id, owner, influence FROM gs_gang_territories') or {} end
function Store.saveTerritories(rows)
    if #rows == 0 then return end
    MySQL.prepare('REPLACE INTO gs_gang_territories (id, owner, influence) VALUES (?, ?, ?)', rows)
end
