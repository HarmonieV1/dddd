-- [CONFIG] Vibe, le réseau social de la ville (ex-Néon). Interface : app Vibe du téléphone.
Config = {}

Config.MaxLength = 280
Config.FeedSize = 60               -- posts gardés en mémoire et affichés
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
