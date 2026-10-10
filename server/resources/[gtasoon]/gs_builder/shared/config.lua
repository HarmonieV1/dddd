-- [CONFIG] Mapping en jeu.
Config = {}

Config.Ace = 'gs.builder'          -- permission (cfg/permissions.cfg : super-admin et fondateur)
Config.MaxObjects = 3000           -- total sur le serveur
Config.MaxHides = 500              -- objets de la map d'origine retirés (poubelles, bancs…)
Config.HideRadius = 1.5            -- rayon de recherche du modèle à retirer autour du point visé
Config.MaxPlaceDistance = 60.0     -- distance max entre le staff et l'objet placé
Config.StreamIn = 150.0            -- objets affichés à moins de X m (chaque client ne crée que ce qui est proche)
Config.StreamOut = 180.0
Config.StreamTick = 1500           -- ms entre deux vérifications de distance

-- V11.6 · Catalogue par catégories (menu staff F11 → Monde et lieux → Mapping). Modèles du jeu de base, noms en
-- français. N'importe quel autre modèle reste utilisable en le tapant. Pas d'image : le jeu n'en fournit aucune.
Config.Catalog = {
    { label = 'Mobilier urbain', icon = 'couch', items = {
        { model = 'prop_bench_01a', label = 'Banc en bois' }, { model = 'prop_bench_04', label = 'Banc métal' }, { model = 'prop_bench_05', label = 'Banc de parc' },
        { model = 'prop_bench_08', label = 'Banc moderne' }, { model = 'prop_bench_11', label = 'Banc béton' }, { model = 'prop_table_03', label = 'Table' },
        { model = 'prop_table_02', label = 'Table ronde' }, { model = 'prop_chair_01a', label = 'Chaise' }, { model = 'prop_chair_08', label = 'Chaise pliante' },
        { model = 'prop_picnictable_01', label = 'Table de pique-nique' }, { model = 'prop_streetlight_01', label = 'Lampadaire' },
        { model = 'prop_streetlight_03', label = 'Lampadaire double' }, { model = 'prop_fire_hydrant_1', label = 'Bouche à incendie' },
        { model = 'prop_parknmeter_01', label = 'Parcmètre' }, { model = 'prop_postbox_01a', label = 'Boîte aux lettres' }, { model = 'prop_bus_stop_sign', label = 'Panneau arrêt de bus' },
        { model = 'prop_busstop_02', label = 'Abribus' }, { model = 'prop_bikerack_1a', label = 'Range-vélos' }, { model = 'prop_sign_road_01a', label = 'Panneau routier' },
        { model = 'prop_bollard_01a', label = 'Borne' }, { model = 'prop_fncwood_16a', label = 'Clôture bois' }, { model = 'prop_fnclink_03e', label = 'Grillage' },
        { model = 'prop_phonebox_01a', label = 'Cabine téléphonique' }, { model = 'prop_atm_01', label = 'Distributeur de billets (décor)' },
        { model = 'prop_vend_soda_01', label = 'Distributeur de boissons' }, { model = 'prop_vend_snak_01', label = 'Distributeur de snacks' },
        { model = 'prop_news_disp_02a', label = 'Présentoir de journaux' }, { model = 'prop_wall_light_12a', label = 'Applique murale' },
    } },
    { label = 'Chantier et barrières', icon = 'person-digging', items = {
        { model = 'prop_barrier_work05', label = 'Barrière de chantier' }, { model = 'prop_barrier_work06a', label = 'Barrière rouge et blanche' },
        { model = 'prop_barrier_work01a', label = 'Barrière lumineuse' }, { model = 'prop_barier_conc_01a', label = 'Bloc de béton' },
        { model = 'prop_barier_conc_02a', label = 'Bloc de béton (long)' }, { model = 'prop_mp_cone_01', label = 'Cône' }, { model = 'prop_mp_cone_02', label = 'Cône (petit)' },
        { model = 'prop_roadcone02a', label = 'Cône routier' }, { model = 'prop_mp_barrier_02b', label = 'Barrière de course' }, { model = 'prop_ld_barrier_01', label = 'Barrière police' },
        { model = 'prop_worklight_03b', label = 'Projecteur de chantier' }, { model = 'prop_generator_03b', label = 'Groupe électrogène' },
        { model = 'prop_portaloo_01a', label = 'Toilettes de chantier' }, { model = 'prop_skip_06a', label = 'Benne de chantier' }, { model = 'prop_scafold_01a', label = 'Échafaudage' },
        { model = 'prop_sandpile_01', label = 'Tas de sable' }, { model = 'prop_roadpole_01a', label = 'Poteau routier' }, { model = 'prop_traffic_lightset_01', label = 'Feu tricolore' },
        { model = 'prop_tool_bench02', label = 'Établi' }, { model = 'prop_toolchest_05', label = 'Servante d\'atelier' }, { model = 'prop_carjack', label = 'Cric' },
        { model = 'prop_jerrycan_01a', label = 'Jerrican' }, { model = 'prop_consign_01a', label = 'Panneau de chantier' },
    } },
    { label = 'Éclairage et fête', icon = 'lightbulb', items = {
        { model = 'prop_neon_01', label = 'Néon' }, { model = 'prop_spot_01', label = 'Spot' }, { model = 'prop_studio_light_01', label = 'Projecteur de studio' },
        { model = 'prop_speaker_06', label = 'Enceinte' }, { model = 'prop_speaker_05', label = 'Enceinte (grande)' }, { model = 'prop_dj_deck_01', label = 'Table de DJ' },
        { model = 'prop_lightstand_01', label = 'Pied de lumière' }, { model = 'prop_stage_lights_01', label = 'Rampe de lumières' }, { model = 'prop_party_balloons', label = 'Ballons' },
        { model = 'prop_gazebo_02', label = 'Tonnelle' }, { model = 'prop_beach_fire', label = 'Feu de camp' }, { model = 'prop_bbq_5', label = 'Barbecue' },
        { model = 'prop_cooler_01', label = 'Glacière' }, { model = 'prop_mic_01a', label = 'Micro sur pied' }, { model = 'prop_tv_flat_01', label = 'Télé écran plat' },
        { model = 'prop_air_bigradar', label = 'Grand radar (event)' }, { model = 'prop_flag_us', label = 'Drapeau (mât)' }, { model = 'prop_xmas_tree_int', label = 'Sapin de Noël' },
    } },
    { label = 'Végétation', icon = 'tree', items = {
        { model = 'prop_palm_med_01b', label = 'Palmier' }, { model = 'prop_palm_fan_02_a', label = 'Palmier éventail' }, { model = 'prop_palm_sm_01e', label = 'Petit palmier' },
        { model = 'prop_tree_pine_01', label = 'Pin' }, { model = 'prop_tree_oak_01', label = 'Chêne' }, { model = 'prop_tree_cedar_02', label = 'Cèdre' },
        { model = 'prop_bush_lrg_02', label = 'Grand buisson' }, { model = 'prop_bush_med_02', label = 'Buisson' }, { model = 'prop_plant_01a', label = 'Plante en pot' },
        { model = 'prop_plant_int_03a', label = 'Plante d\'intérieur' }, { model = 'prop_flowerpot_01', label = 'Jardinière' }, { model = 'prop_planter_03a', label = 'Bac à fleurs' },
        { model = 'prop_rock_1_a', label = 'Rocher' }, { model = 'prop_rock_4_big2', label = 'Gros rocher' }, { model = 'prop_log_01', label = 'Tronc couché' },
        { model = 'prop_cactus_01a', label = 'Cactus' }, { model = 'prop_grass_da_01', label = 'Herbes hautes' },
    } },
    { label = 'Commerce et stands', icon = 'store', items = {
        { model = 'prop_hotdogstand_01', label = 'Stand hot-dog' }, { model = 'prop_burgerstand_01', label = 'Stand burger' }, { model = 'prop_icecream_stand_01', label = 'Stand de glaces' },
        { model = 'prop_food_cb_counter', label = 'Comptoir' }, { model = 'prop_till_01', label = 'Caisse enregistreuse' }, { model = 'prop_shop_counter_01', label = 'Comptoir de magasin' },
        { model = 'prop_boxpile_07d', label = 'Pile de caisses' }, { model = 'prop_boxpile_06b', label = 'Pile de cartons' }, { model = 'prop_box_wood02a', label = 'Caisse en bois' },
        { model = 'prop_pallet_02a', label = 'Palette' }, { model = 'prop_pallet_pile_02', label = 'Pile de palettes' }, { model = 'prop_barrel_01a', label = 'Baril' },
        { model = 'prop_crate_11e', label = 'Caisse militaire' }, { model = 'prop_fruit_stand_01', label = 'Étal de fruits' }, { model = 'prop_veg_crop_03_cab', label = 'Cageot de légumes' },
        { model = 'prop_gas_pump_1a', label = 'Pompe à essence' }, { model = 'prop_vend_coffe_01', label = 'Machine à café' }, { model = 'prop_rub_cabinet02', label = 'Armoire (déco)' },
        { model = 'prop_sign_road_restrictions_01', label = 'Panneau interdiction' }, { model = 'prop_a_frame_sign_01', label = 'Chevalet (ardoise)' },
    } },
    { label = 'Déchets et rue', icon = 'trash', items = {
        { model = 'prop_bin_05a', label = 'Poubelle' }, { model = 'prop_bin_01a', label = 'Poubelle (grille)' }, { model = 'prop_bin_07a', label = 'Poubelle ronde' },
        { model = 'prop_dumpster_01a', label = 'Benne à ordures' }, { model = 'prop_dumpster_02a', label = 'Benne (grande)' }, { model = 'prop_recyclebin_03_a', label = 'Bac de tri' },
        { model = 'prop_rub_binbag_01', label = 'Sac poubelle' }, { model = 'prop_rub_trolley01a', label = 'Caddie abandonné' }, { model = 'prop_rub_tyre_01', label = 'Pneu usé' },
        { model = 'prop_rub_matress_01', label = 'Matelas abandonné' }, { model = 'prop_rub_cardpile_01', label = 'Tas de cartons' }, { model = 'prop_shopping_bags', label = 'Sacs de courses' },
        { model = 'prop_skateboard_01', label = 'Skateboard' }, { model = 'prop_sofa_01', label = 'Canapé défoncé' }, { model = 'prop_bbq_3', label = 'Barbecue (bidon)' },
    } },
    { label = 'Plage et loisirs', icon = 'umbrella-beach', items = {
        { model = 'prop_parasol_04b', label = 'Parasol' }, { model = 'prop_beach_lg_float', label = 'Bouée géante' }, { model = 'prop_beach_towel_01', label = 'Serviette de plage' },
        { model = 'prop_beachbag_01', label = 'Sac de plage' }, { model = 'prop_surf_board_01', label = 'Planche de surf' }, { model = 'prop_beach_volball01', label = 'Ballon de volley' },
        { model = 'prop_beach_lilo_01', label = 'Matelas gonflable' }, { model = 'prop_lifeguard_chair_01', label = 'Chaise de maître-nageur' },
        { model = 'prop_table_tennis', label = 'Table de ping-pong' }, { model = 'prop_pooltable_02', label = 'Billard' }, { model = 'prop_bball_hoop_01', label = 'Panier de basket' },
        { model = 'prop_golf_bag_01', label = 'Sac de golf' }, { model = 'prop_tent_01', label = 'Tente' }, { model = 'prop_camping_chair_01', label = 'Chaise de camping' },
        { model = 'prop_fishing_rod_01', label = 'Canne à pêche' }, { model = 'prop_boxing_bag_01', label = 'Sac de frappe' },
    } },
    { label = 'Police et urgence', icon = 'car-side', items = {
        { model = 'prop_barrier_work05', label = 'Barrière' }, { model = 'p_ld_stinger_s', label = 'Herse' }, { model = 'prop_police_barrier_01', label = 'Barrière police' },
        { model = 'prop_roadcone02a', label = 'Cône' }, { model = 'prop_flare_01', label = 'Fusée au sol' }, { model = 'prop_ld_ambulance_pack', label = 'Sac médical' },
        { model = 'prop_hosp_bed_01', label = 'Lit d\'hôpital' }, { model = 'prop_wheelchair_01', label = 'Fauteuil roulant' }, { model = 'prop_cs_police_torch', label = 'Lampe police' },
        { model = 'prop_sec_barier_01a', label = 'Barrière de sécurité' }, { model = 'prop_cctv_cam_01a', label = 'Caméra (décor)' }, { model = 'prop_police_phone', label = 'Borne police' },
    } },
}

