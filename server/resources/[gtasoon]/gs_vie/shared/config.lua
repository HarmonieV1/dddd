-- gs_vie · réglages (V12.57)
Config = {}

-- 123 · Fouiller les poubelles : chaque benne a son propre délai (tout le monde), chaque joueur un délai court + un plafond
Config.Dumpster = {
    models = { 'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b', 'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b' },
    duration = 6000,        -- ms de fouille
    cooldown = 20,          -- minutes avant qu'une même benne redonne quelque chose
    playerCooldown = 45,    -- secondes entre deux fouilles d'un même joueur
    perHour = 12,           -- fouilles maximum par joueur et par heure
    range = 3.0,
    -- poids = chances relatives ; « rien » compris
    loot = {
        { item = nil, weight = 40 },
        { item = 'scrapmetal', weight = 18, min = 1, max = 3 },
        { item = 'copper', weight = 8, min = 1, max = 2 },
        { item = 'sandwich', weight = 10, min = 1, max = 1 },
        { item = 'water', weight = 10, min = 1, max = 1 },
        { item = 'gs_chips', weight = 8, min = 1, max = 1 },
        { item = 'gs_cigarettes', weight = 6, min = 1, max = 1 },
    },
}

-- 125 · Se laver : lavabos, douches, fontaines, ou /laver dans l'eau (mer, lac, piscine)
Config.Wash = {
    models = { 'prop_sink_02', 'prop_sink_04', 'prop_sink_05', 'prop_sink_06', 'v_res_mbsink', 'v_res_tre_sink', 'prop_ff_sink_01',
        'prop_ff_sink_02', 'v_ilev_mm_faucet', 'prop_shower_rack_01', 'v_ilev_ph_bench', 'prop_fountain2', 'prop_watercooler' },
    duration = 5000,
}

