-- [CONFIG] gs_lives · V12.60 « Lives » (demandé au backtest du 15/10, inspiré du panneau LIVES d'un autre serveur) : le staff
-- ouvre une liste des joueurs connectés et regarde l'écran d'un ou plusieurs d'entre eux dans des fenêtres déplaçables,
-- redimensionnables et fermables, pendant qu'il continue de jouer. Une image toutes les `every` ms (pas une vidéo : c'est
-- léger pour le serveur). Il faut la ressource officielle screenshot-basic (docs/PHOTOS.md) ; sans elle, le menu le dit.
-- Chaque visionnage est écrit dans le journal staff (qui regarde qui, quand).
Config = {}
Config.Level = 2            -- niveau gs_admin minimum (modérateur), en mode staff
Config.MaxWindows = 4       -- fenêtres ouvertes en même temps par membre du staff
Config.Every = 400          -- ms minimum entre deux images d'un joueur regardé (V12.63 : 1 s ; V12.64 : flux continu ≈ 2,5 images/s)
Config.Quality = 0.55       -- qualité de compression (0.1 à 0.9) : plus bas = plus léger (V12.64 : image réduite, donc 0,55)
-- V12.64 · fluidité (backtest : « ça marche mais ça rame vraiment ») : image réduite CHEZ LE JOUEUR avant l'envoi (largeur en
-- pixels, 0 = pleine taille) et compressée en WebP (repli JPEG automatique) : 4 à 6 fois plus légère qu'une capture 1080p.
Config.MaxWidth = 960
Config.Encoding = 'webp'    -- 'webp' (plus léger) ou 'jpg'
Config.Lease = 3000         -- ms : la capture continue tant qu'une fenêtre (F11 ou appli) a redemandé une image depuis moins de 3 s
Config.Command = 'lives'

-- V12.62 · Replay staff (proposition n° 137) : tant qu'un ticket est ouvert, les dernières images de l'écran de son auteur
-- (et du joueur nommé : « /report 12 il me fonce dessus ») sont gardées EN MÉMOIRE seulement, effacées à la fermeture.
-- 20 images × 1,5 s = 30 s. `max` : joueurs suivis en même temps (charge réseau).
Config.Replay = { enabled = true, frames = 20, every = 1500, quality = 0.35, max = 4 }
