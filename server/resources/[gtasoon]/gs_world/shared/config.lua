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
        mainland = { counter = vec3(-1037.8, -2737.8, 20.17), arrival = vec4(-1042.1, -2745.3, 21.36, 330.0), label = 'Vol pour Cayo Perico' },
        island = { counter = vec3(4494.3, -4525.3, 4.41), arrival = vec4(4500.8, -4522.0, 4.41, 20.0), label = 'Vol retour pour Los Santos' },
        -- Petit film du vol (avion au-dessus de l'océan) ; [Espace] = transfert rapide. false = simple fondu au noir.
        cinematic = { enabled = true, seconds = 10, model = 'luxor', from = vec3(-1300.0, -3400.0, 420.0), to = vec3(4300.0, -4650.0, 380.0) },
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
    -- Bahama Mamas : DJ
    { label = 'DJ (Bahama Mamas)', model = 'a_m_y_clubcust_01', coords = vec4(-1381.0, -616.0, 31.5, 120.0), anim = { dict = 'anim@amb@nightclub@djs@dixon@', clip = 'dixn_dance_cntr_open_dix' } },
}
