-- [CONFIG] Métiers de récolte (libres, sans embauche) : on achète l'outil en quincaillerie, on va sur un point [E],
-- on récolte (durée réelle vérifiée par le serveur), on revend chez l'acheteur. Coords à caler en jeu (F11 → Copier mes coordonnées).
Config = {}

Config.Tolerance = 3.0
Config.SpotRadius = 3.0
Config.BreakChance = 0.03   -- l'outil casse parfois (on en rachète un)
Config.Regrow = 300         -- secondes avant qu'un arbre / rocher / tas épuisé revienne (pour ce joueur)
Config.PropRange = 90.0     -- distance d'apparition des arbres / rochers / tas (créés chez chaque joueur)

-- Vestiaire de chaque activité : tenue de travail (même base que le bleu du mécano), retour en civil au même endroit
Config.WorkOutfit = {
    male = { [3] = { 0, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 66, 0 } },
    female = { [3] = { 14, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 60, 0 } },
}

-- Noms affichés des objets récoltés (messages en français)
Config.ItemLabels = {
    fish = 'poisson', tuna = 'thon', scrapmetal = 'ferraille', copper = 'cuivre', stone = 'pierre', iron_ore = 'minerai de fer',
    gold_ore = 'pépite d\'or', wood_log = 'bûche', tomato = 'tomate', potato = 'pomme de terre', meat = 'viande', leather = 'cuir',
}

