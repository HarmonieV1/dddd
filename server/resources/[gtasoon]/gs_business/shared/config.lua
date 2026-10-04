-- [CONFIG] Commerces tenus par des joueurs. Le métier (grades, salaires, embauche, caisse du job) est dans gs_jobs ;
-- ici : préparation, caisse client et comptabilité. stock = réserve n°1 du job (gs_<job>_1). Coords à caler.
-- Les ingrédients viennent du jeu : alcools et sodas (supérettes / cavistes), viande (chasse), tomates / pommes de terre (ferme).
Config = {}

Config.Range = 2.5
Config.SelfServiceMarkup = 1.2     -- sans employé en service : libre-service, prix +20 %
Config.MaxQty = 10
Config.MinPrice, Config.MaxPrice = 1, 1000

-- Libre-service (aucun employé en service) : un barman PNJ sert la carte de base (`npc`), stock illimité, prix majorés ;
-- la maison touche Config.NpcShare de la recette (le reste = coût du barman). Employés en service : leur carte à eux,
-- préparée avec les ingrédients de la réserve.
Config.NpcShare = 0.3

Config.Businesses = {
    bar = {
        label = 'Tequi-la-la', stash = 'gs_bar_1',
        register = vec3(-560.4, 287.3, 82.2), craft = vec3(-562.9, 289.9, 82.2),
        products = {
            gs_cocktail = { label = 'Cocktail Vice', price = 45, needs = { vodka = 1, sprunk = 1 }, time = 5000 },
            gs_whiskycola = { label = 'Whisky-cola', price = 40, needs = { whiskey = 1, sprunk = 1 }, time = 4000 },
            beer = { label = 'Bière pression', price = 15, resale = true },   -- revendue telle quelle (achetée en gros)
        },
        npc = { beer = 15, sprunk = 8, water = 6 },
    },
    vanilla = {
        label = 'Vanilla Unicorn', stash = 'gs_vanilla_1',
        register = vec3(127.9, -1285.0, 29.28), craft = vec3(130.0, -1281.5, 29.27),
        products = {
            gs_cocktail = { label = 'Cocktail Vice', price = 60, needs = { vodka = 1, sprunk = 1 }, time = 5000 },
            gs_whiskycola = { label = 'Whisky-cola', price = 50, needs = { whiskey = 1, sprunk = 1 }, time = 4000 },
            beer = { label = 'Bière', price = 18, resale = true },
        },
        npc = { beer = 18, sprunk = 10, water = 8 },
    },
    bahama = {
        label = 'Bahama Mamas', stash = 'gs_bahama_1',
        register = vec3(-1388.4, -607.2, 30.32), craft = vec3(-1385.8, -609.4, 30.32),
        products = {
            gs_cocktail = { label = 'Cocktail Vice', price = 55, needs = { vodka = 1, sprunk = 1 }, time = 5000 },
            gs_whiskycola = { label = 'Whisky-cola', price = 45, needs = { whiskey = 1, sprunk = 1 }, time = 4000 },
            beer = { label = 'Bière', price = 16, resale = true },
        },
        npc = { beer = 16, sprunk = 9, water = 7 },
    },
}

-- V9 · La doublure : quand aucun employé n'est en service, le patron peut laisser sa « doublure » (un PNJ à son
-- apparence) tenir le comptoir. Elle sert la carte de base pour une meilleure part de la recette… et peut être braquée.
-- Seuls les commerces listés ici l'ont (pas général). La doublure se tient au plan de travail, face au comptoir.
Config.Double = {
    businesses = { bar = true, vanilla = true, bahama = true },
    share = 0.5,        -- part de la recette gardée (au lieu de Config.NpcShare)
    hours = 72,         -- durée maximale sans repasser au comptoir
    rob = { cooldown = 7200, pct = 0.10, min = 300, max = 3000, time = 8000, range = 5.0 },
}
