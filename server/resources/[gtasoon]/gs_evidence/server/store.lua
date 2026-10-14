-- gs_evidence : fichier des empreintes / ADN (personnes fichées lors d'une arrestation) ; V12.42 : scellés gardés en base
-- (avant : en mémoire seulement → après un redémarrage, les sacs de l'inventaire ne correspondaient plus à rien au labo).
Store = {}

function Store.init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_evidence_filed` (
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL,
        `filed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_evidence_seals` (
        `id` INT UNSIGNED NOT NULL,
        `data` TEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    -- analyses terminées depuis plus de 60 jours : effacées (les dossiers judiciaires gardent leur texte)
    MySQL.update.await('DELETE FROM `gs_evidence_seals` WHERE `updated_at` < (NOW() - INTERVAL 60 DAY)')
end

--- Champs gardés d'un scellé (les coordonnées en table simple : un vector3 ne passe pas en JSON)
local KEEP = { 'id', 'kind', 'status', 'by', 'byName', 'at', 'date', 'key', 'cid', 'weapon', 'serial', 'registered', 'vtype', 'color',
    'readyAt', 'result', 'trace', 'n' }
function Store.saveSeal(s)
    local d = {}
    for _, k in ipairs(KEEP) do d[k] = s[k] end
    if s.coords then d.coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z } end
    MySQL.update('INSERT INTO `gs_evidence_seals` (`id`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)', { s.id, json.encode(d) })
end

function Store.loadSeals()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `data` FROM `gs_evidence_seals`') or {}) do
        local ok, d = pcall(json.decode, r.data)
        if ok and type(d) == 'table' then
            d.id = tonumber(r.id)
            if d.coords then d.coords = vec3(d.coords.x + 0.0, d.coords.y + 0.0, d.coords.z + 0.0) end
            out[#out + 1] = d
        end
    end
    return out
end

function Store.filed(cid)
    return MySQL.scalar.await('SELECT `name` FROM `gs_evidence_filed` WHERE `citizenid` = ?', { cid })
end

function Store.file(cid, name)
    MySQL.insert.await('INSERT INTO `gs_evidence_filed` (`citizenid`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)', { cid, name })
end
