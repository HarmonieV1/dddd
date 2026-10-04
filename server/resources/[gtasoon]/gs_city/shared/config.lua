-- [CONFIG] Los Santos réactif. Quartiers = cercles (centre x/y, rayon) ; un point hors de tout cercle n'a pas de tension.
Config = {}

Config.Districts = {
    { id = 'downtown', label = 'Centre-ville', center = vec2(150.0, -850.0), radius = 650.0 },
    { id = 'south', label = 'South Los Santos', center = vec2(100.0, -1750.0), radius = 700.0 },
    { id = 'east', label = 'East Los Santos', center = vec2(1150.0, -1500.0), radius = 700.0 },
    { id = 'vespucci', label = 'Vespucci et Del Perro', center = vec2(-1300.0, -1100.0), radius = 650.0 },
    { id = 'rockford', label = 'Rockford Hills et Richman', center = vec2(-1000.0, -200.0), radius = 750.0 },
    { id = 'vinewood', label = 'Vinewood', center = vec2(300.0, 300.0), radius = 700.0 },
    { id = 'port', label = 'Port et Elysian Island', center = vec2(600.0, -2900.0), radius = 750.0 },
    { id = 'sandy', label = 'Sandy Shores et Blaine', center = vec2(1800.0, 3700.0), radius = 1200.0 },
    { id = 'paleto', label = 'Paleto Bay', center = vec2(-200.0, 6300.0), radius = 700.0 },
}

-- Tension = somme des « heat » des crimes signalés (gs_wanted : braquage 30, banque 60, coups de feu 15…), plafonnée.
Config.MaxHeat = 150
Config.HeatScale = 1.0
Config.DecayPerMinute = 2        -- un quartier « chaud » (90) redevient calme en ~45 min sans nouveau crime

-- Niveaux : report = témoins plus prompts à appeler ; npcStars = police IA plus nombreuse (sans LSPD en ligne) ;
-- peds / vehicles = passants et trafic (multiplie la densité de gs_world) ; enter = message en entrant dans le quartier.
Config.Levels = {
    { min = 0, label = 'calme', report = 1.0, npcStars = 0, peds = 1.0, vehicles = 1.0 },
    { min = 40, label = 'tendu', report = 1.15, npcStars = 0, peds = 0.75, vehicles = 0.85,
      enter = 'Quartier tendu : les riverains sont sur leurs gardes et appellent vite la police.' },
    { min = 90, label = 'chaud', report = 1.35, npcStars = 1, peds = 0.45, vehicles = 0.65,
      enter = 'Quartier sous tension : rues désertes, témoins nerveux, la police arrive en force.' },
}

-- Brèves Weazel News automatiques (gs_social) quand un quartier change d'ambiance.
Config.News = {
    [2] = '%s : plusieurs incidents signalés, les riverains appellent à la prudence.',
    [3] = '%s sous tension : braquages et coups de feu, les habitants restent chez eux. Renforts de police attendus.',
    calm = 'Retour au calme à %s après plusieurs heures de tension.',
}

-- V10 · Le quartier évolue : standing de -100 (à l'abandon) à +100 (huppé). Les commerces qui vendent, les vitrines
-- réparées et les déchets ramassés le font monter ; crimes, tags, trafics et racket le font baisser. Il revient
-- doucement vers 0. Effets : déchets dans la rue (à ramasser, payé par la mairie), recette des commerces, brèves Weazel.
Config.Standing = {
    revenue = 0.02,      -- +1 point par 50 $ de vraies ventes dans le quartier
    crime = 0.15,        -- -0.15 point par point de « heat » d'un crime (braquage 30 → -4.5)
    tag = 3, untag = 2,  -- tag posé / effacé
    gang = 1.5,          -- livraison au receleur, atelier de munitions…
    repair = 2,          -- vitrine réparée
    clean = 0.5,         -- un tas de déchets ramassé
    drift = 1,           -- points par heure vers 0
    max = 100,
    levels = {           -- du plus bas au plus haut
        { max = -50, label = 'à l\'abandon', trash = 6, sales = 0.85 },
        { max = -15, label = 'en déclin', trash = 3, sales = 0.95 },
        { max = 15, label = 'ordinaire', trash = 0, sales = 1.0 },
        { max = 50, label = 'en plein essor', trash = 0, sales = 1.05 },
        { max = 101, label = 'huppé', trash = 0, sales = 1.10 },
    },
    news = {
        [1] = '%s à l\'abandon : déchets, tags et vitrines brisées, les commerçants ferment boutique.',
        [2] = '%s en déclin : les riverains se plaignent de la saleté et des trafics.',
        [4] = '%s en plein essor : les commerces tournent, le quartier attire du monde.',
        [5] = '%s devient le quartier chic de Los Santos.',
    },
    cleanPay = { 25, 45 }, cleanPerHour = 30,
    trashProps = { 'prop_rub_binbag_01', 'prop_rub_binbag_03', 'prop_rub_litter_03', 'prop_rub_cardpile_04', 'prop_rub_tyre_01', 'prop_bin_05a' },
}
