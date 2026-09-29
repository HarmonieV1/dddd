-- [CONFIG] Progression. Tout se règle ici ; les quêtes sont dans quests.lua.
Config = {}

Config.MaxLevel = 50
--- XP nécessaire pour passer du niveau `level` au suivant (200, 300, 400…).
function Config.StepXP(level) return 100 + 100 * level end
--- Récompense de passage de niveau (banque).
function Config.LevelReward(level) return 150 * level end

-- XP gagnée ailleurs (appelée par les autres ressources via exports.gs_quests:AddXP)
Config.XP = {
    job_mission = 25,     -- mission de métier terminée
    drug_sale = 5,        -- vente de drogue réussie
    heist = 20,           -- point de butin d'un braquage
}

Config.TalkRadius = 3.0
Config.Tolerance = 3.0
Config.Key = 'F5'         -- menu Progression (/progression)

-- Paquets cachés (clin d'œil aux premiers GTA) : invisibles sur la carte, un petit colis au sol quand on passe à côté.
Config.Packages = {
    xp = 50,
    allXp = 2500, allCash = 5000,  -- bonus quand tout est trouvé
    spawnDistance = 40.0,
    points = { -- coords à caler en jeu
        vec3(-1605.1, -1070.4, 13.0), vec3(-1379.5, -1402.0, 3.2), vec3(-1047.3, -2744.7, 13.9), vec3(-58.2, -2517.3, 7.4),
        vec3(1208.3, -3113.6, 5.5), vec3(835.6, -2176.3, 29.7), vec3(96.8, -1940.3, 20.8), vec3(386.2, -738.4, 29.3),
        vec3(-75.1, -818.3, 326.2), vec3(233.8, 1167.9, 225.5), vec3(-424.8, 1123.1, 325.9), vec3(738.9, 1292.4, 360.3),
        vec3(1692.8, 3288.0, 41.1), vec3(1964.7, 3740.3, 32.3), vec3(2451.3, 4960.6, 46.6), vec3(1664.4, 4855.2, 42.0),
        vec3(-275.4, 6228.8, 31.5), vec3(501.4, 5604.1, 797.9), vec3(-1575.6, 5163.0, 19.6), vec3(3070.3, 2205.4, 3.0),
    },
}
