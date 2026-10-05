-- [CONFIG] gs_discord. Les adresses et le jeton sont dans cfg/secrets.cfg (CONFIGURER-DISCORD.bat les y écrit) :
--   set gs_webhook_status "…"        salon #statut : un seul message, mis à jour toutes les minutes
--   set gs_webhook_annonces "…"      salon #annonces : serveur en ligne, redémarrages
--   set gs_discord_bot_token "…"     (optionnel) jeton du bot RoadLine pour donner les rôles de métier
--   set gs_discord_guild "…"         (optionnel) identifiant du serveur Discord
Config = {}

Config.Every = 60                     -- secondes entre deux mises à jour du statut
Config.Name = 'RoadLine RP'
Config.Color = 0xB048FF               -- violet néon du site
Config.Services = {                   -- compteurs « en service » affichés dans le statut
    { job = 'police', label = '🚓 Police' },
    { job = 'ambulance', label = '🚑 EMS' },
    { job = 'mechanic', label = '🔧 Mécanos' },
    { job = 'taxi', label = '🚕 Taxis' },
}

-- Rôles Discord donnés selon le métier en jeu (identifiant du rôle : clic droit sur le rôle → Copier l'identifiant).
-- Vide = pas de synchronisation. Le bot doit avoir la permission « Gérer les rôles » et être AU-DESSUS de ces rôles.
Config.Roles = {
    -- police = '123456789012345678',
    -- sheriff = '123456789012345678',
    -- ambulance = '123456789012345678',
    -- mechanic = '123456789012345678',
}

-- V10.2 · Le fil de la ville : chaque soir, un court résumé de la journée dans le salon #annonces (6 lignes max, aucun
-- nom de joueur sauf les légendes, déjà publiques). Rien à dire = rien n'est posté. false = désactivé.
Config.Digest = { enabled = true, hour = 23, minute = 30 }
