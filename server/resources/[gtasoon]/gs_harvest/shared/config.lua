-- [CONFIG] Métiers de récolte (libres, sans embauche) : on achète l'outil en quincaillerie, on va sur un point [E],
-- on récolte (durée réelle vérifiée par le serveur), on revend chez l'acheteur. Coords à caler en jeu (F11 → Copier mes coordonnées).
Config = {}

Config.Tolerance = 3.0
Config.SpotRadius = 3.0
Config.BreakChance = 0.03   -- l'outil casse parfois (on en rachète un)
Config.Regrow = 300         -- secondes avant qu'un arbre / rocher / carcasse épuisé revienne (pour ce joueur)
Config.PropRange = 90.0     -- distance d'apparition des arbres / rochers / carcasses (créés chez chaque joueur)

-- Vestiaire de chaque activité : tenue de travail (même base que le bleu du mécano), retour en civil au même endroit
Config.WorkOutfit = {
    male = { [3] = { 0, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 66, 0 } },
    female = { [3] = { 14, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 60, 0 } },
}

-- Noms affichés des objets récoltés (messages en français)
Config.ItemLabels = {
    fish = 'poisson', tuna = 'thon', scrapmetal = 'ferraille', copper = 'cuivre', stone = 'pierre', iron_ore = 'minerai de fer',
    gold_ore = 'pépite d\'or', wood_log = 'bûche', tomato = 'tomate', potato = 'pomme de terre', meat = 'viande', leather = 'cuir',
    barley = 'orge', hops = 'houblon', corn = 'épi de maïs', tobacco_leaf = 'feuilles de tabac', poppy_resin = 'latex de pavot',
}

