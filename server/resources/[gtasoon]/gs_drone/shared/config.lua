-- [CONFIG] gs_drone · V12.64 · Drone de repérage (proposition n° 231, demandé par le fondateur : « pour le côté légal aussi,
-- et le rendre accessible plus difficilement pour les gangs »).
--   · LÉGAL : la police en service sort le drone du service (F4 → Drone de surveillance, ou /drone). Longue portée, grosse
--     batterie, vision thermique, et [G] marque un suspect vu à l'écran : ses collègues en service le suivent sur la carte
--     pendant `Mark.seconds` s (position rafraîchie, jamais son nom).
--   · GANGS : « Drone de repérage » (objet) au marché noir, réservé aux gangs, cher et rare ; il ne vole qu'entre les mains d'un
--     membre confirmé (grade ≥ `minGrade`). Portée et batterie réduites, pas de thermique, et le radar de la police peut le
--     repérer (`radar` : chance d'un signalement « drone non identifié » dans une zone floue).
-- Le pilote reste sur place (tablette en main, vulnérable). Le drone est visible de tous et ABATTABLE : `hitPoints` balles
-- au but (vérifiées par le serveur) et il tombe ; un drone de gang abattu est perdu.
Config = {}

Config.Model = 'ch_prop_casino_drone_02a'
Config.Item = 'gs_drone'
Config.LegalJobs = { police = true }
Config.Command = 'drone'
Config.HitPoints = 2

Config.Types = {
    police = { label = 'Drone de surveillance LSPD', range = 260.0, battery = 240, speed = 13.0, thermal = true, mark = true, cooldown = 60 },
    gang = { label = 'Drone de repérage', range = 140.0, battery = 120, speed = 10.0, thermal = false, mark = false, cooldown = 300,
        minGrade = 1, radar = 0.35, radarRadius = 250.0 },
}
Config.Mark = { seconds = 60, refresh = 5, maxDistance = 220.0 } -- suspect marqué : suivi par les collègues, visible du drone (m)
Config.MaxHeight = 120.0  -- m au-dessus du sol
Config.Shooter = { radius = 200.0 } -- un tireur à plus de X m du drone ne peut pas le toucher (contrôle serveur)
