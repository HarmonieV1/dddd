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
