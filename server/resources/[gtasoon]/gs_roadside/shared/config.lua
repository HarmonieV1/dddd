-- [CONFIG] V8 · Rencontres de la route. Jamais imposées : pas de point sur la carte, pas de notification, pas de quête.
-- La scène est simplement là, sur le bas-côté ; on s'arrête ou on passe son chemin. Rares (le serveur tire au sort et
-- impose un délai entre deux rencontres), seulement en roulant hors de Los Santos, jamais pendant une poursuite.
Config = {}

Config.RollEvery = 150        -- s de route hors de la ville entre deux tirages
Config.Chance = 0.35          -- chance qu'un tirage donne une rencontre
Config.Cooldown = 35          -- min entre deux rencontres (par personnage)
Config.MinSpeed = 13.0        -- m/s (~47 km/h) : il faut rouler pour en croiser
Config.Lifetime = 480         -- s : la scène disparaît si on l'ignore
Config.SpawnAhead = 230.0     -- m devant le véhicule

--- Hors de Los Santos (route de campagne, autoroutes, désert, côte)
function Config.IsRural(x, y)
    return y > 1100.0 or x > 1550.0 or x < -2300.0
end

-- type = { poids du tirage, variante dangereuse (chance, la nuit surtout), récompenses }
Config.Types = {
    hitchhiker = { label = 'Auto-stoppeur', weight = 22, danger = 0.15, nightDanger = 0.3, pay = { 150, 450 }, minDistance = 800.0 },
    breakdown  = { label = 'Voiture en panne', weight = 18, danger = 0.12, nightDanger = 0.25, pay = { 250, 600 } },
    accident   = { label = 'Accident', weight = 12, pay = { 300, 700 }, item = 'bandage' },
    animal     = { label = 'Animal blessé', weight = 10, pay = { 80, 200 }, item = 'bandage' },
    wallet     = { label = 'Portefeuille perdu', weight = 12, returned = { 400, 900 }, kept = { 150, 350 } },
    vendor     = { label = 'Vendeur ambulant', weight = 12 },
    sheriff    = { label = 'Contrôle du shérif', weight = 14, fine = 750, points = 2 },
}
Config.Friend = { chance = 0.35, gift = { 200, 600 } }   -- l'auto-stoppeur aidé revient parfois (cadeau, tuyau)
Config.Rob = { max = 800 }                                -- auto-stoppeur braqueur : cash pris au maximum

-- Villes où déposer un auto-stoppeur / rendre un portefeuille
Config.Places = {
    { label = 'Sandy Shores', coords = vec3(1961.6, 3740.0, 32.3) },
    { label = 'Paleto Bay', coords = vec3(-136.0, 6357.0, 31.5) },
    { label = 'Grapeseed', coords = vec3(1700.0, 4805.0, 42.0) },
    { label = 'Harmony', coords = vec3(1180.0, 2640.0, 37.8) },
    { label = 'Chumash', coords = vec3(-3150.0, 1100.0, 20.7) },
    { label = 'Mirror Park', coords = vec3(1150.0, -480.0, 66.0) },
    { label = 'Del Perro', coords = vec3(-1600.0, -500.0, 35.0) },
    { label = 'Vinewood', coords = vec3(300.0, 170.0, 103.0) },
}

-- Modèles (PNJ et véhicules du jeu de base)
Config.Models = {
    hitchhiker = { 'a_m_y_hippy_01', 'a_f_y_hippie_01', 'a_m_y_hiker_01', 'a_f_y_hiker_01', 'a_m_m_hillbilly_01', 'a_m_y_beach_01' },
    robber = { 'g_m_y_lost_01', 'a_m_y_methhead_01' },
    driver = { 'a_m_m_farmer_01', 'a_f_m_salton_01', 'a_m_m_salton_02', 'a_f_y_tourist_01' },
    car = { 'emperor', 'regina', 'stanier', 'bfinjection', 'rebel', 'dloader' },
    ambush = { 'g_m_y_lost_02', 'g_m_y_lost_03' },
    vendor = { ped = 's_m_m_strvend_01', van = 'taco' },
    sheriff = { ped = 's_m_y_sheriff_01', car = 'sheriff' },
    animal = { 'a_c_deer', 'a_c_coyote', 'a_c_boar' },
}

-- Vendeur ambulant : quelques articles, prix de bord de route
Config.Vendor = {
    { item = 'sandwich', price = 20 }, { item = 'water', price = 8 }, { item = 'coffee', price = 12 },
    { item = 'bandage', price = 90 }, { item = 'repairkit', price = 320 }, { item = 'gs_gloves', price = 80 },
}

-- Carnet de route : les rencontres à collectionner (titres cosmétiques à venir)
Config.Collection = {
    { 'hitchhiker', 'Auto-stoppeur déposé' }, { 'robbed', 'Auto-stoppeur louche' }, { 'friend', 'Un vieil ami de la route' },
    { 'breakdown', 'Dépannage' }, { 'ambush', 'Fausse panne' }, { 'accident', 'Premiers secours' }, { 'animal', 'Animal soigné' },
    { 'wallet_returned', 'Portefeuille rendu' }, { 'wallet_kept', 'Portefeuille gardé' }, { 'vendor', 'Vendeur ambulant' },
    { 'sheriff', 'Contrôle du shérif' }, { 'sheriff_fled', 'Refus d\'obtempérer' },
}
