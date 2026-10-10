-- [CONFIG] gs_memoire · La mémoire des lieux. Un « lieu » = une case de `Cell` m. Chaque événement de la ville (crime
-- signalé, arrestation, mariage, course gagnée, braquage, guerre de gang, plaque) s'y ajoute. À partir de `MinEvents`,
-- les passants en parlent quand on passe ; à `PlaqueAt` événements, une plaque naît toute seule (gs_scars) ; la nuit,
-- à partir de `EchoAt`, un « écho » (silhouette translucide) rejoue le passé.
Config = {}

Config.Cell = 40.0            -- taille d'une case (m)
Config.MinEvents = 3          -- à partir de combien d'événements un lieu « se souvient »
Config.PlaqueAt = 10          -- plaque automatique (gs_scars) au 10e événement
Config.EchoAt = 5             -- écho nocturne à partir de 5 événements
Config.MaxPlaces = 80         -- lieux publiés aux clients (les plus chargés)
Config.KeepDays = 60          -- les événements de plus de 60 jours ne comptent plus
Config.Talk = { reach = 22.0, cooldown = 30 * 60, pedRange = 14.0 } -- un passant parle quand on passe (1 fois / 30 min / lieu)
Config.Echo = { night = { from = 22, to = 5 }, range = 45.0, alpha = 110, max = 3, seconds = 40 }
Config.Radio = { every = 25 * 60, minEvents = 5 }   -- Radio Los Santos rappelle un lieu toutes les 25 min

-- Phrases des passants et de la radio, par genre d'événement. %s = nombre, %d = lieu (rue)
Config.Lines = {
    crime = { 'C\'est ici que ça a pété, l\'autre jour. Les flics sont arrivés trop tard.', 'Ce coin-là… je passe vite. Il s\'y est passé des trucs.',
        'Ici, y a eu un casse. Les gens en parlent encore.' },
    arrest = { 'Ils l\'ont coffré juste là, devant tout le monde.', 'Je l\'ai vu : menotté contre ce mur, là.' },
    wedding = { 'Ils se sont mariés ici. Toute la rue était en fête.', 'Y a eu un mariage juste là. Ça change des sirènes.' },
    race = { 'Les courses finissent souvent par ici. Un soir, le gagnant a fait un dérapage mémorable.', 'Ici, on a vu une arrivée de course qu\'on n\'oubliera pas.' },
    heist = { 'Le braquage, c\'était là. Tout le quartier a tremblé.', 'Ici, ils ont vidé la caisse en trois minutes. On en parle encore.' },
    war = { 'La guerre de gang s\'est jouée ici. Il reste des traces.', 'Ce bout de rue a changé de mains dans le sang.' },
    plaque = { 'Y a une plaque, là. La ville se souvient.', 'Un lieu de mémoire. Lis la plaque.' },
    generic = { 'Ici, il s\'est passé plus de choses qu\'on ne croit.', 'Ce coin a une histoire. Demande aux anciens.' },
}
Config.RadioLines = {
    'Vous savez ce qui s\'est passé du côté de %s ? La ville, elle, s\'en souvient.',
    'Ce soir, pensée pour %s : certains coins de Los Santos ont plus de souvenirs que de lampadaires.',
    'Du côté de %s, les passants parlent encore de ce qui s\'y est passé. Lenny vous laisse deviner.',
}

-- Échos nocturnes : silhouettes et scénarios rejoués selon le genre dominant du lieu
Config.Echoes = {
    crime = { peds = { 'a_m_y_stbla_01', 'a_m_m_eastsa_01' }, scenario = 'WORLD_HUMAN_STAND_IMPATIENT', text = 'Un écho du passé : des silhouettes, un soir où ça a mal tourné.' },
    arrest = { peds = { 's_m_y_cop_01', 'a_m_y_stbla_02' }, scenario = 'WORLD_HUMAN_COP_IDLES', text = 'Un écho du passé : une arrestation, les gyrophares depuis longtemps éteints.' },
    wedding = { peds = { 'a_f_y_bevhills_01', 'a_m_y_business_01' }, scenario = 'WORLD_HUMAN_PARTYING', text = 'Un écho du passé : deux silhouettes qui dansent encore.' },
    race = { peds = { 'a_m_y_hipster_02', 'a_f_y_hipster_01' }, scenario = 'WORLD_HUMAN_CHEERING', text = 'Un écho du passé : la foule d\'une arrivée de course.' },
    heist = { peds = { 'g_m_y_lost_01', 'g_m_y_ballasout_01' }, scenario = 'WORLD_HUMAN_GUARD_STAND', text = 'Un écho du passé : les guetteurs d\'un braquage.' },
    war = { peds = { 'g_m_y_famca_01', 'g_m_y_mexgoon_01' }, scenario = 'WORLD_HUMAN_SMOKING', text = 'Un écho du passé : deux camps face à face.' },
    plaque = { peds = { 'a_m_o_genstreet_01' }, scenario = 'WORLD_HUMAN_MUSICIAN', text = 'Un écho du passé : un vieil homme joue pour ceux qui ne sont plus là.' },
    generic = { peds = { 'a_m_m_tramp_01' }, scenario = 'WORLD_HUMAN_BUM_STANDING', text = 'Un écho du passé.' },
}
