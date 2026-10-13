-- gs_driving : état du permis par personnage. status : 0 rien, 1 code obtenu, 2 permis (examen ou ancien personnage),
-- 3 retiré par la police (V12.36, permis pour tous : ne doit pas être redonné à la connexion). card : 1 = carte déjà remise.
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_driving` (
        `citizenid` VARCHAR(50) NOT NULL,
        `status` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    -- V8 : permis à points
    MySQL.query.await('ALTER TABLE `gs_driving` ADD COLUMN IF NOT EXISTS `points` TINYINT UNSIGNED NOT NULL DEFAULT 12')
    MySQL.query.await('ALTER TABLE `gs_driving` ADD COLUMN IF NOT EXISTS `last_offense` INT UNSIGNED NOT NULL DEFAULT 0')
    -- V12.36 : la carte « permis » n'est remise qu'une fois par personnage (nouvel essai à la connexion suivante si le sac n'était pas prêt)
    MySQL.query.await('ALTER TABLE `gs_driving` ADD COLUMN IF NOT EXISTS `card` TINYINT UNSIGNED NOT NULL DEFAULT 0')
end

function Store.points(cid)
    local r = MySQL.single.await('SELECT points, last_offense FROM gs_driving WHERE citizenid = ?', { cid })
    if not r then return nil end
    return r.points, r.last_offense
end
function Store.setPoints(cid, points, last)
    MySQL.query.await('UPDATE gs_driving SET points = ?, last_offense = ? WHERE citizenid = ?', { points, last, cid })
end

function Store.get(cid) return MySQL.scalar.await('SELECT status FROM gs_driving WHERE citizenid = ?', { cid }) end
-- V12.36 : insertion ou mise à jour du statut seul (l'ancien REPLACE effaçait la ligne : points et carte repartaient de zéro)
function Store.set(cid, status)
    MySQL.query.await('INSERT INTO gs_driving (citizenid, status) VALUES (?, ?) ON DUPLICATE KEY UPDATE status = VALUES(status)', { cid, status })
end
function Store.card(cid) return MySQL.scalar.await('SELECT card FROM gs_driving WHERE citizenid = ?', { cid }) or 0 end
function Store.setCard(cid, card) MySQL.query.await('UPDATE gs_driving SET card = ? WHERE citizenid = ?', { card, cid }) end
function Store.hasVehicle(cid) return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? LIMIT 1', { cid }) ~= nil end
