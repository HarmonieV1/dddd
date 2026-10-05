-- gs_places (partagé) · vendeurs des boutiques d'apparence (illenium-appearance). Partagé : le client crée les PNJ,
-- le serveur les déclare à gs_stickup (on peut braquer la caisse d'un vendeur, comme une supérette).
-- Coordonnées = celles d'illenium-appearance (Config.Stores, emplacement prévu pour son vendeur).
AppearanceKinds = {
    barber   = { event = 'illenium-appearance:client:OpenBarberShop', prompt = 'Coiffeur', model = 's_m_m_hairdress_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    tattoo   = { event = 'illenium-appearance:client:OpenTattooShop', prompt = 'Tatoueur', model = 'u_m_y_tattoo_01', scenario = 'WORLD_HUMAN_SMOKING' },
    surgeon  = { event = 'illenium-appearance:client:OpenSurgeonShop', prompt = 'Chirurgien esthétique (visage)', model = 's_m_m_doctor_01', scenario = 'WORLD_HUMAN_CLIPBOARD' },
    clothing = { event = 'illenium-appearance:client:openClothingShopMenu', prompt = 'Boutique de vêtements', model = 's_f_y_shop_mid', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
}
AppearanceStores = {
    { 'clothing', vec4(1693.2, 4828.11, 42.07, 188.66) }, { 'clothing', vec4(-705.5, -149.22, 37.42, 122.0) },
    { 'clothing', vec4(-1192.61, -768.4, 17.32, 216.6) }, { 'clothing', vec4(425.91, -801.03, 29.49, 177.79) },
    { 'clothing', vec4(-168.73, -301.41, 39.73, 238.67) }, { 'clothing', vec4(75.39, -1398.28, 29.38, 6.73) },
    { 'clothing', vec4(-827.39, -1075.93, 11.33, 294.31) }, { 'clothing', vec4(-1445.86, -240.78, 49.82, 36.17) },
    { 'clothing', vec4(9.22, 6515.74, 31.88, 131.27) }, { 'clothing', vec4(615.35, 2762.72, 42.09, 170.51) },
    { 'clothing', vec4(1191.61, 2710.91, 38.22, 269.96) }, { 'clothing', vec4(-3171.32, 1043.56, 20.86, 334.3) },
    { 'clothing', vec4(-1105.52, 2707.79, 19.11, 317.19) }, { 'clothing', vec4(-1119.24, -1440.6, 5.23, 300.5) },
    { 'clothing', vec4(124.82, -224.36, 54.56, 335.41) },
    { 'barber', vec4(-814.22, -183.7, 37.57, 116.91) }, { 'barber', vec4(136.78, -1708.4, 29.29, 144.19) },
    { 'barber', vec4(-1282.57, -1116.84, 6.99, 89.25) }, { 'barber', vec4(1931.41, 3729.73, 32.84, 212.08) },
    { 'barber', vec4(1212.8, -472.9, 65.2, 60.94) }, { 'barber', vec4(-32.9, -152.3, 56.1, 335.22) },
    { 'barber', vec4(-278.1, 6228.5, 30.7, 49.32) },
    { 'tattoo', vec4(1322.6, -1651.9, 51.2, 42.47) }, { 'tattoo', vec4(-1154.01, -1425.31, 4.95, 23.21) },
    { 'tattoo', vec4(322.62, 180.34, 103.59, 156.2) }, { 'tattoo', vec4(-3169.52, 1074.86, 20.83, 253.29) },
    { 'tattoo', vec4(1864.1, 3747.91, 33.03, 17.23) }, { 'tattoo', vec4(-294.24, 6200.12, 31.49, 195.72) },
    { 'surgeon', vec4(298.78, -572.81, 43.26, 114.27) },
}
