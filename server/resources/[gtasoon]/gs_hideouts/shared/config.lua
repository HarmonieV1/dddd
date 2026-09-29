-- [CONFIG] Planques de départ (location à la semaine). Une seule par personnage. À l'échéance : plus d'accès, le coffre
-- est gardé (on reloue pour le récupérer). Tes futurs modèles de planques gratuites s'ajouteront ici (entrance + inside).
-- Intérieur : appartement bas de gamme du jeu (toujours chargé), un monde séparé (routing bucket) par locataire.
Config = {}

Config.Interior = vec4(266.1, -1007.6, -101.0, 0.0)   -- arrivée dans la chambre (porte de sortie)
Config.StashPoint = vec3(265.9, -999.4, -99.0)          -- coffre
Config.WardrobePoint = vec3(259.8, -1004.0, -99.0)      -- garde-robe (tenues illenium-appearance)
Config.Stash = { slots = 40, weight = 80000 }
Config.MaxWeeks = 4
Config.BucketBase = 5000

-- Coords à caler en jeu (F11 → Copier mes coordonnées).
Config.Sites = {
    pinkcage = { label = 'Motel Pink Cage (Vinewood)', price = 350, entrance = vec4(313.2, -198.1, 54.2, 160.0) },
    sandy = { label = 'Motor Motel (Sandy Shores)', price = 220, entrance = vec4(1142.3, 2664.1, 38.2, 90.0) },
    paleto = { label = 'Dream View Motel (Paleto Bay)', price = 250, entrance = vec4(-106.6, 6315.9, 31.5, 315.0) },
}
