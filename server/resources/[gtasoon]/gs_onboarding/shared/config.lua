-- [CONFIG] Arrivée des joueurs. Le règlement complet vit sur Discord ; ici, l'essentiel à accepter avant de jouer.
-- Changer RulesVersion oblige tout le monde à relire et accepter à la prochaine connexion.
Config = {}

Config.RulesVersion = 1
Config.Rules = [[
**1. Respect.** Aucun propos haineux, raciste, sexiste ou homophobe, en jeu comme sur Discord.

**2. Roleplay avant tout.** Tu joues un personnage crédible. Pas de *freekill* (tuer sans raison RP), pas de *metagaming* (utiliser des infos hors jeu), pas de *powergaming* (imposer une action impossible).

**3. Valeur de la vie.** Tu tiens à la vie de ton personnage : sous la menace d'une arme, on obéit.

**4. Pas de triche.** Menus, exploits, macros, bugs volontaires : bannissement définitif. Un bug ? Signale-le avec /report.

**5. Zones calmes.** Pas de crime à l'hôpital, au commissariat, à la mairie ni au Pôle Emploi.

**6. Staff.** Les décisions du staff s'appliquent tout de suite ; une contestation se fait après, calmement, sur Discord.

**7. Boutique.** Uniquement du cosmétique : aucun avantage de jeu ne s'achète.

Règlement complet et sanctions : discord.gg/8y2sX7EvZN · roadlinerp.netlify.app
]]

-- V11.5 · Arrivée en bus d'un nouveau personnage : part de `from`, s'arrête au nœud de route le plus proche de `stop`
-- (arrêt devant la mairie, Max à deux pas), descente, puis le bus repart. Espace pour passer. false = apparition simple.
Config.Arrival = {
    enabled = true, bus = 'bus', driver = 's_m_m_gentransport', seat = 1, speed = 13.0, seconds = 28, leaveAfter = 6,
    from = vec3(-790.0, -300.0, 36.5),               -- Rockford Hills, quelques rues avant la mairie
    stop = vec4(-548.0, -200.5, 37.7, 30.0),         -- trottoir de la mairie (le perso est posé ici en descendant)
}

-- Liste blanche : active seulement si la convar `gs_whitelist` vaut "true" (cfg/prod.cfg). Candidature sur Discord,
-- puis un staff ajoute le joueur avec /whitelist add <id serveur | license:...>. Les ACE `WhitelistBypassAce` passent toujours.
Config.WhitelistBypassAce = 'gs.admin.helper'
Config.ManageAce = 'gs.admin.mod'
Config.DiscordInvite = 'discord.gg/8y2sX7EvZN'   -- affiché aux joueurs non inscrits (convar gs_discord_invite prioritaire)

-- V8 · Mentors : un joueur expérimenté (niveau ≥ minLevel) se déclare parrain ; un nouveau (niveau ≤ newbieMaxLevel) le
-- choisit avec /mentor. Si le filleul est toujours là `days` jours plus tard (et a joué au moins `minDaysPlayed` jours
-- différents), les deux sont récompensés. Le parrain peut retrouver son filleul en ville (GPS).
Config.Mentor = { minLevel = 5, newbieMaxLevel = 3, maxMentees = 3, days = 7, minDaysPlayed = 3,
    rewardMentor = 2500, rewardNewbie = 1000, requestSeconds = 120 }
