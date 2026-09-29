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
    poaching = { label = 'Braconnage (chasse sans permis)', heat = 6, chance = 0.35 },
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
    stars = { { heat = 10, stars = 1 }, { heat = 30, stars = 2 }, { heat = 45, stars = 3 }, { heat = 999, stars = 4 } },
}

Config.Dispatch = {
    blipSeconds = 90,
    history = 20,
}
