-- [CONFIG] gs_fightclub · Combats clandestins. Une adresse par jour (réel), ouverte la nuit (heure du jeu).
Config = {}

-- [À CALER] lieux discrets (entrepôts, hangars) : coords = centre du ring, npc = organisateur
Config.Rings = {
    { hint = 'un entrepôt désaffecté de Cypress Flats',  coords = vec3(857.5, -2128.0, 30.5),  npc = vec4(852.0, -2124.0, 30.5, 220.0) },
    { hint = 'les docks d\'Elysian Island, près des conteneurs', coords = vec3(-238.0, -2652.0, 6.0), npc = vec4(-232.0, -2648.0, 6.0, 140.0) },
    { hint = 'la gare de triage de La Mesa',             coords = vec3(512.0, -586.0, 24.8),   npc = vec4(518.0, -582.0, 24.8, 120.0) },
    { hint = 'un hangar abandonné de Sandy Shores',       coords = vec3(1735.0, 3292.0, 41.1),  npc = vec4(1741.0, 3296.0, 41.1, 130.0) },
    { hint = 'la scierie de Paleto Bay',                 coords = vec3(-570.0, 5332.0, 70.2),  npc = vec4(-565.0, 5336.0, 70.2, 160.0) },
    { hint = 'les hauteurs d\'El Burro, derrière la raffinerie', coords = vec3(1320.0, -1662.0, 51.2), npc = vec4(1326.0, -1658.0, 51.2, 90.0) },
}
Config.Night = { from = 21, to = 5 }      -- heure du jeu (gs_weather) ; sans gs_weather : toujours ouvert
Config.Model = 'g_m_y_lost_01'            -- l'organisateur
Config.Reveal = 18.0                      -- distance à laquelle on découvre le ring (pas de blip, pas d'adresse côté client)
Config.Radius = 9.0                       -- sortir du ring = forfait
Config.Stakes = { 500, 1000, 2500, 5000 } -- mises des combattants (liquide)
Config.Bet = { min = 100, max = 10000, window = 60, range = 25.0 } -- paris : fenêtre de 60 s, spectateurs à 25 m
Config.Cut = 0.10                         -- la maison prend 10 %
Config.KoHealth = 115                     -- santé (sur 200) en dessous de laquelle c'est K.-O.
Config.MaxDuration = 180                  -- secondes : au-delà, match nul (tout est rendu)
Config.RumorEvery = 30                    -- minutes : le bouche-à-oreille rappelle l'adresse
