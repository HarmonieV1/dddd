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
    -- V12.59 (backtest 15/10) : délires « sur moi » en plus, pour animer un événement
    carspeed = 3,    -- super vitesse de la voiture que je conduis
    carjump = 3,     -- voiture sauteuse (Espace en conduisant)
    rainbow = 3,     -- voiture arc-en-ciel
    drunk = 3,       -- caméra ivre
    -- V12.63 : effets d'un instant, à ma position, vus par les joueurs autour (animation d'événement)
    fireworks = 3,   -- feux d'artifice
    confetti = 3,    -- pluie de confettis
    smoke = 3,       -- apparition dans un nuage de fumée
    -- V12.63 (2e série) : effets plus poussés, toujours sur moi / à ma position
    teleportfx = 3,  -- téléportation « alien » (éclair vert)
    vanish = 3,      -- désintégration (je disparais dans un éclat)
    boom = 3,        -- souffle lumineux (sans dégâts)
    carshield = 3,   -- ma voiture indestructible (celle que je conduis)
    tyresmoke = 3,   -- fumée de pneus colorée sur ma voiture
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
-- V12.59 : n'importe quel autre ped HUMAIN du jeu (~700) par son nom de modèle : menu Persos GTA → « Autre perso (nom du modèle) ».
Config.PedPattern = { '^[asgu]_[mf]_', '^ig_', '^csb?_', '^hc_', '^player_' } -- (pas mp_ : le modèle des persos joueurs)
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
-- effet appliqué aux joueurs dans le rayon pendant `minutes`. fx : lowgravity, melee (boxe : armes rangées).
-- V12.36 : « Course à super vitesse » et « Concours de super saut » retirés (demande du fondateur) ; fastrun / superjump restent
-- des pouvoirs du menu « Effets sur moi » du staff, plus des événements.
-- V12.59 : « Chute lunaire » retirée aussi (hors RP pour tout un quartier) : la gravité lunaire reste dans « Effets sur moi ».
Config.Events = {
    boxing = { label = 'Soirée boxe', icon = 'hand-fist', fx = 'melee', radius = 30.0, minutes = 20,
        text = 'Soirée boxe : aux poings seulement, armes rangées automatiquement dans la zone.' },
    cayoparty = { label = 'Soirée DJ plage de Cayo Perico', icon = 'music', radius = 0.0, minutes = 60, party = true,
        at = vec3(4893.2, -4924.0, 3.37), text = 'Soirée DJ sur la plage de Cayo Perico ! Vol gratuit au comptoir de l\'aéroport (LSIA).' },
    streetrace = { label = 'Course de rue (inscription gratuite)', icon = 'flag-checkered', radius = 0.0, minutes = 30, freeRaces = true,
        text = 'Course de rue organisée : inscription gratuite, rendez-vous au point GPS !' },
    roadtrip = { label = 'Départ du road trip du mois', icon = 'route', radius = 0.0, minutes = 30, roadtrip = true,
        text = 'Grand départ du road trip du mois : rendez-vous au point GPS, puis /carnet. Bonus pour ceux qui arrivent en convoi !' },
    -- V12.63 : rassemblements simples et crédibles (annonce + GPS ; armes rangées dans la zone quand `fx = 'melee'`)
    carmeet = { label = 'Rassemblement auto', icon = 'car', fx = 'melee', radius = 60.0, minutes = 45,
        text = 'Rassemblement auto : viens montrer ta voiture, armes rangées dans la zone. Rendez-vous au point GPS !' },
    club = { label = 'Soirée en club', icon = 'martini-glass', fx = 'melee', radius = 40.0, minutes = 60,
        text = 'Soirée en club : musique, verres et rencontres, armes rangées à l\'entrée. Rendez-vous au point GPS !' },
    -- V12.63 (2e série) : événements classiques en plus, lancés là où se trouve le staff (devant le lieu choisi)
    concert = { label = 'Concert en plein air', icon = 'guitar', fx = 'melee', radius = 60.0, minutes = 60,
        text = 'Concert en plein air : musique live, foule et ambiance, armes rangées dans la zone. Rendez-vous au point GPS !' },
    nightmarket = { label = 'Marché de nuit', icon = 'store', fx = 'melee', radius = 40.0, minutes = 60,
        text = 'Marché de nuit : stands, bonnes affaires et rencontres. Rendez-vous au point GPS !' },
    parade = { label = 'Défilé de voitures', icon = 'car-side', radius = 0.0, minutes = 30,
        text = 'Défilé de voitures : rejoins le cortège au point GPS, on traverse la ville ensemble (code de la route respecté).' },
    soccer = { label = 'Match de foot', icon = 'futbol', fx = 'melee', radius = 50.0, minutes = 45,
        text = 'Match de foot : deux équipes, un ballon, des supporters. Rendez-vous au terrain (point GPS) !' },
    billiard = { label = 'Tournoi de billard', icon = 'circle', fx = 'melee', radius = 25.0, minutes = 60,
        text = 'Tournoi de billard : inscriptions sur place, le gagnant repart avec la gloire. Rendez-vous au point GPS !' },
    lasergame = { label = 'Partie de laser game', icon = 'crosshairs', radius = 0.0, minutes = 45,
        text = 'Partie de laser game : équipes formées sur place. Rendez-vous au point GPS !' },
    jobfair = { label = 'Salon de l\'emploi', icon = 'briefcase', radius = 0.0, minutes = 30,
        text = 'Salon de l\'emploi : entreprises et services recrutent, entretiens sur place. Rendez-vous au point GPS !' },
    -- Chasse au trésor : le staff cache une mallette là où il se trouve ; tout le monde reçoit une ZONE (pas le point exact) ;
    -- le premier qui la ramasse ([E]) empoche la prime (en banque). Le staff ne peut pas la ramasser.
    hunt = { label = 'Chasse au trésor', icon = 'gem', radius = 150.0, minutes = 20, hunt = true,
        text = 'Une mallette est cachée dans la zone du GPS : le premier qui la trouve l\'empoche !' },
}
Config.Hunt = { prize = 1500, maxPrize = 5000, bigPrizeLevel = 4, model = 'prop_cash_case_02', pickup = 3.0 } -- au-delà de `prize` : super-admin

