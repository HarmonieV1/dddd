-- [CONFIG] Courses de rue. Coords des points de passage à caler en jeu (F11 → Copier mes coordonnées) : chaque point est
-- validé à `checkpointRadius` m ; ajouter / retirer des points librement (le premier = ligne de départ, le dernier = arrivée).
Config = {}

Config.StartRadius = 12.0         -- distance à la ligne de départ pour lancer / rejoindre
Config.CheckpointRadius = 14.0
Config.Tolerance = 4.0
Config.MaxSpeed = 95.0            -- m/s crédibles entre deux points (~340 km/h)
Config.JoinWindow = 45            -- secondes pour rejoindre une course à mise
Config.Countdown = 5              -- secondes de compte à rebours (véhicules figés côté client)
Config.MaxDuration = 900          -- une course est abandonnée au bout de 15 min
Config.SoloCooldown = 30          -- secondes entre deux chronos solo
Config.MaxPlayers = 8
Config.Entry = 500                -- mise d'une course à plusieurs (liquide), 10 % de la cagnotte part en frais (pas d'argent gratuit)
Config.PotKeep = 0.9
Config.Shares = { [1] = { 1.0 }, [2] = { 0.7, 0.3 }, [3] = { 0.6, 0.3, 0.1 } } -- selon le nombre de partants (≥ 3 : la 3e ligne)
Config.PoliceChance = 0.3         -- chance qu'une course à plusieurs soit signalée (crime « street_race »)
Config.Blip = { sprite = 315, color = 5 }

Config.Circuits = {
    sprint = { label = 'Sprint centre-ville', points = {
        vec3(229.4, -793.3, 30.6), vec3(298.0, -584.0, 43.2), vec3(-46.0, -284.0, 45.7), vec3(-555.0, -190.0, 38.2),
        vec3(-1392.0, -585.0, 30.2), vec3(-1037.0, -2730.0, 20.2) } },
    boucle = { label = 'Boucle des plages', points = {
        vec3(-1604.0, -1049.0, 13.0), vec3(-1222.9, -906.9, 12.3), vec3(-1392.0, -585.0, 30.2), vec3(-1487.6, -379.1, 40.2),
        vec3(-1222.9, -906.9, 12.3), vec3(-1604.0, -1049.0, 13.0) } },
    montagne = { label = 'Descente de Vinewood', points = {
        vec3(373.9, 328.4, 103.6), vec3(1135.0, -472.0, 66.5), vec3(1163.4, -323.8, 69.2), vec3(298.0, -584.0, 43.2), vec3(123.0, -1296.0, 29.3) } },
}
