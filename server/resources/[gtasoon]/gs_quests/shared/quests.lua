-- [CONFIG] Personnages récurrents et quêtes de départ. Personnages originaux (aucun perso Rockstar ni marque réelle) :
-- l'hommage est dans l'ambiance (le parrain à l'ancienne, la cabine téléphonique, les paquets cachés), pas dans les noms.
-- Coords à caler en jeu : menu staff F11 → « Copier mes coordonnées ». model = nil → pas de PNJ (ex : cabine).
--
-- Quête : id, title, giver (personnage), gender ('male' | 'female' | nil = tous), requires (quête terminée avant),
--         minLevel, night (20 h → 5 h), intro (texte du personnage), outro, give (items au départ),
--         vehicle (prêté au départ, repris à la fin), cleanup (items quête retirés en fin / abandon),
--         steps (objectifs dans l'ordre), reward { xp, cash, items }, badge (Config.Badges, débloqué à la fin)
-- Étapes : talk { character } · goto { coords, radius } · drive { coords, radius, limit? } (dans un véhicule)
--          deliver { coords | character, item, count } · collect { points, item? } (un ramassage par point)
--          limit = secondes pour finir l'étape (sinon quête échouée, à relancer)

Characters = {
    guide = { name = 'Max « le Guide » Delgado', model = 'a_m_y_business_02', coords = vec4(-536.9, -218.4, 37.65, 30.0) },
    sal   = { name = 'Big Sal Moretti', model = 'a_m_m_malibu_01', coords = vec4(-1181.9, -889.4, 13.9, 305.0) },
    lenny = { name = 'Lenny « Doigts Collants »', model = 'a_m_m_eastsa_01', coords = vec4(89.4, -1959.2, 20.7, 320.0) },
    dock  = { name = 'Le Contact du port', model = 's_m_m_highsec_01', coords = vec4(1208.9, -3099.6, 5.9, 90.0) },
    rosa  = { name = 'Mama Rosa Valdez', model = 'a_f_m_bevhills_01', coords = vec4(-712.3, -155.1, 37.4, 120.0) },
    kiki  = { name = 'Kiki Starlight', model = 'a_f_y_vinewood_02', coords = vec4(298.4, 180.2, 104.3, 160.0) },
    nova  = { name = 'DJ Nova', model = 'a_m_y_vinewood_01', coords = vec4(-1640.2, -1081.3, 13.1, 50.0) },
    voice = { name = 'La Voix (cabine téléphonique)', model = nil, coords = vec4(196.6, -937.1, 30.7, 0.0) },
}

Quests = {
    -- Tout le monde ----------------------------------------------------------------------------------------------
    {
        id = 'welcome', title = 'Bienvenue à Los Santos', giver = 'guide',
        intro = 'Nouveau en ville ? Moi c\'est Max. Ici, on commence par un boulot et des roues. Suis le guide, je te paie le café.',
        outro = 'Tu vois, c\'est pas sorcier. Reviens me voir de temps en temps : je connais du monde.',
        steps = {
            { type = 'goto', label = 'Passe au Pôle Emploi', coords = vec3(-265.0, -963.6, 31.22), radius = 6.0 },
            { type = 'goto', label = 'Repère la location de véhicules de la mairie', coords = vec3(-515.6, -262.5, 35.5), radius = 6.0 },
            { type = 'talk', label = 'Retourne voir Max', character = 'guide' },
        },
        reward = { xp = 150, cash = 250 },
    },
    {
        id = 'voice', title = 'La Voix au bout du fil', giver = 'voice', requires = 'welcome', minLevel = 3,
        intro = '« … Tu ne me connais pas. Moi, je te connais. Cinq colis traînent en ville, ramène-les avant les autres. Je rappellerai. »',
        outro = '« Pas mal. Garde ton téléphone allumé… ou pas. Clic. »',
        steps = {
            { type = 'collect', label = 'Récupère les colis de la Voix', item = 'gs_parcel', points = {
                vec3(-1197.0, -1776.3, 3.9), vec3(-1305.2, -393.4, 36.7), vec3(705.3, -965.3, 30.4),
                vec3(1133.9, -982.6, 46.4), vec3(-47.3, -1757.6, 29.4),
            } },
            { type = 'deliver', label = 'Rappelle la Voix depuis la cabine', character = 'voice', item = 'gs_parcel', count = 5 },
        },
        cleanup = { 'gs_parcel' },
        reward = { xp = 800, cash = 1500 }, badge = 'voice',
    },

    -- Chaîne homme : les affaires de Big Sal ----------------------------------------------------------------------
    {
        id = 'sal_pizza', title = 'Livraison brûlante', giver = 'sal', gender = 'male', requires = 'welcome',
        intro = 'Eh, toi ! T\'as l\'air d\'un gars fiable. Prends mon scooter, livre cette pizza à Vinewood. Froide, je la paie pas. Froide, TU la paies.',
        outro = 'Encore chaude ? Bravo, ragazzo. J\'aurai d\'autres courses pour toi.',
        give = { { 'gs_parcel', 1 } },
        vehicle = { model = 'faggio', type = 'bike', at = vec4(-1177.4, -893.8, 13.8, 300.0) },
        steps = {
            { type = 'deliver', label = 'Livre la pizza à Vinewood (4 min)', coords = vec3(-6.3, 257.6, 108.6), item = 'gs_parcel', count = 1, limit = 240 },
            { type = 'talk', label = 'Rapporte la recette à Big Sal', character = 'sal' },
        },
        cleanup = { 'gs_parcel' },
        reward = { xp = 250, cash = 400 },
    },
    {
        id = 'sal_debt', title = 'Le Recouvrement', giver = 'sal', gender = 'male', requires = 'sal_pizza',
        intro = 'Lenny me doit 3 enveloppes. Il jure qu\'il les a « perdues ». Va lui parler. Poliment. Au début.',
        outro = 'Les trois ? Tu vois qu\'on peut discuter entre gens civilisés.',
        steps = {
            { type = 'talk', label = 'Trouve Lenny à Davis', character = 'lenny' },
            { type = 'collect', label = 'Lenny a planqué les enveloppes dans le quartier', item = 'gs_envelope', points = {
                vec3(84.2, -1966.3, 20.7), vec3(101.6, -1951.0, 20.7), vec3(76.9, -1947.4, 21.2),
            } },
            { type = 'deliver', label = 'Rapporte les enveloppes à Big Sal', character = 'sal', item = 'gs_envelope', count = 3 },
        },
        cleanup = { 'gs_envelope' },
        reward = { xp = 350, cash = 600 },
    },
    {
        id = 'sal_offer', title = 'Une offre qu\'on ne refuse pas', giver = 'sal', gender = 'male', requires = 'sal_debt',
        intro = 'Un ami m\'attend au port. Il n\'aime pas attendre. Toi, tu as 5 minutes. Prends n\'importe quelle caisse.',
        outro = 'Mon ami dit que tu es ponctuel. Dans cette ville, c\'est rare. Bienvenue dans la famille… des clients.',
        steps = {
            { type = 'drive', label = 'Fonce au port en véhicule (5 min)', coords = vec3(1204.1, -3102.3, 5.9), radius = 12.0, limit = 300 },
            { type = 'talk', label = 'Parle au contact du port', character = 'dock' },
        },
        reward = { xp = 500, cash = 1000 }, badge = 'sal_family',
    },

    -- Chaîne femme : le cercle de Mama Rosa -----------------------------------------------------------------------
    {
        id = 'rosa_look', title = 'Le Look parfait', giver = 'rosa', gender = 'female', requires = 'welcome',
        intro = 'Ma chérie, avec cette tenue tu ne passeras pas la porte du moindre club. File te changer, puis montre-toi au panorama de Vinewood.',
        outro = 'Divine. Maintenant, on peut parler affaires.',
        steps = {
            { type = 'goto', label = 'Passe dans une boutique de vêtements', coords = vec3(425.5, -806.3, 29.5), radius = 8.0 },
            { type = 'goto', label = 'Fais-toi voir au panorama de l\'observatoire', coords = vec3(-425.0, 1123.4, 325.9), radius = 12.0 },
            { type = 'talk', label = 'Retourne voir Mama Rosa', character = 'rosa' },
        },
        reward = { xp = 250, cash = 400 },
    },
    {
        id = 'rosa_gossip', title = 'Les ragots de Vinewood', giver = 'rosa', gender = 'female', requires = 'rosa_look',
        intro = 'Kiki Starlight sait tout sur tout le monde. Va la voir, elle a « égaré » des lettres qui m\'intéressent beaucoup.',
        outro = 'Oh, oh… Ces lettres valent de l\'or. Tu viens de te faire une alliée, ma belle.',
        steps = {
            { type = 'talk', label = 'Rencontre Kiki Starlight sur Vinewood Boulevard', character = 'kiki' },
            { type = 'collect', label = 'Retrouve les lettres parfumées de Kiki', item = 'gs_envelope', points = {
                vec3(313.2, 165.9, 103.8), vec3(282.9, 196.7, 104.4), vec3(262.5, 172.4, 104.8),
            } },
            { type = 'deliver', label = 'Apporte les lettres à Mama Rosa', character = 'rosa', item = 'gs_envelope', count = 3 },
        },
        cleanup = { 'gs_envelope' },
        reward = { xp = 350, cash = 600 },
    },
    {
        id = 'rosa_neon', title = 'Nuit Néon', giver = 'rosa', gender = 'female', requires = 'rosa_gossip', night = true,
        intro = 'Ce soir, DJ Nova joue sur la jetée et toute la ville sera là. Prends ma décapotable, tu as 6 minutes. Et ne raye pas la peinture.',
        outro = 'Nova dit que tu as fait une entrée remarquée. Évidemment : c\'était ma voiture.',
        vehicle = { model = 'issi2', type = 'automobile', at = vec4(-705.6, -160.9, 37.4, 120.0) },
        steps = {
            { type = 'drive', label = 'Rejoins la jetée de Del Perro en voiture (6 min)', coords = vec3(-1630.1, -1072.8, 13.0), radius = 15.0, limit = 360 },
            { type = 'talk', label = 'Salue DJ Nova', character = 'nova' },
        },
        reward = { xp = 500, cash = 1000 }, badge = 'rosa_circle',
    },
}
