-- [CONFIG] gs_cctv · Caméras de surveillance. Positions [À CALER] (déplaçables en jeu : F11 → Déplacer un point).
-- Une caméra relève les véhicules qui passent dans son champ (rayon) ; le serveur décide, le client ne déclare rien.
-- V11.5 : le boîtier s'accroche tout seul au mur ou au poteau le plus proche (rayon Mount.reach), à hauteur Mount.height,
-- et regarde vers la rue. `heading` facultatif par caméra = direction imposée (sinon : celle du mur trouvé).
Config = {}

Config.Mount = { reach = 7.0, height = 3.2, minHeight = 2.6, maxHeight = 5.0 }

Config.Sample = 4             -- secondes entre deux relevés
Config.Radius = 32.0          -- portée d'une caméra
Config.Dedupe = 90            -- secondes : un même véhicule n'est relevé qu'une fois par caméra pendant ce délai
Config.Keep = 80              -- passages gardés par caméra (les plus récents)
Config.MaxAge = 120           -- minutes : au-delà, le passage est effacé
Config.PoliceJob = 'police'
Config.Terminals = {          -- ordinateurs où la police consulte les enregistrements
    vec3(447.0, -985.2, 30.69),   -- Mission Row
    vec3(1855.6, 3687.6, 34.27),  -- Sandy Shores (shérif)
    vec3(-449.9, 6014.0, 31.72),  -- Paleto Bay (shérif)
}
Config.TerminalRange = 2.5
Config.Blind = { item = 'spraycan', minutes = 120, time = 5000, range = 3.0 } -- aveugler à la bombe de peinture
Config.Prop = 'prop_cctv_cam_01a'
Config.Trace = { delay = 5, maxAge = 90, keep = 30 } -- V12 : opérations de gang remontées après 5 min, visibles 90 min
Config.Cameras = {
    { label = 'Legion Square', coords = vec3(195.0, -935.0, 34.0) },
    { label = 'Mission Row (commissariat)', coords = vec3(410.0, -970.0, 33.0) },
    { label = 'Pacific Standard (banque)', coords = vec3(235.0, 200.0, 109.0) },
    { label = 'Vinewood Boulevard', coords = vec3(300.0, 180.0, 108.0) },
    { label = 'Alta Street', coords = vec3(-260.0, -900.0, 35.0) },
    { label = 'Little Seoul', coords = vec3(-700.0, -920.0, 23.0) },
    { label = 'Vespucci Boulevard', coords = vec3(-1180.0, -880.0, 18.0) },
    { label = 'Del Perro Freeway (bretelle)', coords = vec3(-1450.0, -530.0, 38.0) },
    { label = 'Rockford Hills (Portola)', coords = vec3(-700.0, -230.0, 40.0) },
    { label = 'Strawberry (Forum Drive)', coords = vec3(30.0, -1350.0, 32.0) },
    { label = 'Grove Street (entrée)', coords = vec3(-60.0, -1720.0, 32.0) },
    { label = 'Davis (Carson Avenue)', coords = vec3(160.0, -1620.0, 32.0) },
    { label = 'Mirror Park', coords = vec3(1140.0, -470.0, 69.0) },
    { label = 'La Mesa (Popular Street)', coords = vec3(800.0, -1000.0, 29.0) },
    { label = 'Port de Los Santos', coords = vec3(830.0, -2950.0, 9.0) },
    { label = 'Aéroport (entrée)', coords = vec3(-1035.0, -2730.0, 22.0) },
    { label = 'Route 68 (Harmony)', coords = vec3(600.0, 2700.0, 44.0) },
    { label = 'Sandy Shores (Alhambra)', coords = vec3(1960.0, 3740.0, 35.0) },
    { label = 'Paleto Boulevard', coords = vec3(-140.0, 6300.0, 34.0) },
    { label = 'Péage de la Great Ocean', coords = vec3(-2600.0, 3000.0, 18.0) },
}
