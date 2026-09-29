-- [CONFIG] Petits boulots (app « Boulots » du téléphone) : sans embauche, avec son propre véhicule.
-- Récupérer quelque chose en A, le déposer en B. Le serveur tire les points, vérifie la présence et un temps de trajet crédible.
Config = {}

Config.OffersPerRefresh = 3
Config.RefreshSeconds = 300       -- nouvelles offres toutes les 5 min (par joueur)
Config.Cooldown = 60              -- secondes entre deux boulots
Config.Radius = 6.0               -- rayon de validation d'un point
Config.MinDistance = 700.0        -- A → B au moins
Config.MaxSpeed = 70.0            -- m/s crédibles (~250 km/h) entre A et B, au-delà = refusé
Config.Timeout = 900              -- 15 min pour finir, sinon annulé

Config.Types = {
    courier = { label = 'Livraison express', icon = '📦', legal = true, perKm = 110, base = 80,
        pickup = 'Récupérer le colis', drop = 'Livrer le colis', desc = 'Un client pressé, un colis fragile. Pas de questions.' },
    smuggler = { label = 'Passeur', icon = '🕶️', legal = false, perKm = 260, base = 200, dirty = true, reportChance = 0.35,
        pickup = 'Récupérer la marchandise', drop = 'Déposer la marchandise', desc = 'Bien payé. Évite les flics. Paiement en liquide sale.' },
}

-- Points de rendez-vous (dehors, accessibles en voiture). À caler / compléter en jeu.
Config.Points = {
    vec3(-1037.0, -2730.0, 20.2), vec3(229.4, -793.3, 30.6), vec3(-555.0, -190.0, 38.2), vec3(298.0, -584.0, 43.2),
    vec3(-1392.0, -585.0, 30.2), vec3(-1604.0, -1049.0, 13.0), vec3(1135.0, -472.0, 66.5), vec3(123.0, -1296.0, 29.3),
    vec3(-48.5, -1757.5, 29.4), vec3(1204.7, -3116.9, 5.5), vec3(716.0, -965.0, 30.4), vec3(-1154.9, -1558.9, 4.4),
    vec3(373.9, 328.4, 103.6), vec3(-3040.5, 585.9, 7.9), vec3(1961.5, 3740.7, 32.3), vec3(-2968.2, 390.9, 15.0),
}
