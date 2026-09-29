-- Définition des jobs. [CONFIG] : tout se règle ici. Coords à caler en jeu (map vanilla).
--
-- whitelisted = true   → embauche par la direction (menu Direction)
-- whitelisted = false  → emploi public, rejoignable au Pôle Emploi
-- society     = true   → le job a une caisse (dépôts, factures, paie 'society')
-- salaryFrom  = 'state' (payé par la ville) | 'society' (payé par la caisse du job)
-- dutyAnywhere= true   → prise de service depuis le menu /job (sinon au point 'duty')
-- grades[n]   = { label, salary (par paie, en service), boss = true pour la direction }
-- points      = duty / boss / stash / armory / garage (listes, plusieurs points possibles) ; déplaçables en jeu :
--               menu staff F11 → « Points de métier » (sauvegardé en BDD, prioritaire sur ces coords)
-- outfits     = tenues de service au vestiaire (points.cloakroom) : { label, minGrade, male = {…}, female = {…} }
--               composants : [n° composant] = { drawable, texture } ; props : p0 chapeau, p1 lunettes (à caler en jeu)
-- armory      = équipement de service gratuit (en service) : { item, max, minGrade } ; on complète jusqu'à `max`
-- vehicles    = véhicules de service (minGrade), type = 'automobile' | 'bike' | 'heli' | 'boat'
-- billing     = factures / amendes (nécessite society = true)
-- vehicleActions = actions sur véhicule (effect = 'repair' | 'clean')
-- mission     = missions à étapes (pool dans locations.lua)

