-- [CONFIG] État civil (mairie).
Config = {}

Config.Desk = vec3(-545.1, -204.3, 38.2)   -- [À CALER] guichet de l'état civil
Config.Range = 6.0
Config.Job = 'cityhall'                     -- un agent en service à proximité célèbre le mariage (sinon : guichet)
Config.MarriageFee = 1000                   -- payé par chacun des deux
Config.DivorceFee = 2500                    -- payé par celui qui demande
Config.ProposalTimeout = 60
