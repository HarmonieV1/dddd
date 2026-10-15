-- [CONFIG] gs_cimetiere · V12.60 « Le cimetière se remplit » (proposition n° 119, demandée au backtest du 15/10).
-- Une mort RP validée par le staff (F11 → Joueurs → le joueur → « Mort RP : tombe », ou F11 → Monde et lieux → Cimetière)
-- pose une tombe avec son épitaphe au cimetière, publie un avis de décès (Weazel tout de suite, Gazette du dimanche),
-- et tout le monde peut y déposer des fleurs (Alt sur la tombe). Le personnage n'est JAMAIS supprimé par cette ressource.
Config = {}

-- Premier emplacement du carré des tombes (Hill Valley, Rockford Hills) : à caler en jeu (F11 → Monde et lieux → Déplacer un
-- point → gs_cimetiere). Les tombes suivantes s'alignent : `perRow` par rangée, `gap` m entre deux, `rowGap` m entre rangées.
Config.Origin = vec4(-1736.0, -214.0, 57.5, 140.0)
Config.Grid = { perRow = 6, gap = 2.6, rowGap = 3.4, max = 60 }

-- Pierre tombale : premier modèle présent dans le jeu ; fleurs et bougie déposées devant pendant `flowerHours`
Config.Stones = { 'prop_gravestones_06a', 'prop_gravestones_04a', 'prop_gravestones_01a', 'prop_gravestones_02a', 'prop_gravestones_03a' }
Config.Flowers = { 'prop_mem_reef_01', 'prop_mem_candle_04' }
Config.FlowerPrice = 25       -- liquide
Config.FlowerHours = 72
Config.FlowerCooldown = 600   -- un dépôt de fleurs par joueur et par tombe toutes les 10 min
Config.StaffLevel = 3         -- niveau gs_admin pour poser / retirer une tombe
Config.Max = { name = 40, epitaph = 90 }
Config.TextRange = 4.0        -- épitaphe lisible de près seulement (discret)
