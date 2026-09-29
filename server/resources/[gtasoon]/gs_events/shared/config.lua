-- [CONFIG] Événements. Dates au format MM-JJ (heure du serveur) ; from > to = à cheval sur le nouvel an.
-- xp = multiplicateur d'XP (gs_quests) ; wheel = tours de roue gratuits en plus par jour (gs_casino).
Config = {}

Config.Calendar = {
    { id = 'summer', label = 'Été à Los Santos', from = '06-21', to = '09-22', xp = 1.10, wheel = 0, desc = 'Plages pleines, +10 % d\'XP.' },
    { id = 'halloween', label = 'Nuits d\'Halloween', from = '10-24', to = '11-01', xp = 1.25, wheel = 1, desc = '+25 % d\'XP et un tour de roue en plus par jour.' },
    { id = 'xmas', label = 'Fêtes de fin d\'année', from = '12-20', to = '01-02', xp = 1.25, wheel = 1, desc = '+25 % d\'XP et un tour de roue en plus par jour.' },
    { id = 'newyear', label = 'Anniversaire du serveur', from = '03-01', to = '03-07', xp = 1.50, wheel = 2, desc = '+50 % d\'XP et deux tours de roue en plus par jour.' },
}

-- Événements lancés par le staff (/gsevent start <id> <minutes>) : mêmes effets pendant la durée choisie.
Config.Manual = {
    double_xp = { label = 'Soirée double XP', xp = 2.0, wheel = 0, desc = 'XP doublée pendant l\'événement !' },
    lucky = { label = 'Soirée chanceuse', xp = 1.25, wheel = 2, desc = 'Deux tours de roue en plus et +25 % d\'XP.' },
}
Config.MaxManualMinutes = 360
Config.ManageAce = 'gs.events.manage'
