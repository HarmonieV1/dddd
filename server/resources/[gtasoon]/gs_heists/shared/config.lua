-- [CONFIG] Braquages. Coords approximatives (map vanilla) : à caler en jeu avec /builder ou le debug ox_target.
Config = {}

Config.PoliceJob = 'police'
Config.DirtyItem = 'black_money'   -- butin en argent sale (item ox_inventory) ; si absent : liquide
Config.SessionTimeout = 300        -- s pour finir un braquage commencé
Config.Tolerance = 3.0             -- marge serveur (latence) sur les distances
Config.DuoRadius = 25.0            -- partenaire de duo à moins de X m = bonus de lien

-- Bonus de butin (multiplicateurs)
Config.Bonus = {
    night = 1.15,                  -- 22h → 5h (heure du jeu, gs_weather)
    weatherEvent = 1.20,           -- tempête / brouillard : la ville est désorganisée
    ownTerritory = 1.15,           -- braquage dans un quartier tenu par ton gang
    influence = 2,                 -- influence gagnée par ton gang dans le quartier, par butin
}

-- type : 'store' (caisse), 'jewelry' (vitrines), 'bank' (coffres)
-- points : chaque point est pillable une fois par braquage (action = durée en ms)
Config.Sites = {
    store_strawberry = { label = 'Supérette de Strawberry', crime = 'store_robbery', minPolice = 1, cooldown = 1800,
        alarmChance = 0.6, action = 25000, reward = { 700, 1400 }, radius = 12.0, center = vec3(25.7, -1347.3, 29.5),
        points = { vec3(24.4, -1345.2, 29.5) }, verb = 'Braquer la caisse' },
    store_grove = { label = 'Supérette de Grove Street', crime = 'store_robbery', minPolice = 1, cooldown = 1800,
        alarmChance = 0.6, action = 25000, reward = { 700, 1400 }, radius = 12.0, center = vec3(-48.5, -1757.5, 29.4),
        points = { vec3(-47.2, -1759.2, 29.4) }, verb = 'Braquer la caisse' },
    store_mirror = { label = 'Supérette de Mirror Park', crime = 'store_robbery', minPolice = 1, cooldown = 1800,
        alarmChance = 0.6, action = 25000, reward = { 700, 1400 }, radius = 12.0, center = vec3(1163.4, -323.8, 69.2),
        points = { vec3(1164.7, -322.6, 69.2) }, verb = 'Braquer la caisse' },
    store_sandy = { label = 'Supérette de Sandy Shores', crime = 'store_robbery', minPolice = 1, cooldown = 1800,
        alarmChance = 0.5, action = 25000, reward = { 800, 1600 }, radius = 12.0, center = vec3(1961.5, 3740.7, 32.3),
        points = { vec3(1959.2, 3740.9, 32.3) }, verb = 'Braquer la caisse' },
    jewelry = { label = 'Bijouterie Vangelico', crime = 'jewelry', minPolice = 3, cooldown = 3600,
        alarmChance = 1.0, action = 6000, reward = { 900, 1500 }, radius = 20.0, center = vec3(-622.0, -231.0, 38.1),
        points = { vec3(-627.2, -234.9, 38.1), vec3(-626.1, -233.1, 38.1), vec3(-625.2, -238.0, 38.1),
                   vec3(-623.0, -232.6, 38.1), vec3(-620.2, -234.4, 38.1), vec3(-619.2, -230.4, 38.1) },
        verb = 'Briser la vitrine' },
    fleeca_legion = { label = 'Fleeca Legion Square', crime = 'bank', minPolice = 4, cooldown = 5400,
        alarmChance = 1.0, action = 20000, reward = { 2500, 4200 }, radius = 15.0, center = vec3(149.0, -1042.0, 29.4),
        points = { vec3(147.0, -1046.0, 29.4), vec3(150.2, -1045.0, 29.4), vec3(149.2, -1047.8, 29.4) },
        verb = 'Forcer le coffre' },
}
