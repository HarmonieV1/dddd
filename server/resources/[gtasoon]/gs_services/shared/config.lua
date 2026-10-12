-- [CONFIG] Secours IA. La ville continue de tourner même sans EMS connecté : personne ne reste à terre indéfiniment.
-- Avec au moins `minEms` EMS joueurs en service, le secours IA est coupé (les vrais EMS gardent la main).
Config = {}

Config.EmsJob = 'ambulance'
Config.Medic = {
    minEms = 1,
    fee = 300,           -- prélevé en banque, sinon en liquide ; gratuit si le patient n'a rien (pas de dette)
    seconds = 25,        -- arrivée + massage cardiaque (vérifié par le serveur)
    cooldown = 120,      -- secondes entre deux appels du même joueur
    model = 's_m_m_paramedic_01',
    key = 47,            -- G
}

-- V12.16 · Filet de sécurité de la réapparition (retour du 12/10 : « le E pour réapparaître ne fonctionne pas une fois mort »).
-- Qbox (qbx_medical + qbx_ambulancejob) gère [E] maintenu ; quand ça échoue sans rien dire (lit d'hôpital resté « occupé »,
-- réapparition restée bloquée après un passage au lit), le joueur restait mort. Si [E] a été maintenu et qu'il est
-- toujours mort `wait` secondes après, le serveur le relève devant l'hôpital le plus proche, aux mêmes frais que Qbox.
Config.Respawn = {
    hold = 2,            -- secondes de [E] maintenu (comme le réglage Qbox RespawnHoldTime = 2)
    wait = 6,            -- secondes laissées à Qbox avant de prendre le relais
    fee = 500,           -- même tarif que l'accueil de l'hôpital (checkInCost) ; gratuit si le joueur n'a rien
    hospitals = {        -- devant l'entrée, au niveau de la rue
        { label = 'Pillbox Hill', coords = vec4(296.0, -575.5, 43.15, 70.0) },
        { label = 'Sandy Shores', coords = vec4(1839.6, 3672.9, 34.28, 210.0) },
        { label = 'Paleto Bay', coords = vec4(-247.8, 6331.2, 32.43, 225.0) },
    },
}
