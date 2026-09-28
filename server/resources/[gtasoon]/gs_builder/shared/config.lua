-- [CONFIG] Mapping en jeu.
Config = {}

Config.Ace = 'gs.builder'          -- permission (cfg/permissions.cfg : group.admin)
Config.MaxObjects = 3000           -- total sur le serveur
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
}
