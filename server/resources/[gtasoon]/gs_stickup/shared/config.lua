-- [CONFIG] Braquage solo de PNJ. Annexe pour quand on est seul : les gros coups restent en duo / en groupe (gs_heists).
-- La peur (0 → 100) monte tant que l'arme est pointée ; parler l'accélère : chuchoter peu, parler normal, CRIER beaucoup
-- (portée de voix pma-voice, touche ²). Arme baissée trop longtemps : la victime s'enfuit et appelle la police.
Config = {}

Config.PoliceJob = 'police'
Config.DirtyItem = 'black_money'
Config.AimRange = 8.0          -- m entre toi et la victime
Config.LostAimTime = 2500      -- ms sans viser avant que la victime s'enfuie
Config.AutoStartMs = 900       -- caisse / guichet : le braquage démarre seul après avoir visé le caissier ce temps-là
-- Caisse / guichet : l'argent sale tombe en petits sacs plastique à ramasser sur le comptoir (pas directement en poche)
Config.Bags = { model = 'prop_poly_bag_01', min = 1, max = 3, label = 'Sac de billets' }

-- Peur gagnée par seconde : arme pointée + voix (index de portée pma-voice : 1 chuchoter, 2 normal, 3 crier)
Config.Fear = { aim = 6, voice = { [1] = 3, [2] = 8, [3] = 18 }, decay = 12 }

-- Types de victimes. minTime = durée minimale réelle vérifiée par le serveur (anti-triche) ; fearScale ralentit la peur.
Config.Kinds = {
    street = { label = 'Racket', crime = 'mugging', reward = { 25, 140 }, dirty = false, minTime = 4, fearScale = 1.0,
        itemChance = 0.2, items = { 'phone', 'gs_cigarettes', 'lighter', 'water' }, playerCooldown = 90 },
    register = { label = 'Caisse', crime = 'store_robbery', reward = { 280, 650 }, dirty = true, minTime = 8, fearScale = 0.6,
        zoneCooldown = 1200, playerCooldown = 300, radius = 4.0, alarmChance = 0.5 },
    teller = { label = 'Guichet', crime = 'teller_robbery', reward = { 550, 1100 }, dirty = true, minTime = 12, fearScale = 0.45,
        zoneCooldown = 2700, playerCooldown = 600, radius = 5.0, alarmChance = 0.8 },
}

-- Anti-farm : plafonds par joueur (heure glissante / jour serveur)
Config.MaxPerHour = 6
Config.MaxPerDay = 5000        -- $ gagnés par jour et par personnage via cette annexe

-- Guichetiers des agences Fleeca (PNJ créés près du comptoir). Coords à caler en jeu (F11 → Copier mes coordonnées).
Config.TellerModel = 'u_m_m_bankman'
Config.Tellers = {
    { id = 'fleeca_legion', label = 'Fleeca Legion Square', coords = vec4(149.5, -1042.1, 29.37, 340.0) },
    { id = 'fleeca_hawick', label = 'Fleeca Hawick', coords = vec4(313.8, -280.5, 54.16, 340.0) },
    { id = 'fleeca_burton', label = 'Fleeca Burton', coords = vec4(-351.3, -51.3, 49.04, 340.0) },
    { id = 'fleeca_rockford', label = 'Fleeca Rockford Plaza', coords = vec4(-1211.9, -332.0, 37.78, 30.0) },
    { id = 'fleeca_chumash', label = 'Fleeca Chumash', coords = vec4(-2961.1, 482.9, 15.7, 90.0) },
    { id = 'fleeca_route68', label = 'Fleeca Route 68', coords = vec4(1175.0, 2708.2, 38.09, 180.0) },
}
