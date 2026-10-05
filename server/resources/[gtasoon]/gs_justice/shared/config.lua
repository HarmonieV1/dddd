-- [CONFIG] Justice. Le tribunal siège à la mairie (le jeu n'a pas de palais de justice ouvert) : coords à caler.
Config = {}

Config.JudgeJob, Config.LawyerJob, Config.PoliceJob = 'judge', 'lawyer', 'police'
Config.Court = vec3(-540.3, -209.9, 38.2)
Config.CourtRadius = 30.0          -- prévenu, avocat et juge présents dans la salle pour un verdict
Config.MaxFine = 250000
Config.MaxJail = 120               -- minutes
Config.ConsentTimeout = 60         -- secondes pour que le client accepte l'accès de son avocat au casier
Config.Command = 'tribunal'

-- V10.1 · Mandat de perquisition : une planque trop fréquentée (planque de gang, chambre de motel louée) finit
-- signalée par les voisins ; la police demande un mandat, un juge en service décide (sinon le juge de permanence
-- l'accorde après quelques minutes), puis la police perquisitionne : le coffre s'ouvre pour elle.
Config.Warrant = {
    threshold = 6,        -- « allées et venues » avant le signalement des voisins
    decay = 20,           -- minutes pour qu'une visite soit oubliée
    suspectHours = 24,    -- le signalement tombe après 24 h sans nouvelle visite
    autoMinutes = 5,      -- sans juge en service : le juge de permanence accorde le mandat après 5 min
    valid = 60,           -- minutes de validité du mandat
    range = 15.0,         -- distance pour perquisitionner
}

-- V10.1 · Preuves recevables : la police et les avocats versent des pièces (photos développées, scellés analysés)
-- au dossier d'une affaire ouverte ; le juge les retient ou les écarte ; le verdict mentionne les pièces retenues.
Config.Pieces = { max = 12, photoItem = 'gs_photo' }

-- V11.2 · Les jurés de Los Santos : pour une affaire ouverte, le juge convoque 5 citoyens tirés au sort (ni partie, ni police,
-- ni juge, ni avocat en service). Ils reçoivent la convocation où qu'ils soient et votent en 3 min. Leur décision lie le juge
-- (coupable / relaxe), le juge fixe la peine. Indemnité pour chaque juré qui a voté. /jury : rouvrir sa convocation.
Config.Jury = { size = 5, min = 3, seconds = 180, fee = 100, cooldown = 2 * 3600, binding = true, command = 'jury' }
