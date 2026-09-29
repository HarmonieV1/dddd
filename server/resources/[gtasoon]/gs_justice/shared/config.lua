-- [CONFIG] Justice. Le tribunal siège à la mairie (le jeu n'a pas de palais de justice ouvert) : coords à caler.
Config = {}

Config.JudgeJob, Config.LawyerJob, Config.PoliceJob = 'judge', 'lawyer', 'police'
Config.Court = vec3(-545.1, -204.3, 38.2)
Config.CourtRadius = 30.0          -- prévenu, avocat et juge présents dans la salle pour un verdict
Config.MaxFine = 250000
Config.MaxJail = 120               -- minutes
Config.ConsentTimeout = 60         -- secondes pour que le client accepte l'accès de son avocat au casier
Config.Command = 'tribunal'
