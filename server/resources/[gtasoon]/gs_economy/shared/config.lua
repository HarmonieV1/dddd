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
    scrapmetal = { label = 'Ferraille', base = 12, min = 0.3, max = 1.5, volume = 200, buy = false },
    copper     = { label = 'Cuivre', base = 30, min = 0.3, max = 1.6, volume = 120, buy = false },
}

-- Multiplicateurs pendant un événement gs_weather
Config.EventMultipliers = {
    heatwave = { water = 1.6, sprunk = 1.4 },
    storm = { repairkit = 1.5, bandage = 1.4, radio = 1.2 },
    fog = {},
}

-- Commerces (achat) et reventes. Coords à caler en jeu.
Config.Shops = {
    { label = 'Supérette Strawberry', coords = vec3(25.7, -1347.3, 29.5), items = { 'water', 'sprunk', 'burger', 'sandwich', 'bandage' }, blip = true },
    { label = 'Supérette Little Seoul', coords = vec3(-707.4, -914.3, 19.2), items = { 'water', 'sprunk', 'burger', 'sandwich', 'bandage' }, blip = true },
    { label = 'Supérette Mirror Park', coords = vec3(1163.4, -323.8, 69.2), items = { 'water', 'sprunk', 'burger', 'sandwich', 'bandage' }, blip = true },
    { label = 'Supérette Sandy Shores', coords = vec3(1961.5, 3740.7, 32.3), items = { 'water', 'sprunk', 'burger', 'sandwich', 'bandage' }, blip = true },
    { label = 'Quincaillerie', coords = vec3(2748.0, 3472.0, 55.7), items = { 'repairkit', 'lockpick', 'radio' }, blip = true },
}

Config.Resellers = {
    { label = 'Casse de Sandy Shores', coords = vec3(2340.0, 3052.0, 48.1), items = { 'scrapmetal', 'copper' }, blip = true },
    { label = 'Ferrailleur La Mesa', coords = vec3(1016.0, -2524.0, 28.3), items = { 'scrapmetal', 'copper' }, blip = true },
}

Config.Blips = {
    shop = { sprite = 52, color = 2, scale = 0.7 },
    reseller = { sprite = 527, color = 47, scale = 0.7 },
}
