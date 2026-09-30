-- [CONFIG] Location de véhicules. Prix bas exprès : c'est un service de base, pas une source de revenus.
-- Coords à caler en jeu (menu staff F11 → « Copier mes coordonnées »). spawn = place de parking libre à côté.
Config = {}

Config.Radius = 3.0          -- distance d'interaction au comptoir
Config.ReturnRadius = 20.0   -- le véhicule doit être à moins de X m du comptoir pour le rendre
Config.WarnBefore = 5        -- minutes : avertissement avant la fin
Config.Grace = 5             -- minutes après la fin avant retrait forcé (si le joueur est encore dedans)

Config.Vehicles = {
    { model = 'bmx',     label = 'BMX',                    type = 'bike',       price = 15,  minutes = 30 },
    { model = 'cruiser', label = 'Vélo de ville',          type = 'bike',       price = 20,  minutes = 45 },
    { model = 'faggio',  label = 'Scooter',                type = 'bike',       price = 45,  minutes = 45 },
    { model = 'panto',   label = 'Mini citadine (2 places)', type = 'automobile', price = 90,  minutes = 60 },
    { model = 'issi2',   label = 'Petite décapotable',     type = 'automobile', price = 140, minutes = 60 },
    -- Bateaux : proposés seulement aux points « nautiques » (kind = 'boat')
    { model = 'seashark', label = 'Jet-ski',                type = 'boat', kind = 'boat', price = 80,  minutes = 30 },
    { model = 'dinghy',   label = 'Semi-rigide',            type = 'boat', kind = 'boat', price = 150, minutes = 45 },
    { model = 'speeder',  label = 'Hors-bord',              type = 'boat', kind = 'boat', price = 260, minutes = 45 },
}

Config.Points = {
    { label = 'Location · Mairie',        coords = vec3(-515.6, -262.5, 35.5), spawn = vec4(-520.8, -268.4, 35.3, 110.0) },
    { label = 'Location · Legion Square', coords = vec3(215.9, -809.8, 30.7),  spawn = vec4(222.4, -805.2, 30.6, 250.0) },
    { label = 'Location · Del Perro',     coords = vec3(-1622.6, -1032.9, 13.1), spawn = vec4(-1616.3, -1038.1, 13.0, 140.0) },
    { label = 'Location · Sandy Shores',  coords = vec3(1852.3, 3686.0, 34.3), spawn = vec4(1858.0, 3682.4, 33.9, 210.0) },
    { label = 'Location · Paleto Bay',    coords = vec3(-155.2, 6360.1, 31.5), spawn = vec4(-160.3, 6364.2, 31.2, 45.0) },
    -- Nautique (spawn dans l'eau, à caler en jeu)
    { label = 'Location de bateaux · Marina de LS', kind = 'boat', coords = vec3(-794.4, -1510.8, 1.6), spawn = vec4(-800.3, -1504.2, 0.0, 110.0) },
    { label = 'Location de bateaux · Jetée de Cayo Perico', kind = 'boat', coords = vec3(4930.0, -5170.0, 2.5), spawn = vec4(4920.0, -5150.0, 0.0, 60.0) },
}

Config.Blip = { sprite = 226, color = 48, scale = 0.7 }
