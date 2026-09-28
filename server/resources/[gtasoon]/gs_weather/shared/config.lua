-- [CONFIG] Météo et heure. Remplace qbx_weathersync (ne pas installer les deux).
Config = {}

-- Profil de la journée : secondes RÉELLES par minute de jeu, selon l'heure.
-- GTA vanilla = 2 s partout (journée de 48 min). Ici : nuits un peu plus courtes, lever et
-- coucher de soleil allongés pour la DA néon / sunset. Doit couvrir 0 → 24 sans trou.
Config.DayProfile = {
    { from = 0,  to = 5,  spm = 1.0 },  -- nuit profonde
    { from = 5,  to = 7,  spm = 3.0 },  -- lever de soleil
    { from = 7,  to = 18, spm = 2.0 },  -- journée
    { from = 18, to = 21, spm = 4.0 },  -- golden hour + coucher de soleil (12 min réelles)
    { from = 21, to = 24, spm = 1.5 },  -- soirée
}
Config.StartTime = { hour = 17, minute = 30 } -- heure au démarrage du serveur

-- Météo normale : durée (minutes réelles) et enchaînements possibles (poids).
-- Pas de saut brutal : on passe par les états intermédiaires (nuages, éclaircies).
Config.WeatherMinutes = { 20, 40 }
Config.TransitionSeconds = 45.0
Config.StartWeather = 'CLEAR'
Config.Transitions = {
    EXTRASUNNY = { EXTRASUNNY = 2, CLEAR = 3, SMOG = 1 },
    CLEAR      = { CLEAR = 3, EXTRASUNNY = 2, CLOUDS = 2, SMOG = 1 },
    SMOG       = { CLEAR = 2, CLOUDS = 1 },
    CLOUDS     = { CLEAR = 2, OVERCAST = 2, CLOUDS = 1, FOGGY = 0.5 },
    OVERCAST   = { CLOUDS = 2, RAIN = 1.5, CLEARING = 1 },
    RAIN       = { CLEARING = 2, OVERCAST = 1, THUNDER = 0.5 },
    THUNDER    = { RAIN = 1, CLEARING = 2 },
    CLEARING   = { CLEAR = 3, CLOUDS = 1 },
    FOGGY      = { CLEAR = 2, CLOUDS = 1 },
}

-- Événements météo : tirés au sort à chaque changement de météo, annoncés en jeu + Discord.
-- Les autres ressources peuvent réagir (exports GetEvent, events gs_weather:server:event*).
-- hours = plage horaire EN JEU où l'événement peut démarrer.
Config.Events = {
    storm = {
        label = 'Tempête tropicale', weather = 'THUNDER', minutes = { 15, 25 }, chance = 0.04,
        wind = 12.0, blackoutChance = 0.35, icon = 'cloud-bolt',
        announce = 'Alerte orange : tempête tropicale sur Los Santos. Restez chez vous, rentrez les flamants roses.',
    },
    heatwave = {
        label = 'Canicule', weather = 'EXTRASUNNY', minutes = { 40, 60 }, chance = 0.05, hours = { 9, 16 },
        icon = 'temperature-high',
        announce = 'Canicule : 42°C à l\'ombre. Buvez de l\'eau, pas que du rhum.',
    },
    fog = {
        label = 'Brouillard épais', weather = 'FOGGY', minutes = { 10, 20 }, chance = 0.05, hours = { 4, 9 },
        icon = 'smog',
        announce = 'Brouillard épais sur la ville. Allumez vos phares, éteignez vos excès de vitesse.',
    },
}

Config.AnnouncePrefix = 'Radio Néon Météo'
