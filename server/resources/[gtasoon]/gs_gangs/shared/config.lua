-- [CONFIG] Gangs et territoires. Les gangs sont créés par le staff (/gsgang create) : pas de gang « sauvage ».
Config = {}

Config.Grades = {
    [0] = { label = 'Recrue' },
    [1] = { label = 'Membre' },
    [2] = { label = 'Bras droit', manage = true },      -- recrute / gère les grades inférieurs
    [3] = { label = 'Chef', manage = true, bank = true }, -- + caisse
}
Config.MaxMembers = 25
Config.InviteRange = 4.0
Config.InviteTimeout = 60
Config.PoliceJob = 'police'
Config.Key = 'F9'

-- Territoires : influence 0-100 par gang. Propriétaire = gang le plus influent au-dessus du seuil.
Config.Territory = {
    tickMinutes = 5,
    presencePerMember = 1,   -- influence / membre présent / tick
    presenceCap = 4,         -- max gagné par tick et par gang via la présence
    crimeBonus = 3,          -- crime signalé dans le quartier par un membre
    decay = 1,               -- baisse / tick pour les gangs absents
    policePerCop = 1,        -- baisse / tick / policier en service présent (tous les gangs)
    ownThreshold = 50,       -- influence minimale pour tenir le quartier
    racketPerHour = 600,     -- revenu versé à la caisse du gang propriétaire, par quartier
    heatWindow = 3600,       -- chaleur de quartier = crimes signalés sur la dernière heure
}

-- Gangs créés automatiquement au 1er démarrage (si absents), avec leur QG / planque dans leur quartier du jeu.
-- Le staff peut ensuite déplacer une planque (/builder → « Placer une planque de gang ici ») ou en créer d'autres.
-- color = couleur de blip GTA. Coords à caler en jeu.
Config.DefaultGangs = {
    { name = 'families', label = 'Families', color = 25, stash = vec3(107.8, -1942.9, 20.8) },    -- Grove Street
    { name = 'ballas', label = 'Ballas', color = 27, stash = vec3(4.9, -1819.3, 29.2) },          -- Davis
    { name = 'vagos', label = 'Vagos', color = 46, stash = vec3(336.3, -2040.2, 21.4) },          -- Rancho / Jamestown
    { name = 'marabunta', label = 'Marabunta Grande', color = 3, stash = vec3(1437.0, -1492.0, 63.6) }, -- El Burro Heights
    { name = 'lostmc', label = 'Lost MC', color = 40, stash = vec3(986.6, -95.1, 74.8) },         -- club-house, East Vinewood
}

-- Garage des gangs par défaut (un véhicule par membre, aux couleurs du gang). garage = sortie ; paint = couleur GTA.
Config.GangGarages = {
    families = { garage = vec4(113.7, -1948.6, 20.7, 50.0), paint = 53, vehicles = { 'chino', 'buccaneer2', 'manchez' } },
    ballas = { garage = vec4(11.6, -1823.6, 25.3, 140.0), paint = 145, vehicles = { 'faction2', 'buccaneer2', 'manchez' } },
    vagos = { garage = vec4(331.5, -2033.4, 20.9, 50.0), paint = 88, vehicles = { 'chino2', 'moonbeam2', 'manchez' } },
    marabunta = { garage = vec4(1429.9, -1497.1, 62.0, 170.0), paint = 70, vehicles = { 'voodoo', 'tornado', 'manchez' } },
    lostmc = { garage = vec4(972.7, -114.6, 74.4, 225.0), paint = 0, vehicles = { 'daemon', 'hexer', 'gburrito' } },
}

-- Tags : bombe de peinture (item spraycan). Limite par gang, distance mini entre deux tags, influence de quartier.
Config.Tags = { maxPerGang = 15, minDistance = 25.0, range = 3.0, influence = 2, drawDistance = 30.0, sprayTime = 6000, eraseTime = 8000 }

-- Couleurs d'affichage (tags) par couleur de blip GTA
Config.ColorRGB = { [1] = { 224, 50, 50 }, [3] = { 93, 182, 229 }, [25] = { 57, 200, 90 }, [27] = { 170, 90, 255 },
    [40] = { 190, 190, 190 }, [46] = { 240, 200, 80 }, default = { 255, 46, 136 } }

