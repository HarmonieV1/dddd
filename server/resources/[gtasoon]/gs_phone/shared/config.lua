-- [CONFIG] Téléphone.
Config = {}

Config.Key = 'F1'
Config.RequireItem = 'phone'        -- item ox_inventory nécessaire (false = pas d'item requis)
Config.NumberPrefix = '555'         -- numéros au format 555-1234
Config.MessageMaxLength = 300
Config.MaxContacts = 200
Config.RingSeconds = 30             -- sonnerie avant « pas de réponse »
Config.TransferMax = 1000000
Config.BlockLinks = true

-- Appels d'urgence : reçus par les joueurs EN SERVICE de ces jobs
Config.Emergency = {
    police = { label = 'Police (LSPD)', jobs = { 'police' } },
    ems = { label = 'Urgences médicales (EMS)', jobs = { 'ambulance' } },
    mechanic = { label = 'Dépanneuse', jobs = { 'mechanic' } },
}
Config.EmergencyBlipSeconds = 120
