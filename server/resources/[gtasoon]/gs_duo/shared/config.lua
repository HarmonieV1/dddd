-- [CONFIG] Duo criminel lié (inspiré du duo de GTA 6, mécanique maison).
-- Deux personnages se lient (consentement des deux). Le lien est persistant et progresse :
-- temps passé ensemble + contrats réussis → niveau → meilleure paie, chaleur partagée réduite.
Config = {}

Config.InviteRange = 4.0
Config.InviteTimeout = 60          -- s
Config.LeaveCooldown = 3600        -- s avant de pouvoir refonder un duo après une rupture
Config.NameMaxLength = 24

Config.PartnerBlipSeconds = 3      -- fréquence d'envoi de la position du partenaire
Config.TogetherRadius = 100.0
Config.TogetherXp = 2              -- XP toutes les 5 min passées ensemble
Config.TogetherMinutes = 5

-- Niveaux : XP requise, bonus de paie, part de chaleur transmise au partenaire proche
Config.Levels = {
    { xp = 0,   pay = 1.00, heatShare = 0.50, label = 'Complices' },
    { xp = 60,  pay = 1.05, heatShare = 0.45, label = 'Associés' },
    { xp = 180, pay = 1.10, heatShare = 0.35, label = 'Partenaires' },
    { xp = 400, pay = 1.20, heatShare = 0.25, label = 'Inséparables' },
    { xp = 800, pay = 1.30, heatShare = 0.15, label = 'Légendes' },
}
Config.HeatShareRadius = 50.0

-- Contrats à deux : les DEUX membres doivent être sur chaque étape (anti-solo, anti-TP).
Config.Contract = {
    radius = 25.0,                 -- les deux membres à moins de X m de l'étape
    tolerance = 4.0,
    minStepDistance = 400.0,
    maxSpeed = 75.0,               -- m/s crédibles
    cooldown = 600,                -- s entre deux contrats pour un duo
    payEach = { 900, 1400 },       -- par membre, × bonus de niveau
    xp = 25,
    crime = 'duo_contract',        -- signalé via gs_wanted à l'étape de récupération
    stepDuration = 5000,
    pickups = {
        vec3(1197.0, -3253.0, 7.1),    -- Docks Elysian
        vec3(-1147.0, -2020.0, 13.2),  -- Hangar LSIA
        vec3(844.0, -2118.0, 30.5),    -- Entrepôt Cypress
        vec3(2672.0, 1612.0, 24.5),    -- Centrale Palmer-Taylor
    },
    drops = {
        vec3(-58.0, 6445.0, 31.5),     -- Paleto Bay
        vec3(1720.0, 4800.0, 42.0),    -- Grapeseed
        vec3(-3170.0, 1100.0, 20.8),   -- Chumash
        vec3(2555.0, 4670.0, 34.0),    -- Grapeseed Est
    },
}
