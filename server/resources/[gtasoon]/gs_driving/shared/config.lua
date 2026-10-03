-- [CONFIG] Auto-école. Coords à caler en jeu (F11 → Copier mes coordonnées).
Config = {}

-- true : un nouveau personnage n'a PAS le permis (Qbox le donne par défaut). Les anciens personnages qui ont déjà
-- un véhicule à leur nom gardent leur permis (ils ne repassent pas l'examen).
Config.RequireExam = true

Config.Desk = vec3(239.5, -1381.0, 33.7)       -- accueil de l'auto-école (code + inscription à la conduite)
Config.Range = 3.0
Config.Job = 'drivingschool'                   -- moniteurs (gs_jobs) : peuvent délivrer le permis après un examen RP

Config.Theory = { price = 500, questions = 10, toPass = 8, cooldown = 300 }
Config.Practical = {
    price = 1000, model = 'blista', plate = 'AUTOECOL',
    spawn = vec4(232.4, -1393.6, 30.5, 140.0),
    speedLimit = 22.3,          -- m/s (≈ 80 km/h) ; au-delà de +10 %, faute
    maxFaults = 3,
    damageFault = 60.0,         -- perte de carrosserie (sur 1000) comptée comme une faute
    checkpointRadius = 10.0,
    snapMax = 20.0,             -- chaque point est recollé à la route la plus proche (en jeu), au plus à 20 m de sa position
    timeout = 600,
    route = {
        vec3(214.0, -1420.9, 29.3), vec3(76.6, -1535.5, 29.3), vec3(-100.2, -1370.4, 29.3),
        vec3(-47.3, -1122.5, 26.4), vec3(158.1, -1046.2, 29.2), vec3(273.4, -1150.1, 29.3), vec3(236.9, -1395.6, 30.4),
    },
}

-- Questions du code (options : la bonne réponse est `answer`, index à partir de 1). Tirées au hasard à chaque essai.
Config.Questions = {
    { q = 'Vitesse maximale en ville (hors panneaux) ?', options = { '50 km/h', '70 km/h', '90 km/h' }, answer = 1 },
    { q = 'Un feu orange fixe signifie :', options = { 'Accélérer', 'S\'arrêter sauf si c\'est dangereux', 'Priorité à droite' }, answer = 2 },
    { q = 'Une sirène de secours approche :', options = { 'Je continue', 'Je me range pour la laisser passer', 'Je la suis' }, answer = 2 },
    { q = 'Sur autoroute, la vitesse maximale est :', options = { '110 km/h', '130 km/h', '160 km/h' }, answer = 2 },
    { q = 'Taux d\'alcool maximal autorisé (permis confirmé) :', options = { '0,5 g/L', '0,8 g/L', 'Aucune limite' }, answer = 1 },
    { q = 'Un stop impose :', options = { 'De ralentir', 'L\'arrêt complet', 'De klaxonner' }, answer = 2 },
    { q = 'À une intersection sans panneau :', options = { 'Priorité à droite', 'Priorité à gauche', 'Le plus rapide passe' }, answer = 1 },
    { q = 'La ceinture de sécurité est :', options = { 'Facultative en ville', 'Obligatoire pour tous', 'Pour le conducteur seulement' }, answer = 2 },
    { q = 'Téléphone au volant :', options = { 'Autorisé à l\'arrêt au feu', 'Interdit en main', 'Autorisé en SMS' }, answer = 2 },
    { q = 'Distance de sécurité sur voie rapide :', options = { '1 seconde', '2 secondes', 'Aucune' }, answer = 2 },
    { q = 'Un piéton s\'engage sur un passage piéton :', options = { 'Je klaxonne', 'Je le laisse passer', 'Je le contourne' }, answer = 2 },
    { q = 'La nuit, en ville éclairée, j\'allume :', options = { 'Les feux de croisement', 'Les pleins phares', 'Rien' }, answer = 1 },
    { q = 'Un policier vous fait signe de vous arrêter :', options = { 'Je m\'arrête en sécurité', 'Je fuis', 'Je l\'ignore' }, answer = 1 },
    { q = 'Dépasser par la droite sur une route à deux voies :', options = { 'Autorisé', 'Interdit sauf exceptions', 'Obligatoire' }, answer = 2 },
}
