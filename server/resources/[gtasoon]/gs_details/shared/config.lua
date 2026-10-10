-- [CONFIG] Petits détails.
Config = {}

Config.Me = { range = 20.0, seconds = 7, maxLength = 120 }   -- /me et /do : texte au-dessus de la tête
Config.HandsUpKey = 'H'   -- à pied seulement (en voiture, H = démarrer sans clé) ; X = annuler une emote (scully)
Config.SeatbeltKey = 'B'
Config.Ejection = { minDrop = 18.0 }  -- m/s perdus d'un coup sans ceinture = éjection (~65 km/h)

-- V11.5 · Armes longues visibles dans le dos quand elles sont rangées (pistolets et armes blanches : jamais).
-- `slots` : jusqu'à `max` armes, 1re en travers du dos (droite), 2e à gauche. Offsets sur l'os SKEL_Spine3 (24818).
Config.Back = {
    bone = 24818, max = 2, range = 60.0,
    slots = {
        { x = 0.10, y = -0.15, z = -0.10, rx = 0.0, ry = 165.0, rz = 0.0 },
        { x = -0.10, y = -0.15, z = -0.10, rx = 0.0, ry = 195.0, rz = 0.0 },
    },
    weapons = {
        WEAPON_PUMPSHOTGUN = true, WEAPON_PUMPSHOTGUN_MK2 = true, WEAPON_SAWNOFFSHOTGUN = true, WEAPON_ASSAULTSHOTGUN = true,
        WEAPON_BULLPUPSHOTGUN = true, WEAPON_HEAVYSHOTGUN = true, WEAPON_DBSHOTGUN = true, WEAPON_AUTOSHOTGUN = true, WEAPON_COMBATSHOTGUN = true,
        WEAPON_ASSAULTRIFLE = true, WEAPON_ASSAULTRIFLE_MK2 = true, WEAPON_CARBINERIFLE = true, WEAPON_CARBINERIFLE_MK2 = true,
        WEAPON_ADVANCEDRIFLE = true, WEAPON_SPECIALCARBINE = true, WEAPON_SPECIALCARBINE_MK2 = true, WEAPON_BULLPUPRIFLE = true,
        WEAPON_BULLPUPRIFLE_MK2 = true, WEAPON_COMPACTRIFLE = true, WEAPON_MILITARYRIFLE = true, WEAPON_HEAVYRIFLE = true,
        WEAPON_TACTICALRIFLE = true, WEAPON_BATTLERIFLE = true, WEAPON_SMG = true, WEAPON_SMG_MK2 = true, WEAPON_ASSAULTSMG = true,
        WEAPON_COMBATPDW = true, WEAPON_GUSENBERG = true, WEAPON_MG = true, WEAPON_COMBATMG = true, WEAPON_COMBATMG_MK2 = true,
        WEAPON_SNIPERRIFLE = true, WEAPON_HEAVYSNIPER = true, WEAPON_HEAVYSNIPER_MK2 = true, WEAPON_MARKSMANRIFLE = true,
        WEAPON_MARKSMANRIFLE_MK2 = true, WEAPON_PRECISIONRIFLE = true, WEAPON_MUSKET = true,
    },
}

-- Kits (items ox_inventory avec client.export = 'gs_details.<nom>')
Config.Kits = {
    repair = { duration = 10000, engine = 750.0 },     -- kit de réparation : moteur remis à 75 % (le mécano fait le reste)
    advancedRepair = { duration = 15000 },             -- kit avancé : réparation complète
    clean = { duration = 5000 },
    range = 3.5,
}
