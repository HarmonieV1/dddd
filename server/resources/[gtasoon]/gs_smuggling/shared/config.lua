-- [CONFIG] V8 · Contrebande maritime. Le contact du port de Paleto confie une cargaison (la nuit, aux membres d'un gang
-- ou aux visages connus de la rue) : aller la repêcher en mer EN BATEAU, la décharger sur une plage. Au chargement, le
-- radar côtier peut donner l'alerte (police en service) ; sans police, des garde-côtes IA prennent le relais.
-- Points à caler en jeu (F11 → Points).
Config = {}
Config.Contact = vec4(-280.0, 6630.0, 7.3, 45.0)
Config.ContactModel = 's_m_m_dockwork_01'
Config.Hours = { 21, 5 }          -- de 21 h à 5 h (heure du jeu)
Config.Cooldown = 45              -- min entre deux cargaisons (par personnage)
Config.MaxActive = 3              -- cargaisons en cours sur tout le serveur
Config.Timeout = 25               -- min pour livrer
Config.MinStreet = 300            -- réputation de rue minimale (si pas membre d'un gang)
Config.Pay = { 3500, 5500 }       -- argent sale (ou liquide si l'objet n'existe pas)
Config.Radar = 0.5                -- chance d'alerte au chargement
Config.CoastGuard = { chance = 0.6, boat = 'predator', ped = 's_m_y_uscg_01' }
Config.Crate = 'prop_box_wood04a'

Config.Pickups = {
    vec3(-1450.0, 7250.0, 0.0), vec3(3600.0, 5600.0, 0.0), vec3(-3300.0, 3200.0, 0.0), vec3(2800.0, -2000.0, 0.0), vec3(-2600.0, -1000.0, 0.0),
}
Config.Drops = {
    vec3(-1600.0, 5200.0, 3.0), vec3(3820.0, 4460.0, 4.0), vec3(-2190.0, 4280.0, 1.5), vec3(-3090.0, 370.0, 7.0), vec3(1550.0, 6620.0, 2.0),
}
