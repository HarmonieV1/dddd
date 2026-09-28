-- [CONFIG] Panel staff. Complète le menu txAdmin (noclip, spectate, ban, véhicules : touche du menu txAdmin).
Config = {}

-- Niveaux (ACE, voir cfg/permissions.cfg). Un niveau inclut les précédents.
Config.Aces = { 'gs.admin.helper', 'gs.admin.mod', 'gs.admin.admin' }
Config.LevelNames = { 'Helper', 'Modérateur', 'Admin' }
Config.Key = 'F10'

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