-- V7 : chaque activité a plusieurs « nœuds » (arbres, rochers, carcasses, rangs de légumes, places de pêche).
-- Un nœud s'épuise après `perNode` récoltes (pour ce joueur) et revient après Config.Regrow : on se déplace, on ne reste
-- pas planté devant un seul arbre. `prop` = objet posé au sol chez le joueur (sinon : simple point, ex. pêche).
-- `sell` = où revendre (affiché après chaque récolte) ; les acheteurs sont loin des points de récolte (marche ou voiture).
-- Coordonnées réglables en jeu : F11 → Monde et lieux → Déplacer un point.
-- loot = { item, poids du tirage, { min, max }, finds = { textes RP de ce qu'on a trouvé } (facultatif, V12.36) }
-- V12.36 · Réglages de scène facultatifs par activité :
--   props = { … }        : plusieurs objets possibles (choix fixe par nœud : tout le monde voit le même) ; `prop` reste le repli
--   phases = { … }       : récolte en plusieurs temps { label, share (part de la durée), anim | scenario, handProp }
--   keepWhenDepleted     : l'objet reste visible une fois le nœud épuisé (une carcasse dépouillée ne disparaît pas), seul [E] s'éteint
--   depletedMsg          : texte quand le nœud s'épuise ; icon = icône ox_target du nœud
--   lockerPed            : PNJ (contremaître) au vestiaire, porté par gs_markers : { model, heading, scenario }
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
        lockerPed = { model = 's_m_y_construct_02', heading = 135.0, scenario = 'WORLD_HUMAN_CLIPBOARD' }, -- chef de carrière
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
        lockerPed = { model = 's_m_y_construct_01', heading = 135.0, scenario = 'WORLD_HUMAN_CLIPBOARD' }, -- contremaître
        spots = { vec3(-590.0, 5560.0, 60.0), vec3(-596.9, 5569.5, 60.0), vec3(-608.1, 5565.9, 60.0), vec3(-608.1, 5554.1, 60.0),
                  vec3(-596.9, 5550.5, 60.0), vec3(-579.7, 5568.6, 60.0), vec3(-594.1, 5581.2, 60.0), vec3(-612.9, 5577.8, 60.0),
                  vec3(-622.0, 5561.1, 60.0), vec3(-614.5, 5543.5, 60.0), vec3(-596.2, 5538.3, 60.0), vec3(-580.7, 5549.5, 60.0) },
    },
    -- Ferrailleur (sans outil à acheter : la casse prête ses clés) : dépouiller les carcasses des casses (Rogers Salvage à LS,
    -- casse de Sandy Shores). Revente à Cypress Flats (gs_economy, prix selon le marché). Ferraille et cuivre servent aussi
    -- aux munitions artisanales des gangs.
    -- V12.36 · Vraie scène : carcasse / bloc moteur / tas posé au sol (varié par nœud), on s'accroupit et on fouille, puis on dévisse
    -- les pièces à genoux avec une clé à molette en main ; pièces variées (voir `finds`) ; la carcasse dépouillée reste là, [E] éteint,
    -- et redevient fouillable après Config.Regrow. Dictionnaires d'animation du jeu :
    --   anim@amb@business@weed@weed_inspecting_lo_med_hi@ / weed_crouch_checkingleaves_idle_01_inspector (fouille accroupie, DLC Bikers)
    --   anim@amb@clubhouse@tutorial@bkr_tut_ig3@ / machinic_loop_mechandplayer (mécanique à genoux, atelier du club-house)
    scrapyard = {
        label = 'Ferraille (casses)', verb = 'Récupérer des pièces', tool = nil, duration = { 9000, 13000 },
        icon = 'fa-solid fa-wrench',
        prop = 'prop_rub_scrap_02', keepWhenDepleted = true, perNode = 3,
        props = { 'prop_rub_scrap_02', 'prop_rub_carwreck_2', 'prop_rub_engine', 'prop_rub_carwreck_3', 'prop_rub_scrap_04', 'prop_rub_carpart_02' },
        phases = {
            { label = 'Fouille de la carcasse…', share = 0.4,
              anim = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_crouch_checkingleaves_idle_01_inspector' } },
            { label = 'Dévissage des pièces…', share = 0.6,
              anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
              handProp = { model = 'prop_tool_wrench', bone = 57005, pos = vec3(0.10, 0.03, -0.02), rot = vec3(-78.0, 13.0, 28.0) } },
        },
        depletedMsg = 'plus rien à prendre ici, passe à la carcasse suivante',
        blip = { sprite = 527, color = 47 }, sell = 'Ferrailleur de Cypress Flats',
        loot = {
            { 'scrapmetal', 50, { 2, 4 }, finds = { 'un pare-chocs rouillé', 'une portière tordue', 'un capot cabossé', 'des ressorts de suspension' } },
            { 'scrapmetal', 20, { 5, 7 }, finds = { 'un bloc moteur grillé', 'un bout de châssis découpé', 'une boîte de vitesses morte' } },
            { 'copper', 30, { 1, 3 }, finds = { 'un faisceau électrique', 'un alternateur', 'des câbles de batterie', 'un radiateur en cuivre' } },
        },
        lockerPed = { model = 's_m_m_autoshop_01', heading = 135.0, scenario = 'WORLD_HUMAN_CLIPBOARD' }, -- gardien de la casse
        spots = { vec3(-468.9, -1717.2, 18.7), vec3(-458.3, -1706.5, 18.8), vec3(-455.1, -1707.7, 18.8), vec3(-467.3, -1704.1, 18.8),
                  vec3(-470.9, -1716.3, 18.8), vec3(-458.7, -1719.9, 18.8), vec3(2346.8, 3048.1, 48.1), vec3(2335.2, 3057.9, 48.1),
                  vec3(2350.8, 3055.0, 48.1), vec3(2339.0, 3062.8, 48.1), vec3(2331.2, 3051.0, 48.1), vec3(2343.0, 3043.2, 48.1) },
    },
    farming = {
        label = 'Ferme (champs de Grapeseed)', verb = 'Cueillir', tool = nil, duration = { 5000, 7000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', prop = 'prop_veg_crop_03_cab', perNode = 2,
        blip = { sprite = 285, color = 2 }, sell = 'Marché de Grapeseed',
        loot = { { 'tomato', 50, { 2, 4 } }, { 'potato', 50, { 2, 4 } } },
        lockerPed = { model = 's_m_m_gardener_01', heading = 135.0, scenario = 'WORLD_HUMAN_CLIPBOARD' }, -- exploitant
        spots = { vec3(2018.0, 4880.0, 42.7), vec3(2027.0, 4883.0, 42.7), vec3(2036.0, 4886.0, 42.7), vec3(2045.0, 4889.0, 42.7),
                  vec3(2020.0, 4889.0, 42.7), vec3(2029.0, 4892.0, 42.7), vec3(2038.0, 4895.0, 42.7), vec3(2047.0, 4898.0, 42.7),
                  vec3(2022.0, 4898.0, 42.7), vec3(2031.0, 4901.0, 42.7), vec3(2040.0, 4904.0, 42.7), vec3(2049.0, 4907.0, 42.7) },
    },
    -- V12.45 · props BzZz (ressource gsa_9a13b85…, « Addon props » gardenpack) : vrais plants d'orge, houblon, maïs, tabac, pavot.
    -- Sans ces props (ressource arrêtée), repli sur un objet du jeu. Points à caler en jeu : F11 → Monde et lieux → Déplacer un point.
    cereals = {
        label = 'Champs d\'orge, de houblon et de maïs (Grapeseed)', verb = 'Récolter', tool = nil, duration = { 5000, 7000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', prop = 'prop_veg_crop_03_cab', perNode = 2,
        props = { 'prop_bzzz_gardenpack_barley001', 'prop_bzzz_gardenpack_hops001', 'prop_bzzz_gardenpack_cornstalk001',
                  'prop_bzzz_gardenpack_barley002', 'prop_bzzz_gardenpack_hops002', 'prop_bzzz_gardenpack_cornstalk002',
                  'prop_bzzz_gardenpack_barley003', 'prop_bzzz_gardenpack_hops003', 'prop_bzzz_gardenpack_cornstalk003' },
        blip = { sprite = 285, color = 46 }, sell = 'Marché de Grapeseed', icon = 'fa-solid fa-wheat-awn',
        loot = { { 'barley', 40, { 2, 4 }, finds = { 'une gerbe d\'orge' } }, { 'hops', 30, { 1, 3 }, finds = { 'des cônes de houblon' } },
                 { 'corn', 30, { 2, 3 }, finds = { 'des épis bien mûrs' } } },
        lockerPed = { model = 'a_m_m_farmer_01', heading = 135.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        spots = { vec3(2062.0, 4912.0, 41.0), vec3(2071.0, 4915.0, 41.0), vec3(2080.0, 4918.0, 41.0), vec3(2089.0, 4921.0, 41.0),
                  vec3(2064.0, 4921.0, 41.0), vec3(2073.0, 4924.0, 41.0), vec3(2082.0, 4927.0, 41.0), vec3(2091.0, 4930.0, 41.0),
                  vec3(2066.0, 4930.0, 41.0), vec3(2075.0, 4933.0, 41.0), vec3(2084.0, 4936.0, 41.0), vec3(2093.0, 4939.0, 41.0) },
    },
    tobacco = {
        label = 'Plantation de tabac (Grapeseed)', verb = 'Cueillir', tool = nil, duration = { 5000, 7000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', prop = 'prop_veg_crop_03_cab', perNode = 2,
        props = { 'prop_bzzz_gardenpack_tabacco001', 'prop_bzzz_gardenpack_tabacco002', 'prop_bzzz_gardenpack_tabacco003' },
        blip = { sprite = 285, color = 21 }, sell = 'Marché de Grapeseed', icon = 'fa-solid fa-leaf', outfit = false,
        loot = { { 'tobacco_leaf', 100, { 2, 4 }, finds = { 'de grandes feuilles de tabac' } } },
        spots = { vec3(1895.0, 4795.0, 44.0), vec3(1903.0, 4799.0, 44.0), vec3(1911.0, 4803.0, 44.0), vec3(1919.0, 4807.0, 44.0),
                  vec3(1897.0, 4804.0, 44.0), vec3(1905.0, 4808.0, 44.0), vec3(1913.0, 4812.0, 44.0), vec3(1921.0, 4816.0, 44.0) },
    },
    -- Illégal : pas de blip, pas de vestiaire ; chaque récolte peut être signalée (gs_wanted, « Culture illicite »)
    poppy = {
        label = 'Champ de pavot', verb = 'Inciser', tool = nil, duration = { 7000, 9000 },
        scenario = 'WORLD_HUMAN_GARDENER_PLANT', prop = 'prop_veg_crop_03_cab', perNode = 2, blip = false, outfit = false,
        illegal = 'drug_cultivation', icon = 'fa-solid fa-seedling',
        props = { 'prop_bzzz_gardenpack_poppy001', 'prop_bzzz_gardenpack_poppy002', 'prop_bzzz_gardenpack_poppy003' },
        sell = 'un receleur du port (on en parle au marché noir)',
        loot = { { 'poppy_resin', 100, { 1, 2 }, finds = { 'quelques gouttes de latex' } } },
        spots = { vec3(2208.0, 5562.0, 53.0), vec3(2214.0, 5566.0, 53.0), vec3(2220.0, 5570.0, 53.0), vec3(2226.0, 5574.0, 53.0),
                  vec3(2210.0, 5571.0, 53.0), vec3(2216.0, 5575.0, 53.0) },
    },
}

-- Chasse : animaux créés par le serveur dans la zone (pas de faux gibier), dépecés au couteau une fois abattus.
-- Permis de chasse (licence Qbox 'hunting') : au comptoir de l'Ammu-Nation de Paleto (V7 : l'ancien pavillon était une
-- maison fermée). Le fusil de chasse et ses munitions (Ammu-Nation) l'exigent ; dépecer sans permis = braconnage.
-- (Pas de PNJ ici : l'armurier de gs_blackmarket tient déjà ce comptoir.)
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
-- V11.5 : acheteur visible (PNJ figé, recalé au sol). V12.36 : porté par gs_markers (champ `ped` du point : { model, heading, scenario },
-- `heading` = direction du regard, le PNJ se tient 1,2 m derrière le point) ; il porte aussi la vente (ox_target), en plus du [E].
Config.Buyers = {
    { label = 'Poissonnerie de Del Perro', coords = vec3(-1637.0, -1093.0, 13.0), blip = { sprite = 356, color = 3 },
      items = { fish = { 25, 40 }, tuna = { 90, 140 } }, ped = { model = 'a_m_m_salton_01', heading = 320.0, scenario = 'WORLD_HUMAN_CLIPBOARD' } },
    { label = 'Scierie de Paleto', coords = vec3(-552.4, 5348.5, 74.7), blip = { sprite = 77, color = 47 },
      items = { wood_log = { 20, 28 } }, ped = { model = 's_m_y_construct_01', heading = 90.0, scenario = 'WORLD_HUMAN_CLIPBOARD' } },
    { label = 'Marché de Grapeseed', coords = vec3(1678.4, 4880.4, 42.2), blip = { sprite = 52, color = 2 },
      items = { tomato = { 6, 9 }, potato = { 5, 8 }, barley = { 4, 7 }, hops = { 7, 10 }, corn = { 5, 8 }, tobacco_leaf = { 9, 13 } }, ped = { model = 'a_m_m_farmer_01', heading = 180.0, scenario = 'WORLD_HUMAN_CLIPBOARD' } },
    -- V12.45 · receleur du port (pavot) : pas de blip, on le trouve par le bouche-à-oreille RP
    { label = 'Receleur du port', coords = vec3(1003.2, -2918.6, 5.9), blip = false,
      items = { poppy_resin = { 45, 70 } }, ped = { model = 'g_m_m_chicold_01', heading = 90.0, scenario = 'WORLD_HUMAN_SMOKING' } },
    { label = 'Boucherie de Paleto (gibier de la chasse)', coords = vec3(-69.2, 6253.8, 31.1), blip = { sprite = 141, color = 47 },
      items = { meat = { 40, 60 }, leather = { 55, 80 } }, ped = { model = 's_m_m_linecook', heading = 45.0, scenario = 'WORLD_HUMAN_CLIPBOARD' } },
}
