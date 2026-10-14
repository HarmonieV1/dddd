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
    -- V12.41 · RoadCoins : solde par COMPTE Cfx.re (acheteur Tebex), partagé entre ses personnages, jamais convertible
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_store_wallet` (
        `buyer` VARCHAR(64) NOT NULL,
        `coins` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`buyer`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_store_coin_log` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `buyer` VARCHAR(64) NOT NULL,
        `delta` INT NOT NULL,
        `reason` VARCHAR(120) NOT NULL,
        `at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_buyer` (`buyer`)
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
    local row = MySQL.single.await('SELECT status, claimed_by, package, buyer FROM gs_store_orders WHERE `transaction` = ?', { transaction })
    if not row then return nil end
    MySQL.update.await("UPDATE gs_store_orders SET status = 'revoked' WHERE `transaction` = ?", { transaction })
    MySQL.update.await('DELETE FROM gs_store_unlocks WHERE `transaction` = ?', { transaction })
    return row.status, row.claimed_by, row.package, row.buyer
end

-- RoadCoins -------------------------------------------------------------------------------------------------
function Store.coins(buyer)
    return tonumber(MySQL.scalar.await('SELECT coins FROM gs_store_wallet WHERE buyer = ?', { buyer })) or 0
end

function Store.addCoins(buyer, n, reason)
    MySQL.update.await('INSERT INTO gs_store_wallet (buyer, coins) VALUES (?, ?) ON DUPLICATE KEY UPDATE coins = coins + VALUES(coins)', { buyer, n })
    MySQL.insert('INSERT INTO gs_store_coin_log (buyer, delta, reason) VALUES (?, ?, ?)', { buyer, n, reason })
end

--- Dépense atomique : false si le solde ne suffit pas (jamais de solde négatif, même avec deux clics simultanés).
function Store.spendCoins(buyer, n, reason)
    local ok = MySQL.update.await('UPDATE gs_store_wallet SET coins = coins - ? WHERE buyer = ? AND coins >= ?', { n, buyer, n }) > 0
    if ok then MySQL.insert('INSERT INTO gs_store_coin_log (buyer, delta, reason) VALUES (?, ?, ?)', { buyer, -n, reason }) end
    return ok
end

--- Retrait après remboursement Tebex : retire ce qui reste (au plus `n`), retourne ce qui a vraiment été retiré.
function Store.takeBackCoins(buyer, n, reason)
    local have = Store.coins(buyer)
    local take = math.min(have, n)
    if take > 0 then Store.spendCoins(buyer, take, reason) end
    return take
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
