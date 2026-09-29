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
