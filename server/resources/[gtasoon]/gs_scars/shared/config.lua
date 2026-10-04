-- [CONFIG] V9 · Les cicatrices de la ville. La ville garde la trace de ce qui s'y passe :
--  - mémorial (bougies, ours, barrières) là où quelqu'un est tombé, quelques heures ;
--  - vitrine brisée (barrières, cônes) après un braquage de commerce, jusqu'à ce qu'un ouvrier de la ville la répare
--    (petit boulot ouvert à tous, payé par la mairie ; pas à l'auteur du braquage) ;
--  - fresque du gang vainqueur d'une guerre de territoire, jusqu'à la prochaine guerre dans ce quartier.
Config = {}
Config.Max = 40                        -- cicatrices visibles en même temps (les plus vieilles partent)
Config.Memorial = { hours = 4, merge = 20.0, perPlayer = 900,
    props = { 'prop_mem_candle_04', 'prop_mem_candle_05', 'prop_mem_teddy_01', 'prop_mem_reef_01' } }
Config.Glass = { crimes = { store_robbery = true, jewelry = true, teller_robbery = true, bank = true, robbery = true },
    merge = 25.0, pay = { 250, 450 }, duration = 15000, props = { 'prop_barrier_work05', 'prop_mp_cone_01', 'prop_mp_cone_01' } }
Config.Mural = { drawDistance = 60.0 }
