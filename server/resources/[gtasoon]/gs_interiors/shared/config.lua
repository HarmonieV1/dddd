-- [CONFIG] Portes vers les intérieurs du jeu déjà chargés par bob74_ipl (business bikers, club-house…).
-- outside = porte dehors, inside = arrivée dedans (et porte de sortie). access : gang = '…' | job = '…' | public = true.
-- Portes non publiques : marqueur visible SEULEMENT par les membres autorisés (les autres ne voient rien).
-- Coords à caler en jeu (F11 → Copier mes coordonnées). Les intérieurs sont sous la map : ne pas les déplacer.
Config = {}

Config.Range = 2.0

Config.Doors = {
    -- Casino Diamond (intérieur bob74_ipl) : ouvert à tous. Roue de la fortune dedans (gs_casino).
    { id = 'casino', label = 'Casino Diamond', access = { public = true }, blip = { sprite = 679, color = 5 },
      outside = vec4(924.36, 46.92, 81.1, 58.0), inside = vec4(1089.73, 206.36, -48.99, 358.0) },
    { id = 'lost_club', label = 'Club-house du Lost MC', access = { gang = 'lostmc' },
      outside = vec4(981.3, -103.3, 74.85, 40.0), inside = vec4(1107.04, -3157.39, -37.52, 0.0) },
    { id = 'lab_families', label = 'Ferme de cannabis (Families)', access = { gang = 'families' }, lab = 'weed',
      outside = vec4(101.4, -1938.6, 20.8, 45.0), inside = vec4(1066.3, -3183.3, -39.16, 90.0) },
    { id = 'lab_ballas', label = 'Labo de cocaïne (Ballas)', access = { gang = 'ballas' }, lab = 'coke',
      outside = vec4(-2.1, -1815.7, 29.15, 50.0), inside = vec4(1088.7, -3187.5, -38.99, 180.0) },
    { id = 'lab_vagos', label = 'Labo (Vagos)', access = { gang = 'vagos' }, lab = 'coke',
      outside = vec4(342.9, -2045.1, 21.6, 230.0), inside = vec4(997.0, -3200.7, -36.39, 270.0) },
    { id = 'lab_marabunta', label = 'Atelier clandestin (Marabunta)', access = { gang = 'marabunta' }, lab = 'weed',
      outside = vec4(1441.6, -1487.4, 63.6, 340.0), inside = vec4(1138.1, -3198.2, -39.67, 0.0) },
}
