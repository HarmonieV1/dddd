-- [CONFIG] Drogue. Items à déclarer dans ox_inventory (voir docs/FEATURES.md) : sinon la drogue est désactivée au démarrage.
Config = {}

Config.PoliceJob = 'police'
Config.DirtyItem = 'black_money'   -- paiement en argent sale ; si l'item n'existe pas : liquide
Config.Tolerance = 3.0

Config.Drugs = {
    weed = {
        label = 'Cannabis',
        harvest = {
            item = 'weed_leaf', amount = { 1, 3 }, duration = 5000, radius = 45.0,
            center = vec3(2224.0, 5577.0, 53.8),                 -- champ près de Grapeseed
            points = { vec3(2220.0, 5575.0, 53.8), vec3(2228.0, 5579.0, 53.8), vec3(2224.0, 5584.0, 53.8), vec3(2216.0, 5582.0, 53.8) },
        },
        process = {
            input = 'weed_leaf', inputCount = 3, output = 'weed_bag', outputCount = 1, duration = 8000, radius = 3.0,
            center = vec3(1391.0, 3605.0, 38.9),                 -- arrière-boutique à Sandy Shores
        },
        sell = { item = 'weed_bag', price = { 70, 120 } },
    },
    coke = {
        label = 'Cocaïne',
        harvest = {
            item = 'coca_leaf', amount = { 1, 2 }, duration = 6000, radius = 30.0,
            center = vec3(2434.0, 4968.0, 46.8),                 -- serre de la ferme de Grapeseed (à caler)
            points = { vec3(2432.0, 4966.0, 46.8), vec3(2437.0, 4970.0, 46.8), vec3(2429.0, 4971.0, 46.8) },
        },
        process = {
            input = 'coca_leaf', inputCount = 4, output = 'coke_bag', outputCount = 1, duration = 12000, radius = 3.0,
            center = vec3(1093.0, -3196.0, -39.0),               -- labo (intérieur du jeu, à caler)
        },
        sell = { item = 'coke_bag', price = { 160, 240 } },
    },
}

-- Labos de gangs (intérieurs gs_interiors) : préparation réservée au gang propriétaire, production ×2.
Config.Labs = {
    weed = { vec3(1060.5, -3182.0, -39.16), vec3(1134.6, -3194.5, -39.67) },
    coke = { vec3(1093.0, -3196.0, -39.0), vec3(1005.8, -3200.4, -38.52) },
}
Config.LabBonus = 2

-- Mode deal (/deal) : des passants viennent à toi quand tu attends à un coin de rue.
Config.Deal = {
    interval = { 20, 40 },        -- secondes entre deux clients
    searchRadius = 45.0,          -- les clients viennent d'aussi loin
    wait = 25,                    -- secondes pendant lesquelles le client attend à côté de toi
}

Config.Sell = {
    radius = 2.5,                  -- distance max au PNJ
    maxPerSale = 3,
    refuseChance = 0.25,           -- base : le PNJ refuse
    rainRefuse = 0.15,             -- + sous la pluie / l'orage (moins de monde dehors)
    policeNearby = 60.0,           -- un policier en service à moins de X m = refus systématique
    nightBonus = 1.15,             -- 22h → 5h
    ownTerritory = 1.20,           -- vente dans un quartier tenu par ton gang
    rivalTerritory = 0.85,         -- quartier tenu par un autre gang
    saturationStep = 0.04,         -- chaque vente récente dans le quartier fait baisser le prix de 4 %
    saturationFloor = 0.55,        -- jusqu'à 55 % du prix au plus bas
    saturationWindow = 3600,       -- ventes comptées sur la dernière heure
    influence = 1,                 -- influence de ton gang par vente
}

-- Plantations libres : une graine + un pot, planter dehors où on veut (pas en intérieur, pas sur la route).
-- Le plant pousse en temps réel (3 stades visibles de tous), il faut l'arroser (bouteille d'eau), l'engrais accélère.
-- Tout le monde peut récolter un plant mûr (vol possible) ; le propriétaire ou la police peuvent le détruire.
Config.Plants = {
    seed = 'weed_seed', pot = 'plant_pot', fertilizer = 'fertilizer', water = 'water',
    maxPerPlayer = 6,
    minSpacing = 1.5,             -- entre deux plants
    growMinutes = 45,             -- de la graine à la récolte (arrosé, sans engrais)
    fertilizerBoost = 1.5,        -- ×1,5 plus vite avec engrais
    waterMinutes = 25,            -- un arrosage tient 25 min
    dryDeathMinutes = 30,         -- sans eau pendant 30 min : le plant meurt
    harvest = { item = 'weed_leaf', amount = { 8, 12 }, seeds = { 1, 2 } },
    policeReward = 150,           -- prime au policier en service qui détruit un plant
    reach = 2.0,
    wildSeedChance = 0.3,         -- récolte au champ sauvage de Grapeseed : 30 % de chance de trouver une graine
    -- props du jeu (DLC bikers), un par stade ; offset z à caler en jeu si le plant flotte / s'enfonce
    props = {
        { model = 'bkr_prop_weed_01_small_01c', z = 0.0 },
        { model = 'bkr_prop_weed_med_01a', z = 0.0 },
        { model = 'bkr_prop_weed_lrg_01a', z = 0.0 },
    },
    -- vendeur de graines (PNJ louche, marqueur caché) ; pots et engrais : quincailleries
    seedShop = { coords = vec4(2197.3, 5602.6, 53.7, 340.0), model = 'a_m_m_hillbilly_01', price = 150, label = 'Vendeur de graines' },
}
