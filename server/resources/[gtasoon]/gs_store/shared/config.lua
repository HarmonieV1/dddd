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
