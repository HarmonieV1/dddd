-- [CONFIG] gs_onboarding · V10 « Que faire ? » : un seul point d'entrée (téléphone → Que faire ?, ou /quefaire) au lieu de
-- 30 commandes. Chaque ligne : un bouton qui lance l'action (`cmd`) ou met le GPS (`point` = clé d'un point déplaçable,
-- donc toujours à jour si le staff le déplace ; `at` = position de secours). `only` : 'gang' | 'nogang' | 'police'.
-- (Hors de Config exprès : ces positions ne doivent pas apparaître deux fois dans « Déplacer un point ».)
Guide = {
    {
        id = 'legal', label = 'Gagner ma vie', icon = 'briefcase', color = '#4fd8ff',
        items = {
            { label = 'Pôle emploi', desc = 'Choisir un métier libre (routier, bus, taxi, livreur, éboueur)', icon = 'building', point = 'gs_jobs:Config.JobCenter.coords' },
            { label = 'Mes emplois et service', desc = 'Prendre ou quitter le service, mes contrats de travail', icon = 'id-badge', cmd = 'job' },
            { label = 'Pêche', desc = 'Canne à pêche à la quincaillerie, puis revente au marché', icon = 'fish', point = 'gs_harvest:Config.Activities.fishing.spots' },
            { label = 'Mine', desc = 'Pioche à la quincaillerie', icon = 'gem', point = 'gs_harvest:Config.Activities.mining.spots' },
            { label = 'Bûcheron', desc = 'Hache à la quincaillerie', icon = 'tree', point = 'gs_harvest:Config.Activities.lumber.spots' },
            { label = 'Ferme', desc = 'Cueillette, sans outil', icon = 'wheat-awn', point = 'gs_harvest:Config.Activities.farming.spots' },
            { label = 'Ferraille', desc = 'Récupérer et revendre le métal', icon = 'recycle', point = 'gs_harvest:Config.Activities.scrapyard.spots' },
            { label = 'Chasse', desc = 'Permis de chasse obligatoire', icon = 'paw', point = 'gs_harvest:Config.Hunting.lodge' },
            { label = 'Revendre ma récolte', desc = 'Le marché le plus proche', icon = 'scale-balanced', point = 'gs_harvest:Config.Buyers' },
            { label = 'Auto-école', desc = 'Code et permis de conduire', icon = 'car', point = 'gs_driving:Config.Desk' },
        },
    },
    {
        id = 'dark', label = 'Côté obscur', icon = 'mask', color = '#ff2340',
        items = {
            { label = 'Appeler le contact', desc = 'Marché noir : il te donne un rendez-vous', icon = 'user-secret', cmd = 'contact' },
            { label = 'Contrats discrets', desc = 'Petits boulots entre gens de confiance', icon = 'file-signature', cmd = 'contrats' },
            { label = 'Écouter les rumeurs', desc = 'Barmans, pompiste : ce qui s\'est passé en ville', icon = 'ear-listen', cmd = 'rumeurs' },
            { label = 'L\'indic\'', desc = 'Il vend les secrets des gangs… et balance aussi', icon = 'user-ninja', point = 'gs_rumors:Config.Informants', only = 'gang' },
            { label = 'Mon gang', desc = 'Caisse, territoires, guerres (F9)', icon = 'people-group', cmd = 'gang', only = 'gang' },
            { label = 'Racket d\'un commerce', desc = 'À la caisse d\'un bar : réclamer une protection', icon = 'sack-dollar', cmd = 'racket', only = 'gang' },
            { label = 'Contrebande', desc = 'Le docker de Paleto, la nuit', icon = 'ship', point = 'gs_smuggling:Config.Contact' },
            { label = 'Braquer une supérette', desc = 'Vise le caissier : il ouvre la caisse. Les témoins parlent.', icon = 'cash-register', point = 'gs_economy:Config.Shops.1.clerk' },
            { label = 'Fugitifs recherchés', desc = 'Avis de recherche, primes, légendes', icon = 'person-running', cmd = 'legendes' },
        },
    },
    {
        id = 'fun', label = 'Me détendre', icon = 'umbrella-beach', color = '#a24bff',
        items = {
            { label = 'Casino', desc = 'Roue du jour, loto, tickets', icon = 'dice', point = 'gs_interiors:Config.Doors.1.outside' },
            { label = 'Enchères de la fourrière', desc = 'Le samedi à 21 h : saisies de la police et voitures abandonnées', icon = 'gavel', point = 'gs_auction:Config.Point' },
            { label = 'Courses de rue', desc = 'L\'organisateur prête les voitures', icon = 'flag-checkered', point = 'gs_races:Config.Organizer.coords' },
            { label = 'Road trip du mois', desc = 'Itinéraires panoramiques, spots photo, primes', icon = 'route', cmd = 'carnet' },
            { label = 'Louer un véhicule', desc = 'Vélo, scooter, citadine, bateau', icon = 'bicycle', point = 'gs_rental:Config.Points.1.coords' },
            { label = 'Boire un verre', desc = 'Bars tenus par des joueurs', icon = 'martini-glass', point = 'gs_business:Config.Businesses.bar.register' },
            { label = 'Rencontres de la route', desc = 'Ma collection (roule hors de la ville)', icon = 'road', cmd = 'rencontres' },
            { label = 'Mode cinéma', desc = 'Pour tes clips', icon = 'film', cmd = 'cinema' },
        },
    },
    {
        id = 'life', label = 'Ma vie', icon = 'user', color = '#f2c230',
        items = {
            { label = 'Mon récap du mois', desc = 'Heures, km, coups, titre et classement', icon = 'chart-simple', cmd = 'recap' },
            { label = 'Rendez-vous de la semaine', desc = 'Métiers, courses, combats, road trip', icon = 'calendar-check', cmd = 'rdv' },
            { label = 'Contrats signés', desc = 'Prêt, salaire, location', icon = 'file-contract', cmd = 'contrat' },
            { label = 'Ambiance des quartiers', desc = 'Tension et standing de chaque quartier', icon = 'city', cmd = 'quartiers' },
            { label = 'Mes factures', desc = 'À payer', icon = 'receipt', cmd = 'factures' },
            { label = 'Mon permis', desc = 'Points restants', icon = 'id-card', cmd = 'permis' },
            { label = 'Histoire de ma voiture', desc = 'Au volant : km, accidents, propriétaires', icon = 'car-side', cmd = 'histoire' },
            { label = 'Réputation et saison', desc = 'Rue, légal, média · pass de saison', icon = 'star', cmd = 'reputation' },
        },
    },
    {
        id = 'help', label = 'Aide', icon = 'circle-question', color = '#5aff8c',
        items = {
            { label = 'Les touches', desc = 'Toutes les touches du serveur', icon = 'keyboard', cmd = 'touches' },
            { label = 'Trouver un parrain', desc = 'Un ancien te guide 7 jours, primes pour les deux', icon = 'handshake', cmd = 'mentor' },
            { label = 'Le règlement', desc = 'À relire', icon = 'scale-balanced', cmd = 'regles' },
            { label = 'Appeler le staff', desc = 'Un souci ? Un ticket arrive au staff', icon = 'life-ring', report = true },
        },
    },
}
