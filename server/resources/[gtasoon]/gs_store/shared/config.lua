-- [CONFIG] Boutique. LIRE docs/BOUTIQUE.md AVANT D'OUVRIR LES VENTES (règles Cfx / Tebex / Rockstar).
-- Règles maison (prompt maître) : Tebex uniquement, cosmétique et confort, zéro pay-to-win,
-- pas de monnaie in-game, pas de loot box, pas de contenu Rockstar ni d'IP tierce (marques, personnages).
Config = {}

-- Désactivée tant qu'Alpha n'a pas validé la conformité (PLA Cfx en vigueur + contenus).
Config.Enabled = false

-- Identifiant utilisé par Tebex pour désigner l'acheteur (compte Cfx.re) : préfixe du FiveM ID.
-- [À VÉRIFIER dans le panel Tebex] variable de commande qui donne ce numéro (voir docs/BOUTIQUE.md).
Config.BuyerIdentifier = 'fivem'

-- Packages : la clé est celle écrite dans la commande Tebex. Chaque package donne une liste d'éléments.
--   vehicle : ajouté au garage du personnage (modèle ORIGINAL ou sous licence, perfs = équivalent en jeu)
--   ped     : skin débloqué, applicable depuis /boutique
--   outfit  : tenue débloquée (composants de vêtements, addons originaux)
Config.Packages = {
    -- V12.41 · RoadCoins : `coins` = crédités tout de suite sur le compte Cfx.re à la livraison Tebex (rien à réclamer).
    -- Monnaie de BOUTIQUE seulement : jamais convertible en $ du jeu, ni en objet de gameplay, ni échangeable entre joueurs.
    roadcoins_500 = { label = '500 RoadCoins', coins = 500 },
    roadcoins_1100 = { label = '1 100 RoadCoins', coins = 1100 },
    roadcoins_2400 = { label = '2 400 RoadCoins', coins = 2400 },
    roadcoins_5000 = { label = '5 000 RoadCoins', coins = 5000 },
    pack_neon_rider = {
        label = 'Pack Neon Rider',
        grants = {
            { type = 'outfit', id = 'neon_jacket' },
            { type = 'vehicle', model = 'faggio', label = 'Scooter néon' }, -- exemple vanilla : remplacer par un modèle maison
        },
    },
    season_pass = {
        label = 'Pass de saison',
        grants = { { type = 'season_pass' } }, -- piste premium de la saison en cours (récompenses 100 % cosmétiques)
    },
    skin_sunset = {
        label = 'Skin Sunset',
        grants = { { type = 'ped', id = 'sunset_runner' } },
    },
}

-- Catalogue des skins (modèle de ped streamé ou vanilla non protégé) et des tenues.
Config.Peds = {
    sunset_runner = { label = 'Sunset Runner', model = 'a_m_y_beach_01' }, -- exemple : remplacer par un ped maison
}

-- Tenues : composants GTA (component = { drawable, texture }). Indices des addons à caler en jeu.
Config.Outfits = {
    -- Récompenses de saison (gs_seasons) : indices à caler en jeu
    season1_bomber = { label = 'Blouson Sunset (Saison 1)', male = { [11] = { 191, 0 }, [8] = { 15, 0 }, [3] = { 14, 0 } }, female = { [11] = { 193, 0 }, [8] = { 14, 0 }, [3] = { 14, 0 } } },
    season1_neon = { label = 'Tenue Néon (Saison 1, premium)', male = { [11] = { 208, 1 }, [8] = { 15, 0 }, [3] = { 4, 0 } }, female = { [11] = { 212, 1 }, [8] = { 14, 0 }, [3] = { 4, 0 } } },
    neon_jacket = {
        label = 'Veste Néon',
        male = { [11] = { 15, 0 }, [8] = { 15, 0 }, [3] = { 15, 0 } },
        female = { [11] = { 15, 0 }, [8] = { 14, 0 }, [3] = { 15, 0 } },
    },
}

Config.ClaimRateLimit = { max = 3, windowMs = 10000 }

