-- [CONFIG] Monde. 1.0 = densité normale de GTA, 0.0 = ville vide.
Config = {}

Config.Density = {
    peds = 0.6,          -- piétons
    scenarios = 0.6,     -- PNJ assis, au travail, sur les bancs…
    vehicles = 0.65,     -- circulation
    parked = 0.75,       -- voitures garées
}

-- Cayo Perico : chargée (terrain, eau, minimap, sons, PNJ) seulement à moins de `loadRadius` m du centre de l'île.
-- Loin de l'île, zéro coût. On y va en bateau, en avion, ou avec le vol régulier ci-dessous.
Config.Island = {
    center = vec3(4840.57, -5174.43, 2.0),
    loadRadius = 2200.0,
    -- vol régulier : comptoir à l'aéroport de LS ↔ piste de l'île (fondu au noir, payé en banque)
    flight = {
        price = 350,
        mainland = { counter = vec3(-1037.8, -2737.8, 20.17), arrival = vec4(-1042.1, -2745.3, 21.36, 330.0), label = 'Vol pour Cayo Perico' },
        island = { counter = vec3(4494.3, -4525.3, 4.41), arrival = vec4(4500.8, -4522.0, 4.41, 20.0), label = 'Vol retour pour Los Santos' },
    },
}
