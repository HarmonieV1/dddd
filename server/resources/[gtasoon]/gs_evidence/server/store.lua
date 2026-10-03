-- gs_evidence : fichier des empreintes / ADN (personnes fichées lors d'une arrestation).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_evidence_filed` (
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `filed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

function Store.filed(cid)
    return MySQL.scalar.await('SELECT `name` FROM `gs_evidence_filed` WHERE `citizenid` = ?', { cid })
end

function Store.file(cid, name)
    MySQL.insert.await('INSERT INTO `gs_evidence_filed` (`citizenid`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)', { cid, name })
end
