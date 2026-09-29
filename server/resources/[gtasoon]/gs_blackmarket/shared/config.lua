-- [CONFIG] Marché noir + cohérence des munitions.
-- Logique : le légal (Ammu-Nation) vend peu de calibres, avec permis et en quantité limitée par jour → les gangs et
-- les braqueurs doivent passer par le marché noir : plus cher, stock limité, risqué (signalement possible), la nuit.
-- L'argent sale des braquages y est accepté (et y est la monnaie normale) : ça fait tourner l'économie illégale.
Config = {}

Config.DirtyItem = 'black_money'
Config.CashMarkup = 1.4             -- payer en liquide propre coûte 40 % de plus
Config.PoliceJob = 'police'

-- Contact : PNJ qui change de planque toutes les `rotateMinutes`. Ouvert la nuit seulement (heure du jeu).
Config.Dealer = {
    model = 'g_m_m_armboss_01', hours = { 20, 6 }, rotateMinutes = 120, reportChance = 0.12, maxHeat = 60,
    locations = {
        vec4(1087.5, -2002.2, 30.9, 320.0),   -- Cypress Flats, entrepôts
        vec4(-1152.2, -1521.6, 4.3, 30.0),    -- Vespucci, ruelle
        vec4(478.8, -1316.6, 29.2, 110.0),    -- La Mesa, casse
        vec4(1394.1, 3613.9, 34.9, 200.0),    -- Sandy Shores, Ace Liquor (arrière)
        vec4(-455.6, 6006.9, 31.3, 45.0),     -- Paleto, derrière le shérif
    },
}

-- Accès : membre d'un gang (n'importe quel grade) OU réputation de rue suffisante (gs_reputation).
Config.Access = { streetRep = 15 }
Config.GangDiscount = 0.10          -- -10 % si la planque du jour est dans un quartier tenu par ton gang

-- Catalogue : prix de base en argent sale, stock maximum (réapprovisionné chaque jour à `restockHour`),
-- `weapon = true` : arme non déclarée (sans numéro de série enregistré), 1 par jour et par personnage.
Config.RestockHour = 4
Config.Scarcity = 0.6               -- prix × (1 + 0,6 × part du stock déjà vendue)
Config.Catalog = {
    { item = 'ammo-9', label = 'Munitions 9 mm (×20)', pack = 20, price = 220, stock = 60 },
    { item = 'ammo-45', label = 'Munitions .45 (×20)', pack = 20, price = 260, stock = 40 },
    { item = 'ammo-shotgun', label = 'Cartouches (×10)', pack = 10, price = 300, stock = 30 },
    { item = 'ammo-rifle', label = 'Munitions 5,56 (×30)', pack = 30, price = 650, stock = 25 },
    { item = 'ammo-rifle2', label = 'Munitions 7,62 (×30)', pack = 30, price = 750, stock = 20 },
    { item = 'WEAPON_SNSPISTOL', label = 'Pistolet compact', price = 4500, stock = 6, weapon = true },
    { item = 'WEAPON_PISTOL', label = 'Pistolet', price = 6000, stock = 6, weapon = true },
    { item = 'WEAPON_MICROSMG', label = 'Micro-SMG', price = 18000, stock = 3, weapon = true, gangOnly = true },
    { item = 'WEAPON_SAWNOFFSHOTGUN', label = 'Fusil à canon scié', price = 14000, stock = 3, weapon = true, gangOnly = true },
    { item = 'at_suppressor_light', label = 'Silencieux (pistolet)', price = 8000, stock = 4 },
    { item = 'at_clip_extended_pistol', label = 'Chargeur grande capacité', price = 3000, stock = 6 },
    { item = 'lockpick', label = 'Crochet', price = 150, stock = 40 },
    { item = 'advancedlockpick', label = 'Crochet avancé', price = 900, stock = 10 },
    { item = 'armour', label = 'Gilet pare-balles', price = 2500, stock = 10 },
}

-- Armureries légales (ox_inventory, boutique « Ammunation ») : plafond par personnage et par jour.
Config.Legal = { shopType = 'Ammunation', ammoPerDay = 120, weaponsPerDay = 1,
    free = { WEAPON_KNIFE = true, WEAPON_BAT = true, WEAPON_FLASHLIGHT = true } } -- armes blanches : pas de plafond
