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

Règlement complet et sanctions : Discord.
]]

-- Liste blanche : active seulement si la convar `gs_whitelist` vaut "true" (cfg/prod.cfg). Candidature sur Discord,
-- puis un staff ajoute le joueur avec /whitelist add <id serveur | license:...>. Les ACE `WhitelistBypassAce` passent toujours.
Config.WhitelistBypassAce = 'gs.admin.helper'
Config.ManageAce = 'gs.admin.mod'
Config.DiscordInvite = 'discord.gg/ton-serveur'   -- affiché aux joueurs non inscrits (convar gs_discord_invite prioritaire)
