-- [CONFIG] Gangs et territoires. Les gangs sont créés par le staff (/gsgang create) : pas de gang « sauvage ».
Config = {}

Config.Grades = {
    [0] = { label = 'Recrue' },
    [1] = { label = 'Membre' },
    [2] = { label = 'Bras droit', manage = true },      -- recrute / gère les grades inférieurs
    [3] = { label = 'Chef', manage = true, bank = true }, -- + caisse
}
-- V12 · Opérations (guerre de l'information) : payées par la caisse, grade minimum, repos entre deux, trace remontable
-- par la police au commissariat (gs_cctv, 5 min d'analyse)
Config.Ops = {
    jam = { label = 'Brouiller les caméras du quartier', icon = 'video-slash', cost = 5000, minutes = 10, radius = 350.0, minGrade = 2, cooldown = 1800,
        help = 'Toutes les caméras de surveillance à 350 m deviennent aveugles pendant 10 min. 5 000 $ de la caisse. La police pourra remonter jusqu\'à vous.' },
    scanner = { label = 'Pirater le scanner police', icon = 'tower-broadcast', cost = 8000, minutes = 10, minGrade = 2, cooldown = 3600,
        help = 'Pendant 10 min, tous les membres en ligne reçoivent les appels passés à la police (signalements, 911). 8 000 $ de la caisse. Traçable.' },
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
    -- V12.40 · Expansion par la notoriété : niveau 0 à 3 selon l'influence du gang qui tient le quartier (au-dessus du seuil),
    -- +15 % de rayon par niveau (+45 % max) ; le staff peut ajouter un bonus (/territoire). Jamais toute la carte :
    maxPerGang = 3,          -- quartiers tenus au maximum par un même gang
    levelStep = 15,          -- points d'influence au-dessus du seuil par niveau
    maxLevel = 3,
    growPerLevel = 0.15,
}

-- V12.40 · Population du gang dans les quartiers qu'il tient (PNJ locaux, créés à l'approche, plus nombreux avec le niveau) :
-- rivaux = hostiles, police = méfiants, civils = neutres (ils répondent si on les provoque).
Config.Population = {
    base = 3, perLevel = 2, max = 9,  -- PNJ par quartier : base + perLevel × niveau
    spawnRange = 160.0, despawnRange = 210.0,
    weapons = { 'WEAPON_PISTOL', 'WEAPON_KNIFE', 'WEAPON_BAT', 'WEAPON_SNSPISTOL' },
    scenarios = { 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_DRINKING', 'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_LEANING', 'WORLD_HUMAN_STAND_IMPATIENT' },
    models = { -- par gang (id) ; autres gangs : `default`
        families = { 'g_m_y_famca_01', 'g_m_y_famdnf_01', 'g_m_y_famfor_01' },
        ballas = { 'g_m_y_ballaeast_01', 'g_m_y_ballaorig_01', 'g_m_y_ballasout_01' },
        vagos = { 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03' },
        lostmc = { 'g_m_y_lost_01', 'g_m_y_lost_02', 'g_m_y_lost_03' },
        madrazo = { 'g_m_m_mexboss_01', 'g_m_y_mexgang_01', 'g_m_m_mexboss_02' },
        default = { 'g_m_y_salvagoon_01', 'g_m_y_strpunk_01', 'g_m_y_korean_01', 'g_m_y_azteca_01' },
    },
}

-- Gangs créés automatiquement au 1er démarrage (si absents), avec leur QG / planque dans leur quartier du jeu.
-- V7 : 4 gangs de rue + 2 organisations criminelles (noms de l'univers GTA). Le staff déplace une planque ou un garage en
-- jeu (F11 → Monde et lieux → Gangs) ou en crée d'autres. color = couleur de blip GTA.
Config.DefaultGangs = {
    { name = 'families', label = 'Families', color = 25, stash = vec3(107.8, -1942.9, 20.8) },    -- Grove Street
    { name = 'ballas', label = 'Ballas', color = 27, stash = vec3(4.9, -1819.3, 29.2) },          -- Davis
    { name = 'vagos', label = 'Vagos', color = 46, stash = vec3(336.3, -2040.2, 21.4) },          -- Rancho / Jamestown
    { name = 'lostmc', label = 'Lost MC', color = 40, stash = vec3(986.6, -95.1, 74.8) },         -- club-house, East Vinewood
    { name = 'madrazo', label = 'Cartel Madrazo (organisation)', color = 1, stash = vec3(1395.0, 1141.8, 114.3) }, -- ranch Madrazo
    { name = 'triads', label = 'Triades (organisation)', color = 3, stash = vec3(-649.6, -1232.2, 11.4) },        -- [À CALER] Little Seoul
}
-- Gangs par défaut des versions précédentes, retirés (seulement s'ils n'ont plus aucun membre)
Config.RemovedGangs = { 'marabunta' }

-- Garage des gangs par défaut (un véhicule par membre, aux couleurs du gang). garage = sortie ; paint = couleur GTA.
Config.GangGarages = {
    families = { garage = vec4(113.7, -1948.6, 20.7, 50.0), paint = 53, vehicles = { 'chino', 'buccaneer2', 'manchez' } },
    ballas = { garage = vec4(11.6, -1823.6, 29.2, 140.0), paint = 145, vehicles = { 'faction2', 'buccaneer2', 'manchez' } },
    vagos = { garage = vec4(331.5, -2033.4, 20.9, 50.0), paint = 88, vehicles = { 'chino2', 'moonbeam2', 'manchez' } },
    lostmc = { garage = vec4(972.7, -114.6, 74.4, 225.0), paint = 0, vehicles = { 'daemon', 'hexer', 'gburrito' } },
    madrazo = { garage = vec4(1406.5, 1118.5, 114.8, 90.0), paint = 0, vehicles = { 'baller', 'cavalcade', 'patriot' } },
    triads = { garage = vec4(-656.0, -1227.0, 11.0, 120.0), paint = 27, vehicles = { 'fugitive', 'sultan', 'bati' } },
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
    -- V12.56 · Forme : cases carrées de `cell` m alignées sur les rues (angle par quartier ci-dessous). Réglage en jeu :
    -- /quartierforme <quartier> <angle> [taille] (admin), gardé au redémarrage. 0° = rues nord-sud / est-ouest.
    cell = 90.0,
    locations = { vec3(-1154.9, -1558.9, 4.4), vec3(1204.7, -3116.9, 5.5), vec3(716.0, -965.0, 30.4), vec3(2474.0, 3444.0, 50.1) },
}

-- Quartiers (coords approximatives, à caler en jeu). angle = sens des rues (V12.56, estimé : à affiner avec /quartierforme)
Config.Territories = {
    grove    = { label = 'Grove Street',      center = vec3(105.0, -1940.0, 20.8),  radius = 220.0, angle = 0.0 },
    davis    = { label = 'Davis',             center = vec3(40.0, -1640.0, 29.3),   radius = 250.0, angle = 0.0 },
    rancho   = { label = 'Rancho',            center = vec3(420.0, -1820.0, 28.3),  radius = 250.0, angle = 0.0 },
    elburro  = { label = 'El Burro Heights',  center = vec3(1370.0, -1560.0, 55.0), radius = 280.0, angle = 0.0 },
    mirror   = { label = 'Mirror Park',       center = vec3(1100.0, -500.0, 64.0),  radius = 280.0, angle = 0.0 },
    canals   = { label = 'Vespucci Canals',   center = vec3(-1070.0, -1010.0, 2.0), radius = 260.0, angle = 37.0 },
    sandy    = { label = 'Sandy Shores',      center = vec3(1850.0, 3700.0, 33.0),  radius = 400.0, angle = 30.0, cell = 120.0 },
    paleto   = { label = 'Paleto Bay',        center = vec3(-200.0, 6300.0, 31.0),  radius = 400.0, angle = 45.0, cell = 110.0 },
}

-- Guerres de territoire déclarées : un chef (grade avec gestion) déclare la guerre au gang qui tient un quartier.
-- Préavis, durée, coût (caisse du gang), points par joueur adverse mis à terre dans le quartier. Le vainqueur prend le quartier.
-- V9 · Racket des commerces de joueurs : « protection » hebdomadaire prélevée sur la caisse du commerce.
Config.Racket = {
    min = 500, max = 5000,       -- montant hebdomadaire demandé
    every = 7,                   -- jours entre deux prélèvements
    range = 8.0,                 -- à portée de la caisse du commerce
    minGrade = 1,                -- les recrues ne rackettent pas
    cooldown = 3600,             -- une demande par commerce et par heure
    answer = 120,                -- secondes pour que le patron réponde
    grudge = 1800,               -- après un refus / un impayé : 30 min pour « faire passer le message »
    damage = 1000,               -- vitrine cassée : dégâts pris sur la caisse du commerce
}
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

-- V12.63 · Trêve entre gangs (proposition n° 152) : un cadre propose une trêve à un autre gang (menu Gang → Trêves), un cadre
-- d'en face l'accepte dans les `offerMinutes`. Pendant `hours` heures : pas de guerre déclarée entre eux. Mettre à terre un
-- membre du gang ami pendant la trêve la ROMPT : le gang fautif perd `penalty` points d'influence dans chaque quartier où il
-- en a (sa réputation chute dans toute la ville), Weazel l'annonce, les deux gangs sont prévenus.
Config.Truce = { hours = 48, offerMinutes = 10, penalty = 15 }
