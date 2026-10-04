-- [CONFIG] gs_stats · Récap / biographie et rétention.
Config = {}

Config.Flush = 60                 -- secondes entre deux écritures groupées en base
Config.TzOffset = 7200            -- décalage horaire (s) pour couper les journées (France été : +2 h)
Config.ShortSession = 15          -- minutes : en dessous, la première session compte comme « abandon »
Config.StaffLevel = 3             -- niveau staff (gs_admin) pour voir les statistiques de rétention
Config.Months = { 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre' }

-- Statistiques suivies (ordre d'affichage) : label, unité, poids pour le « titre » du mois
Config.Stats = {
    { id = 'minutes', label = 'Temps en ville', fmt = 'hours', weight = 1 / 60, title = 'Pilier de la ville' },
    { id = 'meters', label = 'Au volant', fmt = 'km', weight = 1 / 2000, title = 'Roi de la route' },
    { id = 'earned', label = 'Argent gagné', fmt = 'money', weight = 1 / 4000, title = 'Requin des affaires' },
    { id = 'crimes', label = 'Crimes signalés', fmt = 'n', weight = 1.5, title = 'Ennemi public' },
    { id = 'arrests', label = 'Arrestations faites', fmt = 'n', weight = 2, title = 'Incorruptible' },
    { id = 'jailed', label = 'Séjours à Bolingbroke', fmt = 'n', weight = 1, title = 'Habitué du parloir' },
    { id = 'fights', label = 'Combats gagnés', fmt = 'n', weight = 3, title = 'Poids lourd du ring' },
    { id = 'encounters', label = 'Rencontres de la route', fmt = 'n', weight = 2, title = 'Âme du bord de route' },
    { id = 'photos', label = 'Photos développées', fmt = 'n', weight = 0.5, title = 'Œil de Los Santos' },
    { id = 'deaths', label = 'Passages à Pillbox', fmt = 'n', weight = 0, title = nil },
}
