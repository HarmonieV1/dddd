-- [CONFIG] V9 · Les cicatrices de la ville. La ville garde la trace de ce qui s'y passe :
--  - mémorial (bougies, ours, barrières) là où quelqu'un est tombé, quelques heures ;
--  - vitrine brisée (barrières, cônes) après un braquage de commerce, jusqu'à ce qu'un ouvrier de la ville la répare
--    (petit boulot ouvert à tous, payé par la mairie ; pas à l'auteur du braquage) ;
--  - fresque du gang vainqueur d'une guerre de territoire, jusqu'à la prochaine guerre dans ce quartier.
Config = {}
Config.Max = 50                        -- cicatrices visibles en même temps (les plus vieilles partent)
Config.Memorial = { hours = 4, merge = 20.0, perPlayer = 900,
    props = { 'prop_mem_candle_04', 'prop_mem_candle_05', 'prop_mem_teddy_01', 'prop_mem_reef_01' } }
Config.Glass = { crimes = { store_robbery = true, jewelry = true, teller_robbery = true, bank = true, robbery = true, racket = true },
    merge = 25.0, pay = { 250, 450 }, duration = 15000, props = { 'prop_barrier_work05', 'prop_mp_cone_01', 'prop_mp_cone_01' } }
Config.Mural = { drawDistance = 60.0 }

-- V11 « Lieux de mémoire » : une plaque reste là où la ville a vécu un grand moment (30 jours). Automatique après un casse
-- de banque / bijouterie ou une cavale légendaire ; le staff (admin) en pose pour un mariage, un concert… : /plaque <texte>.
-- [E] Lire la plaque : un passant raconte. /plaqueretirer : la plus proche (5 m).
Config.Plaques = { days = 30, max = 15, merge = 40.0, staffLevel = 3, maxLen = 80, reach = 5.0,
    crimes = { bank = 'le casse de la banque', jewelry = 'le casse de la bijouterie' },
    props = { 'prop_mem_reef_01', 'prop_mem_candle_04' },
    talk = { '« J\'y étais. On en parle encore au comptoir. »', '« Ma grand-mère dit que la ville a changé ce jour-là. »',
        '« Les touristes prennent des photos, maintenant. »', '« Y en a qui disent que c\'était arrangé… moi je dis rien. »',
        '« Je passe devant tous les matins. Ça fait quelque chose. »' } }
