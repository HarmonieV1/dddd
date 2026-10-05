# Administration : txAdmin + gs_admin

| Outil | Pour quoi | Accès |
|---|---|---|
| **txAdmin** (web, `http://localhost:40120`) | restarts, console, backups, **bans** (base anti-contournement), whitelist, stats | comptes txAdmin |
| **Menu txAdmin en jeu** (`/tx`) | noclip, god, TP, spectate, freeze, véhicules, warn/ban, IDs au-dessus des têtes | permissions txAdmin |
| **gs_admin** (F10 / `/admin`) | tout ce qui est propre à notre RP : tickets, fiches, isolement, économie, contrats, météo, annonces | ACE `gs.admin.*` |

## gs_admin
- **Tickets** : les joueurs font `/report <message>` (1 ticket ouvert max, cooldown 2 min) ; le staff **en service** (`/staff` ou bouton) est notifié avec un son ; prendre, aller au joueur, ouvrir sa fiche, clôturer.
- **Fiche joueur** branchée sur tous nos systèmes : job actif + contrats, recherche (étoiles), duo, pseudo Néon, isolement, ping, durée de session ; + licence et historique staff (modo) ; + argent (admin).
- **Actions** (le serveur revérifie tout, motif obligatoire pour les sanctions) :
  - Helper : tickets, aller au joueur, fiche
  - Modo : amener, soigner, réanimer, réparer véhicule, figer, effacer la recherche, note staff, **avertir, isoler, expulser**
  - Admin : ajouter/retirer contrat, météo, annonce, section Fun
  - Super-admin : donner/retirer argent (plafond 100 000 $), donner item (plafond 100) — **motif obligatoire**, journalisé
  - Fondateur : promouvoir / rétrograder le staff, items sans motif, retirer / poser des items
- **Anti-abus staff** : impossible de sanctionner un staff de niveau égal ou supérieur ; toute tentative sans le niveau est loggée.
- **Isolement (jail admin)** : cour de Bolingbroke, compte à rebours à l'écran, retour automatique en cellule en cas de fuite, **persiste à la déconnexion** (par licence).
- **Transparence** : avertissements, isolements, expulsions **et bans/warns/kicks txAdmin** publiés sur un salon public (`gs_webhook_sanctions`), staff anonyme.
- **Journal** : toutes les actions staff en BDD (`gs_admin_log`) + webhook staff + onglet Journal (modo+).

## Menu staff rapide (F11) — V7

V7 : 5 catégories — **Joueurs**, **Moi** (pouvoirs, persos GTA, animaux, métier / gang de test, argent et items super-admin),
**Véhicules**, **Monde et lieux** (lieux publics, **Déplacer un point**, points de métier, gangs, décor, coordonnées),
**Événements** (événements en un clic + bonus serveur double XP / soirée chanceuse + effets sur soi). Ancienne description :

## Menu staff rapide (F11) — V2

Menu **cliquable à la souris** (chaque ligne porte sa propre action, sous-menus avec flèche, retour en haut à gauche). Les pouvoirs ne marchent **qu'en mode staff** (1re ligne),
et le couper coupe tout : vol, invisibilité, invincibilité, animal, spectate.

| Fonction | Niveau |
|---|---|
| Mode staff, noms et ID au-dessus des joueurs, aller à un joueur, copier ses coordonnées | Helper |
| Vol libre, invisible, invincible, se transformer en animal, TP au marqueur, spectate, amener, soigner, figer, supprimer un véhicule | Modérateur |
| Se mettre (ou mettre un joueur) un **métier et un grade**, dans un **gang**, faire apparaître un véhicule | Admin |
| **Points de métier** : déplacer service / coffre / armurerie / direction / garage à sa position (bâtiments fermés, futurs MLO) | Admin |
| **Fun** (sur soi, events) : course rapide, super saut, endurance infinie, nage rapide, gravité lunaire, visions nocturne / thermique | Admin |
| **Items** : donner (motif obligatoire) · **Objets du décor** (placer / retirer une poubelle, un banc…) | Super-admin |
| **Items** sans motif, retirer, poser au sol · **Rang staff** d'un joueur (Joueurs → joueur → Rang) | Fondateur (`group.god`) |

