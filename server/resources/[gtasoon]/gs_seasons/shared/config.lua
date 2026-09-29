-- [CONFIG] Saisons. Une saison = 8 semaines à partir de `start` (heure du serveur). Points de saison = XP gagnée (gs_quests).
-- Piste gratuite pour tous ; piste premium débloquée par le paquet Tebex « season_pass » (gs_store) : 100 % cosmétique.
-- Récompenses : cash (petites sommes, piste gratuite seulement), item, title (titre de saison), outfit (tenue gs_store).
Config = {}

Config.Weeks = 8
Config.PointsPerTier = 1000
Config.Seasons = {
    { id = 's1', label = 'Saison 1 · Sunset Boulevard', theme = 'Néons, coucher de soleil et premières légendes.', start = '2026-09-28' },
    { id = 's2', label = 'Saison 2 · Neige sur Vinewood', theme = 'Fêtes, froid et courses sur route mouillée.', start = '2026-11-23' },
}

-- tiers[n] = { free = récompense, premium = récompense }
Config.Tiers = {
    { free = { cash = 500 }, premium = { title = 'Pionnier de la saison' } },
    { free = { item = 'scratch_ticket', count = 2 }, premium = { outfit = 'season1_bomber' } },
    { free = { cash = 1000 }, premium = { item = 'scratch_ticket', count = 5 } },
    { free = { title = 'Habitué de la saison' }, premium = { title = 'Icône Sunset' } },
    { free = { item = 'scratch_ticket', count = 3 }, premium = { outfit = 'season1_neon' } },
    { free = { cash = 2000 }, premium = { title = 'Légende de la saison' } },
}

Config.HallSize = 3                -- palmarès : les 3 meilleurs de chaque saison
