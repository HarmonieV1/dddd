-- [CONFIG] Progression. Tout se règle ici ; les quêtes sont dans quests.lua.
Config = {}

Config.MaxLevel = 50
--- XP nécessaire pour passer du niveau `level` au suivant (200, 300, 400…).
function Config.StepXP(level) return 100 + 100 * level end
--- Récompense de passage de niveau (banque).
function Config.LevelReward(level) return 150 * level end

-- XP gagnée ailleurs (appelée par les autres ressources via exports.gs_quests:AddXP)
Config.XP = {
    job_mission = 25,     -- mission de métier terminée
    drug_sale = 5,        -- vente de drogue réussie
    heist = 20,           -- point de butin d'un braquage
}

-- Titres affichés sur Vibe et dans le panel staff (le plus haut atteint)
Config.Titles = {
    { level = 1, label = 'Nouveau venu' }, { level = 3, label = 'Habitué' }, { level = 5, label = 'Débrouillard' },
    { level = 8, label = 'Figure locale' }, { level = 12, label = 'Pointure' }, { level = 18, label = 'Vétéran' },
    { level = 25, label = 'Légende urbaine' }, { level = 35, label = 'Icône de Los Santos' }, { level = 50, label = 'Mythe' },
}

-- Badges (succès) : débloqués une fois pour toutes
Config.Badges = {
    first_quest = { label = 'Premier contrat', desc = 'Terminer une quête' },
    sal_family  = { label = 'Ami de la famille', desc = 'Terminer l\'histoire de Big Sal' },
    rosa_circle = { label = 'Le cercle de Rosa', desc = 'Terminer l\'histoire de Mama Rosa' },
    voice       = { label = 'Au bout du fil', desc = 'Répondre à la Voix jusqu\'au bout' },
    collector   = { label = 'Collectionneur', desc = 'Trouver tous les paquets cachés' },
    streak7     = { label = 'Fidèle', desc = '7 jours de connexion d\'affilée' },
    daily10     = { label = 'Assidu', desc = 'Réussir 10 défis du jour' },
}

-- Défis du jour : 3 tirés au sort par personnage et par jour (même tirage toute la journée)
Config.Daily = {
    count = 3, xp = 150, allXp = 300, allCash = 500, allItems = { { 'scratch_ticket', 1 } }, -- les 3 défis : + 1 ticket à gratter
    pool = {
        { id = 'job_mission', label = 'Termine une mission de métier', goal = 1 },
        { id = 'quest', label = 'Termine une quête', goal = 1 },
        { id = 'package', label = 'Trouve un paquet caché', goal = 1 },
        { id = 'rental', label = 'Loue un véhicule', goal = 1 },
        { id = 'shop_buy', label = 'Fais 3 achats en magasin', goal = 3 },
        { id = 'sell', label = 'Revends des matériaux à la casse', goal = 1 },
        { id = 'playtime', label = 'Passe 30 minutes en ville', goal = 30 },
        { id = 'drug_sale', label = 'Réussis 3 ventes discrètes', goal = 3 },
        { id = 'heist', label = 'Récupère un butin de braquage', goal = 1 },
        { id = 'race', label = 'Termine une course de rue', goal = 1 },
        { id = 'harvest', label = 'Pêche, mine, coupe du bois ou chasse (5 fois)', goal = 5 },
    },
}

-- Connexion quotidienne : XP × jours d'affilée (plafonné), bonus chaque semaine complète
Config.Streak = { xpPerDay = 50, maxDays = 7, weekCash = 1000 }

Config.TalkRadius = 3.0
Config.Tolerance = 3.0
Config.Key = 'F3'         -- menu Progression (touche seulement) ; F2 = inventaire (ox_inventory), F5 = emotes (scully)

-- Paquets cachés (clin d'œil aux premiers GTA) : invisibles sur la carte, un petit colis au sol quand on passe à côté.
Config.Packages = {
    xp = 50,
    allXp = 2500, allCash = 5000,  -- bonus quand tout est trouvé
    spawnDistance = 40.0,
    points = { -- coords à caler en jeu
        vec3(-1605.1, -1070.4, 13.0), vec3(-1379.5, -1402.0, 3.2), vec3(-1047.3, -2744.7, 13.9), vec3(-58.2, -2517.3, 7.4),
        vec3(1208.3, -3113.6, 5.5), vec3(835.6, -2176.3, 29.7), vec3(96.8, -1940.3, 20.8), vec3(386.2, -738.4, 29.3),
        vec3(-75.1, -818.3, 326.2), vec3(233.8, 1167.9, 225.5), vec3(-424.8, 1123.1, 325.9), vec3(738.9, 1292.4, 360.3),
        vec3(1692.8, 3288.0, 41.1), vec3(1964.7, 3740.3, 32.3), vec3(2451.3, 4960.6, 46.6), vec3(1664.4, 4855.2, 42.0),
        vec3(-275.4, 6228.8, 31.5), vec3(501.4, 5604.1, 797.9), vec3(-1575.6, 5163.0, 19.6), vec3(3070.3, 2205.4, 3.0),
    },
}

Config.PhoneSnap = 60.0   -- V9 : rayon où chercher la vraie cabine / le téléphone mural autour d'un personnage « téléphone »
