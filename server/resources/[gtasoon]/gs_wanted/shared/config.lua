-- [CONFIG] Recherche intelligente. Principe : un crime n'est connu de la police QUE s'il est signalé.
-- Chance de signalement = base du crime + témoins, × heure × météo × arme silencieuse × notoriété.
-- La précision du signalement (zone, plaque, délai) dépend aussi des témoins et de la visibilité.
Config = {}

Config.PoliceJob = 'police'

Config.Crimes = {
    gunshot      = { label = 'Coups de feu', heat = 15, chance = 0.35 },   -- entendus même sans témoin
    explosion    = { label = 'Explosion', heat = 25, chance = 0.90 },
    carjack      = { label = 'Vol de véhicule avec violence', heat = 10, chance = 0.15 },
    robbery      = { label = 'Braquage', heat = 30, chance = 0.50 },
    assault      = { label = 'Agression', heat = 10, chance = 0.20 },
    duo_contract = { label = 'Vol de marchandise', heat = 20, chance = 0.25 },
    store_robbery = { label = 'Braquage de supérette', heat = 30, chance = 0.45 },
    jewelry = { label = 'Braquage de bijouterie', heat = 45, chance = 0.70 },
    bank = { label = 'Braquage de banque', heat = 60, chance = 0.80 },
    drug_sale = { label = 'Vente de stupéfiants', heat = 8, chance = 0.12 },
    street_race = { label = 'Course de rue illégale', heat = 10, chance = 0.35 },
    smuggling = { label = 'Transport de marchandise illégale', heat = 15, chance = 0.4 },
    poaching = { label = 'Braconnage (chasse sans permis)', heat = 6, chance = 0.35 },
    mugging = { label = 'Racket à main armée', heat = 12, chance = 0.40 },
    teller_robbery = { label = 'Braquage de guichet', heat = 35, chance = 0.70 },
    black_market = { label = 'Trafic d\'armes', heat = 15, chance = 0.10 },
    money_laundering = { label = 'Blanchiment d\'argent (contrôle fiscal)', heat = 20, chance = 1.0 },
    contract = { label = 'Contrat criminel', heat = 10, chance = 0.15 },
    refusal = { label = 'Refus d\'obtempérer (contrôle routier)', heat = 12, chance = 0.95 },
}

Config.Witness = {
    radius = 40.0,          -- rayon de recherche des témoins (PNJ vivants + joueurs)
    perWitness = 0.12,      -- chance ajoutée par témoin
    maxChance = 0.97,
    policeRadius = 60.0,    -- un policier en service à portée = signalement certain et précis
}

-- Heure de jeu → visibilité
Config.TimeFactor = {
    { from = 22, to = 24, factor = 0.6 },
    { from = 0,  to = 5,  factor = 0.6 },
    { from = 5,  to = 7,  factor = 0.8 },
    { from = 19, to = 22, factor = 0.8 },
}

-- Météo gs_weather → visibilité (absent = 1.0)
Config.WeatherFactor = { FOGGY = 0.6, RAIN = 0.8, THUNDER = 0.7, SMOG = 0.9 }
Config.BlackoutFactor = 0.6
Config.SilencedFactor = 0.3

-- Précision : 0 (vague) → 1 (parfaite)
Config.Precision = {
    blurMax = 250.0, blurMin = 20.0,  -- rayon de la zone envoyée à la police (m)
    delayMax = 40, delayMin = 5,      -- délai avant l'appel (s)
}

-- Chaleur (notoriété) : monte à chaque signalement, redescend si on se fait oublier.
Config.Heat = {
    max = 100,
    decayPerMinute = 2,
    quietMinutes = 2,       -- pas de baisse pendant X min après un signalement
    recognition = 200,      -- chance × (1 + chaleur / recognition) : un visage connu se fait reconnaître
}

-- Zones sans signalement (stand de tir...)
Config.SafeZones = {
    { coords = vec3(13.0, -1097.0, 29.8), radius = 25.0 },   -- Ammu-Nation Pillbox (stand de tir)
    { coords = vec3(821.0, -2163.0, 29.6), radius = 25.0 },  -- Ammu-Nation Cypress Flats
}

-- Police IA : quand il y a moins de `minCops` policiers joueurs en service, un crime signalé déclenche la police
-- du jeu (étoiles GTA) sur le suspect. La ville ne reste jamais sans police. 0 = désactivé.
Config.NpcPolice = {
    minCops = 1,
    search = { seconds = 120, radius = 180.0 },   -- après avoir semé la police IA : elle fouille la dernière zone connue
    stars = { { heat = 10, stars = 1 }, { heat = 30, stars = 2 }, { heat = 45, stars = 3 }, { heat = 999, stars = 4 } },
    -- V7 : patrouilles créées par le serveur (le « dispatch » du jeu donnait des voitures vides avec la protection
    -- anti-triche des entités). 1 voiture par étoile (max `maxUnits`), 2 agents armés, gyrophares, poursuite.
    units = { maxUnits = 3, maxServer = 9, spawnDistance = 170.0, lifetime = 300, cooldown = 20,
        vehicles = { city = 'police', county = 'sheriff' }, peds = { city = 's_m_y_cop_01', county = 's_m_y_sheriff_01' },
        weapons = { [1] = 'WEAPON_STUNGUN', [2] = 'WEAPON_PISTOL', [3] = 'WEAPON_PUMPSHOTGUN' }, armour = 50 },
}

