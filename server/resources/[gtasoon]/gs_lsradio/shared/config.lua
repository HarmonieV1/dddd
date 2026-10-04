-- [CONFIG] gs_lsradio · Radio Los Santos. Les brèves Weazel ont déjà leur bandeau : la radio parle d'autre chose.
Config = {}

Config.Host = 'Lenny'               -- l'animateur
Config.Gap = 45                     -- secondes minimum entre deux interventions
Config.Chatter = 12                 -- minutes entre deux « points de la ville » (météo, heure, rendez-vous, astuce)
Config.Duration = 9000              -- ms d'affichage du sous-titre
Config.Tips = {
    'Perdu en ville ? Téléphone, appli Que faire : tout ce qui se passe, au bon endroit.',
    'Un quartier sale, c\'est un quartier qui coule. La mairie paie ceux qui ramassent, pensez-y.',
    'Vous roulez dans le comté ? Ouvrez l\'œil : un auto-stoppeur, une panne… la route réserve des surprises.',
    'Un contrat signé, c\'est un contrat tenu. Les juges, eux, n\'oublient pas les retards.',
    'Votre récap du mois vous attend : téléphone ou /recap. Alors, quel titre cette fois ?',
    'Les commerçants ont de la mémoire : fidèles, on vous chouchoute. Braqueurs à visage découvert… on vous reconnaît.',
}
Config.Lines = {
    remind = '%s dans %d minutes : %s',
    start = 'C\'est parti pour %s ! %s',
    fugitive = 'Avis de recherche : %s. Prime de %d $ pour qui le livre à la police. Prudence.',
    faitdivers = 'On nous signale un %s du côté de %s. La police est en route.',
    storm = 'Alerte météo : une tempête arrive sur le comté. Routes de campagne fermées, dépanneurs, à vos crochets !',
    ring = 'Il paraît que ça cogne fort cette nuit, quelque part en ville… Les barmans en savent plus que moi.',
    chatter = 'Il est %s à Los Santos, %s. %s',
}