**Raccourcis du mode staff** (Ctrl gauche maintenu) : `Ctrl+Y` TP au marqueur · `Ctrl+U` vol libre · `Ctrl+O` noms et ID.
Modifiables : Échap → Paramètres → Raccourcis clavier → FiveM.

Chaque action est revérifiée par le serveur (niveau, mode staff, cible) et journalisée (F10 → Journal, webhook staff).
Vol libre : ZQSD, Espace/Ctrl pour monter/descendre, Shift vite, Alt lent. Spectate : Retour pour arrêter.

## Donner les droits (V5)
- **Fondateur** : `DEVENIR-ADMIN.bat` (te met en `group.god`), ou `add_principal identifier.license:XXXX group.god` dans `cfg/secrets.cfg`.
  Un fondateur ne se crée jamais depuis le jeu.
- **Tout le reste, en jeu** : menu staff (F11) → Joueurs → le joueur → **Rang staff (fondateur)** → Helper / Modérateur / Admin /
  Super-admin / Joueur. Effet immédiat, enregistré en base (`gs_admin_ranks`), réappliqué à chaque démarrage.
  Seul le fondateur voit cette ligne ; super-admin et admin ne peuvent promouvoir personne.
- Hiérarchie : god (fondateur) > superadmin > admin > mod > helper (voir `cfg/permissions.cfg`).
- Un rang écrit à la main dans `secrets.cfg` ne peut pas être retiré depuis le jeu : préfère le menu.

## Tests
`tests/test_gs_admin.lua` (50 tests) : niveaux, anti-abus, motifs, plafonds, tickets, isolement persistant, publication des sanctions.

## Mapping en jeu : gs_builder (`/builder` ou menu staff → Objets du décor, super-admin et fondateur)
Placer n'importe quel objet du jeu, le déplacer, le tourner, le dupliquer, le supprimer. Sauvegardé en BDD, visible par tous.
- **Placer** : nom du modèle (ex. `prop_bench_01a`) ou favoris → l'objet suit ton viseur.
- **Contrôles** : `TAB` mode viser/précis · flèches déplacer · `PgUp/PgDn` hauteur · `Q/E` tourner · molette rotation fine ·
  `X` remettre droit · `G` poser au sol · `Shift` rapide · `Ctrl` précis · `Entrée` valider · `Retour` annuler.
- **Modifier** : « Modifier l'objet visé » ou « Objets à proximité » → déplacer / dupliquer / supprimer.
- **Retirer un objet de la map d'origine** (poubelle, banc, barrière…) : vise-le → « Retirer l'objet de la map visé » ; il
  disparaît pour tous. « Objets de la map retirés » les remet (500 max).
- **Planque de gang** : « Placer une planque de gang ici » (le coffre du gang est créé à ta position).
- Perf : chaque joueur ne crée localement que les objets à moins de 150 m (aucune entité réseau), 3000 objets max.
- Sécurité : tout est revalidé serveur (permission, nom de modèle, position, distance < 60 m), chaque action loggée.
- Noms des objets : bibliothèque en ligne « GTA V prop list » (ex. gta-objects.xyz) ou favoris dans `gs_builder/shared/config.lua`.

## V8 · Ajouts au menu F11
- Événements → **Météo événementielle** (tempête, canicule, brouillard, arrêt) et **Halloween sur la route** (activer, désactiver, automatique).
- Joueurs → [joueur] → **Effacer sa recherche (étoiles)**.

