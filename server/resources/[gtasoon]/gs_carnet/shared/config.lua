-- [CONFIG] V8 · Chaque voiture a une histoire (véhicules de joueurs uniquement). Le serveur relève tout seul, toutes les
-- 30 s, les véhicules conduits : kilomètres, accidents (carrosserie qui chute d'un coup), changements de propriétaire,
-- de peinture. Les crimes liés au véhicule ne sont visibles que par la police. /histoire au volant : l'historique public
-- (pratique avant d'acheter une occasion à un autre joueur).
Config = {}
Config.Sample = 30          -- s entre deux relevés
Config.MaxSpeed = 90.0      -- m/s : au-delà, la distance n'est pas comptée (téléportation, bug)
Config.Accident = 150.0     -- chute de carrosserie (sur 1000) entre deux relevés = accident
Config.Keep = 25            -- événements gardés par véhicule
Config.PoliceJob = 'police'

-- V8 · Fausses plaques (marché noir) : la voiture n'est plus reliée à ses signalements ni à son carnet. Mais le numéro de
-- châssis ne colle plus : un policier qui vérifie la plaque voit la fraude. La vraie plaque revient au bout de `minutes`
-- (ou en réutilisant l'objet). Remets-la avant de ranger la voiture au garage.
Config.FakePlate = { item = 'gs_fakeplate', minutes = 45, range = 4.0 }