-- Caméras de surveillance : un crime à moins de `radius` m d'une caméra est presque toujours signalé, avec une zone précise
-- et la plaque lisible. Un pirate (gros coup en duo) peut les aveugler quelques minutes autour d'un site. Coords à compléter.
Config.Cameras = {
    radius = 35.0, chanceBonus = 0.45, precision = 0.85, blindSeconds = 600, keep = 40, -- preuves vidéo gardées (Dossiers police)
    list = {
        { label = 'Legion Square', coords = vec3(195.2, -934.3, 30.7) },
        { label = 'Fleeca Legion Square', coords = vec3(149.4, -1040.5, 29.4) },
        { label = 'Bijouterie Vangelico', coords = vec3(-622.0, -231.0, 38.1) },
        { label = 'Aéroport LSIA', coords = vec3(-1037.8, -2737.8, 20.2) },
        { label = 'Pillbox Hill', coords = vec3(298.0, -584.0, 43.2) },
        { label = 'Jetée de Del Perro', coords = vec3(-1604.0, -1049.0, 13.0) },
        { label = 'Mission Row', coords = vec3(441.0, -981.0, 30.7) },
        { label = 'Casino Diamond', coords = vec3(924.4, 46.9, 81.1) },
        { label = 'Pacific Standard', coords = vec3(247.0, 222.0, 106.3) },
        { label = 'Mirror Park', coords = vec3(1163.4, -323.8, 69.2) },
    },
}

Config.Dispatch = {
    blipSeconds = 90,
    history = 20,
}

-- V8 · La ville se souvient ---------------------------------------------------------------------------------------
-- Les témoins décrivent ce qu'ils ont vu (description brute, jamais l'identité) ; plus la précision est haute, plus
-- la description est complète. La ville garde en mémoire la tenue et le véhicule des suspects : recroisés avec la même
-- tenue ou la même voiture (même plaque ET même couleur), ils sont reconnus plus vite. Changer de tenue, repeindre ou
-- changer de véhicule brouille la piste.
Config.Memory = {
    hours = 2,              -- la ville oublie au bout de X heures réelles
    keep = 5,               -- signalements mémorisés par suspect
    linkChance = 0.25,      -- chance de signalement en plus quand le suspect est reconnu
    linkPrecision = 0.2,    -- précision en plus (zone plus serrée, plaque plus lisible)
    -- précision minimale pour que les témoins remarquent chaque détail
    see = { gender = 0.15, vehicle = 0.25, mask = 0.3, hat = 0.45, bag = 0.55, armour = 0.5, armed = 0.35 },
    outfit = { 1, 4, 6, 11 },   -- masque, bas, chaussures, haut (+ couvre-chef) : empreinte de la tenue
}
-- Visage connu : un témoin peut nommer un suspect célèbre (réputation média ou rue) s'il n'est pas masqué.
Config.Fame = { at = 600, precision = 0.5, chance = 0.6 }

Config.VehicleTypes = { automobile = 'Voiture', bike = 'Deux-roues', boat = 'Bateau', heli = 'Hélicoptère', plane = 'Avion', quadbike = 'Quad' }
-- Couleurs GTA (index de peinture) → mot simple
Config.Colors = {
    { 'noir', { 0, 2 }, { 11, 12 }, { 15, 16 }, { 21, 22 }, { 147, 147 } },
    { 'gris', { 3, 10 }, { 13, 14 }, { 17, 20 }, { 23, 26 }, { 117, 120 }, { 156, 156 } },
    { 'rouge', { 27, 35 }, { 39, 40 }, { 43, 48 }, { 143, 143 }, { 150, 150 } },
    { 'orange', { 36, 36 }, { 38, 38 }, { 41, 41 }, { 104, 104 }, { 123, 124 }, { 130, 130 }, { 138, 138 } },
    { 'jaune', { 37, 37 }, { 42, 42 }, { 88, 89 }, { 91, 91 }, { 126, 126 }, { 158, 159 } },
    { 'vert', { 49, 60 }, { 92, 92 }, { 125, 125 }, { 128, 128 }, { 133, 133 }, { 139, 139 }, { 144, 144 }, { 151, 152 }, { 155, 155 } },
    { 'bleu', { 61, 87 }, { 127, 127 }, { 140, 141 }, { 146, 146 }, { 157, 157 } },
    { 'marron', { 90, 90 }, { 93, 103 }, { 105, 110 }, { 113, 116 }, { 129, 129 }, { 153, 154 } },
    { 'blanc', { 107, 107 }, { 111, 112 }, { 121, 122 }, { 131, 132 }, { 134, 134 } },
    { 'rose', { 135, 137 } },
    { 'violet', { 142, 142 }, { 145, 145 }, { 148, 149 } },
}
