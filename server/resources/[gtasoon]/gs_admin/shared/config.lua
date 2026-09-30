-- [CONFIG] Panel staff. Complète le menu txAdmin (noclip, spectate, ban, véhicules : touche du menu txAdmin).
Config = {}

-- Niveaux (ACE, voir cfg/permissions.cfg). Un niveau inclut les précédents.
-- 1 helper, 2 modo, 3 admin, 4 super-admin, 5 fondateur.
Config.Aces = { 'gs.admin.helper', 'gs.admin.mod', 'gs.admin.admin', 'gs.admin.superadmin', 'gs.admin.founder' }
Config.LevelNames = { 'Helper', 'Modérateur', 'Admin', 'Super-admin', 'Fondateur' }
Config.Key = 'F10'          -- panel complet
Config.QuickKey = 'DELETE'  -- menu staff rapide (F11) ; F11 reste à pma-voice (portée de la voix)

-- Rangs donnés en jeu : SEUL le fondateur promeut / rétrograde (jusqu'à super-admin). Les fondateurs se déclarent
-- dans secrets.cfg (group.god), jamais depuis le jeu. Groupe ACE de chaque rang :
Config.RankGroups = { 'group.helper', 'group.mod', 'group.admin', 'group.superadmin' }

-- Raccourcis clavier du mode staff (maintenir Ctrl gauche + touche). Modifiables dans Paramètres → Raccourcis → FiveM.
Config.Shortcuts = {
    tpm = 'Y',      -- Ctrl + Y : téléportation au marqueur
    noclip = 'U',   -- Ctrl + U : vol libre
    names = 'O',    -- Ctrl + O : noms et ID
}
-- Pouvoirs du menu rapide : niveau minimum. Tous exigent le mode staff (/staff ou 1re ligne du menu).
Config.Powers = {
    names = 1,       -- noms + ID au-dessus des joueurs
    noclip = 2,      -- vol libre
    invisible = 2,
    godmode = 2,
    animal = 2,      -- se transformer (Config.Animals)
    tpm = 2,         -- téléportation au marqueur
    -- Section « Fun » (staff et événements) : sur soi uniquement, jamais sur un joueur
    fastrun = 3,     -- course rapide
    superjump = 3,   -- super saut
    stamina = 3,     -- endurance infinie
    lowgravity = 3,  -- gravité lunaire (sur ton écran seulement)
    nightvision = 3, -- vision nocturne
    thermal = 3,     -- vision thermique
    fastswim = 3,    -- nage rapide
}

Config.Animals = {
    { model = 'a_c_chop', label = 'Chien (rottweiler)' }, { model = 'a_c_husky', label = 'Husky' },
    { model = 'a_c_retriever', label = 'Retriever' }, { model = 'a_c_shepherd', label = 'Berger' },
    { model = 'a_c_cat_01', label = 'Chat' }, { model = 'a_c_coyote', label = 'Coyote' },
    { model = 'a_c_mtlion', label = 'Puma' }, { model = 'a_c_deer', label = 'Cerf' },
    { model = 'a_c_boar', label = 'Sanglier' }, { model = 'a_c_pig', label = 'Cochon' },
    { model = 'a_c_cow', label = 'Vache' }, { model = 'a_c_chimp', label = 'Chimpanzé' },
    { model = 'a_c_rabbit_01', label = 'Lapin' }, { model = 'a_c_rat', label = 'Rat' },
    { model = 'a_c_panther', label = 'Panthère' }, { model = 'a_c_rottweiler', label = 'Rottweiler' },
    { model = 'a_c_poodle', label = 'Caniche' }, { model = 'a_c_pug', label = 'Carlin' }, { model = 'a_c_westy', label = 'Westie' },
    { model = 'a_c_rhesus', label = 'Singe' }, { model = 'a_c_hen', label = 'Poule' }, { model = 'a_c_chickenhawk', label = 'Faucon' },
    { model = 'a_c_seagull', label = 'Mouette' }, { model = 'a_c_pigeon', label = 'Pigeon' }, { model = 'a_c_crow', label = 'Corbeau' },
    { model = 'a_c_cormorant', label = 'Cormoran' }, { model = 'a_c_fish', label = 'Poisson' }, { model = 'a_c_sharktiger', label = 'Requin' },
    { model = 'a_c_dolphin', label = 'Dauphin' }, { model = 'a_c_killerwhale', label = 'Orque' }, { model = 'a_c_humpback', label = 'Baleine' },
    { model = 'a_c_boar_02', label = 'Sanglier (brun)' }, { model = 'a_c_deer_02', label = 'Biche' }, { model = 'a_c_mtlion_02', label = 'Puma (clair)' },
}
-- Les animaux absents du build du jeu sont refusés proprement (« modèle absent »). Aquatiques : à utiliser dans l'eau.

-- Événements staff en un clic (admin+, mode staff) : centrés sur TA position, annonce + GPS pour tout le monde,
-- effet appliqué aux joueurs dans le rayon pendant `minutes`. fx : fastrun, superjump, lowgravity, melee (boxe : armes rangées).
Config.Events = {
    speedrace = { label = 'Course à super vitesse', icon = 'person-running', fx = 'fastrun', radius = 250.0, minutes = 10,
        text = 'Course à pied en super vitesse ! Rejoins le point GPS.' },
    moon = { label = 'Chute lunaire', icon = 'moon', fx = 'lowgravity', radius = 250.0, minutes = 10,
        text = 'Gravité lunaire activée : sautez du plus haut possible !' },
    jump = { label = 'Concours de super saut', icon = 'arrow-up', fx = 'superjump', radius = 200.0, minutes = 10,
        text = 'Concours de super saut : qui ira le plus haut ?' },
    boxing = { label = 'Soirée boxe', icon = 'hand-fist', fx = 'melee', radius = 30.0, minutes = 20,
        text = 'Soirée boxe : aux poings seulement, armes rangées automatiquement dans la zone.' },
    cayoparty = { label = 'Soirée DJ plage de Cayo Perico', icon = 'music', radius = 0.0, minutes = 60, party = true,
        at = vec3(4893.2, -4924.0, 3.37), text = 'Soirée DJ sur la plage de Cayo Perico ! Vol gratuit au comptoir de l\'aéroport (LSIA).' },
    streetrace = { label = 'Course de rue (inscription gratuite)', icon = 'flag-checkered', radius = 0.0, minutes = 30, freeRaces = true,
        text = 'Course de rue organisée : inscription gratuite, rendez-vous au point GPS !' },
    roadtrip = { label = 'Départ du road trip du mois', icon = 'route', radius = 0.0, minutes = 30, roadtrip = true,
        text = 'Grand départ du road trip du mois : rendez-vous au point GPS, puis /carnet. Bonus pour ceux qui arrivent en convoi !' },
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

-- Argent et items : super-admin minimum (motif obligatoire, journalisé) ; le fondateur seul sans motif.
Config.Give = { maxMoney = 100000, maxItems = 100 }

-- Transparence (prompt maître) : sanctions publiées sur un salon public (convar gs_webhook_sanctions).
Config.PublicSanctions = true
Config.PublicShowName = true   -- nom du joueur sanctionné visible ; le staff reste anonyme

Config.LogHistory = 150
