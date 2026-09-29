-- [CONFIG] Statistiques économiques. Les mouvements entre joueurs (virements, factures, remboursements) ne créent ni ne
-- détruisent d'argent : ils sont ignorés (motifs contenant un des mots ci-dessous).
Config = {}

Config.Ace = 'gs.admin.admin'
Config.NeutralReasons = { 'virement', 'facture', 'remboursement', 'transfer', 'caisse', 'société', 'society', 'retrait', 'dépôt', 'depot' }
Config.FlushSeconds = 60           -- écriture en base (cumul en mémoire entre deux)
Config.ReportHour = 6              -- rapport Discord de la veille, chaque jour à 6 h
Config.AlertNetPerDay = 2000000    -- alerte si plus de 2 M$ créés net dans la journée (exploit ? économie trop généreuse ?)
