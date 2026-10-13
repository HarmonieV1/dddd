-- Réglages globaux de gs_jobs. [CONFIG] règle tout ici, pas dans le code.
Config = {}

Config.Debug = false               -- affiche les zones ox_target

-- Contrats
Config.MaxJobs = 3                 -- contrats max par personnage (le chômage ne compte pas)
Config.UnemployedJob = 'unemployed'
Config.OfferTimeout = 60           -- secondes pour accepter une offre d'embauche

-- Paie
Config.PayrollMinutes = 15
-- Direction : salaires réglables (entreprises payées par leur caisse) entre min et max fois le salaire de base ; primes
-- Carnet de commandes : /depanneur (mécano), /taxi (chauffeur) ; les employés en service voient les demandes (/commandes)
Config.Orders = { expire = 1800, jobs = { mechanic = 'mécano', taxi = 'taxi' } }
-- Blanchiment (menu Direction des entreprises privées) : argent sale → caisse de l'entreprise, avec commission,
-- délai de traitement, plafond = min(cap, ratio × chiffre d'affaires légal du jour), risque de contrôle fiscal.
Config.Launder = { fee = 0.30, cap = 30000, revenueRatio = 1.5, delay = 1800, auditBase = 0.04, auditMax = 0.35, dirtyItem = 'black_money' }
Config.Salary = { min = 0.5, max = 2.0, maxBonus = 5000 }
Config.UnemployedAllowance = 50    -- allocation versée aux sans-emploi à chaque paie (0 = désactivé)
Config.AntiAfk = true              -- pas de paie si le joueur n'a pas bougé de 2 m depuis la dernière paie

-- Distances (mètres)
Config.ZoneRadius = 1.5            -- rayon des zones ox_target
Config.ServerTolerance = 4.0       -- marge serveur ajoutée aux contrôles (latence, désync)
Config.PlayerActionRange = 4.0     -- embauche / facture : distance max entre les deux joueurs

Config.Billing = {
    issuerShare = 0.10,            -- part reversée à l'émetteur, le reste va à la caisse du job
    maxUnpaidPerPlayer = 20,
    reasonMaxLength = 80,
}

Config.Garage = {
    clearRadius = 3.0,             -- sortie refusée si un véhicule est déjà sur la place
    storeRadius = 25.0,            -- distance max du véhicule pour le ranger
}

-- V12.37 · Interactions aux points de métier (PNJ, zone ox_target, touche [E])
Config.InteractLock = 1000         -- ms : verrou anti-double-clic côté client (une seule action de point par seconde)
Config.DutyDebounce = 1500         -- ms : une 2e demande de prise / fin de service dans ce délai est ignorée (double déclenchement)
Config.PedDistance = 2.0           -- m : le PNJ d'un point se tient à cette distance du point et porte seul l'interaction ox_target

-- V12.37 · Équipement de service : prêté par l'armurerie, repris à la fin du service / changement de métier / déconnexion
Config.Armory = {
    restoreDelay = 5000,           -- ms après la connexion avant de reprendre l'équipement non rendu (l'inventaire se charge après le perso)
}

Config.Missions = {
    checkpointRadius = 6.0,
    vehicleRadius = 40.0,          -- le véhicule de service doit être à moins de X m de l'étape
    depositRadius = 8.0,           -- V12.39 · objet porté (sac) : jeté à moins de X m du véhicule de service
    minStepDistance = 250.0,       -- distance min entre deux étapes
    maxSpeed = 75.0,               -- m/s crédibles entre deux étapes (~270 km/h), au-delà = TP suspect
    cooldown = 20,                 -- secondes entre deux missions
}

Config.JobCenter = {
    coords = vec3(-265.0, -963.6, 31.22),
    blip = { sprite = 407, color = 27, scale = 0.8, label = 'Pôle Emploi & services (papiers)' },
}
