-- gs_tuning : lecture / écriture des véhicules possédés (player_vehicles, qbx_vehicles) : plaque et néons dans `mods` (JSON).
Store = {}

--- Id du véhicule possédé par ce personnage avec cette plaque (comparaison sans espaces ni casse) ou nil.
function Store.ownedByPlate(cid, plate)
    return MySQL.scalar.await([[SELECT id FROM player_vehicles WHERE citizenid = ? AND UPPER(TRIM(plate)) = UPPER(TRIM(?)) LIMIT 1]], { cid, plate })
end

function Store.plateTaken(plate)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE UPPER(TRIM(plate)) = UPPER(TRIM(?)) LIMIT 1', { plate }) ~= nil
end

function Store.setPlate(id, cid, plate)
    return MySQL.update.await([[UPDATE player_vehicles SET plate = ?, mods = JSON_SET(COALESCE(NULLIF(mods, ''), '{}'), '$.plate', ?)
        WHERE id = ? AND citizenid = ?]], { plate, plate, id, cid }) > 0
end

--- rgb = { r, g, b } → néons allumés de cette couleur ; nil → néons éteints.
function Store.setNeon(id, cid, rgb)
    if rgb then
        return MySQL.update.await([[UPDATE player_vehicles SET mods = JSON_SET(COALESCE(NULLIF(mods, ''), '{}'),
            '$.neonEnabled', JSON_ARRAY(TRUE, TRUE, TRUE, TRUE), '$.neonColor', JSON_ARRAY(?, ?, ?)) WHERE id = ? AND citizenid = ?]],
            { rgb[1], rgb[2], rgb[3], id, cid }) > 0
    end
    return MySQL.update.await([[UPDATE player_vehicles SET mods = JSON_SET(COALESCE(NULLIF(mods, ''), '{}'),
        '$.neonEnabled', JSON_ARRAY(FALSE, FALSE, FALSE, FALSE)) WHERE id = ? AND citizenid = ?]], { id, cid }) > 0
end

--- Véhicule possédé (n'importe quel propriétaire) par plaque → id, plaque en base, citizenid du propriétaire ; ou nil.
--- V12.36 : le citizenid sert à vérifier que le client est à côté (son accord) et à prévenir son jeu.
function Store.byPlate(plate)
    local row = MySQL.single.await('SELECT id, plate, citizenid FROM player_vehicles WHERE UPPER(TRIM(plate)) = UPPER(TRIM(?)) LIMIT 1', { plate })
    return row and row.id, row and row.plate, row and row.citizenid
end

--- V12.36 · Réglages actuels du véhicule en base (format ox_lib) : table (vide si rien), nil si la ligne n'existe pas.
function Store.getProps(id)
    local row = MySQL.single.await('SELECT mods FROM player_vehicles WHERE id = ? LIMIT 1', { id })
    if not row then return nil end
    local ok, props = pcall(json.decode, row.mods or '{}')
    return ok and type(props) == 'table' and props or {}
end

--- Remplace les réglages du véhicule (format ox_lib getVehicleProperties, comme qbx_vehicles).
--- V12.36 : réussite = requête exécutée (des réglages identiques donnent 0 ligne modifiée, ce n'est pas une erreur).
function Store.setProps(id, json)
    return MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE id = ?', { json, id }) ~= nil
end
