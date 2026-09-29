-- Accès BDD (oxmysql). Toutes les requêtes sont paramétrées (jamais de concaténation).
DB = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `gs_job_members` (
        `citizenid` VARCHAR(50) NOT NULL,
        `job` VARCHAR(50) NOT NULL,
        `grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `job`),
        KEY `idx_job` (`job`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `gs_societies` (
        `job` VARCHAR(50) NOT NULL,
        `money` BIGINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`job`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `gs_bills` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `job` VARCHAR(50) NOT NULL,
        `amount` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(100) NOT NULL DEFAULT '',
        `issuer_citizenid` VARCHAR(50) NOT NULL,
        `issuer_name` VARCHAR(100) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_citizen` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `gs_job_audit` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `action` VARCHAR(32) NOT NULL,
        `job` VARCHAR(50) NULL,
        `actor` VARCHAR(50) NULL,
        `target` VARCHAR(50) NULL,
        `amount` INT NULL,
        `details` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_job_date` (`job`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `gs_job_salaries` (
        `job` VARCHAR(50) NOT NULL,
        `grade` TINYINT UNSIGNED NOT NULL,
        `salary` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`job`, `grade`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- Salaires fixés par la direction (entreprises payées par leur caisse) ------------------------------------
function DB.getSalaries() return MySQL.query.await('SELECT job, grade, salary FROM gs_job_salaries') or {} end
function DB.setSalary(job, grade, salary)
    MySQL.update('REPLACE INTO gs_job_salaries (job, grade, salary) VALUES (?, ?, ?)', { job, grade, salary })
end

function DB.init()
    for _, query in ipairs(SCHEMA) do MySQL.query.await(query) end
    for name, def in pairs(Jobs) do
        if def.society then MySQL.update.await('INSERT IGNORE INTO gs_societies (job, money) VALUES (?, 0)', { name }) end
    end
end

-- Contrats -----------------------------------------------------------------------

function DB.getMemberships(cid)
    return MySQL.query.await('SELECT job, grade FROM gs_job_members WHERE citizenid = ?', { cid }) or {}
end

function DB.countMemberships(cid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM gs_job_members WHERE citizenid = ?', { cid }) or 0
end

function DB.getMember(cid, job)
    return MySQL.single.await('SELECT grade, name FROM gs_job_members WHERE citizenid = ? AND job = ?', { cid, job })
end

function DB.getEmployees(job)
    return MySQL.query.await(
        'SELECT citizenid, grade, name FROM gs_job_members WHERE job = ? ORDER BY grade DESC, name', { job }) or {}
end

function DB.addMember(cid, job, grade, name)
    return MySQL.update.await('INSERT INTO gs_job_members (citizenid, job, grade, name) VALUES (?, ?, ?, ?)',
        { cid, job, grade, name }) > 0
end

function DB.removeMember(cid, job)
    return MySQL.update.await('DELETE FROM gs_job_members WHERE citizenid = ? AND job = ?', { cid, job }) > 0
end

function DB.setGrade(cid, job, grade)
    MySQL.update.await('UPDATE gs_job_members SET grade = ? WHERE citizenid = ? AND job = ?', { grade, cid, job })
end

function DB.updateName(cid, name)
    MySQL.update('UPDATE gs_job_members SET name = ? WHERE citizenid = ?', { name, cid })
end

-- Caisses ------------------------------------------------------------------------

function DB.getSociety(job)
    return MySQL.scalar.await('SELECT money FROM gs_societies WHERE job = ?', { job }) or 0
end

function DB.addSociety(job, amount)
    return MySQL.update.await('UPDATE gs_societies SET money = money + ? WHERE job = ?', { amount, job }) > 0
end

--- Retrait atomique : échoue si le solde est insuffisant (pas de course possible entre deux retraits).
function DB.removeSociety(job, amount)
    return MySQL.update.await('UPDATE gs_societies SET money = money - ? WHERE job = ? AND money >= ?',
        { amount, job, amount }) > 0
end

-- Factures -----------------------------------------------------------------------

function DB.createBill(cid, job, amount, reason, issuerCid, issuerName)
    return MySQL.insert.await(
        'INSERT INTO gs_bills (citizenid, job, amount, reason, issuer_citizenid, issuer_name) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, job, amount, reason, issuerCid, issuerName })
end

function DB.countBills(cid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM gs_bills WHERE citizenid = ?', { cid }) or 0
end

function DB.getBills(cid)
    return MySQL.query.await([[SELECT id, job, amount, reason, issuer_name, DATE_FORMAT(created_at, '%d/%m %H:%i') AS date
        FROM gs_bills WHERE citizenid = ? ORDER BY id DESC LIMIT 50]], { cid }) or {}
end

function DB.getBill(id, cid)
    return MySQL.single.await('SELECT id, job, amount, issuer_citizenid FROM gs_bills WHERE id = ? AND citizenid = ?',
        { id, cid })
end

function DB.deleteBill(id, cid)
    return MySQL.update.await('DELETE FROM gs_bills WHERE id = ? AND citizenid = ?', { id, cid }) > 0
end

-- Audit (non bloquant) -------------------------------------------------------------

function DB.audit(action, job, actor, target, amount, details)
    MySQL.insert('INSERT INTO gs_job_audit (action, job, actor, target, amount, details) VALUES (?, ?, ?, ?, ?, ?)',
        { action, job, actor, target, amount, details })
end
