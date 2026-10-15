-- [CONFIG] gs_lives · V12.60 « Lives » (demandé au backtest du 15/10, inspiré du panneau LIVES d'un autre serveur) : le staff
-- ouvre une liste des joueurs connectés et regarde l'écran d'un ou plusieurs d'entre eux dans des fenêtres déplaçables,
-- redimensionnables et fermables, pendant qu'il continue de jouer. Une image toutes les `every` ms (pas une vidéo : c'est
-- léger pour le serveur). Il faut la ressource officielle screenshot-basic (docs/PHOTOS.md) ; sans elle, le menu le dit.
-- Chaque visionnage est écrit dans le journal staff (qui regarde qui, quand).
Config = {}
Config.Level = 2            -- niveau gs_admin minimum (modérateur), en mode staff
Config.MaxWindows = 4       -- fenêtres ouvertes en même temps par membre du staff
Config.Every = 1500         -- ms entre deux images d'une fenêtre
Config.Quality = 0.45       -- qualité JPEG (0.1 à 0.9) : plus bas = plus léger
Config.Command = 'lives'

-- V12.62 · Replay staff (proposition n° 137) : tant qu'un ticket est ouvert, les dernières images de l'écran de son auteur
-- (et du joueur nommé : « /report 12 il me fonce dessus ») sont gardées EN MÉMOIRE seulement, effacées à la fermeture.
-- 20 images × 1,5 s = 30 s. `max` : joueurs suivis en même temps (charge réseau).
Config.Replay = { enabled = true, frames = 20, every = 1500, quality = 0.35, max = 4 }
