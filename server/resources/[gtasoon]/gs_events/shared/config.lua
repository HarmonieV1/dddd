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

-- V9 · Rendez-vous fixes : chaque semaine, mêmes jours, mêmes heures (heure du serveur). Rappel 30 min avant
-- (en jeu + salon #annonces via gs_discord). day : 1 = dimanche, 2 = lundi … 7 = samedi. /rdv affiche le programme.
Config.Weekly = {
    { id = 'wed_jobs', day = 4, from = '21:00', to = '23:00', label = 'Mercredi des métiers', xp = 1.25, wheel = 0,
        desc = '+25 % d\'XP : la ville recrute, les patrons cherchent du monde.' },
    { id = 'fri_races', day = 6, from = '21:00', to = '23:30', label = 'Vendredi des courses', xp = 1.15, wheel = 0,
        desc = 'Courses de rue et circuits : retrouvez-vous aux points de départ.' },
    { id = 'sat_fight', day = 7, from = '22:00', to = '23:59', label = 'Nuit des combats', xp = 1.10, wheel = 1,
        desc = 'Le ring clandestin est ouvert toute la soirée (son adresse circule dans les rumeurs).' },
    { id = 'sun_roadtrip', day = 1, from = '17:00', to = '19:00', label = 'Dimanche road trip', xp = 1.15, wheel = 0,
        desc = 'Balade organisée sur les routes du comté : rencontres de la route plus fréquentes.' },
}
Config.Days = { 'Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi' }
Config.Remind = 30 -- minutes
