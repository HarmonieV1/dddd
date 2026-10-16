-- [CONFIG] Monde. 1.0 = densité normale de GTA, 0.0 = ville vide.
Config = {}

Config.Density = {
    peds = 0.35,         -- piétons
    scenarios = 0.3,     -- PNJ assis, au travail, sur les bancs…
    vehicles = 0.3,      -- circulation
    parked = 0.4,        -- voitures garées
    -- Serveur plein : tout est encore réduit (x1 jusqu'à `from` joueurs, puis jusqu'à x`min` à `to` joueurs)
    crowd = { from = 24, to = 96, min = 0.45 },
}

-- Cayo Perico : chargée (terrain, eau, minimap, sons, PNJ) seulement à moins de `loadRadius` m du centre de l'île.
-- Loin de l'île, zéro coût. On y va en bateau, en avion, ou avec le vol régulier ci-dessous.
Config.Island = {
    center = vec3(4840.57, -5174.43, 2.0),
    loadRadius = 2200.0,
    -- vol régulier : comptoir à l'aéroport de LS ↔ piste de l'île (fondu au noir). Accès libre : 0 = gratuit.
    flight = {
        price = 0,
        -- V12.63 : arrivée = devant le pilote du comptoir (on sort du vol face à lui)
        mainland = { counter = vec3(-1037.8, -2737.8, 20.17), arrival = vec4(-1037.4, -2737.9, 20.17, 330.0), label = 'Vol pour Cayo Perico' },
        island = { counter = vec3(4494.3, -4525.3, 4.41), arrival = vec4(4493.8, -4524.6, 4.41, 290.0), label = 'Vol retour pour Los Santos' },
        -- Petit film du vol (avion au-dessus de l'océan) ; [Espace] = transfert rapide. false = simple fondu au noir.
        cinematic = { enabled = true, seconds = 10, model = 'luxor', from = vec3(-1300.0, -3400.0, 420.0), to = vec3(4300.0, -4650.0, 380.0),
            -- V12.33 : l'avion atterrit près du comptoir d'arrivée au lieu de disparaître. V12.63 : tout le vol dans l'axe de l'arrivée ;
            -- finale de `finalDistance` m commencée à `finalHeight` m, toucher des roues `before` m avant le comptoir à `touchSpeed` m/s,
            -- roulage de `roll` m jusqu'à l'arrêt (il s'arrête `before - roll` m avant le comptoir)
            landing = { approachSeconds = 5, finalDistance = 650.0, finalHeight = 70.0, touchSpeed = 60.0, before = 110.0, roll = 90.0, wheelHeight = 1.2 },
            -- V12.63 · Pistes d'atterrissage : l'avion s'aligne dans un virage, touche les roues au point `toucher` et roule jusqu'à
            -- `arret` (sens de la piste = de toucher vers arret, 400 m de roulage au plus). Positions estimées [À CALER] : debout au
            -- début de la piste, F11 → Monde et lieux → Déplacer un point → « Piste … · toucher », puis au bout du roulage → « … · arret ».
            runways = {
                mainland = { label = 'Piste LSIA', toucher = vec3(-1336.0, -3044.0, 13.9), arret = vec3(-1040.0, -3215.0, 13.9) },
                island = { label = 'Piste Cayo Perico', toucher = vec3(4180.0, -4545.0, 4.4), arret = vec3(4440.0, -4500.0, 4.4) },
            } },
    },
    -- Soirée DJ sur la plage (lancée par le staff : F11 → Événements → Soirée plage Cayo) : sono, lumières, danseurs,
    -- musique des enceintes de l'île. Coords à caler en jeu.
    party = {
        spot = vec3(4893.2, -4924.0, 3.37), radius = 250.0,
        props = {
            { model = 'ba_prop_battle_dj_stand', pos = vec4(4893.2, -4924.0, 2.4, 200.0) },
            { model = 'prop_speaker_06', pos = vec4(4890.0, -4922.5, 2.4, 200.0) },
            { model = 'prop_speaker_06', pos = vec4(4896.4, -4925.5, 2.4, 200.0) },
            { model = 'prop_worklight_03b', pos = vec4(4886.0, -4930.0, 2.4, 30.0) },
            { model = 'prop_worklight_03b', pos = vec4(4900.0, -4933.0, 2.4, 330.0) },
            { model = 'prop_beach_fire', pos = vec4(4893.0, -4936.0, 2.4, 0.0) },
        },
        dancers = { models = { 'a_f_y_beach_01', 'a_m_y_beach_01', 'a_f_y_bevhills_01', 'a_m_y_beach_02', 'a_f_y_juggalo_01' }, count = 12, area = 9.0 },
        emitters = { 'SE_DLC_Hei4_Island_Beach_Party_Music_New_01_Left', 'SE_DLC_Hei4_Island_Beach_Party_Music_New_02_Right',
                     'SE_DLC_Hei4_Island_Beach_Party_Music_New_03_Reverb', 'SE_DLC_Hei4_Island_Beach_Party_Music_New_04_Reverb' },
    },
}

-- V12.63 · Journée North Yankton (proposition n° 191) : la ville enneigée du prologue de GTA V occupe les MÊMES coordonnées
-- que Cayo Perico (les deux ne peuvent pas être chargées ensemble). Le vol régulier de l'aéroport mène donc un jour à Cayo,
-- le lendemain à North Yankton (jour de jeu = de `dayStartHour` h à `dayStartHour` h, heure du serveur : le redémarrage de 6 h),
-- ou à la destination choisie par le staff (F11 → Monde et lieux → Destination du vol de l'île, gardée après redémarrage).
-- Changement en cours de journée : les joueurs sur place sont d'abord rapatriés à l'aéroport. Un jour North Yankton :
-- Cayo n'est jamais chargée (ni sa soirée plage), la neige tombe pour ceux qui sont là-bas seulement.
Config.Yankton = {
    alternate = true,        -- false = Cayo tous les jours (sauf choix du staff)
    dayStartHour = 6,
    staffLevel = 4,          -- choisir la destination (même niveau que le menu Monde et lieux)
    zone = { x = 4300.0, y = -5000.0 }, loadRadius = 2400.0, -- centre de la zone chargée (pas un point à déplacer)
    weather = 'XMAS',        -- neige pendant le séjour, chez les voyageurs seulement
    flight = {
        price = 0,
        mainlandLabel = 'Vol pour North Yankton',
        -- [À CALER] comptoir du vol retour à Ludendorff (F11 → Déplacer un point)
        island = { counter = vec3(3363.5, -4846.0, 111.8), arrival = vec4(3363.9, -4846.1, 111.8, 315.0), label = 'Vol retour pour Los Santos' }, -- arrivée devant le pilote
        cinematicTo = vec3(3250.0, -4650.0, 420.0), -- film du vol : l'avion file vers la ville (pas de piste : fondu à l'arrivée)
    },
    -- Sur place (jours North Yankton) : café de Ludendorff [À CALER] (F11 → Déplacer un point) et « se mettre au vert » : la
    -- recherche (gs_wanted) retombe de `coolPerMinute` chaque minute passée là-bas, loin de la police de Los Santos.
    cafe = { label = 'Café de Ludendorff', coords = vec3(3361.5, -4843.0, 111.8),
        items = { { item = 'coffee', price = 6 }, { item = 'sandwich', price = 14 }, { item = 'water', price = 4 } } },
    coolPerMinute = 3,
    -- Décor du prologue (IPL du jeu de base). Un nom absent du jeu est simplement ignoré.
    ipls = {
        'plg_01', 'prologue01', 'prologue01_lod', 'prologue01c', 'prologue01c_lod', 'prologue01d', 'prologue01d_lod',
        'prologue01e', 'prologue01e_lod', 'prologue01f', 'prologue01f_lod', 'prologue01g', 'prologue01h', 'prologue01h_lod',
        'prologue01i', 'prologue01i_lod', 'prologue01j', 'prologue01j_lod', 'prologue01k', 'prologue01k_lod', 'prologue01z',
        'prologue01z_lod', 'plg_02', 'prologue02', 'prologue02_lod', 'plg_03', 'prologue03', 'prologue03_lod', 'prologue03b',
        'prologue03b_lod', 'prologue03_grv_dug', 'prologue03_grv_dug_lod', 'prologue_grv_torch', 'plg_04', 'prologue04',
        'prologue04_lod', 'prologue04b', 'prologue04b_lod', 'prologue04_cover', 'des_protree_end', 'des_protree_start',
        'des_protree_start_lod', 'plg_05', 'prologue05', 'prologue05_lod', 'prologue05b', 'prologue05b_lod', 'plg_06', 'prologue06',
        'prologue06_lod', 'prologue06b', 'prologue06b_lod', 'prologue06_int', 'prologue06_int_lod', 'prologue06_pannel',
        'prologue06_pannel_lod', 'prologue_m2_door', 'prologue_m2_door_lod', 'plg_occl_00', 'prologue_occl', 'plg_rd', 'prologuerd',
        'prologuerdb', 'prologuerd_lod',
    },
}

-- PNJ d'ambiance (V7) : créés chez chaque joueur à l'approche (60 m), invincibles, figés dans leur animation.
-- scenario = scénario du jeu ; anim = { dict, clip } en boucle. Coordonnées approximatives : la hauteur est recalée au sol,
-- et tout se règle en jeu (F11 → Monde et lieux → Déplacer un point).
Config.AmbientPeds = {
    -- Casino Diamond
    { label = 'Barman du casino', model = 's_m_y_barman_01', coords = vec4(1110.3, 208.9, -49.44, 30.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    { label = 'Caissière du casino', model = 'u_f_m_casinocash_01', coords = vec4(1117.6, 219.9, -49.44, 90.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    { label = 'Sécurité du casino', model = 's_m_m_highsec_01', coords = vec4(1089.9, 208.6, -49.0, 310.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
    { label = 'Croupier', model = 's_m_y_casino_01', coords = vec4(1149.4, 269.0, -51.84, 45.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    { label = 'Croupière', model = 's_f_y_casino_01', coords = vec4(1143.8, 263.6, -51.84, 315.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    -- Vanilla Unicorn : danseuses sur la scène, barman
    { label = 'Danseuse 1 (Vanilla Unicorn)', model = 's_f_y_stripper_01', coords = vec4(112.6, -1287.0, 28.46, 300.0), anim = { dict = 'mini@strip_club@pole_dance@pole_dance1', clip = 'pd_dance_01' } },
    { label = 'Danseuse 2 (Vanilla Unicorn)', model = 's_f_y_stripper_02', coords = vec4(104.2, -1293.9, 29.26, 30.0), anim = { dict = 'mini@strip_club@pole_dance@pole_dance2', clip = 'pd_dance_02' } },
    { label = 'Danseuse 3 (Vanilla Unicorn)', model = 'csb_stripper_01', coords = vec4(102.3, -1290.0, 29.26, 210.0), anim = { dict = 'mini@strip_club@private_dance@part1', clip = 'priv_dance_p1' } },
    { label = 'Videur (Vanilla Unicorn)', model = 's_m_y_doorman_01', coords = vec4(127.5, -1296.5, 29.27, 210.0), scenario = 'WORLD_HUMAN_GUARD_STAND' },
    -- Tequi-la-la : groupe sur scène
    { label = 'Guitariste (Tequi-la-la)', model = 'a_m_y_hipster_02', coords = vec4(-552.8, 284.9, 82.98, 175.0), scenario = 'WORLD_HUMAN_MUSICIAN' },
    { label = 'Bassiste (Tequi-la-la)', model = 'a_m_y_hipster_01', coords = vec4(-554.6, 285.4, 82.98, 175.0), scenario = 'WORLD_HUMAN_MUSICIAN' },
    { label = 'Chanteuse (Tequi-la-la)', model = 'a_f_y_hipster_02', coords = vec4(-553.7, 283.9, 82.98, 175.0), anim = { dict = 'anim@mp_player_intcelebrationfemale@uncle_disco', clip = 'uncle_disco' } },
    -- Cayo Perico : pilote au comptoir du vol retour
    -- V12.63 : `island` = seulement les jours où le vol mène là (Cayo et North Yankton partagent les mêmes coordonnées)
    { label = 'Pilote (vol retour)', model = 's_m_m_pilot_01', coords = vec4(4495.3, -4524.0, 4.41, 110.0), scenario = 'WORLD_HUMAN_CLIPBOARD', island = 'cayo' },
    { label = 'Pilote (vol retour, North Yankton)', model = 's_m_m_pilot_01', coords = vec4(3365.0, -4845.0, 111.8, 135.0), scenario = 'WORLD_HUMAN_CLIPBOARD', island = 'yankton' },
    { label = 'Serveuse (café de Ludendorff)', model = 'a_f_m_salton_01', coords = vec4(3362.5, -4841.8, 111.8, 180.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT', island = 'yankton' },
    { label = 'Shérif de Ludendorff', model = 's_m_m_snowcop_01', coords = vec4(3351.5, -4848.5, 111.8, 270.0), scenario = 'WORLD_HUMAN_COP_IDLES', island = 'yankton' },
    { label = 'Pilote (vol pour Cayo)', model = 's_m_m_pilot_01', coords = vec4(-1036.6, -2736.4, 20.17, 150.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
    -- Bahama Mamas : DJ
    { label = 'DJ (Bahama Mamas)', model = 'a_m_y_clubcust_01', coords = vec4(-1381.0, -616.0, 31.5, 120.0), anim = { dict = 'anim@amb@nightclub@djs@dixon@', clip = 'dixn_dance_cntr_open_dix' } },
}
