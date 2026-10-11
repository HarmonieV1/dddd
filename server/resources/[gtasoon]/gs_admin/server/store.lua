-- Persistance staff : journal, notes, avertissements, jail (par licence = compte, pas par personnage).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_log` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `staff` VARCHAR(100) NOT NULL,
        `action` VARCHAR(32) NOT NULL,
        `target` VARCHAR(100) NULL,
        `details` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_date` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_notes` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `license` VARCHAR(64) NOT NULL,
        `kind` ENUM('note', 'warn') NOT NULL,
        `text` VARCHAR(255) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_license` (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_jail` (
        `license` VARCHAR(64) NOT NULL,
        `until_ts` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(255) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_vip` (
        `license` VARCHAR(64) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_ranks` (
        `license` VARCHAR(64) NOT NULL,
        `rank` TINYINT UNSIGNED NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    -- V12.4 · Bannissements RoadLine (en plus de txAdmin) : posés et RETIRÉS depuis le jeu (F11), ce que txAdmin ne
    -- permet pas. `until_ts` = 0 : définitif. Le pseudo est gardé pour pouvoir rechercher un banni hors ligne.
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_admin_bans` (
        `license` VARCHAR(64) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `until_ts` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(255) NOT NULL,
        `staff` VARCHAR(100) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`), KEY `idx_name` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Bannissement actif d'une licence (nil si aucun, ou si la peine est écoulée : la ligne est alors effacée).
function Store.ban(license)
    local b = MySQL.single.await('SELECT name, until_ts, reason, staff FROM gs_admin_bans WHERE license = ?', { license })
    if not b then return nil end
    if b.until_ts ~= 0 and b.until_ts <= os.time() then
        MySQL.update('DELETE FROM gs_admin_bans WHERE license = ?', { license })
        return nil
    end
    return b
end

--- Bannit une licence. `untilTs` = 0 : définitif.
function Store.banSet(license, name, untilTs, reason, staff)
    MySQL.update.await('REPLACE INTO gs_admin_bans (license, name, until_ts, reason, staff) VALUES (?, ?, ?, ?, ?)',
        { license, name, untilTs, reason, staff })
end

--- Lève un bannissement. Retourne true si une ligne a bien été retirée.
function Store.banClear(license)
    return (MySQL.update.await('DELETE FROM gs_admin_bans WHERE license = ?', { license }) or 0) > 0
end

--- Bannis actifs, les plus récents d'abord ; `search` filtre sur le pseudo ou la licence.
--- Deux requêtes fixes plutôt qu'une construite bout à bout : aucune chaîne SQL n'est assemblée à l'exécution.
function Store.bans(search, limit)
    limit = limit or 25
    if search and search ~= '' then
        local like = '%' .. search .. '%'
        return MySQL.query.await([[SELECT license, name, until_ts, reason, staff, UNIX_TIMESTAMP(created_at) AS created
            FROM gs_admin_bans WHERE (until_ts = 0 OR until_ts > ?) AND (name LIKE ? OR license LIKE ?)
            ORDER BY created_at DESC LIMIT ?]], { os.time(), like, like, limit }) or {}
    end
    return MySQL.query.await([[SELECT license, name, until_ts, reason, staff, UNIX_TIMESTAMP(created_at) AS created
        FROM gs_admin_bans WHERE (until_ts = 0 OR until_ts > ?)
        ORDER BY created_at DESC LIMIT ?]], { os.time(), limit }) or {}
end

--- Rangs donnés en jeu par un fondateur (0 = retiré : la ligne est supprimée).
function Store.ranks()
    return MySQL.query.await('SELECT license, `rank` FROM gs_admin_ranks') or {}
end

function Store.rankSet(license, rank, staff)
    if rank == 0 then return MySQL.update.await('DELETE FROM gs_admin_ranks WHERE license = ?', { license }) end
    MySQL.update.await('REPLACE INTO gs_admin_ranks (license, `rank`, staff) VALUES (?, ?, ?)', { license, rank, staff })
end

--- V11.5 · VIP (2 personnages), par licence
function Store.vips()
    return MySQL.query.await('SELECT license FROM gs_admin_vip') or {}
end

function Store.vipSet(license, on, staff)
    if not on then return MySQL.update.await('DELETE FROM gs_admin_vip WHERE license = ?', { license }) end
    MySQL.update.await('REPLACE INTO gs_admin_vip (license, staff) VALUES (?, ?)', { license, staff })
end

function Store.log(staff, action, target, details)
    MySQL.insert('INSERT INTO gs_admin_log (staff, action, target, details) VALUES (?, ?, ?, ?)', { staff, action, target, details })
end

function Store.recentLogs(limit)
    return MySQL.query.await([[SELECT staff, action, target, details, UNIX_TIMESTAMP(created_at) AS time
        FROM gs_admin_log ORDER BY id DESC LIMIT ?]], { limit }) or {}
end

function Store.addNote(license, kind, text, staff)
    MySQL.insert('INSERT INTO gs_admin_notes (license, kind, text, staff) VALUES (?, ?, ?, ?)', { license, kind, text, staff })
end

function Store.notes(license)
    return MySQL.query.await([[SELECT kind, text, staff, UNIX_TIMESTAMP(created_at) AS time
        FROM gs_admin_notes WHERE license = ? ORDER BY id DESC LIMIT 50]], { license }) or {}
end

function Store.jailGet(license)
    return MySQL.single.await('SELECT until_ts, reason FROM gs_admin_jail WHERE license = ?', { license })
end

function Store.jailSet(license, untilTs, reason, staff)
    MySQL.update.await('REPLACE INTO gs_admin_jail (license, until_ts, reason, staff) VALUES (?, ?, ?, ?)', { license, untilTs, reason, staff })
end

function Store.jailClear(license)
    MySQL.update('DELETE FROM gs_admin_jail WHERE license = ?', { license })
end
