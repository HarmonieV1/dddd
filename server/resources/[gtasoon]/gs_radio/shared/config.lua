-- [CONFIG] Radio (pma-voice). Parler : maintenir Verr. Maj (convar voice_defaultRadio). Menu : Z (radial) → Radio, ou /radio.
Config = {}

Config.Item = 'radio'            -- objet requis (sans lui : radio coupée)
Config.ItemCheck = 5000          -- ms entre deux vérifications de l'objet quand on est connecté
Config.MaxChannel = 999.99

-- Canaux réservés aux métiers (job actif ; en service si onDuty = true). Les autres canaux sont libres.
Config.JobChannels = {
    [1] = { jobs = { 'police' }, label = 'LSPD', onDuty = true },
    [2] = { jobs = { 'police' }, label = 'LSPD tactique', onDuty = true },
    [3] = { jobs = { 'police', 'ambulance' }, label = 'Police + EMS (commun)', onDuty = true },
    [4] = { jobs = { 'ambulance' }, label = 'EMS', onDuty = true },
    [5] = { jobs = { 'mechanic' }, label = 'Mécanos', onDuty = false },
    [6] = { jobs = { 'taxi' }, label = 'Taxis', onDuty = false },
    [7] = { jobs = { 'trucker', 'bus' }, label = 'Transport', onDuty = false },
    [8] = { jobs = { 'weazel' }, label = 'Weazel News', onDuty = false },
    [9] = { jobs = { 'judge', 'lawyer', 'cityhall' }, label = 'Justice et mairie', onDuty = false },
    [10] = { jobs = { 'realestate', 'cardealer' }, label = 'Commerciaux', onDuty = false },
}

-- Chaque gang a son canal privé dans cette plage (attribué automatiquement, fixe tant que le gang existe).
Config.GangRange = { 500, 999 }
