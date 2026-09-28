-- Persistance boutique. Une commande Tebex = une ligne (transaction unique : jamais livrée deux fois).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_store_orders` (
        `transaction` VARCHAR(64) NOT NULL,
        `package` VARCHAR(64) NOT NULL,
        `buyer` VARCHAR(64) NOT NULL,
        `status` ENUM('pending', 'claimed', 'revoked') NOT NULL DEFAULT 'pending',
        `claimed_by` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `claimed_at` TIMESTAMP NULL,
        PRIMARY KEY (`transaction`),
        KEY `idx_buyer` (`buyer`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_store_unlocks` (
        `citizenid` VARCHAR(50) NOT NULL,
        `type` VARCHAR(16) NOT NULL,
        `ref` VARCHAR(64) NOT NULL,
        `transaction` VARCHAR(64) NOT NULL,
        PRIMARY KEY (`citizenid`, `type`, `ref`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_store_prefs` (
        `citizenid` VARCHAR(50) NOT NULL,
        `ped` VARCHAR(64) NULL,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

--- Retourne true si la commande est nouvelle (false = déjà connue, rien à faire).
function Store.addOrder(transaction, package, buyer)
    return MySQL.update.await('INSERT IGNORE INTO gs_store_orders (`transaction`, package, buyer) VALUES (?, ?, ?)',
        { transaction, package, buyer }) > 0
end

function Store.pending(buyer)
    return MySQL.query.await(
        "SELECT `transaction`, package FROM gs_store_orders WHERE buyer = ? AND status = 'pending' ORDER BY created_at",
        { buyer }) or {}
end

--- Passe une commande de pending à claimed. Atomique : false si déjà réclamée / révoquée / pas à lui.
function Store.claim(transaction, buyer, cid)
    return MySQL.update.await(
        "UPDATE gs_store_orders SET status = 'claimed', claimed_by = ?, claimed_at = NOW() WHERE `transaction` = ? AND buyer = ? AND status = 'pending'",
        { cid, transaction, buyer }) > 0
end

--- Révocation (remboursement / chargeback). Retourne l'ancien statut et le personnage éventuel.
function Store.revoke(transaction)
    local row = MySQL.single.await('SELECT status, claimed_by FROM gs_store_orders WHERE `transaction` = ?', { transaction })
    if not row then return nil end
    MySQL.update.await("UPDATE gs_store_orders SET status = 'revoked' WHERE `transaction` = ?", { transaction })
    MySQL.update.await('DELETE FROM gs_store_unlocks WHERE `transaction` = ?', { transaction })
    return row.status, row.claimed_by
end

function Store.unlock(cid, gtype, ref, transaction)
    MySQL.update.await('INSERT IGNORE INTO gs_store_unlocks (citizenid, type, ref, `transaction`) VALUES (?, ?, ?, ?)',
        { cid, gtype, ref, transaction })
end

function Store.unlocks(cid)
    return MySQL.query.await('SELECT type, ref FROM gs_store_unlocks WHERE citizenid = ?', { cid }) or {}
end

function Store.setPed(cid, ped)
    MySQL.update('INSERT INTO gs_store_prefs (citizenid, ped) VALUES (?, ?) ON DUPLICATE KEY UPDATE ped = VALUES(ped)', { cid, ped })
end

function Store.getPed(cid)
    return MySQL.scalar.await('SELECT ped FROM gs_store_prefs WHERE citizenid = ?', { cid })
end