## V9 · Staff, sécurité, Discord, sauvegardes
- **F11 → Anti-triche** : dernières alertes (téléportations répétées, vitesse impossible à pied / en voiture, arme interdite, gains d'argent anormaux sur 5 min, rafale d'objets). **Aucune sanction automatique** : on vérifie (spectate, Aller à) puis on décide. Tout le staff (niveau 1+) et les ACE `command` sont exemptés : vol libre, invisible, TP, dons d'argent du staff ne déclenchent rien. Alertes aussi dans Discord (`gs_webhook_anticheat`, sinon `gs_staff_webhook`). Désactiver : `set gs_anticheat "false"` ; seuil d'argent : `set gs_anticheat_money "250000"`.
- **F11 → Statistiques de rétention** (admin, niveau 3+) : nouveaux joueurs sur 7 jours, retour le lendemain, retour dans la semaine, abandon à la première session (< 15 min), durée moyenne, joueurs et pic par jour. Console : `gsstats`.
- **Discord** : `CONFIGURER-DISCORD.bat` remplit `secrets.cfg` (webhooks #statut et #annonces, adresse `gs_connect`, jeton du bot et serveur Discord, saisis masqués). Le message #statut est modifié chaque minute ; « La ville est ouverte » au démarrage ; redémarrages txAdmin annoncés (15, 5, 1 min). Rôles de métier : identifiants des rôles dans `gs_discord/shared/config.lua` (`Config.Roles`), le bot doit être au-dessus de ces rôles avec « Gérer les rôles ». Le **bot RoadLine tourne dans le serveur** (`gs_discord/server/bot.js`, présence + /statut /rejoindre /rdv /site) : rien à installer, il démarre avec le serveur (local ou hébergeur) dès que le jeton est rempli ; CONFIGURER-DISCORD ouvre le lien pour l'ajouter à ton Discord. `METTRE-A-JOUR.bat` sauvegarde la base avant chaque mise à jour et programme les sauvegardes toutes les 6 h tout seul.
- **Sauvegardes** : `SAUVEGARDER-BDD.bat` → programmer **toutes les 6 h** (30 gardées, ~1 semaine). **Retour en arrière** : `RESTAURER-BDD.bat` → 1. toute la base (serveur arrêté) ou 2. **un seul joueur** (citizenid : perso, argent, inventaire, métier + véhicules) pendant que le serveur tourne (joueur déconnecté). L'état actuel est toujours sauvegardé avant (« avant-restauration ») pour pouvoir annuler. Hébergeur Linux : `scripts/linux/roadline-bdd.sh` (`sauvegarde`, `liste`, `restaurer`, `restaurer-joueur`, `programmer`).
- **Rendez-vous fixes** (`gs_events/shared/config.lua`, `Config.Weekly`) : mercredi des métiers, vendredi des courses, nuit des combats (le ring reste ouvert), road trip du dimanche. Rappel en jeu + Discord 30 min avant. `/gsevent` reste prioritaire.
- **Nouveaux systèmes à surveiller** : racket (`/racket`, crimes `racket` signalés aux témoins), fraude à l'assurance (casier « Fraude à l'assurance »), contrats en litige (juges / avocats prévenus), doublure des patrons (bars uniquement).

## V10 · Ville vivante, téléphone, quartiers
- **Faits divers PNJ** (`gs_faitsdivers`) : créés seulement si un policier est en service ET que les joueurs n'ont presque pas commis de crimes depuis 20 min (2 affaires ouvertes max, classées après 25 min). Staff : F11 → Événements → **Fait divers PNJ** (au hasard ou par type), ou `faitdivers [burglary|body|hitrun|vandalism]` en console. Lieux déplaçables (F11 → Monde → Déplacer un point).
- **Le quartier évolue** (`gs_city`, `Config.Standing`) : standing -100 → +100 par quartier, sauvegardé. Monte avec les vraies ventes des commerces et les vitrines réparées, baisse avec crimes, tags, trafics ; revient vers 0 d'1 point par heure. Visible dans `/quartiers` et l'appli Ville. Déchets à ramasser en déclin (payés, 30 par heure et par joueur max).
- **Radio Los Santos** (`gs_lsradio`) : ne relaie pas les brèves Weazel (elles ont déjà leur bandeau) ; ajoute des lignes via `exports.gs_lsradio:Say('texte')`.
- **Les commerçants se souviennent** (`gs_economy`, `Config.Regulars`) : habitué = 5 jours d'achats (-5 %), braqueur à visage découvert refusé 48 h dans ce magasin.
- **Téléphone** : notes, lieux favoris, appels récents et réglages sont gardés sur le PC du joueur (rien en base) ; « Que faire ? » vient de `gs_onboarding/shared/guide.lua` (lignes faciles à ajouter : libellé, description, commande ou point GPS).
- **Bot Discord** : installation pas à pas dans `docs/DISCORD.md` (5 étapes, une seule fois).

