-- [CONFIG] Monde. 1.0 = densité normale de GTA, 0.0 = ville vide.
Config = {}

Config.Density = {
    peds = 0.6,          -- piétons
    scenarios = 0.6,     -- PNJ assis, au travail, sur les bancs…
    vehicles = 0.65,     -- circulation
    parked = 0.75,       -- voitures garées
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
