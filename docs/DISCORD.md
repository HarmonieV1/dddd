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
| `/annonce texte [titre] [mention] [en_jeu]` | V12.5 : **publiée sur Discord** dans `#annonces` (ou dans le salon courant si `#annonces` n'est pas relié), 1 800 caractères, `@everyone` / `@here` en option ; `en_jeu` = aussi affichée à toute la ville |
| `/isoler id minutes motif` · `/liberer id` | isolement hors RP (cour de Bolingbroke, 1 à 240 min, publié dans #sanctions) / libération |
| `/reanimer id` | réanime et soigne un joueur bloqué |
| `/ticket sujet` · `/fermer` · `/aide` (= `/help`) | tickets en fil privé (tous les membres) · liste des commandes |
| `/ip` · `/rejoindre` · `/statut` · `/rdv` · `/site` | tous les membres : adresse de connexion, mode d'emploi, état du serveur, rendez-vous, site |

Pour bannir : txAdmin (`http://IP:40120`), qui marche aussi sur téléphone. Autre possibilité : le panneau staff web
`http://IP:30120/gs_admin/` (voir docs/OVH.md, § 5). Chaque action est journalisée « Discord · pseudo ».
**« Commande disponible uniquement sur le Discord RoadLine » alors que tu y es** (avant V12.5) : l'identifiant du serveur
Discord (`gs_discord_guild`) était vide ou faux. Depuis V12.5 : si le bot n'est que sur ton Discord, il le **détecte tout
seul** à la connexion ; sinon le message dit exactement quoi corriger. GERER-OVH → diagnostic affiche « réglé / NON RÉGLÉ ».
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

## Message de bienvenue (V12.8)

Le bot RoadLine accueille chaque nouveau membre dans le salon de ton choix : « Nous sommes heureux de t'accueillir parmi
nous, @membre, sur RoadLine RP ! Lis le règlement, puis `/ticket` si tu as une question. » (texte modifiable).

1. discord.com/developers → ton application → **Bot** → **Privileged Gateway Intents** → activer **Server Members Intent** → Save.
   Sans ça, Discord refuse l'intent : le bot l'écrit dans la console, coupe la bienvenue et continue normalement.
2. CONFIGURER-DISCORD.bat → « Salon #bienvenue » : identifiant du salon (clic droit → Copier l'identifiant).
   Le bot doit pouvoir écrire dans ce salon (droits du rôle du bot sur le salon).
3. Texte personnalisé (optionnel) : `set gs_discord_welcome_text "Bienvenue {membre} ! …"` dans `cfg/secrets.cfg`
   (`{membre}` = mention du nouveau).
4. GERER-OVH → 12 (le bot redémarre avec le serveur), puis fais entrer un compte de test : le message doit apparaître.

Avant la V12.8, le bot RoadLine n'envoyait **aucun** message de bienvenue : si tu en avais un jusqu'au 4 octobre, il venait
d'un autre bot (MEE6, Dyno, Carl…) ou de l'onboarding Discord ; vérifie-le de son côté, ou laisse le bot RoadLine s'en charger.

## Liste de contrôle Discord (à faire une fois, dans l'ordre)

1. Portail développeur : application créée, **Bot** → jeton (Reset Token), **Server Members Intent** activé.
2. CONFIGURER-DISCORD.bat : webhooks #statut, #annonces, #logs-staff (privé), #sanctions (public), adresse de connexion,
   jeton du bot, identifiants : serveur Discord, rôle staff, salon #tickets, salon #bienvenue.
   Dans `cfg/secrets.cfg` aussi : `gs_webhook_candidatures` (site → #candidatures), `gs_webhook_social`, `gs_webhook_jobs`,
   `gs_webhook_boutique`, `gs_webhook_anticheat`, `gs_discord_roles` (métier → rôle).
3. Inviter le bot avec le lien affiché par CONFIGURER-DISCORD (droits : voir, écrire, liens, historique, gérer les rôles,
   fils privés et les gérer). Sur #tickets : le bot doit pouvoir **créer des fils privés** et **gérer les fils**.
4. GERER-OVH → 12 (envoi + redémarrage) puis → 17 : un message de test dans chaque salon relié, bot « connecté » dans la console.
5. Tester en tant que membre : `/statut`, `/ip`, `/rejoindre`, `/rdv`, `/site`, `/aide` (= `/help`), `/ticket test` puis `/fermer` ;
   en tant que staff (rôle staff ou administrateur) : `/joueurs`, `/geler`, `/degeler`, `/avertir`, `/message`, `/annonce`,
   `/expulser`, `/isoler`, `/liberer`, `/reanimer` ; faire entrer un compte de test → message de bienvenue.
6. Si une commande manque : le bot enregistre les commandes à chaque connexion sur le Discord `gs_discord_guild` ;
   si l'identifiant est faux ou le bot absent du serveur, elles passent en « globales » (jusqu'à 1 h de délai Discord).

## V11 · Vérifier que tout est relié (VPS)
1. Sur le PC : **CONFIGURER-DISCORD.bat** (jeton du bot, webhooks des salons).
2. **GERER-OVH.bat → 12** : envoie ces réglages au VPS (la base du VPS n'est pas touchée), le serveur redémarre.
3. **GERER-OVH.bat → 17** : « Bot Discord : connecté » + un message « ✅ Test du VPS » dans chaque salon relié (sinon : REFUSÉ = webhook
   supprimé ou mal copié, non réglé = vide dans secrets.cfg). L'adresse `/rejoindre` est réglée toute seule si elle était vide.
- Le salon **staff** reçoit aussi les alertes de la veille (serveur tombé / revenu).
