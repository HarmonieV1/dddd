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
}

-- Préfixes réservés (services, locations, plaques staff / métiers) et mots interdits
Config.ReservedPrefixes = { 'LSPD', 'LSFD', 'EMS', 'GOV', 'STAFF', 'ADMIN', 'MOD', 'LOC', 'TAXI', 'POST', 'PROP', 'PDM', 'DYN8', 'TRUK', 'BUS', 'RTNRT' }
Config.BannedWords = { 'NAZI', 'HITLER', 'SS', 'KKK', 'FUCK', 'PUTE', 'SALOP', 'NIQUE', 'NTM', 'FDP', 'PD', 'ENCUL', 'MERDE', 'CONNARD', 'BITE', 'CUL' }
