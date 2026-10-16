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
    -- V12.63 · North Yankton (journée North Yankton) : véhicules enneigés du jeu de base, au comptoir de Ludendorff seulement
    { model = 'asea2',      label = 'Berline enneigée',     type = 'automobile', kind = 'snow', price = 90,  minutes = 60 },
    { model = 'sadler2',    label = 'Pick-up enneigé',      type = 'automobile', kind = 'snow', price = 130, minutes = 60 },
    { model = 'rancherxl2', label = '4x4 enneigé',          type = 'automobile', kind = 'snow', price = 160, minutes = 60 },
}

Config.Points = {
    { label = 'Location · Mairie',        coords = vec3(-515.6, -262.5, 35.5), spawn = vec4(-520.8, -268.4, 35.3, 110.0) },
    { label = 'Location · Legion Square', coords = vec3(215.9, -809.8, 30.7),  spawn = vec4(222.4, -805.2, 30.6, 250.0) },
    { label = 'Location · Del Perro',     coords = vec3(-1622.6, -1032.9, 13.1), spawn = vec4(-1616.3, -1038.1, 13.0, 140.0) },
    -- V12.37 : sorti du poste de police de Sandy Shores (il était dans le hall du shérif) → devant le supermarché 24/7
    -- d'Alhambra Drive, place de parking à côté [À CALER] (autre option : la station-service Xero, 2005.0, 3774.0, 32.4)
    { label = 'Location · Sandy Shores',  coords = vec3(1966.0, 3746.0, 32.3), spawn = vec4(1973.0, 3751.0, 32.1, 120.0) },
    { label = 'Location · Paleto Bay',    coords = vec3(-155.2, 6360.1, 31.5), spawn = vec4(-160.3, 6364.2, 31.2, 45.0) },
    -- Nautique (spawn dans l'eau, à caler en jeu)
    { label = 'Location de bateaux · Marina de LS', kind = 'boat', coords = vec3(-794.4, -1510.8, 1.6), spawn = vec4(-800.3, -1504.2, 0.0, 110.0) },
    -- V12.63 : `island` = ouvert seulement les jours où le vol de l'aéroport mène à cette île (Cayo et North Yankton se partagent la place)
    { label = 'Location de bateaux · Jetée de Cayo Perico', kind = 'boat', island = 'cayo', coords = vec3(4930.0, -5170.0, 2.5), spawn = vec4(4920.0, -5150.0, 0.0, 60.0) },
    -- V12.37 · Retour en ville depuis la campagne et les pôles de passage (demande du fondateur) : vélos / scooters / mini
    -- citadines (pas de bateau). Ajoutés EN FIN de liste pour ne pas décaler les clés des points déjà déplacés par le staff
    -- (clé = gs_rental:Config.Points.N.coords). Coordonnées plausibles [À CALER] en jeu : F11 → Points → « Placer ce point ici ».
    { label = 'Location · Grapeseed',          coords = vec3(1692.0, 4934.0, 42.1),   spawn = vec4(1685.0, 4940.0, 41.9, 145.0) },  -- devant le 24/7 et la station
    { label = 'Location · Harmony (Route 68)', coords = vec3(1046.0, 2666.0, 39.6),   spawn = vec4(1053.0, 2660.0, 39.4, 180.0) },  -- station-service de Route 68
    { label = 'Location · Vinewood',           coords = vec3(614.0, 262.5, 103.1),    spawn = vec4(607.0, 257.5, 102.9, 340.0) },   -- station-service de Clinton Ave
    { label = 'Location · Vespucci',           coords = vec3(-1215.0, -1573.0, 4.4),  spawn = vec4(-1222.0, -1580.0, 4.2, 35.0) },   -- front de mer, parking de la plage
    { label = 'Location · Aéroport (LSIA)',    coords = vec3(-1037.5, -2731.0, 13.8), spawn = vec4(-1030.0, -2743.0, 13.6, 240.0) }, -- parking devant le terminal
    { label = 'Location · Hôpital Pillbox',    coords = vec3(306.0, -592.0, 43.3),    spawn = vec4(316.0, -600.0, 43.1, 340.0) },   -- sortie principale, côté rue
    -- V12.63 · North Yankton (jours North Yankton seulement) : à côté de l'arrivée du vol, à Ludendorff [À CALER] en jeu
    -- (F11 → Monde et lieux → Déplacer un point) ; le véhicule est reposé au sol par le jeu à la sortie (jamais à travers la carte)
    { label = 'Location · Ludendorff (North Yankton)', kind = 'snow', island = 'yankton', coords = vec3(3356.5, -4853.5, 111.8), spawn = vec4(3366.0, -4858.0, 111.8, 90.0) },
}

Config.Blip = { sprite = 226, color = 48, scale = 0.7 }
