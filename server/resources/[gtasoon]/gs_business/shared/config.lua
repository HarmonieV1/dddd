-- [CONFIG] Commerces tenus par des joueurs. Le métier (grades, salaires, embauche, caisse du job) est dans gs_jobs ;
-- ici : préparation, caisse client et comptabilité. stock = réserve n°1 du job (gs_<job>_1). Coords à caler.
-- Les ingrédients viennent du jeu : alcools et sodas (supérettes / cavistes), viande (chasse), tomates / pommes de terre (ferme).
Config = {}

Config.Range = 2.5
Config.SelfServiceMarkup = 1.2     -- sans employé en service : libre-service, prix +20 %
Config.MaxQty = 10
Config.MinPrice, Config.MaxPrice = 1, 1000

Config.Businesses = {
    bar = {
        label = 'Bar Le Néon', stash = 'gs_bar_1',
        register = vec3(-560.4, 287.3, 82.2), craft = vec3(-562.9, 289.9, 82.2),
        products = {
            gs_cocktail = { label = 'Cocktail Vice', price = 45, needs = { vodka = 1, sprunk = 1 }, time = 5000 },
            gs_whiskycola = { label = 'Whisky-cola', price = 40, needs = { whiskey = 1, sprunk = 1 }, time = 4000 },
            beer = { label = 'Bière pression', price = 15, resale = true },   -- revendue telle quelle (achetée en gros)
        },
    },
    restaurant = {
        label = 'Horny\'s Burgers', stash = 'gs_restaurant_1',
        register = vec3(1242.9, -367.5, 69.1), craft = vec3(1245.9, -363.1, 69.1),
        products = {
            gs_burger_deluxe = { label = 'Burger deluxe', price = 35, needs = { meat = 1, tomato = 1 }, time = 6000 },
            gs_fries = { label = 'Frites maison', price = 15, needs = { potato = 2 }, time = 4000 },
            sprunk = { label = 'Sprunk', price = 8, resale = true },
        },
    },
}
