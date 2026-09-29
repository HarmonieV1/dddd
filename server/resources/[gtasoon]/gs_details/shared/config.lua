-- [CONFIG] Petits détails.
Config = {}

Config.Me = { range = 20.0, seconds = 7, maxLength = 120 }   -- /me et /do : texte au-dessus de la tête
Config.HandsUpKey = 'X'
Config.SeatbeltKey = 'B'
Config.Ejection = { minDrop = 18.0 }  -- m/s perdus d'un coup sans ceinture = éjection (~65 km/h)

-- Kits (items ox_inventory avec client.export = 'gs_details.<nom>')
Config.Kits = {
    repair = { duration = 10000, engine = 750.0 },     -- kit de réparation : moteur remis à 75 % (le mécano fait le reste)
    advancedRepair = { duration = 15000 },             -- kit avancé : réparation complète
    clean = { duration = 5000 },
    range = 3.5,
}