-- 118 (allégé) · Démarche blessée après une grosse blessure (relevé par l'EMS ou un coéquipier)
Config.Injured = {
    minutes = 10,
    cures = { bandage = true, painkillers = true, firstaid = true, ifaks = true }, -- objets qui soignent la démarche
    clipset = { m = 'move_m@injured', f = 'move_f@injured' },
}

-- 120 · Passagers bavards : un PNJ assis dans ton véhicule (bus, taxi, client…) raconte une vraie rumeur de la ville
Config.Passengers = {
    check = 10000,          -- ms entre deux regards dans le véhicule
    every = { 90, 180 },    -- secondes entre deux bavardages (au hasard)
    chance = 0.6,
    fallback = {
        'Il paraît que les loyers vont encore monter à Vespucci.',
        'Mon cousin dit que la police tourne beaucoup du côté de Grove Street ces temps-ci.',
        'Vous avez entendu parler du nouveau bar à Vinewood ? Tout le monde en parle.',
        'Moi je dis que la météo est bizarre en ce moment, ça sent l\'orage.',
        'On m\'a dit que la Weazel cherche des témoins pour une histoire de braquage.',
        'Sandy Shores, c\'est calme… trop calme, si vous voulez mon avis.',
        'Le casino a encore fait un gros gagnant hier soir, à ce qu\'il paraît.',
        'Mon voisin s\'est fait voler sa voiture devant chez lui. En plein jour !',
    },
}

-- 126 · Porter / prendre en otage : avec l'accord de l'autre, sauf s'il est menotté, à terre ou mort
Config.Carry = {
    range = 2.5,
    askTimeout = 20,        -- secondes pour accepter
    hostageWeapons = {      -- arme de poing en main pour prendre en otage
        'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL',
        'WEAPON_SNSPISTOL_MK2', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_REVOLVER',
        'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION', 'WEAPON_MACHINEPISTOL', 'WEAPON_MICROSMG', 'WEAPON_KNIFE', 'WEAPON_SWITCHBLADE',
    },
    anims = {
        carry = {
            carrier = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman', flag = 49 },
            carried = { dict = 'nm', clip = 'firemans_carry', flag = 33 },
            attach = { x = 0.27, y = 0.15, z = 0.63, rx = 0.5, ry = 0.5, rz = 180.0 },
        },
        hostage = {
            carrier = { dict = 'anim@gangops@hostage@', clip = 'perp_idle', flag = 49 },
            carried = { dict = 'anim@gangops@hostage@', clip = 'victim_idle', flag = 49 },
            attach = { x = -0.24, y = 0.11, z = 0.0, rx = 0.5, ry = 0.5, rz = 0.0 },
        },
    },
}

-- 130 · Mesure de charge (/perfserveur, staff) : retard de la boucle serveur échantillonné, journal par minute
Config.Perf = {
    tick = 50,              -- ms visés entre deux mesures
    maxMinutes = 120,
    file = 'perf-serveur.log',
}

-- V12.63 · Emotes en rapport avec l'objet (Alt dessus) : chaque type d'objet propose ses gestes, avec une vraie animation.
-- Les lavabos et douches enlèvent le sang et la saleté ; les fontaines désaltèrent (RP) ; dans la mer : E pour se rincer.
-- EMS en service : « Nettoyer les plaies » sur un joueur (sang effacé chez lui, vérifié par le serveur).
Config.Gestures = {
    sink = { models = { 'prop_sink_02', 'prop_sink_04', 'prop_sink_05', 'prop_sink_06', 'v_res_mbsink', 'v_res_tre_sink', 'prop_ff_sink_01', 'prop_ff_sink_02', 'v_ilev_mm_faucet' },
        options = {
            { label = 'Se laver les mains', icon = 'fa-solid fa-hands-bubbles', dict = 'missheist_agency3aig_23', clip = 'urinal_sink_loop', ms = 5000, clean = true },
            { label = 'Se rafraîchir le visage', icon = 'fa-solid fa-face-smile', dict = 'switch@michael@wash_face', clip = 'loop_michael', ms = 6000, clean = true },
        } },
    shower = { models = { 'prop_shower_rack_01', 'v_ilev_ph_bench' },
        options = {
            { label = 'Prendre une douche', icon = 'fa-solid fa-shower', dict = 'mp_safehouseshower@male@', clip = 'male_shower_idle_a', dictF = 'mp_safehouseshower@female@', clipF = 'shower_idle_a', ms = 10000, clean = true },
        } },
    drink = { models = { 'prop_watercooler', 'prop_watercooler_dark', 'prop_fountain2', 'prop_fountain1' },
        options = {
            { label = 'Boire un peu d\'eau', icon = 'fa-solid fa-glass-water', dict = 'mp_player_intdrink', clip = 'loop_bottle', ms = 4000, drink = true },
            { label = 'S\'asperger le visage', icon = 'fa-solid fa-droplet', dict = 'missheist_agency3aig_23', clip = 'urinal_sink_loop', ms = 4000, clean = true },
        } },
    emsJob = 'ambulance', emsMs = 6000, emsRange = 3.0,
}

-- V12.64 · Salle de sport (proposition n° 206, demandée par le fondateur) : aux salles en plein air, une SÉANCE = `session`
-- exercices différents (pompes, abdos, haltères, yoga, course sur place, `duration` ms chacun, animés) en moins de `window`
-- s. Séance finie : bonus d'endurance pendant `hours` h réelles (souffle au sprint et en apnée, récupération plus rapide),
-- gardé même après une reconnexion ou un redémarrage. Gratuit ; les exercices sont vérifiés par le serveur (durée, lieu).
Config.Gym = {
    places = {
        { label = 'Muscle Beach (Vespucci)', coords = vec3(-1202.6, -1566.2, 4.6), radius = 30.0, blip = true },
        { label = 'Cour de Bolingbroke', coords = vec3(1746.4, 2481.4, 45.7), radius = 35.0, blip = false },
        { label = 'Plage de Sandy Shores', coords = vec3(1393.2, 3606.6, 34.98), radius = 20.0, blip = false },
    },
    exercises = {
        { id = 'pushups', label = 'Pompes', icon = 'person', anim = { dict = 'amb@world_human_push_ups@male@base', clip = 'base' } },
        { id = 'situps', label = 'Abdominaux', icon = 'person', anim = { dict = 'amb@world_human_sit_ups@male@base', clip = 'base' } },
        { id = 'weights', label = 'Haltères', icon = 'dumbbell', anim = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', clip = 'base' },
          prop = { model = 'prop_curl_bar_01', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } } },
        { id = 'yoga', label = 'Étirements (yoga)', icon = 'spa', anim = { dict = 'amb@world_human_yoga@male@base', clip = 'base_a' } },
        { id = 'jog', label = 'Course sur place', icon = 'person-running', anim = { dict = 'amb@world_human_jog_standing@male@idle_a', clip = 'idle_a' } },
    },
    duration = 20000, session = 3, window = 900, hours = 6,
    bonus = { stamina = 100, lung = 100, regen = 0.15 }, -- statistiques du jeu (0-100) et récupération du souffle au sprint
}
