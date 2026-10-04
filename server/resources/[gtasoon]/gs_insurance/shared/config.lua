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