Jobs = {
    police = {
        label = 'LSPD', type = 'leo', whitelisted = true, society = true, salaryFrom = 'state',
        platePrefix = 'LSPD',
        blip = { sprite = 60, color = 29, label = 'Commissariat de Mission Row' },
        billing = { label = 'Amende', max = 25000 },
        grades = {
            [0] = { label = 'Cadet', salary = 350 },
            [1] = { label = 'Officier', salary = 450 },
            [2] = { label = 'Sergent', salary = 550 },
            [3] = { label = 'Lieutenant', salary = 650 },
            [4] = { label = 'Capitaine', salary = 800, boss = true },
        },
        points = {
            duty = { vec3(441.0, -981.9, 30.69) },
            boss = { vec3(447.9, -973.3, 30.69) },
            stash = {
                { label = 'Coffre du commissariat', coords = vec3(452.3, -980.0, 30.69), slots = 80, weight = 300000, minGrade = 1 },
                { label = 'Saisies', coords = vec3(474.8, -994.5, 26.27), slots = 100, weight = 500000, minGrade = 0 },
            },
            armory = { vec3(451.7, -984.2, 30.69) },
            cloakroom = { vec3(461.5, -998.4, 30.69) },
            garage = {
                { coords = vec3(458.9, -1017.1, 28.2), spawn = vec4(446.1, -1025.4, 28.6, 5.0) },
            },
        },
        vehicles = {
            { model = 'police', label = 'Cruiser', minGrade = 0 },
            { model = 'police2', label = 'Buffalo', minGrade = 1 },
            { model = 'police3', label = 'Interceptor', minGrade = 2 },
            { model = 'policeb', label = 'Moto', minGrade = 2, type = 'bike' },
            { model = 'fbi', label = 'Banalisée', minGrade = 3 },
        },
        outfits = {
            { label = 'Cadet', minGrade = 0,
              male = { [3] = { 30, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } },
              female = { [3] = { 44, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } } },
            { label = 'Patrouille (casquette)', minGrade = 1,
              male = { [3] = { 30, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 }, p0 = { 46, 0 } },
              female = { [3] = { 44, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 }, p0 = { 45, 0 } } },
            { label = 'Officier supérieur (veste)', minGrade = 3,
              male = { [3] = { 31, 0 }, [4] = { 35, 0 }, [6] = { 10, 0 }, [8] = { 58, 0 }, [11] = { 32, 0 } },
              female = { [3] = { 44, 0 }, [4] = { 34, 0 }, [6] = { 29, 0 }, [8] = { 35, 0 }, [11] = { 25, 0 } } },
        },
        armory = {
            { item = 'radio', max = 1 }, { item = 'handcuffs', max = 2 }, { item = 'WEAPON_FLASHLIGHT', max = 1 },
            { item = 'WEAPON_NIGHTSTICK', max = 1 }, { item = 'WEAPON_STUNGUN', max = 1 }, { item = 'armour', max = 1 },
            { item = 'bandage', max = 5 }, { item = 'binoculars', max = 1 }, { item = 'empty_evidence_bag', max = 10 },
            { item = 'WEAPON_PISTOL', max = 1, minGrade = 1 }, { item = 'ammo-9', max = 60, minGrade = 1 },
            { item = 'WEAPON_CARBINERIFLE', max = 1, minGrade = 3 }, { item = 'ammo-rifle', max = 90, minGrade = 3 },
        },
    },

    ambulance = {
        label = 'EMS', type = 'ems', whitelisted = true, society = true, salaryFrom = 'state',
        platePrefix = 'EMS',
        blip = { sprite = 61, color = 2, label = 'Hôpital Pillbox' },
        billing = { label = 'Soins', max = 5000 },
        grades = {
            [0] = { label = 'Stagiaire', salary = 350 },
            [1] = { label = 'Ambulancier', salary = 450 },
            [2] = { label = 'Infirmier', salary = 550 },
            [3] = { label = 'Médecin', salary = 650 },
            [4] = { label = 'Chef de service', salary = 750, boss = true },
        },
        points = {
            duty = { vec3(298.5, -584.5, 43.26) },
            boss = { vec3(303.0, -581.0, 43.28) },
            stash = {
                { label = 'Pharmacie', coords = vec3(301.0, -588.0, 43.28), slots = 60, weight = 150000, minGrade = 0 },
            },
            armory = { vec3(306.4, -601.5, 43.28) },
            cloakroom = { vec3(300.3, -597.7, 43.28) },
            garage = {
                { coords = vec3(294.5, -574.0, 43.18), spawn = vec4(290.0, -570.0, 43.2, 70.0) },
            },
        },
        vehicles = {
            { model = 'ambulance', label = 'Ambulance', minGrade = 0 },
            { model = 'lguard', label = 'Intervention rapide', minGrade = 2 },
        },
        outfits = {
            { label = 'Tenue EMS', minGrade = 0,
              male = { [3] = { 85, 0 }, [4] = { 96, 0 }, [6] = { 25, 0 }, [8] = { 129, 0 }, [11] = { 250, 0 } },
              female = { [3] = { 109, 0 }, [4] = { 99, 0 }, [6] = { 25, 0 }, [8] = { 159, 0 }, [11] = { 258, 0 } } },
            { label = 'Médecin (blouse)', minGrade = 3,
              male = { [3] = { 88, 0 }, [4] = { 96, 0 }, [6] = { 10, 0 }, [8] = { 31, 0 }, [11] = { 250, 1 } },
              female = { [3] = { 101, 0 }, [4] = { 99, 0 }, [6] = { 29, 0 }, [8] = { 38, 0 }, [11] = { 258, 1 } } },
        },
        armory = {
            { item = 'radio', max = 1 }, { item = 'bandage', max = 20 }, { item = 'firstaid', max = 10 },
            { item = 'painkillers', max = 10 }, { item = 'ifaks', max = 5 }, { item = 'WEAPON_FLASHLIGHT', max = 1 },
        },
    },

    mechanic = {
        label = 'Mécano LS Customs', type = 'mechanic', whitelisted = true, society = true, salaryFrom = 'society',
        platePrefix = 'MECA',
        blip = { sprite = 446, color = 47, label = 'LS Customs' },
        billing = { label = 'Facture garage', max = 15000 },
        grades = {
            [0] = { label = 'Apprenti', salary = 250 },
            [1] = { label = 'Mécanicien', salary = 350 },
            [2] = { label = "Chef d'atelier", salary = 450 },
            [3] = { label = 'Patron', salary = 550, boss = true },
        },
        points = {
            duty = { vec3(736.0, -1080.0, 22.2) },
            boss = { vec3(740.0, -1076.0, 22.2) },
            stash = {
                { label = 'Atelier', coords = vec3(738.5, -1085.0, 22.2), slots = 60, weight = 200000, minGrade = 0 },
            },
            armory = { vec3(733.4, -1088.6, 22.2) },
            cloakroom = { vec3(736.6, -1072.4, 22.2) },
            garage = {
                { coords = vec3(718.0, -1088.0, 22.3), spawn = vec4(706.0, -1080.0, 22.4, 90.0) },
            },
        },
        vehicles = {
            { model = 'towtruck', label = 'Dépanneuse', minGrade = 0 },
            { model = 'flatbed', label = 'Plateau', minGrade = 1 },
        },
        outfits = {
            { label = 'Bleu de travail', minGrade = 0,
              male = { [3] = { 0, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 66, 0 } },
              female = { [3] = { 14, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 60, 0 } } },
        },
        armory = {
            { item = 'radio', max = 1 }, { item = 'repairkit', max = 5 }, { item = 'cleaningkit', max = 5 },
            { item = 'jerry_can', max = 2 }, { item = 'WEAPON_WRENCH', max = 1 },
            { item = 'advancedrepairkit', max = 2, minGrade = 1 },
        },
        vehicleActions = {
            repair = { label = 'Réparer', effect = 'repair', item = 'repairkit', itemLabel = 'Kit de réparation',
                duration = 10000, icon = 'fa-solid fa-wrench', anim = { scenario = 'PROP_HUMAN_BUM_BIN' } },
            clean = { label = 'Nettoyer', effect = 'clean', duration = 5000, icon = 'fa-solid fa-soap',
                anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' } },
        },
    },

    cardealer = {
        label = 'Concession PDM', type = 'cardealer', whitelisted = true, society = true, salaryFrom = 'society',
        platePrefix = 'PDM',
        blip = { sprite = 326, color = 3, label = 'Concession Premium Deluxe' },
        billing = { label = 'Vente / reprise véhicule', max = 500000 },
        grades = {
            [0] = { label = 'Vendeur stagiaire', salary = 200 },
            [1] = { label = 'Vendeur', salary = 300 },
            [2] = { label = 'Chef des ventes', salary = 400 },
            [3] = { label = 'Directeur', salary = 500, boss = true },
        },
        points = {
            duty = { vec3(-31.6, -1106.4, 26.42) },
            boss = { vec3(-32.7, -1114.2, 26.42) },
            stash = {
                { label = 'Bureau', coords = vec3(-27.9, -1103.8, 26.42), slots = 30, weight = 50000, minGrade = 0 },
            },
            cloakroom = { vec3(-30.4, -1111.0, 26.42) },
            garage = {
                { coords = vec3(-18.4, -1113.9, 26.67), spawn = vec4(-15.8, -1105.5, 26.67, 160.0) },
            },
        },
        vehicles = { { model = 'baller', label = 'Véhicule d\'essai', minGrade = 0 } },
        outfits = {
            { label = 'Costume', minGrade = 0,
              male = { [3] = { 4, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 }, [8] = { 31, 0 }, [11] = { 28, 0 } },
              female = { [3] = { 5, 0 }, [4] = { 6, 0 }, [6] = { 29, 0 }, [8] = { 38, 0 }, [11] = { 25, 0 } } },
        },
    },

    -- Agent immobilier : crée les biens à vendre / louer avec /createproperty (qbx_properties, nom de job imposé : realestate)
    realestate = {
        label = 'Agence immobilière Dynasty 8', type = 'realestate', whitelisted = true, society = true, salaryFrom = 'society',
        dutyAnywhere = true, -- le bureau Dynasty 8 du jeu n'a pas d'intérieur : service partout, points devant la vitrine
        platePrefix = 'DYN8',
        blip = { sprite = 374, color = 2, label = 'Dynasty 8 (immobilier)' },
        billing = { label = 'Frais d\'agence', max = 100000 },
        grades = {
            [0] = { label = 'Agent stagiaire', salary = 200 },
            [1] = { label = 'Agent immobilier', salary = 300 },
            [2] = { label = 'Directeur d\'agence', salary = 450, boss = true },
        },
        points = { -- [À CALER] trottoir devant l'agence Dynasty 8 (Rockford Hills)
            duty = { vec3(-716.4, 261.2, 84.1) },
            boss = { vec3(-714.0, 264.5, 84.1) },
            stash = { { label = 'Dossiers', coords = vec3(-712.5, 262.0, 84.1), slots = 20, weight = 20000, minGrade = 0 } },
            garage = { { coords = vec3(-706.0, 273.0, 83.1), spawn = vec4(-700.0, 277.0, 83.1, 300.0) } },
        },
        vehicles = { { model = 'tailgater', label = 'Voiture de l\'agence', minGrade = 0 } },
    },

    trucker = {
        label = 'Routier', whitelisted = false, dutyAnywhere = true, salaryFrom = 'state',
        description = 'Des kilomètres de bitume et une cabine qui sent le café.',
        icon = 'truck', platePrefix = 'TRUK',
        blip = { sprite = 477, color = 21, label = 'Dépôt poids lourds' },
        grades = { [0] = { label = 'Chauffeur routier', salary = 0 } },
        points = {
            garage = { { coords = vec3(1191.0, -3253.0, 7.1), spawn = vec4(1180.0, -3240.0, 6.0, 90.0) } },
        },
        vehicles = { { model = 'pounder', label = 'Porteur', minGrade = 0 } },
        mission = {
            pool = 'depots', stops = 2, stepDuration = 6000,
            stepLabels = { 'Charger la marchandise', 'Décharger la marchandise' },
            payPerStop = { 150, 250 }, perKm = 180, completionBonus = 150,
        },
    },

    bus = {
        label = 'Chauffeur de bus', whitelisted = false, dutyAnywhere = true, salaryFrom = 'state',
        description = 'Terminus, tout le monde descend. Oui, toi aussi.',
        icon = 'bus', platePrefix = 'BUS',
        blip = { sprite = 513, color = 38, label = 'Dépôt de bus' },
        grades = { [0] = { label = 'Chauffeur', salary = 0 } },
        points = {
            garage = { { coords = vec3(453.2, -602.3, 28.6), spawn = vec4(462.0, -605.0, 28.5, 214.0) } },
        },
        vehicles = { { model = 'bus', label = 'Bus', minGrade = 0 } },
        mission = {
            pool = 'busstops', stops = 5, stepDuration = 5000, stepLabel = 'Arrêt : montée / descente des passagers',
            payPerStop = { 70, 110 }, perKm = 40, completionBonus = 120,
        },
    },

    taxi = {
        label = 'Taxi', whitelisted = false, dutyAnywhere = true, salaryFrom = 'state',
        description = 'Le client est roi, même quand il salit la banquette.',
        icon = 'taxi', platePrefix = 'TAXI',
        blip = { sprite = 198, color = 5, label = 'Downtown Cab Co.' },
        grades = { [0] = { label = 'Chauffeur', salary = 0 } },
        points = {
            garage = { { coords = vec3(903.0, -170.0, 74.1), spawn = vec4(916.0, -170.5, 74.4, 120.0) } },
        },
        vehicles = { { model = 'taxi', label = 'Taxi', minGrade = 0 } },
        mission = {
            pool = 'city', stops = 2, stepDuration = 2500,
            stepLabels = { 'Prendre le client', 'Déposer le client' },
            payPerStop = { 0, 0 }, perKm = 140, completionBonus = 60,
        },
    },

    delivery = {
        label = 'Livreur Post OP', whitelisted = false, dutyAnywhere = true, salaryFrom = 'state',
        description = 'Colis déposés, pas balancés par-dessus le portail.',
        icon = 'box', platePrefix = 'POST',
        blip = { sprite = 478, color = 31, label = 'Dépôt Post OP' },
        grades = { [0] = { label = 'Livreur', salary = 0 } },
        points = {
            garage = { { coords = vec3(-424.0, -2789.8, 6.0), spawn = vec4(-440.0, -2795.0, 6.0, 45.0) } },
        },
        vehicles = { { model = 'boxville2', label = 'Fourgon', minGrade = 0 } },
        mission = {
            pool = 'shops', stops = 3, stepDuration = 3000, stepLabel = 'Livrer le colis',
            payPerStop = { 180, 260 }, perKm = 0, completionBonus = 100,
        },
    },

    garbage = {
        label = 'Éboueur', whitelisted = false, dutyAnywhere = true, salaryFrom = 'state',
        description = 'Le métier le plus respecté de Los Santos. Si, si.',
        icon = 'trash', platePrefix = 'PROP',
        blip = { sprite = 318, color = 25, label = 'Dépôt de la voirie' },
        grades = { [0] = { label = 'Éboueur', salary = 0 } },
        points = {
            garage = { { coords = vec3(-321.7, -1545.8, 31.0), spawn = vec4(-328.0, -1523.0, 27.5, 270.0) } },
        },
        vehicles = { { model = 'trash', label = 'Benne', minGrade = 0 } },
        mission = {
            pool = 'shops', stops = 4, stepDuration = 4000, stepLabel = 'Vider les poubelles',
            payPerStop = { 120, 180 }, perKm = 0, completionBonus = 80,
        },
    },
}

-- Normalisation (ne pas modifier)
for name, def in pairs(Jobs) do
    def.name = name
    def.points = def.points or {}
end
