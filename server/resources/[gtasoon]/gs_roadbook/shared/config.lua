-- [CONFIG] Carnets de route. Chaque étape : coords, nom, anecdote (affichée en arrivant), photo = spot photo ([E] sur place).
-- Coords à caler en jeu (F11 → Copier mes coordonnées). Ordre libre des carnets, étapes dans l'ordre.
Config = {}

Config.Radius = 25.0            -- rayon de validation d'une étape
Config.PhotoRadius = 8.0
Config.MaxSpeed = 90.0          -- m/s crédibles entre deux étapes
Config.MaxHours = 3             -- un carnet commencé doit être fini dans les 3 h
Config.DuoRadius = 60.0         -- partenaire de duo (gs_duo) à côté à l'arrivée : bonus
Config.DuoBonus = 1.5
Config.Titles = { { count = 1, label = 'Routard' }, { count = 3, label = 'Explorateur' }, { count = 5, label = 'Globe-trotteur de San Andreas' } }

Config.Routes = {
    ouest = {
        label = 'La côte Ouest', xp = 400, desc = 'De la jetée de Del Perro aux pins de Paleto, l\'océan à ta gauche.',
        steps = {
            { coords = vec3(-1604.0, -1049.0, 13.0), label = 'Jetée de Del Perro', text = 'Ici, tout le monde commence un jour. La grande roue tourne depuis avant ta naissance.' },
            { coords = vec3(-2025.0, -360.0, 44.1), label = 'Falaises de Pacific Bluffs', text = 'Les villas d\'ici n\'ont pas de clôture : elles ont des avocats.', photo = true },
            { coords = vec3(-3040.5, 585.9, 7.9), label = 'Chumash', text = 'Les surfeurs disent que la meilleure vague arrive toujours quand tu n\'as pas ta planche.' },
            { coords = vec3(-2197.0, 4278.0, 48.5), label = 'Route de la côte, nord', text = 'Plus de bitume que de réseau. Profite du silence.', photo = true },
            { coords = vec3(-350.0, 6150.0, 31.5), label = 'Paleto Bay', text = 'Terminus. Un café, une part de tarte, et on repart quand on veut.' },
        },
    },
    sunset = {
        label = 'Vinewood au coucher du soleil', xp = 350, desc = 'Des étoiles sur le trottoir aux lettres géantes sur la colline.',
        steps = {
            { coords = vec3(373.9, 328.4, 103.6), label = 'Vinewood Boulevard', text = 'Chaque étoile sur ce trottoir a coûté un rêve à quelqu\'un.' },
            { coords = vec3(-438.0, 1076.0, 352.4), label = 'Observatoire', text = 'Toute la ville d\'un coup d\'œil. Reviens de nuit : c\'est encore mieux.', photo = true },
            { coords = vec3(711.0, 1198.0, 348.5), label = 'Sous les lettres de Vinewood', text = 'Interdit d\'escalader. Personne ne respecte cette règle.', photo = true },
            { coords = vec3(1135.0, -472.0, 66.5), label = 'Mirror Park', text = 'Le lac, les cafés, les vélos : le Los Santos qui prend son temps.' },
        },
    },
    desert = {
        label = 'Le grand Nord de Blaine', xp = 500, desc = 'Désert, lac salé et montagne : le vrai roadtrip.',
        steps = {
            { coords = vec3(1851.4, 3683.0, 34.3), label = 'Sandy Shores', text = 'Ici, tout le monde connaît tout le monde. Surtout ceux qu\'il ne faut pas.' },
            { coords = vec3(1299.4, 4217.9, 33.9), label = 'Alamo Sea', text = 'Un lac au milieu du désert. On raconte qu\'il y a des choses au fond.', photo = true },
            { coords = vec3(2415.0, 4990.0, 46.2), label = 'Fermes de Grapeseed', text = 'Des champs à perte de vue et des tracteurs qui roulent à 20 km/h. Respire.' },
            { coords = vec3(501.4, 5604.1, 797.9), label = 'Sommet du mont Chiliad', text = 'Tu es au-dessus de tout. Même des problèmes.', photo = true },
        },
    },
}
