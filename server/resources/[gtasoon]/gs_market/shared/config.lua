-- [CONFIG] Bourse de la ville. Chaque indice est relevé toutes les `SnapshotMinutes` et gardé `KeepHours`.
-- Les valeurs bougent avec l'activité des joueurs : achats / reventes (gs_economy), argent en circulation, biens immobiliers.
Config = {}

Config.SnapshotMinutes = 60
Config.KeepHours = 168          -- 7 jours d'historique (graphique)
Config.CacheSeconds = 60

Config.Indices = {
    { id = 'prices', label = 'Indice des prix', unit = 'pts', icon = '🛒' },
    { id = 'fuel', label = 'Carburant (jerrican)', unit = '$', icon = '⛽' },
    { id = 'metals', label = 'Métaux (cuivre, revente)', unit = '$', icon = '🔩' },
    { id = 'housing', label = 'Immobilier (prix moyen)', unit = '$', icon = '🏠' },
    { id = 'wealth', label = 'Richesse de la ville', unit = 'M$', icon = '💰' },
}
