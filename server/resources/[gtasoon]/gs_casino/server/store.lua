-- gs_casino : compteur quotidien par personnage (roue, tickets).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_casino_daily` (
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `day` VARCHAR(10) NOT NULL,
        `count` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Nombre d'utilisations aujourd'hui (0 si autre jour ou jamais).
function Store.used(cid, kind, day)
    local row = MySQL.single.await('SELECT `day`, `count` FROM `gs_casino_daily` WHERE `citizenid` = ? AND `kind` = ?', { cid, kind })
    if not row or row.day ~= day then return 0 end
    return row.count
end

function Store.bump(cid, kind, day)
    MySQL.query.await([[INSERT INTO `gs_casino_daily` (`citizenid`, `kind`, `day`, `count`) VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `count` = IF(`day` = VALUES(`day`), `count` + 1, 1), `day` = VALUES(`day`)]], { cid, kind, day })
end

-- Loto hebdomadaire ----------------------------------------------------------------------------------------
function Store.initLotto()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_lotto_tickets` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `week` VARCHAR(8) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(40) NOT NULL,
        PRIMARY KEY (`id`), KEY `idx_week` (`week`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await('CREATE TABLE IF NOT EXISTS `gs_lotto_draws` (`week` VARCHAR(8) NOT NULL, `result` TEXT NOT NULL, PRIMARY KEY (`week`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
    MySQL.query.await('CREATE TABLE IF NOT EXISTS `gs_lotto_state` (`k` VARCHAR(20) NOT NULL, `v` BIGINT NOT NULL DEFAULT 0, PRIMARY KEY (`k`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
    MySQL.query.await('CREATE TABLE IF NOT EXISTS `gs_lotto_pending` (`citizenid` VARCHAR(50) NOT NULL, `amount` BIGINT NOT NULL DEFAULT 0, PRIMARY KEY (`citizenid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
end
function Store.lottoBuy(week, cid, name, n)
    for _ = 1, n do MySQL.insert.await('INSERT INTO gs_lotto_tickets (week, citizenid, name) VALUES (?, ?, ?)', { week, cid, name }) end
end
function Store.lottoMine(week, cid) return MySQL.scalar.await('SELECT COUNT(*) FROM gs_lotto_tickets WHERE week = ? AND citizenid = ?', { week, cid }) or 0 end
function Store.lottoTickets(week) return MySQL.query.await('SELECT id, citizenid, name FROM gs_lotto_tickets WHERE week = ?', { week }) or {} end
function Store.lottoOpenWeeks()
    local rows = MySQL.query.await('SELECT DISTINCT week FROM gs_lotto_tickets WHERE week NOT IN (SELECT week FROM gs_lotto_draws) ORDER BY week') or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.week end
    return out
end
function Store.lottoDone(week, result) MySQL.query.await('REPLACE INTO gs_lotto_draws (week, result) VALUES (?, ?)', { week, result }) end
function Store.lottoLast() return MySQL.scalar.await('SELECT result FROM gs_lotto_draws ORDER BY week DESC LIMIT 1') end
function Store.lottoCarry() return MySQL.scalar.await("SELECT v FROM gs_lotto_state WHERE k = 'carry'") or 0 end
function Store.lottoSetCarry(n) MySQL.query.await("REPLACE INTO gs_lotto_state (k, v) VALUES ('carry', ?)", { n }) end
function Store.pendingAdd(cid, n) MySQL.query.await('INSERT INTO gs_lotto_pending (citizenid, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)', { cid, n }) end
function Store.pendingTake(cid)
    local n = MySQL.scalar.await('SELECT amount FROM gs_lotto_pending WHERE citizenid = ?', { cid }) or 0
    if n > 0 then MySQL.query.await('DELETE FROM gs_lotto_pending WHERE citizenid = ?', { cid }) end
    return n
end
