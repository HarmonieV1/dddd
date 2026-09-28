-- [CONFIG] Réseau social Néon.
Config = {}

Config.MaxLength = 280
Config.FeedSize = 60               -- posts gardés en mémoire et affichés
Config.PostCooldown = 30000        -- ms entre deux posts d'un même joueur
Config.HandleMin, Config.HandleMax = 3, 16
Config.BlockLinks = true           -- liens et invitations Discord remplacés par [lien] (pub, phishing)
Config.ModerateAce = 'gs.social.moderate'
Config.MirrorToDiscord = true      -- copie des posts sur le salon public (convar gs_webhook_social)
Config.Key = 'F3'
