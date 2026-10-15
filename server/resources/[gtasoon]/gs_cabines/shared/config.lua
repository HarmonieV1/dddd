-- [CONFIG] gs_cabines · V12.60 « Cabines téléphoniques refaites » (proposition n° 128, demandée au backtest du 15/10).
-- Toutes les cabines et téléphones muraux DU JEU (Alt dessus) : appel anonyme à la police (arrive au central comme un
-- signalement, sans nom ni description du correspondant, zone floue autour de la cabine) ou tuyau à la rédaction Weazel
-- (journalistes en service, sinon gardé pour le prochain qui prend son service : /tuyaux).
-- Anonyme pour les joueurs ; le staff garde une trace (journal staff) en cas d'abus (canular, harcèlement).
Config = {}

Config.Models = { 'prop_phonebox_01a', 'prop_phonebox_01b', 'prop_phonebox_01c', 'prop_phonebox_02', 'prop_phonebox_03', 'prop_phonebox_04',
    'p_phonebox_01b_s', 'p_phonebox_02_s', 'prop_phone_ing', 'prop_phone_ing_02', 'prop_phone_ing_03' }
Config.Price = 1              -- pièce glissée dans la cabine (liquide)
Config.Cooldown = 300         -- un appel toutes les 5 min par joueur
Config.MaxLength = 140
Config.Reach = 4.0            -- distance max à la cabine (vérifiée par le serveur)
Config.Blur = 60.0            -- la police reçoit une zone de ce rayon autour de la cabine, pas la cabine exacte
Config.PoliceJob = 'police'
Config.PressJob = 'weazel'
Config.Tips = { keep = 10, hours = 6 } -- tuyaux gardés pour la rédaction quand aucun journaliste n'est en service
Config.CallTime = 6000        -- durée de l'appel (animation)
-- V12.61 · Appeler un NUMÉRO depuis la cabine (le correspondant voit « Numéro masqué ») : plus court délai entre deux appels
Config.NumberCooldown = 60
-- V12.61 · Écoute : la police (grade `grade` et plus, en service, sur mandat du juge en RP) met une cabine sur écoute pendant
-- `hours` heures. Chaque appel passé depuis elle arrive au central : heure, destinataire, message, et le genre de l'appelant.
Config.Tap = { grade = 2, hours = 2, max = 5 }
