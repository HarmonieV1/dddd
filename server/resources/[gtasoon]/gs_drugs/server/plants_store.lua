-- gs_drugs : plants de cannabis en base (survivent au redémarrage).
PlantStore = {}

function PlantStore.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_weed_plants` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `owner` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `growth` FLOAT NOT NULL DEFAULT 0,
        `water` FLOAT NOT NULL DEFAULT 0,
        `health` FLOAT NOT NULL DEFAULT 100,
        `fert` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`), KEY `owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function PlantStore.all() return MySQL.query.await('SELECT * FROM `gs_weed_plants`') or {} end

function PlantStore.insert(owner, c)
    return MySQL.insert.await('INSERT INTO `gs_weed_plants` (`owner`, `x`, `y`, `z`) VALUES (?, ?, ?, ?)', { owner, c.x, c.y, c.z })
end

function PlantStore.update(p)
    MySQL.update('UPDATE `gs_weed_plants` SET `growth` = ?, `water` = ?, `health` = ?, `fert` = ? WHERE `id` = ?',
        { p.growth, p.water, p.health, p.fert and 1 or 0, p.id })
end

function PlantStore.delete(id) MySQL.update('DELETE FROM `gs_weed_plants` WHERE `id` = ?', { id }) end