-- V12.41 · Vitrine de la boutique EN JEU (/boutique ou la touche réglable dans Paramètres → Raccourcis → FiveM).
-- Affichage seulement : on paie sur Tebex (bouton « Acheter » = ouvre ShopUrl dans le navigateur), puis on récupère ici
-- (onglet « Mes achats »). `package` = clé de Config.Packages livrée par Tebex. price = prix Tebex affiché (texte, nil = « Prix
-- à venir ») ; coins = prix en RoadCoins (article payable directement en jeu, si le pack a des `grants`). Montants à valider.
-- Catégories : vip, vehicules, perso, armes (skins d'armes UNIQUEMENT : teintes, gravures ; jamais une arme ni un bonus).
Config.ShopUrl = '' -- adresse de la boutique Tebex (ex. 'https://roadline.tebex.io') ; vide = boutons « Bientôt »
Config.Categories = {
    { id = 'roadcoins', label = 'RoadCoins', icon = '🪙' },
    { id = 'vip', label = 'VIP', icon = '👑' },
    { id = 'vehicules', label = 'Véhicules', icon = '🏎️' },
    { id = 'perso', label = 'Personnalisation', icon = '🧥' },
    { id = 'armes', label = 'Skins d\'armes', icon = '🎨' },
}
Config.Catalog = {
    -- RoadCoins (achetés sur Tebex). `bonus` = texte du badge. Les autres articles peuvent avoir `coins = N` : payables en RoadCoins.
    { package = 'roadcoins_500', cat = 'roadcoins', icon = '🪙', label = '500 RoadCoins', price = nil, pack = 500,
      points = { 'Crédités tout de suite sur ton compte', 'Partagés entre tes personnages', 'Uniquement pour la boutique' } },
    { package = 'roadcoins_1100', cat = 'roadcoins', icon = '💰', label = '1 100 RoadCoins', hot = '+10 %', price = nil, pack = 1100,
      points = { 'Crédités tout de suite sur ton compte', 'Partagés entre tes personnages', 'Uniquement pour la boutique' } },
    { package = 'roadcoins_2400', cat = 'roadcoins', icon = '💎', label = '2 400 RoadCoins', hot = '+20 %', price = nil, pack = 2400,
      points = { 'Crédités tout de suite sur ton compte', 'Partagés entre tes personnages', 'Uniquement pour la boutique' } },
    { package = 'roadcoins_5000', cat = 'roadcoins', icon = '👑', label = '5 000 RoadCoins', hot = '+25 %', price = nil, pack = 5000,
      points = { 'Crédités tout de suite sur ton compte', 'Partagés entre tes personnages', 'Uniquement pour la boutique' } },
    { package = 'vip_argent', cat = 'vip', icon = '👑', label = 'VIP Argent', price = nil, unit = '/ mois',
      points = { '2e personnage', 'Badge VIP sur Discord', 'File d\'attente prioritaire' } },
    { package = 'vip_or', cat = 'vip', icon = '💠', label = 'VIP Or', hot = 'Populaire', price = nil, unit = '/ mois',
      points = { 'Tout le VIP Argent', '3 tenues enregistrées en plus', 'Plaque personnalisée (1 / mois)' } },
    { package = 'vip_neon', cat = 'vip', icon = '🌌', label = 'VIP Néon', price = nil, unit = '/ mois',
      points = { 'Tout le VIP Or', 'Couleur de nom sur Discord', 'Accès anticipé aux nouveautés' } },
    { package = 'pack_neon_rider', cat = 'vehicules', icon = '🛵', label = 'Pack Neon Rider', hot = 'Pack', price = nil, coins = 1500,
      points = { 'Scooter néon livré au garage', 'Veste Néon', 'Performances de série' } },
    { package = 'vehicule_exclusif', cat = 'vehicules', icon = '🏎️', label = 'Véhicule exclusif', hot = 'Unique', price = nil,
      points = { 'Modèle hors concession', 'Mêmes performances que sa catégorie', 'Livré dans ton garage' } },
    { package = 'plaque_perso', cat = 'vehicules', icon = '🔢', label = 'Plaque personnalisée', price = nil,
      points = { '8 caractères au choix', 'Validée par le staff', 'Sur le véhicule de ton choix' } },
    { package = 'skin_sunset', cat = 'perso', icon = '🌅', label = 'Skin Sunset', price = nil, coins = 600,
      points = { 'Apparence alternative', 'Tu reprends ton perso quand tu veux', 'Purement visuel' } },
    { package = 'season_pass', cat = 'perso', icon = '🎟️', label = 'Pass de saison', price = nil, coins = 900,
      points = { 'Piste premium de la saison', 'Récompenses 100 % cosmétiques', 'Tenues exclusives' } },
    { package = 'retouche_perso', cat = 'perso', icon = '✂️', label = 'Retouche du personnage', price = nil,
      points = { 'Visage, coiffure, héritage', 'Sans recréer ton perso', 'Une fois, quand tu veux' } },
    { package = 'teintes_armes', cat = 'armes', icon = '🎨', label = 'Teintes d\'armes', price = nil,
      points = { 'Finitions or, chrome, néon', 'Sur une arme que tu possèdes déjà', 'Aucun bonus de dégâts' } },
    { package = 'gravure_arme', cat = 'armes', icon = '🗡️', label = 'Gravure personnalisée', price = nil,
      points = { 'Ton nom ou ton gang sur l\'arme', 'Visible à l\'inspection', 'Aucun bonus de dégâts' } },
}
