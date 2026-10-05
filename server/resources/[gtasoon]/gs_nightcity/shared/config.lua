-- [CONFIG] gs_nightcity · Ville de jour / ville de nuit. Purement en plus : aucun commerce existant ne ferme, aucun PNJ
-- existant ne change. Heures = heure du jeu (gs_weather). Positions déplaçables en jeu (F11 → Déplacer un point).
Config = {}
Config.Night = { from = 22, to = 5 }   -- la nuit : 22 h → 5 h
Config.Day = { from = 8, to = 19 }     -- le jour : 8 h → 19 h
Config.SpawnRange, Config.DespawnRange = 90.0, 120.0

-- Ambiance : groupes de PNJ (scénarios du jeu) selon le moment
Config.Ambience = {
    { when = 'night', label = 'Sortie du Vanilla Unicorn', coords = vec4(127.6, -1306.4, 29.2, 210.0),
      peds = { { 'a_f_y_clubcust_01', 'WORLD_HUMAN_PARTYING' }, { 'a_m_y_clubcust_01', 'WORLD_HUMAN_SMOKING' }, { 'a_m_y_clubcust_02', 'WORLD_HUMAN_DRINKING' } } },
    { when = 'night', label = 'File du Bahama Mamas', coords = vec4(-1392.1, -583.7, 30.2, 300.0),
      peds = { { 'a_f_y_clubcust_02', 'WORLD_HUMAN_STAND_MOBILE' }, { 'a_m_y_clubcust_03', 'WORLD_HUMAN_PARTYING' }, { 'a_f_y_clubcust_03', 'WORLD_HUMAN_SMOKING' } } },
    { when = 'night', label = 'Feu de camp à Vespucci', coords = vec4(-1381.5, -1600.4, 2.2, 0.0),
      peds = { { 'a_m_y_beach_01', 'WORLD_HUMAN_DRINKING' }, { 'a_f_y_beach_01', 'WORLD_HUMAN_PARTYING' }, { 'a_m_y_beach_02', 'WORLD_HUMAN_MUSICIAN' } } },
    { when = 'day', label = 'Musicien de Legion Square', coords = vec4(196.8, -938.9, 30.7, 150.0),
      peds = { { 'a_m_y_hipster_01', 'WORLD_HUMAN_MUSICIAN' }, { 'a_f_y_tourist_01', 'WORLD_HUMAN_TOURIST_MAP' } } },
    { when = 'day', label = 'Pêcheurs de la jetée', coords = vec4(-1851.3, -1251.6, 8.6, 140.0),
      peds = { { 'a_m_m_salton_01', 'WORLD_HUMAN_STAND_FISHING' }, { 'a_m_o_beach_01', 'WORLD_HUMAN_STAND_FISHING' } } },
}

-- Marchés de nuit : un stand avec vendeur, ouvert seulement la nuit (vérifié par le serveur)
Config.Markets = {
    { label = 'Food truck de Legion Square', coords = vec4(194.6, -931.9, 30.7, 150.0), model = 's_m_m_linecook' },
    { label = 'Stand de la jetée de Del Perro', coords = vec4(-1637.4, -1018.6, 13.1, 50.0), model = 'a_f_y_beach_01' },
    { label = 'Stand de Vinewood', coords = vec4(-556.9, 267.8, 83.0, 175.0), model = 's_m_y_strvend_01' },
}
Config.MarketItems = {
    { item = 'sandwich', price = 35 }, { item = 'coffee', price = 15 }, { item = 'gs_donut', price = 12 },
    { item = 'gs_chips', price = 10 }, { item = 'gs_energy', price = 20 }, { item = 'beer', price = 18 },
}
Config.MarketRange = 4.0
