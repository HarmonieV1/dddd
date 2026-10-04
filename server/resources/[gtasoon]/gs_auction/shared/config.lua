-- [CONFIG] gs_auction · V10.1 « Enchères de la fourrière »
Config = {}
Config.Point = vec3(403.9, -1625.6, 29.29)  -- fourrière de Davis, à côté du guichet du garage (déplaçable : F11 → Déplacer un point)
Config.Day, Config.Hour, Config.Minutes = 7, 21, 30 -- samedi (1 = dimanche … 7 = samedi), 21 h, pendant 30 min
Config.PoliceJob = 'police'
Config.MaxLots, Config.MaxVehicles = 16, 4
Config.MinStart = 50                -- mise de départ minimale ($)
Config.StepPct, Config.MinStep = 0.05, 50 -- surenchère : +5 % (au moins 50 $)
Config.VehicleStart = 0.25          -- véhicule abandonné : mise de départ = 25 % du prix catalogue
Config.UnsoldFactor = 0.8           -- lot invendu : remis la semaine suivante à 80 %
Config.MaxWeeks = 4                 -- au-delà, le lot invendu est détruit
Config.DepositRange = 15.0          -- la police dépose ses saisies sur place
Config.Account = 'bank'             -- les mises sont bloquées sur le compte en banque
