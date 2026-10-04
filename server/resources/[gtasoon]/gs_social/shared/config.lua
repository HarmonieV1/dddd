-- [CONFIG] Vibe, le réseau social de la ville (ex-Néon). Interface : app Vibe du téléphone.
Config = {}

Config.MaxLength = 280
Config.FeedSize = 60               -- posts gardés en mémoire et affichés
-- Weazel News automatique (brèves des grands événements de la ville, sans nom de suspect)
Config.Newsroom = { enabled = true, handle = 'WeazelNews', perKind = 120, perHour = 15 }
Config.PostCooldown = 30000        -- ms entre deux posts d'un même joueur
Config.HandleMin, Config.HandleMax = 3, 16
Config.BlockLinks = true           -- liens et invitations Discord remplacés par [lien] (pub, phishing)
Config.ModerateAce = 'gs.social.moderate'
Config.MirrorToDiscord = true      -- copie des posts sur le salon public (convar gs_webhook_social)
Config.InfluencerFollowers = 25    -- badge « influenceur » à partir de N abonnés (le badge vérifié est posé par la modération)
Config.TopSize = 5                 -- classements de la semaine (posts, créateurs, abonnés)
Config.TopCacheSeconds = 60
Config.PressJob = 'weazel'           -- journalistes : badge presse, « flash info » envoyé à toute la ville
Config.FlashCooldown = 300          -- secondes entre deux flash info (toute la rédaction)
-- Journal Weazel News (/journal) : articles longs écrits par les journalistes en service. Chaque article publié rapporte
-- `pay` $ à la caisse de la rédaction (société weazel), au plus `paidPerDay` articles payés par jour pour toute la rédaction.
Config.Journal = { cooldown = 600, pay = 400, paidPerDay = 8, titleMin = 5, titleMax = 80, bodyMin = 40, bodyMax = 2000, list = 20 }

-- Vibe influence la ville : un hashtag repris par `authors` personnes différentes en `TrendWindow` secondes déclenche l'effet.
Config.TrendWindow = 1800
Config.Trends = {
    rassemblement = { authors = 5, cooldown = 7200, duration = 1200, radius = 40.0, xp = 150, spots = {
        { label = 'la jetée de Del Perro', coords = vec3(-1604.0, -1049.0, 13.0) },
        { label = 'Legion Square', coords = vec3(195.2, -934.3, 30.7) },
        { label = 'l\'observatoire', coords = vec3(-438.0, 1076.0, 352.4) },
        { label = 'la plage de Vespucci', coords = vec3(-1344.0, -1581.0, 4.4) },
    } },
    promo = { authors = 5, cooldown = 10800, duration = 900, factor = 0.85 },
    course = { authors = 4, cooldown = 7200, duration = 900 },
}

-- Photos et stories. Hébergement d'images à configurer (cfg/secrets.cfg) : gs_photo_upload_url (adresse d'envoi, avec la clé
-- si l'hébergeur en demande une), gs_photo_field (nom du champ fichier), gs_photo_allowed_host (début des adresses acceptées).
-- Sans ces convars, l'appareil photo est simplement masqué. Nécessite la ressource screenshot-basic.
-- gs_photo_auth : en-tête Authorization (clé d'API), gs_photo_url_field : champ de la réponse JSON contenant l'adresse (défaut url).
Config.Photos = { storyHours = 24, storyCooldown = 120, goldenHours = { 18, 20 }, goldenXp = 100, maxBytes = 1500000, uploadCooldown = 20 }

-- V10.1 · Direct Weazel : une grosse poursuite (chaleur ≥ minHeat) passe en direct. Bandeau pour toute la ville,
-- hélicoptère de la chaîne au-dessus du suspect (local à chaque joueur proche : aucun coût réseau), journalistes en
-- service sur place payés à la minute, brève de fin (interpellé, semé, disparu) et Radio Los Santos.
Config.Live = { minHeat = 45, cooldown = 1200, maxMinutes = 12, range = 500.0, pressRange = 200.0, pressPerMinute = 150,
    pressMax = 1500, heli = 'frogger', pilot = 's_m_m_pilot_01', altitude = 60.0 }
