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
