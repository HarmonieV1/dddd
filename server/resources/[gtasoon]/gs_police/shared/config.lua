-- [CONFIG] Interventions police / EMS. Toutes les actions sont revérifiées par le serveur (métier en service,
-- distance, état de la cible, items). Coords à caler en jeu.
Config = {}

Config.Key = 'F4'
Config.PoliceJob = 'police'
Config.EmsJob = 'ambulance'
Config.Range = 3.0              -- distance max agent ↔ cible
Config.Tolerance = 2.0

-- Permis délivrés / retirés par la police (grade ≥ minGrade) depuis le contrôle d'identité. Sans permis d'arme :
-- pas d'arme de poing à Ammu-Nation (ox_inventory). Le permis de chasse s'achète aussi au pavillon de chasse.
Config.Licences = { minGrade = 2, kinds = { weapon = 'Port d\'arme', hunting = 'Permis de chasse' } }

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
