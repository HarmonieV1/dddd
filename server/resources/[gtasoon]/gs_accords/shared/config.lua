-- [CONFIG] gs_accords · Contrats signés. Le serveur prélève les échéances (compte en banque du payeur), garde l'argent
-- en dépôt si le bénéficiaire n'est pas en ville, compte les retards et transmet les litiges aux juges en service.
Config = {}

Config.Range = 3.0               -- signature face à face
Config.Answer = 90               -- secondes pour signer
Config.MaxActive = 5             -- contrats en cours par personnage
Config.Grace = 72                -- heures de délai après une échéance (payeur absent ou sans le sou)
Config.Penalty = 0.10            -- retard : +10 % sur l'échéance suivante
Config.Dispute = 2               -- retards avant litige (juges et avocats prévenus)
Config.Item = 'gs_contrat'       -- copie papier remise aux deux parties

Config.Types = {
    loan = { label = 'Prêt d\'argent', icon = 'hand-holding-dollar', payer = 'b', money = true,
        help = 'A prête une somme à B, qui rembourse en échéances (intérêts compris).', maxRate = 0.5 },
    salary = { label = 'Salaire privé', icon = 'user-shield', payer = 'a', money = true,
        help = 'A paie B à intervalles fixes (garde du corps, chauffeur, assistant…).' },
    rent = { label = 'Location', icon = 'key', payer = 'b', money = true,
        help = 'B paie un loyer à A (logement, véhicule, local…).' },
}
Config.Limits = { amount = { 50, 100000 }, count = { 1, 52 }, every = { 1, 30 } } -- montant, nombre d'échéances, jours
Config.JudgeJob, Config.LawyerJob = 'judge', 'lawyer'
