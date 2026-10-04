# Discord de RoadLine : structure conseillée

Un modèle Discord ne contient que des salons, rôles et permissions. Le plus fiable : créer la structure ci-dessous une
fois, puis **Paramètres du serveur → Modèle de serveur → Générer un lien** pour la dupliquer. (Des modèles communautaires
existent aussi, par ex. xenon.bot/templates/for/fivem : vérifie les permissions avant d'en importer un.)

## Rôles (du plus haut au plus bas)
Fondateur · Super-admin · Admin · Modérateur · Helper · Bot · Whitelisté · Candidat · Visiteur
(les mêmes rangs qu'en jeu ; les rangs en jeu se donnent dans le menu staff F11, pas via Discord)

## Catégories et salons
- **📢 ACCUEIL** : `règlement` (lecture seule, même texte que /regles), `annonces`, `mises-à-jour`, `statut-serveur`
- **📝 CANDIDATURES** : `comment-candidater`, `candidatures` (formulaire → staff), `résultats`
- **💬 COMMUNAUTÉ** : `général`, `médias`, `clips`, `idées`, `vibe-miroir` ← webhook `gs_webhook_social`
- **⚖️ TRANSPARENCE** : `sanctions` ← webhook `gs_webhook_sanctions` (public, staff anonyme)
- **🛟 SUPPORT** : `aide`, `signaler-un-bug`, `tickets` (bot de tickets au choix), `remboursements`
- **🎭 RP HORS JEU** : `entreprises` (recrutements), `gangs` (sur candidature), `événements`
- **🔒 STAFF** (Helper+) : `staff-général`, `logs-staff` ← `gs_staff_webhook`, `logs-jobs` ← `gs_webhook_jobs`,
  `logs-boutique` ← `gs_webhook_boutique`, `vocal-staff`
- **🔊 VOCAL** : `Salle d'attente support`, `Détente`, `Événements`

Webhooks : clic droit sur le salon → Modifier → Intégrations → Webhooks → copier l'adresse dans `cfg/secrets.cfg`.

## Le bot RoadLine (V10) : installation en 5 minutes, une seule fois
Le bot tourne **dans le serveur FiveM** : rien à installer sur le PC, il démarre et s'arrête avec le serveur (en local
comme chez l'hébergeur). Ensuite, plus rien à faire : les mises à jour passent par METTRE-A-JOUR.bat.

1. **Créer le bot** : va sur `discord.com/developers/applications` → **New Application** → nom « RoadLine » → menu
   **Bot** → **Reset Token** → **Copy** (c'est le jeton : ne le donne jamais à personne).
2. **Webhooks** : sur ton Discord, salon `statut-serveur` → Modifier → Intégrations → Webhooks → Nouveau → Copier
   l'URL. Pareil pour le salon `annonces`.
3. **Double-clic sur `CONFIGURER-DISCORD.bat`** et colle, quand on te le demande :
   - l'URL du webhook `statut-serveur`, puis celle d'`annonces` ;
   - l'adresse pour rejoindre (txAdmin → `cfx.re/join/...`) ;
   - le jeton du bot (il s'écrit masqué) et l'identifiant de ton Discord (clic droit sur l'icône du serveur →
     Copier l'identifiant ; active le Mode développeur dans les paramètres Discord si l'option n'apparaît pas).
4. La page d'invitation s'ouvre toute seule : choisis ton serveur Discord → **Autoriser**.
5. **Relance le serveur** (ou METTRE-A-JOUR.bat). Dans la minute : le bot passe « en ligne » avec « 12/48 citoyens à
   Los Santos », le salon statut se met à jour, et `/statut`, `/rejoindre`, `/rdv`, `/site` marchent.

**Chez un hébergeur** : PREPARER-HEBERGEUR.bat emporte `secrets.cfg`, donc le bot suit tout seul.
**Rôles de métier** (facultatif) : mets les identifiants des rôles Discord dans `[gtasoon]/gs_discord/shared/config.lua`
(`Config.Roles`) et place le rôle du bot au-dessus d'eux (Paramètres → Rôles).
**Ça ne marche pas ?** Console du serveur : « Bot Discord connecté » = OK ; « Jeton refusé » = relance CONFIGURER-DISCORD
avec un nouveau jeton.
