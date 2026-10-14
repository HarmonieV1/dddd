-- [CONFIG] Radio (pma-voice). Parler : maintenir Verr. Maj (convar voice_defaultRadio). Menu : W (radial, Z en QWERTY) → Radio, ou /radio.
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
    [11] = { jobs = { 'police', 'ambulance', 'mechanic' }, label = 'Urgences (tous services)', onDuty = true },
}

-- Chaque gang a son canal privé dans cette plage (attribué automatiquement, fixe tant que le gang existe).
Config.GangRange = { 500, 999 }

-- V12.51 · Portées de la voix de proximité (mètres), posées par l'export officiel pma-voice `addVoiceMode` (marche quelle que
-- soit la version de pma-voice, sans retoucher ses fichiers). Avant : 1,5 / 3 / 6 m en audio natif, on ne s'entendait qu'en criant.
-- Les noms restent ceux de pma-voice (Whisper / Normal / Shouting) : l'affichage français est fait par gs_details et gs_hud.
Config.VoiceRanges = { Whisper = 2.0, Normal = 6.0, Shouting = 14.0 }
