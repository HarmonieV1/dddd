-- [CONFIG] gs_faitsdivers · La ville a ses propres criminels. Un fait divers PNJ est créé seulement si la ville est
-- calme (peu de crimes de joueurs) ET qu'au moins un policier est en service : il ne remplace jamais les joueurs.
Config = {}

Config.Every = 8              -- minutes entre deux tirages
Config.Chance = 0.6           -- chance de créer un fait divers à chaque tirage (si la ville est calme)
Config.QuietWindow = 20       -- minutes : la ville est « calme » s'il y a eu moins de…
Config.QuietCrimes = 2        -- … crimes de joueurs pendant cette fenêtre
Config.MinPolice = 1
Config.MaxOpen = 2
Config.Lifetime = 25          -- minutes avant que l'affaire soit classée (« l'auteur court toujours »)
Config.Range = 6.0            -- distance pour traiter la scène
Config.Duration = 8000        -- ms de constatations
Config.PoliceJob, Config.EmsJob, Config.PressJob = 'police', 'ambulance', 'weazel'

Config.Kinds = {
    burglary = { label = 'Cambriolage', icon = 'house-crack', reward = { 300, 500 }, ems = false,
        brief = 'Cambriolage à %s : la police sur place, les voisins n\'ont rien vu.', action = 'Constater l\'effraction' },
    body = { label = 'Corps retrouvé', icon = 'skull', reward = { 400, 650 }, ems = true,
        brief = 'Macabre découverte à %s : un corps retrouvé, la police scientifique enquête.', action = 'Faire les constatations' },
    hitrun = { label = 'Délit de fuite', icon = 'car-burst', reward = { 300, 450 }, ems = true,
        brief = 'Délit de fuite à %s : un véhicule abandonné, le conducteur introuvable.', action = 'Relever les indices' },
    vandalism = { label = 'Vandalisme', icon = 'spray-can', reward = { 200, 350 }, ems = false,
        brief = 'Vandalisme à %s : vitrine brisée et tags, les commerçants excédés.', action = 'Constater les dégâts' },
}

-- [À CALER] lieux (déplaçables en jeu par le staff) ; kinds = types possibles à cet endroit
Config.Spots = {
    { coords = vec3(-14.5, -1441.6, 31.1), kinds = { 'burglary', 'vandalism' } },
    { coords = vec3(1229.6, -725.4, 60.8), kinds = { 'burglary' } },
    { coords = vec3(-842.9, -25.1, 40.4), kinds = { 'burglary' } },
    { coords = vec3(-1114.0, -1068.9, 2.2), kinds = { 'burglary', 'body' } },
    { coords = vec3(1972.6, 3815.5, 33.4), kinds = { 'burglary', 'body' } },
    { coords = vec3(-374.9, 6191.2, 31.7), kinds = { 'burglary', 'vandalism' } },
    { coords = vec3(-1040.4, -1338.6, 5.4), kinds = { 'body' } },
    { coords = vec3(491.0, -1314.0, 29.3), kinds = { 'body', 'vandalism' } },
    { coords = vec3(-546.0, -1640.0, 19.0), kinds = { 'body' } },
    { coords = vec3(209.0, -1470.0, 29.1), kinds = { 'hitrun', 'vandalism' } },
    { coords = vec3(-622.0, -930.0, 22.0), kinds = { 'hitrun' } },
    { coords = vec3(1160.0, -330.0, 68.8), kinds = { 'hitrun' } },
    { coords = vec3(2560.0, 383.0, 108.5), kinds = { 'hitrun' } },
    { coords = vec3(-215.0, -1330.0, 30.9), kinds = { 'vandalism' } },
}
Config.Models = { body = { 'a_m_m_skidrow_01', 'a_m_y_methhead_01', 'a_f_y_hipster_01' }, hitrun = { 'emperor', 'asea', 'primo', 'ingot' } }
