-- [CONFIG] Petits détails.
Config = {}

Config.Me = { range = 20.0, seconds = 7, maxLength = 120 }   -- /me et /do : texte au-dessus de la tête
Config.HandsUpKey = 'H'   -- à pied seulement (en voiture, H = démarrer sans clé) ; X = annuler une emote (scully)
Config.SeatbeltKey = 'B'
Config.Ejection = { minDrop = 18.0 }  -- m/s perdus d'un coup sans ceinture = éjection (~65 km/h)

-- V11.5 · Armes longues visibles dans le dos quand elles sont rangées (pistolets et armes blanches : jamais).
-- `slots` : jusqu'à `max` armes, 1re en travers du dos (droite), 2e à gauche. Décalages (m) et rotations (°) sur l'os
-- `bone` : 24818 = SKEL_Spine3 (défaut), 24816 = SKEL_Spine2 (un peu plus bas).
-- V12.37 · Réglage en direct par le staff : /dosreglage (menu : ±1 cm, ±2°, bascule d'os, saisie exacte, « Copier le bloc »
-- → coller ici à la place des lignes `bone` et `slots`). `refresh` (ms) : voisins rafraîchis toutes les `busy` ms quand
-- quelqu'un autour porte une arme dans le dos, `idle` sinon ; `sweep` = balayage des objets orphelins. Pas de boucle par image.
Config.Back = {
    bone = 24818, max = 2, range = 60.0,
    refresh = { busy = 400, idle = 2000, sweep = 5000 }, -- V12.37
    tune = { pos = 0.01, rot = 2.0 },                    -- V12.37 : pas du menu /dosreglage (1 cm, 2°)
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

-- V12.26 · Garde-robe (touche U ou /garderobe) : chaque pièce portée peut être retirée et devient un objet « Vêtement »
-- (gs_cloth), à enfiler d'un double-clic dans l'inventaire ou depuis la garde-robe ; la pièce remplacée revient dans le sac.
-- kind = 'c' composant / 'p' accessoire (prop) ; arms = le haut emporte les bras assortis (sinon ils ne collent plus).
-- side = colonne autour du personnage. none = valeur « rien porté » par modèle (m = homme, f = femme).
Config.Wardrobe = {
    key = 'U',
    slots = {
        { key = 'hat',      kind = 'p', id = 0,  label = 'Chapeau',            image = 'cloth_hat',      side = 'left' },
        { key = 'glasses',  kind = 'p', id = 1,  label = 'Lunettes',           image = 'cloth_glasses',  side = 'left' },
        { key = 'ears',     kind = 'p', id = 2,  label = 'Boucles d\'oreilles', image = 'cloth_ears',     side = 'left' },
        { key = 'mask',     kind = 'c', id = 1,  label = 'Masque',             image = 'cloth_mask',     side = 'left', none = { m = 0, f = 0 } },
        { key = 'chain',    kind = 'c', id = 7,  label = 'Collier / cravate',  image = 'cloth_chain',    side = 'left', none = { m = 0, f = 0 } },
        { key = 'watch',    kind = 'p', id = 6,  label = 'Montre',             image = 'cloth_watch',    side = 'left' },
        { key = 'bracelet', kind = 'p', id = 7,  label = 'Bracelet',           image = 'cloth_bracelet', side = 'left' },
        { key = 'top',      kind = 'c', id = 11, label = 'Haut / veste',       image = 'cloth_top',      side = 'right', none = { m = 15, f = 15 }, arms = { m = 15, f = 15 } },
        { key = 'shirt',    kind = 'c', id = 8,  label = 'T-shirt / dessous',  image = 'cloth_shirt',    side = 'right', none = { m = 15, f = 14 } },
        { key = 'vest',     kind = 'c', id = 9,  label = 'Gilet',              image = 'cloth_vest',     side = 'right', none = { m = 0, f = 0 } },
        { key = 'bag',      kind = 'c', id = 5,  label = 'Sac',                image = 'cloth_bag',      side = 'right', none = { m = 0, f = 0 } },
        { key = 'legs',     kind = 'c', id = 4,  label = 'Pantalon / jupe',    image = 'cloth_legs',     side = 'right', none = { m = 61, f = 14 } },
        { key = 'shoes',    kind = 'c', id = 6,  label = 'Chaussures',         image = 'cloth_shoes',    side = 'right', none = { m = 34, f = 35 } },
    },
}

-- V12.63 · Vitesse maximale par modèle (km/h), appliquée quand on prend le volant : pour les voitures importées dont le
-- réglage (handling) n'a pas de limite. Nom du modèle = nom de spawn. Ex. backtest du 16/10 : cycloneex0 sans limite.
Config.SpeedCaps = { cycloneex0 = 210 }
