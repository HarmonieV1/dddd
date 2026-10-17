-- [CONFIG] Banque. Les virements entre joueurs restent dans le téléphone (app Banque).
Config = {}

Config.Range = 3.5                -- distance joueur ↔ distributeur / guichet
Config.HistorySize = 15
Config.MinAmount = 1

-- Plafond de retrait par personnage et par jour (heure du serveur) ; les guichets ont un plafond plus haut.
Config.Atm = { dailyWithdraw = 15000, perOperation = 5000 }
Config.Counter = { dailyWithdraw = 250000, perOperation = 100000 }

-- Props de distributeurs du jeu (ox_target les détecte partout, sans liste de coordonnées)
Config.AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

-- Guichets (agences) : coords à caler en jeu si le marqueur flotte.
Config.Counters = {
    { label = 'Fleeca Legion Square', coords = vec3(149.4, -1040.5, 29.4) },
    { label = 'Fleeca Hawick', coords = vec3(314.2, -278.6, 54.2) },
    { label = 'Fleeca Burton', coords = vec3(-351.5, -49.5, 49.0) },
    { label = 'Fleeca Rockford Plaza', coords = vec3(-1212.9, -330.8, 37.8) },
    { label = 'Fleeca Chumash', coords = vec3(-2962.6, 482.6, 15.7) },
    { label = 'Fleeca Route 68', coords = vec3(-1305.4, -706.2, 25.3) },
    { label = 'Fleeca Sandy Shores', coords = vec3(1175.1, 2706.6, 38.1) },
    { label = 'Pacific Standard', coords = vec3(247.0, 222.0, 106.3) },
    { label = 'Blaine County Savings', coords = vec3(-112.2, 6469.3, 31.6) },
}

-- V12.64 · Piratage de distributeur (proposition n° 227, demandé par le fondateur « via un objet créé + animation ») :
-- le « Boîtier de piratage » (marché noir) se branche sur le lecteur de carte d'un distributeur (ox_target, [Alt]), puis
-- mini-jeu sur la tablette (touches au bon moment). Réussi : le distributeur crache des billets (argent sale) pendant
-- `drain` ms. Raté : l'alarme sonne. La caméra du distributeur peut filmer le visage (preuve vidéo pour la police, sans
-- masque). Un distributeur piraté reste surveillé `atmCooldown` s ; un même joueur attend `playerCooldown` s.
Config.Hack = {
    item = 'gs_atm_hacker',
    dirtyItem = 'black_money',       -- butin en argent sale (si l'objet n'existe pas : liquide)
    reward = { 450, 950 },
    nightBonus = 1.25, night = { from = 22, to = 5 }, -- la nuit : moins de monde, meilleur butin, moins d'alarme
    install = 7000,                  -- ms : brancher le boîtier (animation)
    drain = 15000,                   -- ms : retrait forcé (billets qui sortent)
    skill = { 'easy', 'medium', 'medium', 'hard' }, keys = { 'w', 'a', 's', 'd' },
    atmCooldown = 2700, playerCooldown = 600,
    breakChance = 0.35,              -- le boîtier grille après un piratage réussi
    failBreak = 0.6,                 -- … ou raté
    alarm = { day = 0.55, night = 0.25 }, -- alarme silencieuse après un piratage réussi (raté = toujours)
    camera = 0.7,                    -- la caméra du distributeur filme (preuve vidéo, visage décrit sans masque)
    cameraLabel = 'Caméra du distributeur',
    crime = 'atm_hack',
}
