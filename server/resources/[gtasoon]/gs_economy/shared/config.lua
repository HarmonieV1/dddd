-- [CONFIG] Économie dynamique.
-- Chaque achat fait monter la "pression" d'un produit (prix ↑), chaque revente la fait baisser (prix ↓).
-- La pression revient doucement vers 0 : le marché se stabilise tout seul.
-- Les événements météo (gs_weather) multiplient certains prix (canicule → eau, tempête → kits).
-- Les items doivent exister dans ox_inventory (noms à vérifier dans ox_inventory/data/items.lua).
Config = {}

Config.Elasticity = 0.5          -- effet de la pression sur le prix
Config.DecayPerTick = 0.08       -- retour vers l'équilibre à chaque tick (8 %)
Config.TickMinutes = 10
Config.SaveMinutes = 5
Config.MaxQuantity = 20          -- par transaction
Config.InteractRadius = 2.0
Config.ServerTolerance = 4.0

-- base = prix d'équilibre ; min/max = bornes (× base) ; volume = quantité qui fait bouger la pression de 1
-- sell = prix de revente (× prix d'achat courant) si l'item est aussi racheté ; buy = false : revente seule
Config.Items = {
    water     = { label = 'Eau', base = 5, min = 0.6, max = 2.0, volume = 60 },
    sprunk    = { label = 'Sprunk', base = 7, min = 0.6, max = 2.0, volume = 60 },
    burger    = { label = 'Burger', base = 12, min = 0.7, max = 1.8, volume = 50 },
    sandwich  = { label = 'Sandwich', base = 9, min = 0.7, max = 1.8, volume = 50 },
    bandage   = { label = 'Bandage', base = 40, min = 0.7, max = 2.0, volume = 30 },
    repairkit = { label = 'Kit de réparation', base = 250, min = 0.7, max = 1.8, volume = 20 },
    lockpick  = { label = 'Crochet', base = 150, min = 0.8, max = 2.0, volume = 15 },
    radio     = { label = 'Radio', base = 300, min = 0.8, max = 1.5, volume = 15 },
    -- Supérette : snacks, boissons, tabac, téléphone
    gs_chips  = { label = 'Chips', base = 5, min = 0.7, max = 1.8, volume = 60 },
    gs_donut  = { label = 'Donut', base = 6, min = 0.7, max = 1.8, volume = 60 },
    coffee    = { label = 'Café', base = 6, min = 0.7, max = 1.8, volume = 60 },
    gs_energy = { label = 'Boisson énergisante', base = 9, min = 0.7, max = 1.8, volume = 50 },
    gs_cigarettes = { label = 'Paquet de cigarettes', base = 15, min = 0.8, max = 1.6, volume = 40 },
    lighter   = { label = 'Briquet', base = 5, min = 0.8, max = 1.5, volume = 40 },
    phone     = { label = 'Téléphone', base = 450, min = 0.9, max = 1.3, volume = 10 },
    -- Alcool (supérettes et cavistes)
    beer      = { label = 'Bière', base = 8, min = 0.7, max = 1.8, volume = 60 },
    wine      = { label = 'Vin', base = 25, min = 0.7, max = 1.6, volume = 30 },
    vodka     = { label = 'Vodka', base = 35, min = 0.7, max = 1.6, volume = 25 },
    whiskey   = { label = 'Whisky', base = 45, min = 0.7, max = 1.6, volume = 25 },
    -- Quincaillerie
    jerry_can = { label = 'Jerrican', base = 60, min = 0.8, max = 1.6, volume = 20 },
    binoculars = { label = 'Jumelles', base = 150, min = 0.8, max = 1.5, volume = 15 },
    scrapmetal = { label = 'Ferraille', base = 12, min = 0.3, max = 1.5, volume = 200, buy = false },
    copper     = { label = 'Cuivre', base = 30, min = 0.3, max = 1.6, volume = 120, buy = false },
}

-- Multiplicateurs pendant un événement gs_weather
Config.EventMultipliers = {
    heatwave = { water = 1.6, sprunk = 1.4 },
    storm = { repairkit = 1.5, bandage = 1.4, radio = 1.2 },
    fog = {},
}

-- Catalogues (ordre = ordre d'affichage)
local SUPERETTE = { 'water', 'sprunk', 'coffee', 'gs_energy', 'burger', 'sandwich', 'gs_chips', 'gs_donut',
    'beer', 'wine', 'gs_cigarettes', 'lighter', 'bandage', 'phone' }
local CAVISTE = { 'beer', 'wine', 'vodka', 'whiskey', 'gs_cigarettes', 'lighter', 'water', 'sprunk', 'gs_chips' }
local QUINCAILLERIE = { 'repairkit', 'jerry_can', 'lockpick', 'radio', 'binoculars', 'phone' }

-- Commerces (achat). Coords = comptoirs des magasins du jeu (mêmes points qu'ox_inventory) ; blip = style de Config.Blips.
-- clerk = vendeur PNJ derrière le comptoir (vec4, à caler en jeu : F11 → Copier mes coordonnées).
Config.ClerkModel = 'mp_m_shopkeep_01'
Config.Shops = {
    { label = 'Supérette Strawberry', coords = vec3(25.06, -1347.32, 29.5), items = SUPERETTE, blip = 'shop', clerk = vec4(24.47, -1346.62, 29.5, 271.66) },
    { label = 'Supérette Little Seoul', coords = vec3(-707.4, -914.3, 19.2), items = SUPERETTE, blip = 'shop', clerk = vec4(-706.06, -913.97, 19.22, 88.04) },
    { label = 'Supérette Mirror Park', coords = vec3(1163.4, -323.8, 69.2), items = SUPERETTE, blip = 'shop', clerk = vec4(1164.71, -322.94, 69.21, 101.72) },
    { label = 'Supérette Sandy Shores', coords = vec3(1960.54, 3740.28, 32.34), items = SUPERETTE, blip = 'shop', clerk = vec4(1959.6, 3740.93, 32.34, 296.84) },
    { label = 'Supérette Chumash', coords = vec3(-3039.18, 585.13, 7.91), items = SUPERETTE, blip = 'shop', clerk = vec4(-3039.54, 584.38, 7.91, 17.27) },
    { label = 'Supérette Banham Canyon', coords = vec3(-3242.2, 1000.58, 12.83), items = SUPERETTE, blip = 'shop', clerk = vec4(-3242.97, 1000.01, 12.83, 357.57) },
    { label = 'Supérette Paleto Bay', coords = vec3(1728.39, 6414.95, 35.04), items = SUPERETTE, blip = 'shop', clerk = vec4(1728.07, 6415.63, 35.04, 242.95) },
    { label = 'Supérette Grapeseed', coords = vec3(1698.37, 4923.43, 42.06), items = SUPERETTE, blip = 'shop', clerk = vec4(1697.8, 4922.5, 42.06, 324.71) },
    { label = 'Supérette Harmony', coords = vec3(548.5, 2671.25, 42.16), items = SUPERETTE, blip = 'shop', clerk = vec4(549.13, 2670.85, 42.16, 99.39) },
    { label = 'Supérette Senora', coords = vec3(2678.29, 3279.94, 55.24), items = SUPERETTE, blip = 'shop', clerk = vec4(2677.47, 3279.76, 55.24, 335.08) },
    { label = 'Supérette Tataviam', coords = vec3(2557.19, 381.4, 108.62), items = SUPERETTE, blip = 'shop', clerk = vec4(2556.66, 380.84, 108.62, 356.67) },
    { label = 'Supérette Vinewood', coords = vec3(373.13, 326.29, 103.57), items = SUPERETTE, blip = 'shop', clerk = vec4(372.66, 326.98, 103.57, 253.73) },
    { label = 'Caviste Mirror Park', coords = vec3(1134.9, -982.34, 46.41), items = CAVISTE, blip = 'liquor', clerk = vec4(1134.2, -983.26, 46.42, 277.24) },
    { label = 'Caviste Vespucci', coords = vec3(-1222.33, -907.82, 12.43), items = CAVISTE, blip = 'liquor', clerk = vec4(-1221.58, -908.15, 12.33, 35.49) },
    { label = 'Caviste Morningwood', coords = vec3(-1486.67, -378.46, 40.26), items = CAVISTE, blip = 'liquor', clerk = vec4(-1486.59, -377.68, 40.16, 139.51) },
    { label = 'Caviste Chumash', coords = vec3(-2967.0, 390.9, 15.14), items = CAVISTE, blip = 'liquor', clerk = vec4(-2966.39, 391.42, 15.04, 87.48) },
    { label = 'Caviste Route 68', coords = vec3(1165.95, 2710.2, 38.26), items = CAVISTE, blip = 'liquor', clerk = vec4(1165.28, 2710.8, 38.16, 179.43) },
    { label = 'Caviste Sandy Shores', coords = vec3(1393.0, 3605.95, 35.11), items = CAVISTE, blip = 'liquor', clerk = vec4(1392.46, 3606.41, 34.98, 199.0) },
    { label = 'Quincaillerie Senora', coords = vec3(2746.8, 3473.13, 55.67), items = QUINCAILLERIE, blip = 'hardware', clerk = vec4(2747.8, 3472.86, 55.67, 255.08) },
    { label = 'Quincaillerie La Mesa', coords = vec3(342.99, -1298.26, 32.51), items = QUINCAILLERIE, blip = 'hardware' },
}

Config.Resellers = {
    { label = 'Casse de Sandy Shores', coords = vec3(2340.0, 3052.0, 48.1), items = { 'scrapmetal', 'copper' }, blip = true },
    { label = 'Ferrailleur La Mesa', coords = vec3(1016.0, -2524.0, 28.3), items = { 'scrapmetal', 'copper' }, blip = true },
}

Config.Blips = {
    shop = { sprite = 52, color = 2, scale = 0.7 },
    liquor = { sprite = 93, color = 27, scale = 0.7 },
    hardware = { sprite = 402, color = 47, scale = 0.7 },
    reseller = { sprite = 527, color = 47, scale = 0.7 },
}
