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