## V10.1 · Justice, presse, staff à distance, OVH
- **Caméras** (`gs_cctv`) : 20 caméras (déplaçables), 3 terminaux police ; passages gardés 60 min ; une bombe de peinture aveugle une caméra 30 min.
- **Mandat** (`gs_justice`, `Config.Warrant`) : planques de gang et chambres de motel signalent leurs visites ; seuil → signalement police ; juge de permanence si aucun juge en service.
- **Pièces au tribunal / chantage** (`gs_justice` + `gs_evidence`, `Config.Pieces`, `Config.Blackmail`) : 12 pièces max par affaire ; chantage 100 à 50 000 $, une photo ne sert qu'une fois.
- **Enchères de la fourrière** (`gs_auction`) : samedi 21 h (30 min) ; staff : `/encheres` → ouvrir / clore une vente à tout moment ; gagnant hors ligne livré à sa connexion.
- **Direct Weazel** (`gs_social`, `Config.Live`) : chaleur ≥ 45 ; un direct toutes les 20 min max ; journalistes payés 150 $/min (1 500 $ max).
- **Staff à distance** : bot Discord (docs/DISCORD.md) et panneau web `/gs_admin/` (codes `gs_admin_web` dans secrets.cfg, docs/OVH.md § 5). Mêmes actions, journalisées.
- **CAPTURER-ERREURS.bat** : lance le serveur 2 min et ouvre `C:\GTASOON\logs\erreurs.txt` (erreurs + 80 dernières lignes) — à m'envoyer en cas de souci au démarrage.
- **Serveur officiel** : docs/OVH.md (PREPARER-OVH.bat, METTRE-A-JOUR-OVH.bat, commande `roadline`).

## V10.2 · Retours du backtest, rumeurs, nuit, dossier
- **Objets** : METTRE-A-JOUR.bat traduit les noms (server/locales-fr/items.json, weapons.json) et ajoute les images manquantes (server/item-icons, généré par `python3 tools/item_icons.py`).
- **Anti carkill** (`gs_security`) : dégâts d'un véhicule sur un joueur à pied annulés ; alerte « carkill probable » dans F11 → Anti-triche. Désactivable : `set gs_anticarkill false`.
- **Alertes LSPD** (`gs_wanted`, `Config.Alerts`) : coups de feu (sauf silencieux) et arme blanche toujours signalés aux policiers en service (rue + GPS, sans description).
- **Coiffeur** (`gs_places`, `Config.Barber`) : 150 $ ; `enabled = false` pour revenir au menu d'illenium.
- **Rumeurs qui deviennent vraies** (`gs_rumors`, `Config.Seeds`) : 3 personnes différentes en 2 h → le staff reçoit l'alerte ; `/rumeurvraie storm|stash|crime` ou `/rumeurfausse …` (staff niveau 2+) ; sans réponse en 10 min, la ville tranche seule.
- **Ville de nuit** (`gs_nightcity`) : groupes de PNJ et marchés de nuit déplaçables (F11 → Déplacer un point) ; marché ouvert 22 h → 5 h (heure du jeu).
- **Dossier** (`gs_dossier`, `/dossier`) : lecture seule ; chaque consultation est journalisée (logs métiers).
- **Carte en direct du site** : remplir `cityUrl` dans `docs/site/index.html` avec l'adresse https du serveur + `/gs_city/ville.json`.

