-- [CONFIG] Assurance auto (Mors Mutual). La prime dépend du prix du véhicule ; la fourrière (qbx_garages) coûte `impoundFactor` du tarif normal.
Config = {}

Config.Counter = { label = 'Mors Mutual Insurance', coords = vec3(-826.0, -238.0, 37.2) } -- [À CALER] agence
Config.Range = 3.5
Config.Days = 7
Config.PremiumRate = 0.04         -- 4 % du prix du véhicule par semaine
Config.PremiumMin = 300
Config.PremiumMax = 25000
Config.DefaultPrice = 20000       -- si le prix du véhicule est inconnu (véhicule ajouté par le staff)
Config.ImpoundFactor = 0.25       -- assuré : 25 % du tarif de fourrière
Config.MaxDaysAhead = 28          -- on ne peut pas s'assurer plus de 4 semaines à l'avance

-- V9 · Déclarations de vol (et fraude). L'expert recoupe avec le carnet du véhicule (gs_carnet) : si le propriétaire
-- est vu au volant ou si la voiture change de main après la déclaration, c'est une arnaque.
Config.Claim = {
    rate = 0.6,             -- indemnité : 60 % du prix du véhicule
    max = 150000,
    review = 45,            -- minutes d'enquête de l'expert avant le versement
    recent = 10,            -- refus si le propriétaire conduisait la voiture il y a moins de 10 min
    minInsuredHours = 24,   -- il faut être assuré depuis au moins 24 h (pas d'assurance « la veille du vol »)
    cooldownDays = 14,      -- une déclaration par joueur toutes les 2 semaines
    penalty = 0.5,          -- fraude : remboursement + 50 % d'amende
    charge = 'Fraude à l\'assurance',
}

-- V12 · Le registre des véhicules disparus : un dossier de vol jamais clos refait surface après `afterHours`.
-- fates : casse (à la casse, récupérable), garage (garage louche, récupérable), encheres (fourrière, samedi 21 h).
Config.Lost = {
    afterHours = 48, tick = 30, spawnRange = 140.0, keepDays = 14,
    fates = { { id = 'casse', weight = 0.45 }, { id = 'garage', weight = 0.35 }, { id = 'encheres', weight = 0.20 } },
    places = {
        casse = { vec4(-468.0, -1717.0, 18.7, 300.0), vec4(2346.0, 3048.0, 48.1, 60.0), vec4(1016.0, -2524.0, 28.3, 90.0) },     -- Rogers Salvage, Sandy, Cypress Flats
        garage = { vec4(-1152.0, -1500.0, 4.3, 125.0), vec4(1181.0, -3278.0, 5.9, 90.0), vec4(880.0, -2195.0, 30.6, 180.0), vec4(-1081.0, -2100.0, 13.2, 320.0) },
    },
}
