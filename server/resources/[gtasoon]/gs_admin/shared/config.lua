-- [CONFIG] Panel staff. Complète le menu txAdmin (noclip, spectate, ban, véhicules : touche du menu txAdmin).
Config = {}

-- Niveaux (ACE, voir cfg/permissions.cfg). Un niveau inclut les précédents.
Config.Aces = { 'gs.admin.helper', 'gs.admin.mod', 'gs.admin.admin', 'gs.admin.founder' }
Config.LevelNames = { 'Helper', 'Modérateur', 'Admin', 'Fondateur' }
Config.Key = 'F10'        -- panel complet
Config.QuickKey = 'F11'   -- menu staff rapide (flèches + Entrée), pouvoirs actifs seulement en mode staff

-- Pouvoirs du menu rapide : niveau minimum. Tous exigent le mode staff (/staff ou 1re ligne du menu).
Config.Powers = {
    names = 1,       -- noms + ID au-dessus des joueurs
    noclip = 2,      -- vol libre
    invisible = 2,
    godmode = 2,
    animal = 2,      -- se transformer (Config.Animals)
    tpm = 2,         -- téléportation au marqueur
}

Config.Animals = {
    { model = 'a_c_chop', label = 'Chien (rottweiler)' }, { model = 'a_c_husky', label = 'Husky' },
    { model = 'a_c_retriever', label = 'Retriever' }, { model = 'a_c_shepherd', label = 'Berger' },
    { model = 'a_c_cat_01', label = 'Chat' }, { model = 'a_c_coyote', label = 'Coyote' },
    { model = 'a_c_mtlion', label = 'Puma' }, { model = 'a_c_deer', label = 'Cerf' },
    { model = 'a_c_boar', label = 'Sanglier' }, { model = 'a_c_pig', label = 'Cochon' },
    { model = 'a_c_cow', label = 'Vache' }, { model = 'a_c_chimp', label = 'Chimpanzé' },
    { model = 'a_c_rabbit_01', label = 'Lapin' }, { model = 'a_c_rat', label = 'Rat' },
}

Config.Vehicle = { maxDeleteDistance = 10.0 }

Config.Report = { cooldown = 120000, maxLength = 250 }

-- Jail admin (hors RP) : cour de la prison de Bolingbroke. Coords à caler en jeu.
Config.Jail = {
    coords = vec3(1642.0, 2570.0, 45.6),
    release = vec3(1850.0, 2585.0, 45.7),
    radius = 45.0,
    maxMinutes = 240,
}

Config.Give = { maxMoney = 100000, maxItems = 100 }

-- Transparence (prompt maître) : sanctions publiées sur un salon public (convar gs_webhook_sanctions).
Config.PublicSanctions = true
Config.PublicShowName = true   -- nom du joueur sanctionné visible ; le staff reste anonyme

Config.LogHistory = 150