-- Receleur (vente en gros) : grade minimum, quantité minimum, nuit seulement, lieu qui change toutes les heures
-- Flotte du gang : le chef (grade 3) choisit jusqu'à `max` modèles pour le garage, plus UN véhicule personnalisé
-- (modèle + 2 couleurs GTA 0-159). Liste des modèles autorisés (lowriders, muscle, motos, utilitaires discrets).
Config.GangFleet = {
    max = 4,
    choices = { 'chino', 'chino2', 'buccaneer2', 'faction', 'faction2', 'faction3', 'moonbeam2', 'voodoo', 'voodoo2', 'tornado', 'tornado5',
        'primo2', 'sabregt2', 'virgo2', 'virgo3', 'minivan2', 'slamvan3', 'blade', 'dominator', 'gauntlet', 'ellie', 'impaler',
        'baller', 'cavalcade', 'granger', 'patriot', 'gburrito', 'speedo', 'manchez', 'sanchez', 'daemon', 'hexer', 'zombiea', 'bati' },
}

-- Atelier de munitions artisanales (dans la planque du gang) : ferraille + cuivre (ferrailleur, gs_harvest).
-- Moins cher que le marché noir, mais il faut récolter ; plafond par gang et par jour.
Config.AmmoCraft = {
    dailyCap = 600, range = 3.0,
    recipes = {
        ['ammo-9'] = { label = '9 mm (×20)', out = 20, scrapmetal = 6, copper = 2, time = 15000, minGrade = 1 },
        ['ammo-45'] = { label = '.45 (×20)', out = 20, scrapmetal = 7, copper = 3, time = 15000, minGrade = 1 },
        ['ammo-shotgun'] = { label = 'Cartouches (×10)', out = 10, scrapmetal = 6, copper = 2, time = 15000, minGrade = 1 },
        ['ammo-rifle'] = { label = '5,56 (×30)', out = 30, scrapmetal = 12, copper = 5, time = 25000, minGrade = 2 },
    },
}

Config.Fence = {
    minGrade = 1, minQty = 10, maxQty = 50, bonus = 1.35, hours = { 21, 5 }, rotateMinutes = 60, reportChance = 0.35,
    locations = { vec3(-1154.9, -1558.9, 4.4), vec3(1204.7, -3116.9, 5.5), vec3(716.0, -965.0, 30.4), vec3(2474.0, 3444.0, 50.1) },
}

-- Quartiers (coords approximatives, à caler en jeu)
Config.Territories = {
    grove    = { label = 'Grove Street',      center = vec3(105.0, -1940.0, 20.8),  radius = 220.0 },
    davis    = { label = 'Davis',             center = vec3(40.0, -1640.0, 29.3),   radius = 250.0 },
    rancho   = { label = 'Rancho',            center = vec3(420.0, -1820.0, 28.3),  radius = 250.0 },
    elburro  = { label = 'El Burro Heights',  center = vec3(1370.0, -1560.0, 55.0), radius = 280.0 },
    mirror   = { label = 'Mirror Park',       center = vec3(1100.0, -500.0, 64.0),  radius = 280.0 },
    canals   = { label = 'Vespucci Canals',   center = vec3(-1070.0, -1010.0, 2.0), radius = 260.0 },
    sandy    = { label = 'Sandy Shores',      center = vec3(1850.0, 3700.0, 33.0),  radius = 400.0 },
    paleto   = { label = 'Paleto Bay',        center = vec3(-200.0, 6300.0, 31.0),  radius = 400.0 },
}

-- Guerres de territoire déclarées : un chef (grade avec gestion) déclare la guerre au gang qui tient un quartier.
-- Préavis, durée, coût (caisse du gang), points par joueur adverse mis à terre dans le quartier. Le vainqueur prend le quartier.
Config.Wars = {
    cost = 5000,                 -- prélevé dans la caisse du gang attaquant
    notice = 600,                -- secondes avant le début (les défenseurs sont prévenus)
    duration = 1200,             -- secondes de guerre
    cooldown = 21600,            -- 6 h avant qu'un gang attaquant puisse en redéclarer une
    defenderCooldown = 3600,     -- 1 h de répit pour le défenseur après une guerre
    minAttackers = 2, minDefenders = 1,   -- membres en ligne requis à la déclaration
    killPoints = 3, winMargin = 3,        -- points par joueur mis à terre ; écart minimal pour l'emporter
    hitWindow = 15,              -- secondes entre le dernier coup reçu et la chute pour compter
    victimCooldown = 60,         -- une même victime ne rapporte qu'une fois par minute
    winInfluence = 65,           -- influence du vainqueur sur le quartier (dépasse le seuil de 50)
}
