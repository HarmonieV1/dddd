-- [CONFIG] Casino : roue de la fortune et tickets à gratter. Tous les tirages se font sur le serveur.
-- Pas de vente d'argent réel ici : on joue avec l'argent du jeu, et la boutique Tebex n'y touche jamais.
Config = {}

-- Roue : 1 tour gratuit par personnage et par jour (remise à zéro à minuit, heure du serveur).
-- Props du jeu (DLC casino) posés en local ; coords de la roue d'origine du casino (à caler en jeu si besoin).
Config.Wheel = {
    coords = vec3(1111.05, 229.85, -49.13),   -- centre de la roue
    base = vec3(1111.05, 229.85, -50.64),     -- socle
    heading = 0.0,
    stand = vec3(1109.6, 228.6, -49.64),      -- où le joueur se tient ([E])
    range = 3.0,
    spinMs = 6500,
    -- 20 cases (18° chacune), dans l'ordre de la roue. weight = poids du tirage (plus haut = plus fréquent).
    segments = {
        { label = '2 500 $', cash = 2500, weight = 8 },
        { label = 'Ticket à gratter', item = 'scratch_ticket', count = 1, weight = 12 },
        { label = '500 XP', xp = 500, weight = 8 },
        { label = '5 000 $', cash = 5000, weight = 4 },
        { label = 'Kit de réparation', item = 'repairkit', count = 1, weight = 8 },
        { label = '1 000 $', cash = 1000, weight = 12 },
        { label = '3 tickets à gratter', item = 'scratch_ticket', count = 3, weight = 4 },
        { label = '250 XP', xp = 250, weight = 12 },
        { label = '10 000 $', cash = 10000, weight = 2 },
        { label = 'Kit de réparation avancé', item = 'advancedrepairkit', count = 1, weight = 3 },
        { label = '1 500 $', cash = 1500, weight = 10 },
        { label = '1 000 XP', xp = 1000, weight = 3 },
        { label = '750 $', cash = 750, weight = 14 },
        { label = 'Ticket à gratter', item = 'scratch_ticket', count = 1, weight = 12 },
        { label = '3 000 $', cash = 3000, weight = 6 },
        { label = '5 Bières', item = 'beer', count = 5, weight = 8 },
        { label = '2 000 $', cash = 2000, weight = 8 },
        { label = '750 XP', xp = 750, weight = 5 },
        { label = '25 000 $ (jackpot)', cash = 25000, weight = 1 },
        { label = '1 000 $', cash = 1000, weight = 12 },
    },
}

-- Ticket à gratter : acheté en supérette (gs_economy) ou donné par les défis du jour (gs_quests).
-- Gain moyen < prix (≈ 70 %) : pas une machine à sous rentable, mais de beaux coups de temps en temps.
Config.Scratch = {
    perDay = 10,          -- tickets grattés max par personnage et par jour (anti-farm)
    scratchMs = 4000,
    prizes = {            -- chance = sur 1000 tirages
        { cash = 0, chance = 620 },
        { cash = 50, chance = 180 },
        { cash = 100, chance = 110 },
        { cash = 250, chance = 55 },
        { cash = 500, chance = 25 },
        { cash = 2000, chance = 8 },
        { cash = 10000, chance = 2 },
    },
}
