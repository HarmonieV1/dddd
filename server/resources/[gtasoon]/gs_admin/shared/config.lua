-- [CONFIG] Panel staff. Complète le menu txAdmin (noclip, spectate, ban, véhicules : touche du menu txAdmin).
Config = {}

-- Niveaux (ACE, voir cfg/permissions.cfg). Un niveau inclut les précédents.
-- 1 helper, 2 modo, 3 admin, 4 super-admin, 5 fondateur.
Config.Aces = { 'gs.admin.helper', 'gs.admin.mod', 'gs.admin.admin', 'gs.admin.superadmin', 'gs.admin.founder' }
Config.LevelNames = { 'Helper', 'Modérateur', 'Admin', 'Super-admin', 'Fondateur' }
Config.Key = 'F10'          -- panel complet
Config.QuickKey = 'F11'     -- menu staff rapide (la portée de la voix de pma-voice est sur ²)

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

-- Persos GTA (peds) pour le staff : animation, événements, figurants. Même pouvoir que les animaux (niveau `animal`).
Config.Peds = {
    { model = 'player_zero', label = 'Michael De Santa' }, { model = 'player_one', label = 'Franklin Clinton' },
    { model = 'player_two', label = 'Trevor Philips' }, { model = 'ig_lamardavis', label = 'Lamar Davis' },
    { model = 'ig_lestercrest', label = 'Lester Crest' }, { model = 'ig_jimmydisanto', label = 'Jimmy De Santa' },
    { model = 'ig_amandatownley', label = 'Amanda De Santa' }, { model = 'ig_tracydisanto', label = 'Tracey De Santa' },
    { model = 'ig_wade', label = 'Wade' }, { model = 'ig_ron', label = 'Ron' }, { model = 'ig_davenorton', label = 'Dave Norton' },
    { model = 'ig_stevehains', label = 'Steve Haines' }, { model = 'ig_tenniscoach', label = 'Prof de tennis' },
    { model = 'ig_chef', label = 'Chef' }, { model = 'ig_stretch', label = 'Stretch' }, { model = 'ig_tanisha', label = 'Tanisha' },
    { model = 'ig_lazlow', label = 'Lazlow' }, { model = 'ig_paper', label = 'Agent du FIB' }, { model = 'u_m_y_imporage', label = 'Clown' },
    { model = 's_m_y_cop_01', label = 'Policier' }, { model = 's_m_y_sheriff_01', label = 'Shérif' }, { model = 's_m_y_swat_01', label = 'SWAT' },
    { model = 's_m_m_paramedic_01', label = 'Ambulancier' }, { model = 's_m_y_fireman_01', label = 'Pompier' },
    { model = 's_m_m_security_01', label = 'Agent de sécurité' }, { model = 's_m_y_construct_01', label = 'Ouvrier' },
    { model = 's_m_m_postal_01', label = 'Facteur' }, { model = 's_m_y_clown_01', label = 'Clown de fête' },
    { model = 'u_m_y_zombie_01', label = 'Zombie' }, { model = 's_m_m_movalien_01', label = 'Extraterrestre' },
    { model = 'u_m_m_jesus_01', label = 'Jésus' }, { model = 'a_f_y_beach_01', label = 'Plagiste' },
    { model = 'a_m_y_hipster_01', label = 'Hipster' }, { model = 'g_m_y_ballasout_01', label = 'Ballas' },
    { model = 'g_m_y_famca_01', label = 'Families' }, { model = 'g_m_y_mexgoon_01', label = 'Vagos' },
    { model = 'g_m_y_lost_01', label = 'Lost MC' },
}

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

-- V11.5 · Personnages : 1 par joueur (réglage qbx_core posé par METTRE-A-JOUR), `extra` pour le fondateur, les
-- super-admins et les VIP (menu staff → Joueurs → VIP, fondateur seulement).
Config.Characters = { extra = 2 }

-- Transparence (prompt maître) : sanctions publiées sur un salon public (convar gs_webhook_sanctions).
Config.PublicSanctions = true
Config.PublicShowName = true   -- nom du joueur sanctionné visible ; le staff reste anonyme

Config.LogHistory = 150
