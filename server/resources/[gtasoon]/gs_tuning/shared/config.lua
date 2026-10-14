-- [CONFIG] Personnalisation cosmétique (néons, plaque). Aucun effet sur les performances : pas de pay-to-win.
Config = {}

Config.Range = 5.0
Config.NeonPrice = 800
Config.PlatePrice = 2500
Config.PlateMin, Config.PlateMax = 2, 8

Config.Shops = { -- [À CALER] Los Santos Customs (mêmes points que le mécano)
    { label = 'LS Customs Burton', coords = vec3(-337.4, -136.9, 39.0) },
    { label = 'LS Customs Aéroport', coords = vec3(-1155.5, -2007.2, 13.2) },
    { label = 'Beeker\'s Paleto', coords = vec3(110.8, 6626.4, 31.8) },
}

Config.Neon = {
    { label = 'Rose Vice', rgb = { 255, 46, 136 } }, { label = 'Cyan', rgb = { 40, 224, 255 } }, { label = 'Violet', rgb = { 155, 107, 255 } },
    { label = 'Vert acide', rgb = { 57, 255, 154 } }, { label = 'Or sunset', rgb = { 255, 196, 0 } }, { label = 'Orange', rgb = { 255, 138, 61 } },
    { label = 'Rouge', rgb = { 255, 30, 60 } }, { label = 'Bleu électrique', rgb = { 20, 80, 255 } }, { label = 'Blanc', rgb = { 255, 255, 255 } },
}

-- V12.36 · Personnalisation par le mécano en service (client/mechanic.lua + server/mechanic.lua) : distances et limites.
Config.Mechanic = {
    range = 8.0,        -- le mécano doit être à moins de X m du véhicule
    ownerRange = 30.0,  -- le propriétaire doit être en ville et à moins de X m de son véhicule (c'est son accord)
    maxJson = 16000,    -- taille max (caractères) des réglages envoyés par le client
    maxBill = 60000,    -- V12.40 · facture automatique plafonnée
    -- V12.40 · Prix (facture automatique au client à la validation, recalculée par le serveur) : par clé ox_lib modifiée.
    prices = {
        perf = { -- niveau 0, 1, 2, 3, 4 (-1 = d'origine : gratuit)
            modEngine = { 2500, 5000, 9000, 15000 }, modBrakes = { 1500, 3000, 6000 }, modTransmission = { 2000, 4000, 8000 },
            modSuspension = { 1000, 2000, 3500, 5000 }, modArmor = { 2500, 5000, 8000, 12000, 16000 },
        },
        turbo = 12000,
        keys = { color1 = 1200, color2 = 900, pearlescentColor = 800, wheelColor = 500, paintType1 = 400, paintType2 = 300,
            customPrimaryColor = 1500, customSecondaryColor = 1000, modFrontWheels = 900, wheels = 200, windowTint = 400,
            modXenon = 700, xenonColor = 200, neonEnabled = 800, neonColor = 300, plateIndex = 300, tyreSmokeColor = 400,
            modSmokeEnabled = 600, interiorColor = 300, dashboardColor = 300, extras = 150, modLivery = 900, livery = 900 },
        mod = 600, -- toute autre pièce de carrosserie / intérieur (aileron, capot, sièges…)
    },
}

-- Préfixes réservés (services, locations, plaques staff / métiers) et mots interdits
Config.ReservedPrefixes = { 'LSPD', 'LSFD', 'EMS', 'GOV', 'STAFF', 'ADMIN', 'MOD', 'LOC', 'TAXI', 'POST', 'PROP', 'PDM', 'DYN8', 'TRUK', 'BUS', 'RTNRT' }
Config.BannedWords = { 'NAZI', 'HITLER', 'SS', 'KKK', 'FUCK', 'PUTE', 'SALOP', 'NIQUE', 'NTM', 'FDP', 'PD', 'ENCUL', 'MERDE', 'CONNARD', 'BITE', 'CUL' }
