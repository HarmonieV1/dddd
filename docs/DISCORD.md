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

**Sur le VPS OVH** : PREPARER-OVH.bat emporte `secrets.cfg`, donc le bot suit tout seul (docs/OVH.md).
**Rôles de métier** (facultatif) : dans `cfg/secrets.cfg`, `set gs_discord_roles "police=ID,ambulance=ID,mechanic=ID"`
(gardé aux mises à jour), et place le rôle du bot au-dessus d'eux (Paramètres → Rôles).

## Modérer depuis Discord (V10.1), même sur téléphone
V12.3 : commandes réservées au **rôle staff** (`set gs_discord_staff_role "ID-DU-ROLE"`), au **propriétaire** et aux
**administrateurs du Discord RoadLine**, et **uniquement sur ce Discord** (`gs_discord_guild`, vérifié avant tout :
un bot invité ailleurs ne répond à personne). CONFIGURER-DISCORD.bat demande ces identifiants.
Les réponses ne sont visibles que par toi. `/aide` liste les commandes (avec celles du staff si tu y as droit).

| Commande | Effet en jeu |
|---|---|
| `/joueurs` | joueurs en ville : identifiant, nom, personnage, ping |
| `/geler id` · `/degeler id` | le joueur ne peut plus bouger (tricheur repéré) / libéré |
| `/avertir id texte` | avertissement (note au dossier, publié dans les sanctions) |
| `/expulser id texte` | expulsion du serveur |
| `/message id texte` | message privé du staff au joueur |
| `/annonce texte` | annonce à toute la ville |
| `/isoler id minutes motif` · `/liberer id` | isolement hors RP (cour de Bolingbroke, 1 à 240 min, publié dans #sanctions) / libération |
| `/reanimer id` | réanime et soigne un joueur bloqué |
| `/ticket sujet` · `/fermer` · `/aide` | tickets en fil privé (tous les membres) · liste des commandes |

Pour bannir : txAdmin (`http://IP:40120`), qui marche aussi sur téléphone. Autre possibilité : le panneau staff web
`http://IP:30120/gs_admin/` (voir docs/OVH.md, § 5). Chaque action est journalisée « Discord · pseudo ».
**Ça ne marche pas ?** Console du serveur : « Bot Discord connecté » = OK ; « Jeton refusé » = relance CONFIGURER-DISCORD
avec un nouveau jeton.

## Tickets (V11.4)
`/ticket sujet` ouvre un **fil privé** dans `#tickets` : le joueur et le rôle staff y sont ajoutés, rien n'est visible
des autres. `/fermer` (auteur ou staff) l'archive et le verrouille. Un ticket ouvert par membre, 2 min entre deux.
1. Crée le salon `tickets` : les membres peuvent **voir** le salon et **utiliser les commandes**, mais pas y écrire ni
   créer de fils eux-mêmes. Le staff : « Gérer les fils » (voit tous les tickets).
2. **CONFIGURER-DISCORD.bat** : colle l'identifiant du salon `tickets` (et du rôle staff), puis réautorise le bot avec le
   lien qui s'ouvre (nouveaux droits : fils privés). **GERER-OVH.bat → 12** pour l'envoyer au VPS.
Bot de tickets externe à la place : `set gs_discord_tickets "false"` dans `secrets.cfg` (les commandes disparaissent).

## V11 · Vérifier que tout est relié (VPS)
1. Sur le PC : **CONFIGURER-DISCORD.bat** (jeton du bot, webhooks des salons).
2. **GERER-OVH.bat → 12** : envoie ces réglages au VPS (la base du VPS n'est pas touchée), le serveur redémarre.
3. **GERER-OVH.bat → 17** : « Bot Discord : connecté » + un message « ✅ Test du VPS » dans chaque salon relié (sinon : REFUSÉ = webhook
   supprimé ou mal copié, non réglé = vide dans secrets.cfg). L'adresse `/rejoindre` est réglée toute seule si elle était vide.
- Le salon **staff** reçoit aussi les alertes de la veille (serveur tombé / revenu).