-- V12.63 · Mises en scène du staff (admin et plus) : jouées chez le joueur visé, sanction appliquée par le serveur à la fin
-- de la scène (ou au bout de `maxSeconds` quoi qu'il arrive). Enlèvement = expulsion « en camionnette » ; arrestation PNJ =
-- isolement dans une cellule du commissariat de Mission Row (mêmes cellules que la garde à vue de gs_police).
Config.Scenes = {
    level = 3,
    kidnap = { van = 'speedo', thug = 'g_m_m_chicold_01', maxSeconds = 55, -- burrito3 : remplacé par un mod importé au handling illisible (crash)
        -- V12.64 (fondateur : « qu'ils jettent bien le joueur plus loin ») : après le trajet, la camionnette le jette sur le bord
        -- d'une route isolée, à plus de `minDistance` m de l'enlèvement (il s'y reconnecte : Qbox garde la dernière position).
        -- Altitude recalculée au sol ; points à caler en jeu si l'un d'eux tombe mal.
        minDistance = 800.0,
        drops = {
            vec4(1218.0, -2995.0, 5.9, 90.0),     -- docks du Terminal
            vec4(868.0, -2352.0, 30.3, 175.0),    -- zone industrielle de Cypress Flats
            vec4(1127.0, -1296.0, 34.7, 0.0),     -- terrain vague de Murrieta Heights
            vec4(2948.0, 2782.0, 42.0, 300.0),    -- carrière de Davis Quartz
            vec4(-24.0, 2862.0, 58.0, 160.0),     -- route 68, bord du désert
            vec4(1312.0, 4292.0, 33.9, 260.0),    -- rive du lac Alamo
            vec4(-1585.0, 2101.0, 68.0, 230.0),   -- route de Tongva, dans les collines
        } },
    arrest = { cop = 's_m_y_cop_01', maxSeconds = 40, minutes = 5,
        cell = { coords = vec3(459.9, -994.3, 24.91), radius = 6.0, release = vec3(434.1, -981.9, 30.71) },
        -- V12.65 (proposition n° 292) : option « interrogatoire » : avant la cellule, un inspecteur PNJ pose ses questions dans la
        -- salle d'interrogatoire de Mission Row ; les réponses du joueur arrivent au staff qui a lancé la scène (et au journal).
        interrogation = { room = vec4(472.3, -994.9, 24.91, 90.0), inspector = 's_m_m_ciasec_01', maxSeconds = 150, answerSeconds = 30,
            questions = { 'Où étais-tu ce soir, entre 21 h et minuit ?', 'Qui était avec toi ?', 'Tu as quelque chose à ajouter avant qu\'on te mette au frais ?' } } },
    -- V12.65 (proposition n° 295, « version douce » de l'enlèvement) : même camionnette, mais le joueur est relâché dans le
    -- désert, SANS son argent liquide (`takeCash`) et en sous-vêtements (`strip`) ; pas d'expulsion. Journalisé (motif).
    desert = { van = 'speedo', thug = 'g_m_m_chicold_01', maxSeconds = 55, minDistance = 800.0, takeCash = true, strip = true, desert = true,
        drops = {
            vec4(1595.0, 2830.0, 39.0, 120.0),    -- désert du Grand Senora
            vec4(2425.0, 3090.0, 48.2, 30.0),     -- casse au milieu du désert
            vec4(-1100.0, 2690.0, 18.9, 220.0),   -- bord de la route 68, côté ouest
            vec4(2715.0, 4140.0, 43.9, 300.0),    -- route de Grapeseed, champs vides
        } },
    -- V12.65 (propositions n° 294) : transfert vers Bolingbroke en fourgon, attaquable. Le fourgon part de `from` ; s'il est
    -- arrêté (moteur détruit, conducteur à terre) avant `seconds` s, le détenu est libre (évasion journalisée) ; sinon,
    -- isolement à Bolingbroke pour la durée donnée. L'annonce Weazel (optionnelle) prévient la ville.
    transfer = { van = 'policet', cop = 's_m_y_cop_01', maxSeconds = 420, seconds = 400, minutes = 10, engineFail = 300.0,
        from = vec4(408.0, -1000.0, 29.2, 180.0), to = vec3(1855.0, 2600.0, 45.6) },
    -- V12.65 · Mises en scène d'AMBIANCE (sans sanction) : pimenter une scène plutôt que la couper (propositions 278, 280, 282,
    -- chien errant / alcoolique collant). Entités réseau (tout le monde les voit), supprimées par le serveur à la fin.
    stages = {
        heli = { label = 'Hélico de la police', seconds = 30, model = 'polmav', pilot = 's_m_y_pilot_01', height = 45.0, radius = 40.0 },
        crowd = { label = 'Foule de curieux', seconds = 40, count = 6,
            models = { 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_m_business_01', 'a_f_m_bevhills_01', 'a_m_y_skater_01', 'a_f_y_tourist_01', 'a_m_m_socenlat_01' } },
        call = { label = 'Appel masqué', seconds = 12 },
        stray = { label = 'Chien errant', seconds = 60, model = 'a_c_retriever' },
        drunk = { label = 'Alcoolo collant', seconds = 60, model = 'a_m_o_tramp_01',
            lines = { 'Eh toi ! T\'aurais pas une petite pièce ?', 'T\'as une bonne tête, toi… on est amis maintenant.', 'C\'est moi le roi de Vespucci, tu le savais ?',
                'Attends-moi ! Je marche moins vite que toi…', 'Tu sens ça ? C\'est l\'odeur de la liberté… et du whisky.' } },
    },
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

-- V12.63 · Appli staff externe (tablette, téléphone, PC : http(s)://ADRESSE/gs_admin/). Connexion : pseudo (pour le journal) +
-- mot de passe collectif (secrets.cfg : set gs_admin_web_password "…", jamais dans le dépôt ; GERER-OVH → 20) ou code personnel
-- (gs_admin_web). Une session dure `sessionHours`. Les sanctions depuis l'appli ne touchent pas un staff de rang ≥ `protectLevel`.
-- Avec l'adresse https (GERER-OVH → 21), les connexions en clair par le port 30120 sont refusées (gs_admin_web_https).
Config.Web = {
    sessionHours = 12, maxBanDays = 3650,
    protectLevel = 1, -- V12.63 (relecture) : aucune sanction ni téléportation à distance sur un membre du staff, quel que soit son rang
    -- V12.63 (fondateur) · Rangs dans l'appli : le mot de passe collectif donne `collectiveLevel` (2 = modérateur) ; un code
    -- personnel « Pseudo:code:rang » (GERER-OVH → 20 → A) donne son rang (5 = fondateur). Un rang agit sur les joueurs et sur
    -- le staff de rang INFÉRIEUR ; le fondateur agit sur tout le monde. Rang minimum par action ci-dessous.
    collectiveLevel = 2, codeLevel = 2,
    actionLevel = { message = 1, note = 1, heal = 1, revive = 1, fixveh = 1, ticket_claim = 1, ticket_close = 1, warn = 1,
        freeze = 2, unfreeze = 2, jail = 2, unjail = 2, kick = 2, tp = 2, clearheat = 2, ban = 3, unban = 3, announce = 3, unstuck = 1,
        watch = 3, unwatch = 3, offlineban = 3, lockdown = 4 }, -- V12.63 : modération avancée (Config.Moderation)
    places = { -- « Téléporter vers… » (positions du jeu, à caler si besoin)
        { label = 'Hôpital Pillbox', coords = vec3(298.6, -584.4, 43.3) },
        { label = 'Commissariat Mission Row', coords = vec3(441.2, -981.9, 30.7) },
        { label = 'Mairie', coords = vec3(-544.9, -204.4, 38.2) },
        { label = 'Parking de Legion Square', coords = vec3(215.8, -810.1, 30.7) },
        { label = 'Aéroport LSIA', coords = vec3(-1037.8, -2737.8, 20.2) },
        { label = 'Sandy Shores', coords = vec3(1853.0, 3686.0, 34.3) },
        { label = 'Paleto Bay', coords = vec3(-448.0, 6012.0, 31.7) },
    },
}

-- V12.63 · Modération avancée (admin, super-admin, fondateur) : F11 → Modération, F10 → Serveur et fiche joueur, appli staff.
-- Surveillance d'un compte (alerte à chaque arrivée), fermeture des arrivées (raid), contournement de ban (empreintes du PC et
-- comptes liés, jamais l'IP), bannissement hors ligne depuis les départs récents. Rang minimum par outil ci-dessous.
Config.Moderation = {
    levels = { watch = 3, departed = 3, lockdown = 4, offlineban = 4 }, -- en jeu (F10 / F11) ; appli : Config.Web.actionLevel
    lockMaxMinutes = 60,   -- fermeture des arrivées : rouvre toute seule au bout de la durée choisie (60 min maximum)
    departedKeep = 50,     -- départs récents gardés (mémoire : vidés au redémarrage du serveur)
    evasion = 'alert',     -- compte lié à un banni : 'alert' (staff prévenu, il entre) ou 'block' (arrivée refusée)
}

-- V12.63 · Joueur coincé sous la carte (proposition n° 193) : hors intérieur et hors de l'eau, sous `z` m pendant `seconds` s =
-- ramené au dernier endroit sûr (noté toutes les 10 s quand il est au sol). Le staff peut aussi le faire depuis l'appli.
Config.Unstuck = { z = -25.0, seconds = 6, fallback = vec3(215.8, -810.1, 30.7) }

-- V12.65 · Outils staff (F11 + appli) : server/staffhub.lua
-- Chat staff synchronisé jeu ↔ appli (/sc), carte des incidents de la soirée, événements programmés, double validation des
-- bans définitifs (proposition n° 307) : un ban définitif posé par un admin ou un super-admin est d'abord un ban de
-- `tempDays` jour(s) ; il devient définitif quand un AUTRE admin le valide (F11 → Bans définitifs à valider, ou appli →
-- Sanctions). Refusé ou jamais validé : il reste au ban temporaire. Le fondateur (rang 5) n'a pas besoin de validation.
Config.StaffHub = {
    chatKeep = 60,                       -- messages gardés (mémoire)
    incidentHours = 12,                  -- carte des incidents : les X dernières heures
    banReview = { enabled = true, tempDays = 1, bypassLevel = 5, minLevel = 3, keepHours = 72 },
    scheduleMax = 12,                    -- événements programmés en même temps
}
