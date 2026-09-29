-- [CONFIG] Métiers de récolte (libres, sans embauche) : on achète l'outil en quincaillerie, on va sur un point [E],
-- on récolte (durée réelle vérifiée par le serveur), on revend chez l'acheteur. Coords à caler en jeu (F11 → Copier mes coordonnées).
Config = {}

Config.Tolerance = 3.0
Config.SpotRadius = 3.0
Config.BreakChance = 0.03   -- l'outil casse parfois (on en rachète un)

-- loot = { item, poids du tirage, { min, max } }
Config.Activities = {
    fishing = {
        label = 'Pêche', verb = 'Pêcher', tool = 'fishingrod', duration = { 8000, 15000 },
        scenario = 'WORLD_HUMAN_STAND_FISHING', blip = { sprite = 68, color = 3 },
        loot = { { 'fish', 70, { 1, 2 } }, { 'tuna', 12, { 1, 1 } }, { 'scrapmetal', 18, { 1, 1 } } },
        spots = { vec3(-1850.3, -1250.2, 8.6), vec3(-1838.8, -1266.1, 8.6), vec3(-3427.5, 967.8, 8.3),
                  vec3(1299.4, 4217.9, 33.9), vec3(-275.0, 6635.3, 7.5), vec3(713.5, 4093.7, 34.7) },
    },
    mining = {
        label = 'Mine', verb = 'Miner', tool = 'pickaxe', duration = { 7000, 10000 },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' }, blip = { sprite = 618, color = 5 },
        loot = { { 'stone', 55, { 2, 4 } }, { 'iron_ore', 30, { 1, 2 } }, { 'copper', 10, { 1, 2 } }, { 'gold_ore', 5, { 1, 1 } } },
        spots = { vec3(2947.8, 2791.4, 40.9), vec3(2957.1, 2775.4, 42.1), vec3(2966.4, 2790.9, 40.4),
                  vec3(2937.2, 2771.9, 39.4), vec3(2926.5, 2794.4, 40.6) },
    },
    lumber = {
        label = 'Bûcheron', verb = 'Couper', tool = 'axe', duration = { 8000, 11000 },
        anim = { dict = 'melee@hatchet@streamed_core', clip = 'plyr_rear_takedown_b' }, blip = { sprite = 77, color = 25 },
        loot = { { 'wood_log', 100, { 2, 3 } } },
        spots = { vec3(-553.1, 5445.2, 63.9), vec3(-567.7, 5451.9, 61.4), vec3(-541.6, 5460.3, 66.4),
                  vec3(-611.2, 5470.7, 55.5), vec3(-596.3, 5438.5, 57.7) },
    },
    farming = {
        label = 'Ferme', verb = 'Cueillir', tool = nil, duration = { 5000, 7000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', blip = { sprite = 285, color = 2 },
        loot = { { 'tomato', 50, { 2, 4 } }, { 'potato', 50, { 2, 4 } } },
        spots = { vec3(2029.0, 4899.1, 42.7), vec3(2040.1, 4907.4, 42.7), vec3(2051.4, 4915.9, 42.7),
                  vec3(2018.6, 4889.8, 42.7), vec3(2008.7, 4880.6, 42.7) },
    },
}

-- Chasse : animaux créés par le serveur dans la zone (pas de faux gibier), dépecés au couteau une fois abattus.
Config.Hunting = {
    label = 'Chasse', tool = 'huntingknife', skinTime = 6000, max = 6, respawnSeconds = 90, playerRadius = 500.0,
    blip = { sprite = 141, color = 1 }, center = vec3(-580.0, 5010.0, 140.0),
    animals = {
        ['a_c_deer'] = { { 'meat', 1, { 2, 3 } }, { 'leather', 1, { 1, 1 } } },
        ['a_c_boar'] = { { 'meat', 1, { 2, 4 } }, { 'leather', 1, { 1, 1 } } },
    },
    spawns = { vec3(-640.0, 5040.0, 142.0), vec3(-560.0, 4960.0, 158.0), vec3(-520.0, 5060.0, 118.0),
               vec3(-700.0, 4980.0, 152.0), vec3(-610.0, 4920.0, 177.0), vec3(-480.0, 4990.0, 125.0) },
}

-- Acheteurs : prix unitaire tiré dans [min, max] à chaque vente
Config.Buyers = {
    { label = 'Poissonnerie du port', coords = vec3(-1846.3, -1195.4, 14.3), blip = { sprite = 356, color = 3 },
      items = { fish = { 25, 40 }, tuna = { 90, 140 } } },
    { label = 'Fonderie', coords = vec3(1109.9, -2008.2, 31.0), blip = { sprite = 618, color = 47 },
      items = { stone = { 6, 10 }, iron_ore = { 28, 40 }, gold_ore = { 140, 200 } } },
    { label = 'Scierie de Paleto', coords = vec3(-552.4, 5348.5, 74.7), blip = { sprite = 77, color = 47 },
      items = { wood_log = { 18, 26 } } },
    { label = 'Marché de Grapeseed', coords = vec3(1678.4, 4880.4, 42.2), blip = { sprite = 52, color = 2 },
      items = { tomato = { 5, 8 }, potato = { 4, 7 } } },
    { label = 'Boucherie', coords = vec3(-69.2, 6253.8, 31.1), blip = { sprite = 141, color = 47 },
      items = { meat = { 40, 60 }, leather = { 55, 80 } } },
}
