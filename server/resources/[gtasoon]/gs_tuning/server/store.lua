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