-- V7 : chaque activité a plusieurs « nœuds » (arbres, rochers, tas de ferraille, rangs de légumes, places de pêche).
-- Un nœud s'épuise après `perNode` récoltes (pour ce joueur) et revient après Config.Regrow : on se déplace, on ne reste
-- pas planté devant un seul arbre. `prop` = objet posé au sol chez le joueur (sinon : simple point, ex. pêche).
-- `sell` = où revendre (affiché après chaque récolte) ; les acheteurs sont loin des points de récolte (marche ou voiture).
-- Coordonnées réglables en jeu : F11 → Monde et lieux → Déplacer un point.
-- loot = { item, poids du tirage, { min, max } }
Config.Activities = {
    fishing = {
        label = 'Pêche', verb = 'Pêcher', tool = 'fishingrod', toolLabel = 'une canne à pêche', duration = { 9000, 15000 },
        scenario = 'WORLD_HUMAN_STAND_FISHING', blip = { sprite = 68, color = 3 }, perNode = 8, outfit = false,
        sell = 'Poissonnerie de Del Perro',
        loot = { { 'fish', 70, { 1, 2 } }, { 'tuna', 12, { 1, 1 } }, { 'scrapmetal', 18, { 1, 1 } } },
        spots = { vec3(-1850.3, -1250.2, 8.6), vec3(-1838.8, -1266.1, 8.6), vec3(-3427.5, 967.8, 8.3),
                  vec3(1299.4, 4217.9, 33.9), vec3(-275.0, 6635.3, 7.5) },
    },
    mining = {
        label = 'Mine (carrière Davis Quartz)', verb = 'Miner', tool = 'pickaxe', toolLabel = 'une pioche', duration = { 7000, 10000 },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
        handProp = { model = 'prop_tool_pickaxe', bone = 57005, pos = vec3(0.18, -0.02, -0.02), rot = vec3(350.0, 100.0, 140.0) },
        prop = 'prop_rock_1_d', perNode = 3, blip = { sprite = 618, color = 5 }, sell = 'Ferrailleur de Cypress Flats (métaux)',
        loot = { { 'stone', 55, { 2, 4 } }, { 'iron_ore', 30, { 1, 2 } }, { 'copper', 10, { 1, 2 } }, { 'gold_ore', 5, { 1, 1 } } },
        spots = { vec3(2947.8, 2791.4, 40.9), vec3(2957.1, 2775.4, 42.1), vec3(2966.4, 2790.9, 40.4), vec3(2937.2, 2771.9, 39.4),
                  vec3(2926.5, 2794.4, 40.6), vec3(2967.0, 2791.5, 41.0), vec3(2950.9, 2806.5, 41.0), vec3(2929.9, 2800.0, 41.0),
                  vec3(2925.0, 2778.5, 41.0), vec3(2941.1, 2763.5, 41.0), vec3(2962.1, 2770.0, 41.0) },
    },
    lumber = {
        label = 'Bûcheron (forêt de Paleto)', verb = 'Couper l\'arbre', tool = 'axe', toolLabel = 'une hache', duration = { 8000, 11000 },
        anim = { dict = 'melee@hatchet@streamed_core', clip = 'plyr_rear_takedown_b' },
        handProp = { model = 'prop_w_me_hatchet', bone = 57005, pos = vec3(0.09, 0.03, -0.02), rot = vec3(-78.0, 13.0, 28.0) },
        prop = 'prop_tree_pine_02', perNode = 3, blip = { sprite = 77, color = 25 }, sell = 'Scierie de Paleto',
        loot = { { 'wood_log', 100, { 2, 3 } } },
        spots = { vec3(-590.0, 5560.0, 60.0), vec3(-596.9, 5569.5, 60.0), vec3(-608.1, 5565.9, 60.0), vec3(-608.1, 5554.1, 60.0),
                  vec3(-596.9, 5550.5, 60.0), vec3(-579.7, 5568.6, 60.0), vec3(-594.1, 5581.2, 60.0), vec3(-612.9, 5577.8, 60.0),
                  vec3(-622.0, 5561.1, 60.0), vec3(-614.5, 5543.5, 60.0), vec3(-596.2, 5538.3, 60.0), vec3(-580.7, 5549.5, 60.0) },
    },
    -- Ferrailleur (sans outil) : trier les casses (Rogers Salvage à LS, casse de Sandy Shores). Revente à Cypress Flats
    -- (gs_economy, prix selon le marché). Ferraille et cuivre servent aussi aux munitions artisanales des gangs.
    scrapyard = {
        label = 'Ferraille (casses)', verb = 'Trier la ferraille', tool = nil, duration = { 7000, 10000 },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, prop = 'prop_rub_scrap_02', perNode = 3,
        blip = { sprite = 527, color = 47 }, sell = 'Ferrailleur de Cypress Flats',
        loot = { { 'scrapmetal', 70, { 2, 4 } }, { 'copper', 30, { 1, 2 } } },
        spots = { vec3(-468.9, -1717.2, 18.7), vec3(-458.3, -1706.5, 18.8), vec3(-455.1, -1707.7, 18.8), vec3(-467.3, -1704.1, 18.8),
                  vec3(-470.9, -1716.3, 18.8), vec3(-458.7, -1719.9, 18.8), vec3(2346.8, 3048.1, 48.1), vec3(2335.2, 3057.9, 48.1),
                  vec3(2350.8, 3055.0, 48.1), vec3(2339.0, 3062.8, 48.1), vec3(2331.2, 3051.0, 48.1), vec3(2343.0, 3043.2, 48.1) },
    },
    farming = {
        label = 'Ferme (champs de Grapeseed)', verb = 'Cueillir', tool = nil, duration = { 5000, 7000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', prop = 'prop_veg_crop_03_cab', perNode = 2,
        blip = { sprite = 285, color = 2 }, sell = 'Marché de Grapeseed',
        loot = { { 'tomato', 50, { 2, 4 } }, { 'potato', 50, { 2, 4 } } },
        spots = { vec3(2018.0, 4880.0, 42.7), vec3(2027.0, 4883.0, 42.7), vec3(2036.0, 4886.0, 42.7), vec3(2045.0, 4889.0, 42.7),
                  vec3(2020.0, 4889.0, 42.7), vec3(2029.0, 4892.0, 42.7), vec3(2038.0, 4895.0, 42.7), vec3(2047.0, 4898.0, 42.7),
                  vec3(2022.0, 4898.0, 42.7), vec3(2031.0, 4901.0, 42.7), vec3(2040.0, 4904.0, 42.7), vec3(2049.0, 4907.0, 42.7) },
    },
}

-- Chasse : animaux créés par le serveur dans la zone (pas de faux gibier), dépecés au couteau une fois abattus.
-- Permis de chasse (licence Qbox 'hunting') : au comptoir de l'Ammu-Nation de Paleto (V7 : l'ancien pavillon était une
-- maison fermée). Le fusil de chasse et ses munitions (Ammu-Nation) l'exigent ; dépecer sans permis = braconnage.
Config.Hunting = {
    licence = 'hunting', licencePrice = 750,
    lodge = vec3(-330.24, 6083.88, 31.45),   -- comptoir de l'Ammu-Nation de Paleto
    label = 'Chasse (gibier)', tool = 'huntingknife', skinTime = 6000, max = 6, respawnSeconds = 90, playerRadius = 500.0,
    blip = { sprite = 141, color = 1 }, center = vec3(-580.0, 5010.0, 140.0),
    animals = {
        ['a_c_deer'] = { { 'meat', 1, { 2, 3 } }, { 'leather', 1, { 1, 1 } } },
        ['a_c_boar'] = { { 'meat', 1, { 2, 4 } }, { 'leather', 1, { 1, 1 } } },
    },
    spawns = { vec3(-640.0, 5040.0, 142.0), vec3(-560.0, 4960.0, 158.0), vec3(-520.0, 5060.0, 118.0),
               vec3(-700.0, 4980.0, 152.0), vec3(-610.0, 4920.0, 177.0), vec3(-480.0, 4990.0, 125.0) },
}

-- Acheteurs : prix unitaire tiré dans [min, max] à chaque vente. Loin des points de récolte (V7).
-- Ferraille, cuivre, pierre et minerais : ferrailleur de Cypress Flats (gs_economy, prix selon le marché).
Config.Buyers = {
    { label = 'Poissonnerie de Del Perro', coords = vec3(-1637.0, -1093.0, 13.0), blip = { sprite = 356, color = 3 },
      items = { fish = { 25, 40 }, tuna = { 90, 140 } } },
    { label = 'Scierie de Paleto', coords = vec3(-552.4, 5348.5, 74.7), blip = { sprite = 77, color = 47 },
      items = { wood_log = { 20, 28 } } },
    { label = 'Marché de Grapeseed', coords = vec3(1678.4, 4880.4, 42.2), blip = { sprite = 52, color = 2 },
      items = { tomato = { 6, 9 }, potato = { 5, 8 } } },
    { label = 'Boucherie de Paleto (gibier de la chasse)', coords = vec3(-69.2, 6253.8, 31.1), blip = { sprite = 141, color = 47 },
      items = { meat = { 40, 60 }, leather = { 55, 80 } } },
}
