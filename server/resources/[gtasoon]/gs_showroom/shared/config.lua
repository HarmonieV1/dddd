-- [CONFIG] gs_showroom (V12.40) : véhicules d'exposition des concessions, posés en jeu par le staff (F11 → Monde et lieux →
-- Concessions). Aucune coordonnée à écrire ici : le staff se place, choisit le modèle, et c'est enregistré (SQL).
Config = {}

Config.StaffLevel = 4        -- niveau staff gs_admin minimum pour poser / retirer (V12.65 : 4 = super-admin et fondateur)
Config.Range = 6.0           -- distance max au véhicule exposé pour l'essayer / l'acheter / voir le prix
Config.StreamRange = 120.0   -- véhicules d'exposition créés (localement) à moins de X m du joueur
Config.Commission = 0.10     -- part du prix versée à la caisse de la concession (métier) à chaque vente

Config.TestDrive = {
    seconds = 120,           -- durée d'un essai
    maxDistance = 1500.0,    -- au-delà (m) du départ : essai terminé
    cooldown = 60,           -- secondes entre deux essais d'un même joueur
}

-- Concessions : `jobs` = métiers qui peuvent changer le modèle exposé (en service). Ajouter une ligne = une concession de plus.
Config.Dealers = {
    patoche = { label = 'Concession automobile', jobs = { 'cardealer' } },
    pdm = { label = 'Premium Deluxe Motorsport', jobs = { 'cardealer' } },
}

-- Catégories du catalogue Qbox jamais exposées / vendues ici
Config.Excluded = { emergency = true, military = true, service = true, trains = true, commercial = true }
