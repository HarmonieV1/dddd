-- [CONFIG] V9 · Les cicatrices de la ville. La ville garde la trace de ce qui s'y passe :
--  - mémorial (bougies, ours, barrières) là où quelqu'un est tombé, quelques heures ;
--  - vitrine brisée (barrières, cônes) après un braquage de commerce, jusqu'à ce qu'un ouvrier de la ville la répare
--    (petit boulot ouvert à tous, payé par la mairie ; pas à l'auteur du braquage) ;
--  - fresque du gang vainqueur d'une guerre de territoire, jusqu'à la prochaine guerre dans ce quartier.
Config = {}
Config.Max = 50                        -- cicatrices visibles en même temps (les plus vieilles partent)
-- V12.59 (backtest 15/10 : « des bougies pour une boucherie de 10 kills, une tache de sang serait plus cohérente ») :
-- là où quelqu'un tombe, plus de bougies ni d'ours : des TRACES. Flaque de sang (une de plus à chaque nouvelle victime
-- au même endroit, 6 au plus) et douilles si c'était par balle. Elles disparaissent après `hours` (24 h au plus).
Config.Memorial = { hours = 4, merge = 20.0, perPlayer = 900, maxBlood = 6,
    shotProps = { 'w_pi_flaregun_shell', 'w_pi_flaregun_shell', 'w_pi_flaregun_shell' }, -- douilles (petit étui du jeu), seulement par balle
    -- V12.63 (backtest : « des objets en rapport avec l'événement ») : arme blanche → couteau au sol ; objet contondant → batte
    bladeProps = { 'w_me_knife_01' }, bluntProps = { 'w_me_bat' } }
Config.Glass = { crimes = { store_robbery = true, shop_robbery = true, jewelry = true, teller_robbery = true, bank = true, robbery = true, racket = true },
    merge = 25.0, pay = { 250, 450 }, duration = 15000, hours = 24, -- V12.59 : barrières de police, effacées au bout de 24 h même sans réparation
    delay = 600, -- V12.63 (backtest : « la réparation apparaît en plein braquage ») : vitrine brisée posée 10 min APRÈS le braquage
    props = { 'prop_mp_barrier_02b', 'prop_barrier_work05', 'prop_mp_cone_01', 'prop_mp_barrier_02b' } }
Config.Mural = { drawDistance = 25.0, hours = 24 } -- V12.59 : texte plus discret, effacé au bout de 24 h

-- V11 « Lieux de mémoire » : une plaque reste là où la ville a vécu un grand moment (30 jours). Automatique après un casse
-- de banque / bijouterie ou une cavale légendaire ; le staff (admin) en pose pour un mariage, un concert… : /plaque <texte>.
-- [E] Lire la plaque : un passant raconte. /plaqueretirer : la plus proche (5 m).
-- V12.59 : plaques AUTOMATIQUES (casse, cavale, lieu de mémoire) : 24 h, sans couronne ni bougie ; plaques du staff : 30 jours.
-- Texte plus discret : lu de près seulement (`textRange`).
Config.Plaques = { days = 30, autoHours = 24, textRange = 6.0, max = 15, merge = 40.0, staffLevel = 3, maxLen = 80, reach = 5.0,
    crimes = { bank = 'le casse de la banque', jewelry = 'le casse de la bijouterie' },
    props = { 'prop_mem_reef_01', 'prop_mem_candle_04' },
    -- V12.63 (backtest : « les lieux de mémoire posent des blips au lieu d'objets ») : plus d'icône flottante, des objets
    -- discrets selon ce qui s'est passé ([E] Lire la plaque de près). Modèle absent du jeu = ignoré.
    kindProps = {
        heist = { 'prop_mp_cone_01', 'prop_barrier_work05', 'prop_mp_cone_01' },      -- casse : cônes et barrière de police
        crime = { 'w_pi_flaregun_shell', 'w_pi_flaregun_shell' }, war = { 'w_pi_flaregun_shell', 'w_pi_flaregun_shell', 'w_pi_flaregun_shell' },
        arrest = { 'prop_mp_cone_01' }, race = { 'prop_rub_tyre_01', 'prop_rub_tyre_01' },
        wedding = { 'prop_mem_candle_04', 'prop_mem_candle_04' }, legend = { 'prop_mem_candle_04' },
    },
    kindBlood = { crime = true, war = true },                                        -- une tache de sang discrète en plus
    talk = { '« J\'y étais. On en parle encore au comptoir. »', '« Ma grand-mère dit que la ville a changé ce jour-là. »',
        '« Les touristes prennent des photos, maintenant. »', '« Y en a qui disent que c\'était arrangé… moi je dis rien. »',
        '« Je passe devant tous les matins. Ça fait quelque chose. »' } }
