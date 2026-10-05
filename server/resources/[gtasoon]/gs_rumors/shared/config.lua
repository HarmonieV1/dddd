-- [CONFIG] V8 · La ville parle. Les rumeurs naissent des VRAIS événements du serveur (crimes signalés, arrestations,
-- évasions, tempêtes…), avec ce que les témoins ont vu — jamais l'identité, sauf visage connu. Les barmans en
-- racontent un bout gratuitement, le reste se paie. L'indic' vend ce qu'il sait des gangs… et parle aussi des clients.
Config = {}

Config.Keep = 40          -- rumeurs gardées
Config.MaxAge = 120       -- min : au-delà, plus personne n'en parle
Config.FreeMinAge = 10    -- min : la rumeur gratuite est toujours un peu vieille
Config.Price = 250        -- « Ce que tu sais vraiment » (3 rumeurs détaillées)

Config.Tellers = {
    { label = 'Barman du Yellow Jack', coords = vec4(1984.6, 3052.6, 47.2, 240.0), model = 's_m_y_barman_01' },
    { label = 'Barmaid du Vanilla Unicorn', coords = vec4(128.9, -1283.6, 29.3, 120.0), model = 's_f_y_bartender_01' },
    { label = 'Barman du Bahama Mamas', coords = vec4(-1388.0, -606.0, 30.3, 120.0), model = 's_m_y_barman_01' },
    { label = 'Patronne du Hen House', coords = vec4(-305.0, 6265.0, 31.5, 40.0), model = 'a_f_m_salton_01' },
    { label = 'Pompiste de Route 68', coords = vec4(1039.0, 2664.0, 39.6, 0.0), model = 'a_m_m_hillbilly_02' },
}

-- L'indic' : activités des gangs (livraisons au receleur, atelier, coups) ; il peut balancer l'acheteur
Config.Informants = {
    { label = 'L\'indic\' du pont de Davis', coords = vec4(46.5, -1748.9, 29.6, 50.0), model = 'a_m_m_tramp_01' },
    { label = 'L\'indic\' des docks', coords = vec4(1207.0, -3120.0, 5.5, 0.0), model = 'a_m_y_methhead_01' },
}
Config.Indic = { price = 600, leak = 0.3, fenceTip = 0.5, keep = 30, maxAge = 180 }

-- Quartiers (pour situer une rumeur sans donner de position exacte)
Config.Zones = {
    { 'Grove Street', 105.0, -1940.0 }, { 'Davis', 20.0, -1700.0 }, { 'Vespucci', -1200.0, -1450.0 }, { 'Del Perro', -1550.0, -550.0 },
    { 'Downtown', 200.0, -900.0 }, { 'Mission Row', 430.0, -1000.0 }, { 'Vinewood', 300.0, 200.0 }, { 'Rockford Hills', -800.0, -150.0 },
    { 'Mirror Park', 1150.0, -500.0 }, { 'La Mesa', 800.0, -1100.0 }, { 'Port de Los Santos', 900.0, -3000.0 }, { 'l\'aéroport', -1100.0, -2700.0 },
    { 'Little Seoul', -700.0, -1000.0 }, { 'Chumash', -3150.0, 1100.0 }, { 'Harmony', 1150.0, 2650.0 }, { 'Sandy Shores', 1900.0, 3750.0 },
    { 'Grapeseed', 1700.0, 4800.0 }, { 'Paleto Bay', -150.0, 6350.0 }, { 'Mont Chiliad', 500.0, 5600.0 }, { 'Vinewood Hills', -400.0, 900.0 },
}

-- V10.2 · Les rumeurs qui deviennent vraies : chez un barman, on paie un verre pour « faire courir un bruit ». Quand
-- `threshold` personnes DIFFÉRENTES ont lancé le même bruit en `window` s, le staff est prévenu et valide (/rumeurvraie)
-- ou refuse (/rumeurfausse) ; sans réponse du staff au bout de `autoAfter` s, la ville tranche seule (ça arrive).
Config.Seeds = {
    threshold = 3, window = 7200, cooldown = 5400, autoAfter = 600, price = 50, staffLevel = 2,
    list = {
        { id = 'storm', label = 'Une grosse tempête arrive sur le comté', fact = 'La tempête dont tout le monde parlait arrive sur le comté !' },
        { id = 'stash', label = 'Un sac de billets aurait été caché quelque part', fact = 'Un sac de billets a été caché du côté de %s. À vous de le trouver.' },
        { id = 'crime', label = 'Un sale coup se prépare en ville cette nuit', fact = 'Le sale coup annoncé a eu lieu : la police est appelée.' },
    },
    stash = { minutes = 45, reward = { 1500, 4000 }, dirty = true, model = 'prop_money_bag_01',
        spots = { vec3(-104.8, 6316.2, 31.5), vec3(1704.3, 3790.5, 34.6), vec3(-1172.9, -1572.6, 4.7), vec3(1229.8, -3170.4, 5.9),
            vec3(-428.5, 1110.2, 327.7), vec3(2556.1, 382.8, 108.6) } },
}
