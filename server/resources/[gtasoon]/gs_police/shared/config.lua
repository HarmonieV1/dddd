-- [CONFIG] Interventions police / EMS. Toutes les actions sont revérifiées par le serveur (métier en service,
-- distance, état de la cible, items). Coords à caler en jeu.
Config = {}

Config.Key = 'F4'
Config.PoliceJob = 'police'
Config.PoliceJobs = { police = true, sheriff = true } -- V8 : le shérif du comté a le même menu F4
Config.EmsJob = 'ambulance'
Config.Range = 3.0              -- distance max agent ↔ cible
Config.Tolerance = 2.0

-- Permis délivrés / retirés par la police (grade ≥ minGrade) depuis le contrôle d'identité. Sans permis d'arme :
-- pas d'arme de poing à Ammu-Nation (ox_inventory). Le permis de chasse s'achète aussi au pavillon de chasse.
-- V11.5 : le permis de conduire se retire (infraction grave, motif obligatoire) et se rend aussi ici ; la carte suit.
Config.Licences = { minGrade = 2, kinds = { weapon = 'Port d\'arme', hunting = 'Permis de chasse', driver = 'Permis de conduire' } }

Config.CuffItem = 'handcuffs'   -- consommé ? non : il faut juste en avoir sur soi

-- Prison RP (peine décidée en jeu par un policier, grade ≥ minGrade)
Config.Jail = {
    minGrade = 1, maxMinutes = 60,
    cell = vec4(1691.6, 2565.4, 45.56, 180.0),       -- cour intérieure de Bolingbroke
    release = vec4(1846.3, 2585.9, 45.67, 270.0),
    radius = 60.0,
}

-- Objets de voirie (police) : max par agent, retirés à sa déconnexion
Config.Objects = {
    max = 10,
    list = {
        cone = { label = 'Cône', model = 'prop_roadcone02a' },
        barrier = { label = 'Barrière', model = 'prop_barrier_work05' },
        spikes = { label = 'Herse', model = 'p_ld_stinger_s', spikes = true },
    },
}

Config.Impound = { duration = 8000, range = 6.0 }

-- EMS
Config.Revive = { item = 'firstaid', duration = 8000 }
Config.Heal = { item = 'bandage', duration = 4000 }

-- Radar de vitesse (police en véhicule) : /radar
Config.Radar = { range = 60.0, unit = 3.6 } -- 3.6 = km/h

-- Base de données de la police (F4 → Dossiers) : recherche d'un citoyen par nom, mandats, rapports.
Config.Dossiers = { warrantGrade = 1, closeGrade = 2, reportDeleteGrade = 3, maxWarrantsPerOfficer = 5, reasonMax = 200, bodyMax = 1500 }

-- V8 · Prison vivante (Bolingbroke). Petits boulots = peine réduite + tickets de cantine ; la cantine et le trafiquant
-- se paient en tickets (échangeables entre détenus) ; évasion seulement à plusieurs, la nuit, avec des outils de fortune.
Config.Prison = {
    ticket = 'gs_canteen', tools = 'gs_prison_tools',
    jobs = {
        { label = 'Nettoyer la cour', coords = vec3(1705.0, 2550.0, 45.56), seconds = 20, reduce = 60, tickets = 2, scenario = 'WORLD_HUMAN_JANITOR' },
        { label = 'Laverie', coords = vec3(1678.0, 2575.0, 45.56), seconds = 25, reduce = 75, tickets = 3, scenario = 'PROP_HUMAN_BUM_BIN' },
        { label = 'Cuisine', coords = vec3(1690.0, 2590.0, 45.56), seconds = 30, reduce = 90, tickets = 3, scenario = 'PROP_HUMAN_BBQ' },
    },
    jobCooldown = 60,           -- s entre deux tâches (par détenu)
    minLeft = 60,               -- une peine ne descend jamais sous 1 min avec les boulots
    canteen = { coords = vec3(1660.0, 2560.0, 45.56), items = { { item = 'sandwich', price = 2 }, { item = 'water', price = 1 }, { item = 'gs_cigarettes', price = 4 } } },
    dealer = { coords = vec3(1645.0, 2585.0, 45.56), items = { { item = 'gs_prison_tools', price = 25, cigarettes = 2 }, { item = 'phone', price = 40, cigarettes = 3 } } },
    escape = { coords = vec3(1650.0, 2540.0, 45.56), out = vec4(1580.0, 2470.0, 45.6, 225.0), radius = 15.0, min = 2,
        seconds = 30, nightFrom = 21, nightTo = 6, cooldown = 1800 },
}

-- V8 · Garde à vue et interrogatoire (Mission Row, sous-sol). Le suspect a des droits (/droits) : demander un avocat,
-- garder le silence, passer aux aveux (peine réduite si incarcéré ensuite). Interrogatoire sans avocat malgré la demande
-- = vice de procédure noté au rapport. Points à caler en jeu (F11 → Points).
-- V12 · Témoin protégé : en garde à vue, dénoncer un gang (/droits) divise la peine par deux ; le gang apprend que
-- « quelqu'un a parlé » (sans le nom), la police protège le témoin `witnessDays` jours (lieu sûr). S'il meurt pendant
-- ce temps : alerte police, chaleur sur les membres du gang en ligne, rumeur.
Config.Custody = {
    maxMinutes = 30, radius = 30.0, confessDiscount = 0.3, lawyerJob = 'lawyer', lawyerRange = 8.0,
    snitchDiscount = 0.5, witnessDays = 7, witnessHeat = 60, safeHouse = vec3(-1150.0, -1520.0, 10.6),
    cell = vec4(459.9, -994.3, 24.91, 270.0),
    room = vec4(472.3, -994.9, 24.91, 90.0),
    release = vec4(434.1, -981.9, 30.71, 90.0),
    station = vec3(441.0, -981.9, 30.69), stationRange = 80.0,
}

-- V8 · Chien de la police (K9) : grade minimum, ce qu'il flaire (drogue, argent sale) dans un véhicule ou sur une personne
Config.K9 = {
    minGrade = 1, model = 'a_c_shepherd', range = 6.0,
    items = { 'weed_bag', 'coke_bag', 'meth_bag', 'weed_leaf', 'coca_leaf', 'black_money', 'gs_prison_tools' },
}
