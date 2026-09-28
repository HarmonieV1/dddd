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