-- Objets proposés en raccourci (n'importe quel modèle du jeu reste utilisable en le tapant)
Config.Favorites = {
    { model = 'prop_bench_01a', label = 'Banc' },
    { model = 'prop_table_03', label = 'Table' },
    { model = 'prop_chair_01a', label = 'Chaise' },
    { model = 'prop_barrier_work05', label = 'Barrière de chantier' },
    { model = 'prop_mp_cone_01', label = 'Cône' },
    { model = 'prop_boxpile_07d', label = 'Pile de caisses' },
    { model = 'prop_palm_med_01b', label = 'Palmier' },
    { model = 'prop_neon_01', label = 'Néon' },
    { model = 'prop_worklight_03b', label = 'Projecteur' },
    { model = 'prop_bbq_5', label = 'Barbecue' },
    { model = 'prop_bin_05a', label = 'Poubelle' },
    { model = 'prop_dumpster_01a', label = 'Benne à ordures' },
    { model = 'prop_recyclebin_03_a', label = 'Bac de tri' },
    { model = 'prop_streetlight_01', label = 'Lampadaire' },
    { model = 'prop_fire_hydrant_1', label = 'Bouche à incendie' },
    { model = 'prop_parknmeter_01', label = 'Parcmètre' },
    { model = 'prop_vend_soda_01', label = 'Distributeur de boissons' },
    { model = 'prop_atm_01', label = 'Distributeur de billets (décor)' },
    { model = 'prop_gazebo_02', label = 'Tonnelle' },
    { model = 'prop_air_bigradar', label = 'Grand radar (event)' },
    { model = 'prop_tool_bench02', label = 'Établi' },
    { model = 'prop_parasol_04b', label = 'Parasol' },
    { model = 'prop_beach_fire', label = 'Feu de camp' },
    { model = 'prop_speaker_06', label = 'Enceinte (event)' },
}
