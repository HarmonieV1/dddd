# État du projet RoadLine RP — récapitulatif complet (à jour au 13/10/2026, V12.38)

Ce document sert de **point de sauvegarde** : si une conversation avec Claude est perdue, compressée ou doit reprendre
ailleurs, tout ce qu'il faut savoir est ici. Il est versionné avec le code (`git log` en garde aussi l'historique).
En bas de ce fichier : un **prompt prêt à coller** dans une nouvelle conversation pour repartir sans rien perdre.

---

## 0. Où on en est (12/10/2026, V12.25) — récapitulatif global

**Phase** : bêta fermée en cours (des testeurs sont en ville et d'autres arrivent cette semaine), ouverture officielle le
**20/10/2026 à 21 h**. Décision du 11/10 : pas de gel des nouveautés, mais désormais **surtout du correctif, de la
configuration et de l'optimisation** ; l'utilisateur se consacre à la promotion.

**Le serveur en chiffres** : 66 ressources maison, ~34 systèmes exclusifs (« signatures »), 40 mappings payants installés,
2 882 tests automatiques, tous verts ; 27 pièges anti-triche ; 25 types de crimes reliés au central police ; budget de performance
tenu (136 boucles client, 6 permanentes par image).

**Documentation** : `docs/hub/index.html` (double-clic) = toute la doc en un site hors ligne, par catégories, recherche,
backtest et priorités à cocher (sauvegardés dans le navigateur, export / import .json, rapport texte, impression).
Régénéré par `python3 tools/doc_hub.py` (aussi lancé par tests/run.sh). Les priorités cochables sont dans `PRIORITIES`.

| Domaine | État |
|---|---|
| Base Qbox/ox, installation PC + VPS (scripts .bat) | ✅ Stable, mises à jour en un clic, sauvegardes BDD programmées |
| Gameplay (métiers, économie, illégal, police, EMS, justice) | ✅ Complet, cohérence des alertes auditée (V12.7) |
| Signatures (ville qui se souvient, rumeurs, Gazette, black-out, échos…) | ✅ Livrées, à éprouver avec du monde |
| Sécurité (anti-triche, pots de miel, bans F11, verrous Discord) | ✅ En place ; `entityLockdown strict` après l'ouverture |
| Staff (F11, appli web, txAdmin, bot Discord) | ✅ Complet ; déplacement des points réparé et vérifié en jeu |
| Bot Discord (statut, tickets, modération, annonces, bienvenue) | ✅ À valider sur le VPS (fiche de recette 1b et 1d) |
| Site (Netlify) | ✅ V13 : météo et heure de la ville en direct, son opt-in, IP masquée jusqu'au 20/10 |
| Arrivée en bus | ✅ Réparée (sol chargé avant le bus, dépose au sol réel, secours si bloqué) |
| Mappings / MLO | ⏳ **40 maps payantes (packs Patoche, escrow)** installées le 12/10, doublons retirés (`RETIRED_MAPS`). Reste : tour en jeu de chaque intérieur (certains « chargent sans fin » : la console signale en rouge les maps activées mais non démarrées = licence Cfx ou .fxap), dernier conflit concession + gang 2 (fusion V12.24 à confirmer) |
| Crash FiveM du fondateur (erreur 506) | ⏳ Côté PC (launcher Rockstar / droits admin / OneDrive) : `REPARER-FIVEM.bat` livré, à lancer |
| Cabines téléphoniques (refonte « vraies cabines de la map ») | ⏳ À discuter |
| Recette en jeu | ⏳ Fiche `ROADLINE_Backtest_complet.pdf` (sessions 0 → 6, dont 1b / 1c / 1d prioritaires) |

**Avant l'ouverture, dans l'ordre** (cochable dans `docs/hub/index.html` → Priorités) : 1) FiveM réparé sur le PC du
fondateur (REPARER-FIVEM) ; 2) tour en jeu des 40 maps, désactiver celles qui chargent sans fin ; 3) backtest (56 tests,
★★★ d'abord) → corrections ; 4) vêtements / coiffures en plus (packs FiveM ready, sans marque) ; 5) Discord finalisé ;
6) annonce de recrutement ; 7) passage du profil privé au public (code cfx.re) le jour J. **Pas de nouveau gros système
avant l'ouverture** : correctifs, configuration, optimisation.

---

## 1. Identité du projet

**RoadLine RP** : serveur FiveM GTA RP **100 % français**, bâti sur **Qbox/ox** (qbx_core, ox_inventory, ox_lib,
ox_target...). Dépôt : `harmoniev1/dddd`. Ressources maison dans `server/resources/[gtasoon]/gs_*` (66 ressources).
Positionnement : **Free Access, zéro pay-to-win**, une ville qui vit même sans les joueurs, beaucoup de systèmes
exclusifs (« ce que tu ne trouveras nulle part ailleurs »).

**Branches à jour** (toujours pousser sur les deux) :
- `feature/phase1-bridge`
- `claude/gta-rp-architecture-stack-pbvdxz`

**Dernier commit poussé** : « V12.38 : fusion des sessions Windows (V12.37) et web (V12.35) » (hash exact :
`git log -1 origin/feature/phase1-bridge`). Les deux branches pointent sur le même commit.

**Deux sessions Claude en parallèle** (poste Windows et session web) : elles ne se voient pas. Toujours synchroniser
par un colis (zip de l'installation ou de la session) + ce fichier, et comparer les arbres en ignorant les fins de ligne
(CRLF) avant de fusionner. La V12.9 est le point de rencontre commun : toute nouvelle session repart de là.

## 2. Versions : interne vs publique (important, piège classique)

Depuis la V11.3, il y a **deux numéros de version différents**, volontairement :
- `gs_version` (convar, `server.cfg.example`) = **V12.38** → version technique interne, vue par le staff (F11, console,
  METTRE-A-JOUR). Continue d'avancer à chaque mise à jour (V11.2, V11.3...).
- `gs_public_version` (convar) = **« V4 · bêta »** → version vue par les **joueurs** (écran de chargement, statut
  Discord, Gazette). Le site affiche son propre journal (V1 à V4, V5 « classé confidentiel »).

**Pourquoi** : le développement local a pris de l'avance (V11.x en interne) alors que, officiellement, le serveur n'a
eu que 4 grosses sorties publiques. Pour que la numérotation reste cohérente aux yeux des joueurs, on affiche V4.
**Ne jamais réaligner les deux** sans que l'utilisateur le demande explicitement.

## 3. Infrastructure

- **VPS OVH** : Ubuntu 24.04, IP **57.129.170.173**, user `ubuntu`, connexion SSH par clé (jamais de mot de passe
  envoyé en clair). Port jeu **30120**, txAdmin **40120**.
- **Mode actuel : txAdmin** (pas le mode « simple »). Le watchdog du serveur surveille le port 40120 dans ce mode.
- **Profil actuel : privé** (caché de la liste FiveM, 16 places) — donc **pas encore de code cfx.re** (il n'apparaît
  qu'au passage en public). Adresse de connexion directe en attendant : `57.129.170.173:30120`.
- **Site** : hébergé sur **Netlify** (roadlinerp), mis à jour en glissant tout le dossier `docs/site/` (voir
  `PUBLIER-SITE.bat`). Carte en direct branchée sur `https://57-129-170-173.sslip.io/gs_city/ville.json`.
- **Ouverture officielle prévue** : **20/10/2026 à 21 h (heure de Paris)** — réglée dans `CONFIG.opening` du site.
- **Discord** : bot RoadLine intégré au serveur (`gs_discord/server/bot.js`, Node pur, pas de dépendance npm externe),
  démarre avec le serveur FiveM dès que le jeton est renseigné. Statut actuel : **bot connecté**, webhooks
  `gs_webhook_status` et `gs_webhook_annonces` **OK** ; `gs_staff_webhook` et `gs_webhook_sanctions`
  **non réglés** (à faire : créer les webhooks dans ces salons Discord, les coller dans CONFIGURER-DISCORD, puis
  GERER-OVH → 12).
  - **V11.4** : commandes staff du bot (`/joueurs /geler /degeler /avertir /expulser /message /annonce`) réservées
    au **rôle `gs_discord_staff_role` + propriétaire du Discord**, et **uniquement sur le Discord `gs_discord_guild`**
    (passe-droit « Administrateur » retiré : faille, le bot pouvait être invité sur un autre Discord). Commandes
    enregistrées sur ce Discord seulement. Nouveau : `/aide`, `/ticket sujet` (fil privé dans `#tickets`,
    `gs_discord_ticket_channel`) et `/fermer`. `gs_discord_tickets "false"` = bot de tickets externe.
  - V12.1 : `sv_maxclients` = 48 en privé (`dev.cfg`) comme en public (`prod.cfg`) : bot et site affichent X/48. 64 = Element Club Argentum.

## 4. Outils d'installation / exploitation (PC Windows + VPS)

Tout est scripté, zéro mot de passe affiché en clair :
- `INSTALLER.bat` / `METTRE-A-JOUR.bat` (PC = environnement de test)
- `METTRE-A-JOUR-OVH.bat` (envoie la version du PC vers le VPS, sauvegarde la base avant, ~30 s de coupure)
- `GERER-OVH.bat` (menu à 22 options : état/diagnostic, console, erreurs, marche/arrêt, public/privé, sauvegardes,
  mode simple/txAdmin, retour arrière, Discord, codes staff, adresse https...)
- `CONFIGURER-DISCORD.bat` (jeton bot, webhooks, adresse de connexion — voir piège ci-dessous)
- `POUSSER-GITHUB.bat` (V12.34 : envoyer les commits du PC sur GitHub après les tests, récupérer ceux de l'autre session ; `docs/GITHUB.md`)
- `PREPARER-OVH.bat`, `CAPTURER-ERREURS.bat`, `SAUVEGARDER-BDD.bat` / `RESTAURER-BDD.bat`, `IMPORTER-MODS.bat`,
  `DEVENIR-ADMIN.bat`, `PUBLIER-SITE.bat`, `REPARER-FIVEM.bat` (erreur 506 / déconnexions Rockstar, côté joueur),
  `VIDER-CACHE-FIVEM.bat`, `NETTOYER-MARQUES.bat`

**Piège vécu cette session** : l'utilisateur a demandé « c'est quoi mon adresse cfx » en croyant qu'elle existait déjà
— elle n'existe pas tant que le serveur n'est pas passé en public au moins une fois. Résolu en utilisant l'IP directe
en attendant.

## 5. Ce qui a été livré, dans l'ordre (V1 → V12.9)

Résumé très condensé (le détail complet est dans `docs/ROADMAP.md`, `docs/FEATURES.md`, `tools/bilan.py`) :
- **V1-V2** : la rue et les métiers de base, la ville a une mémoire (témoins, preuves, carnet véhicule).
- **V3** : une ville qui vit sans le joueur (quartier réactif, radio, justice/presse, ville de jour/nuit, rumeurs).
- **V7 à V10.2** : vagues de confort, staff, récolte, illégal, EMS/casino, tenues objets, cicatrices de la ville,
  cavale/légendes, anti-triche, bot Discord, sauvegardes, téléphone, caméras/mandats, preuves recevables, enchères,
  Direct Weazel, objets en français, anti-carkill, coiffeur, alertes LSPD.
- **V11** : bêta ouverte sur le VPS OVH — lieux de mémoire, ville en timelapse (site), panneau staff mobile (appli),
  veille avec alerte/relance, correctif traduction des objets.
- **V11.1** : nouvel écran de chargement (1re version, coucher de soleil façon Vice City), « Précédemment à Los
  Santos », PUBLIER-SITE.bat.
- **V11.2** (cette session, début) :
  - **Vraie carte de Los Santos** sur le site (atlas du jeu recoloré, calibration CRS précise par points de repère).
  - **Les jurés de Los Santos** (`gs_justice`) : procès → juge convoque un jury de 5 citoyens tirés au sort, vote,
    verdict suit la majorité.
  - **La Gazette du dimanche** (`gs_city/server/gazette.lua`) : journal hebdo auto-composé (faits divers, verdicts,
    jurys, légendes, plaques, rumeurs, black-out), publié dimanche 20 h sur Discord/site/jeu (`/gazette`,
    `/gazettepublier` pour le staff).
  - **Black-out de quartier** (`gs_city/server/blackout.lua`) : sabotage de transformateur (crochet, 20 s) → 15 min
    sans lumière/néons/caméras dans le quartier, police prévenue, réparable par tous (payé par la mairie).
  - **Écran de chargement V2** : intro animée, variante nuit, accueil personnalisé (« Bon retour Prénom · job ·
    absent depuis N jours »), bandeau Weazel News, icône météo dynamique, 8 cartes illustrées.
  - Docs, backtest (88 tests), bilan V11.2, zips de livraison régénérés.
- **V11.2 (suite, retours utilisateur)** :
  - Site : Gazette passée en **habillage papier journal d'époque grisé** (grain SVG, pli central, titre gothique
    Old Standard TT / UnifrakturMaguntia, bandeau N°/édition/prix).
  - Journal des mises à jour du site corrigé : V1→V2→V3→**V4** (contenu ex-« V11 »)→**V5 confidentiel** (au lieu du
    saut V3→V11 qui n'avait pas de sens pour un joueur).
  - **Guide du joueur PDF** créé (`tools/guide_joueur.py`, 25 pages) : premiers pas, argent, véhicules, métiers
    libres/sous contrat, récolte, recettes/fabrication, commerces, activités/loisirs, le côté obscur (illégal),
    justice/police, « la ville qui vit sans toi », + annexe catalogue complet de la concession.
    Données extraites des vrais fichiers de config (`shared/config.lua` de chaque ressource) + liste de véhicules
    Qbox (`shared/vehicles.lua`) + config `qbx_vehicleshop`.
- **V11.3** (cette session, suite aux retours) :
  - **Concession nettoyée** (`scripts/windows/outils-communs.ps1` patché + nouveau fichier
    `scripts/windows/prix-vehicules.json`, appliqués par METTRE-A-JOUR/METTRE-A-JOUR-OVH, idempotents) :
    - **Salle Luxe** ajoutée à la PDM : catégories « ★ Luxe · Sportives » (117 modèles) et « ★ Luxe · Supercars »
      (55 modèles) — avant, ces ~170 véhicules étaient orphelins (envoyés vers une boutique « luxury » désactivée).
    - **94 véhicules retirés** : armés (Weaponized...), d'arène (Apocalypse/Future Shock/Nightmare...), militaires,
      blindés, de service (police, LSDWP...), doublons « (Yacht) », sous-marins.
    - **Aéroport** : passé de 5 à **31 appareils civils** (17 avions + 14 hélicoptères).
    - **Prix remis à plat** : bateaux (12 500 $ à 210 000 $), avions/hélicos (45 000 $ à 3,4 M$), supercars
      (180 000 $ à 650 000 $), sportives (prix Qbox ×1,5). Catalogue final : **600 véhicules**.
    - Simulation/validation faite en Python+Lua dans ce conteneur (pas de PowerShell disponible ici) : patchs
      appliqués deux fois de suite pour prouver l'idempotence, résultat vérifié avec un interpréteur Lua.
  - **Adresse IP masquée jusqu'à l'ouverture** (site) : `CONFIG.hideIpUntilOpening = true`. Tant que la date
    `opening` n'est pas passée : l'adresse s'affiche caviardée (`███.███.███.███`), tous les boutons « Rejoindre »
    pointent vers le Discord. Se lève automatiquement le jour J, sans republier. Adresse de connexion, URL de la
    carte en direct et URL du panneau staff sont stockées **encodées en base64 à l'envers** dans le HTML
    (`connectB64`, `cityUrlB64`, `staffUrlB64`) pour ne pas apparaître en clair dans le code source de la page.
    **Limite connue, assumée** : un visiteur qui ouvre l'onglet Réseau du navigateur peut voir l'IP via l'appel à
    la carte en direct. Un nom de domaine (prévu V12) réglera ça proprement.
  - **Nouvelles signatures ajoutées sur le site** (section « Ce que tu ne trouveras nulle part ailleurs ») dans les
    3 piliers concernés : Black-out de quartier, faits divers PNJ, quartiers qui montent/coulent, économie liée à la
    météo / duo criminel, contrebande en mer, combats clandestins, guerres de territoire et racket, prison vivante /
    jurés, garde à vue avec droits, contrats signés, mentors. Compteur passé à **« 34 systèmes »**.
  - `docs/REGLEMENT.md` : règlement complet prêt à coller sur Discord, **12 messages** (chacun < 2000 caractères,
    limite Discord), 10 sections (respect, bases du RP, valeur de la vie/combats, crime, gangs/territoires,
    police/justice/prison, métiers/économie/véhicules, communication/Discord, staff/sanctions, boutique). Collé aux
    vrais systèmes du serveur (effectifs minimum de braquage, jurés, cavale, guerres de territoire...).
  - **`tools/guide_staff.py`** : micro-guide staff interne (3 pages PDF, `ROADLINE_Guide_staff.pdf`) — rangs et
    pouvoirs, outils (F11/F10/appli/bot), traiter un `/report` en 5 étapes, barème de sanctions, anti-triche,
    commandes pour animer la ville, déontologie, gestion des pépins.
  - Correctif technique en route : point-virgule interdit dans un commentaire de `server.cfg.example` détecté par
    `tests/check_cfg.py` (les `;` sont des séparateurs de commandes FiveM même en commentaire) → corrigé.
  - Tous les tests (`tests/run.sh`) verts, commit `2c1c335` poussé sur les deux branches, zips `livraison/` regénérés
    et envoyés.

- **V11.4** (session du 09/10/2026, poste Windows) — bot Discord :
  - Sécurité : commandes staff limitées au Discord RoadLine + rôle staff + propriétaire (plus de passe-droit admin).
  - Commandes enregistrées sur le Discord RoadLine seulement (globales vidées), `/aide`.
  - Tickets : `/ticket sujet` → fil privé dans `#tickets` (joueur + rôle staff), un par membre, 2 min entre deux,
    `/fermer` (auteur ou staff) archive + verrouille. Réponse différée (pas de « l'application ne répond plus »).
  - Robustesse : connexion morte détectée (battement sans accusé), reconnexion 10 s → 5 min au lieu de 10 s en
    boucle, arrêt net sur jeton refusé / intents invalides (4004, 4010-4014).
  - CONFIGURER-DISCORD demande aussi `gs_staff_webhook`, `gs_webhook_sanctions`, Discord, rôle staff, salon tickets,
    et redonne le lien d'invitation (nouveaux droits : fils privés). Tests du bot : 20 → 43.
  - Outils de test sous Windows : `lua5.4`/`luac5.4` (copies de Lua 5.4.6), Python 3.12, Node 24, et un décalage
    d'`os.date` pour les dates avant 1970 de l'horloge simulée (Windows les refuse, Linux non), hors dépôt.
- **V11.5** (09/10/2026, retours du backtest en jeu) :
  - **Personnages** : 1 par joueur (`defaultNumberOfCharacters = 1`, correctif qbx_core), **2** pour le fondateur, les
    super-admins et les **VIP** (nouveau statut : F11 → Joueurs → VIP, fondateur ; ACE `gs.vip`, table `gs_admin_vip`,
    export `gs_admin:CharacterSlots` appelé par un correctif de `qbx_core/server/character.lua`).
  - **Apparition** : plus de choix du lieu (`qbx_spawn` retiré de `resources.cfg`) → on réapparaît où on s'est
    déconnecté ; nouveau perso : mairie, avec **arrivée en bus** (`gs_onboarding/client/arrival.lua`, une fois par
    personnage, table `gs_arrival`, Espace pour passer, `Config.Arrival`).
  - **Téléphone** : impossible menotté / mort / coma (client + serveur), se range tout seul si ça arrive ; ouvert =
    caméra figée, aucun coup / tir / carte / changement d'arme, quelle que soit l'option « marcher ».
  - **Touches pendant une saisie** : garde `IsNuiFocused()` sur F3, F4, F6, F7, F9, F10, F11, I, H, B, raccourcis
    staff, et sur toutes les boucles « [E] » (marqueurs, duo, missions, preuves, braquage, route, tags).
  - **Prise de service** : depuis le téléphone (appli Emplois) ou `/service` (touche à choisir), de n'importe où, avec
    un téléphone sur soi (`toggleDuty(true)`, `duty_no_phone`) ; au point de service sinon, comme avant.
  - **Permis de conduire** : plus de points (`Config.Points.enabled = false`, réactivable) ; la police **retire / rend**
    le permis (F4 → Contrôle d'identité → Permis, motif obligatoire au casier, `gs_driving:SetLicence`), carte reprise.
  - **Port d'arme (PPA)** : la **carte** `weaponlicense` est remise à l'achat (comptoir) et par la police, reprise au
    retrait (`gs_bridge:LicenceCard`) ; le plafond journalier d'armurerie n'est plus consommé par un achat qui échoue.
  - **Munitions / armes / accessoires en français** : `locales-fr/weapons.json` complet (toutes les armes dont Mk II,
    toutes les munitions `ammo-*`, tous les accessoires `at_*`, qui n'étaient jamais traduits car cherchés dans
    items.lua) ; F11 accepte les noms avec tiret (`ammo-9`).
  - **F11** : items par **catégorie avec image** (armes, munitions, accessoires, nourriture, cartes, RoadLine, autres)
    + recherche ; véhicules : **catalogue Qbox par catégorie** (marque, nom, prix) + nom de spawn.
  - **Armes longues dans le dos** (`gs_details/client/holster.lua`, `Config.Back`) : visibles par tous via le state bag
    `gsBack`, pistolets exclus, 2 max.
  - **Nourriture périssable** : `degrade` ox_inventory (frais 2 j, chips / donut 7 j, boissons jamais).
  - **Food truck de Legion Square** : camion `taco` posé derrière le vendeur (il n'était jamais créé).
  - **Caméras** : accroche automatique au mur / poteau le plus proche (16 rayons, `Config.Mount`), orientées vers la rue.
  - **Acheteurs de récolte** (poissonnerie, scierie, marché, boucherie) : un PNJ visible à chaque point.
  - Tests : driving, police, admin (VIP, munitions), jobs (service par téléphone), blackmarket (PPA, plafond), phone.
  - **Non fait, à discuter** : création de perso façon « gros WL » (grille de visages) = V12 ; DLC vêtements / voitures,
    Miami, îles et détails de map = assets à fournir (importeur prêt) ; effets txAdmin = réglage txAdmin, pas du code ;
    erreurs ambulance / banque = besoin du log (GERER-OVH → 3) ; F11 événements « à optimiser » = préciser.

- **V11.6** (09/10/2026, demande secondaire) :
  - **Mapping dans F11** (Monde et lieux → Mapping, super-admin) : `gs_builder` s'ouvre avec retour vers F11 (`exports.gs_builder:Open`),
    **catalogue par catégories** (`Config.Catalog` : mobilier, chantier, éclairage/fête, végétation, stands, déchets, plage, police ;
    ~150 objets en français) + nom libre + favoris. Pas d'images : le jeu n'en fournit aucune pour les props.
  - **Porter un objet** : W → Moi → « Porter un objet » et `/porter` (carton, caisse à outils, bière, pizzas, sac, boisson, cônes,
    pneu, poubelle, plante, guitare, « Poser ») via `scully_emotemenu:playEmoteByCommand` ; F5 → Props reste complet.
  - **Points** : F11 → « Déplacer / retirer un point » : 300 m, **filtre par ressource**, et **« Retirer ce point du jeu »**
    (super-admin, réversible « Réactiver ») : `gs_bridge` DisablePoint / EnablePoint, KVP `gs_points_off`, la ressource reçoit
    une position hors carte (-9000, -9000, -500), le menu garde la vraie. Les points de métier (service, patron, coffre…)
    gardent leur menu « Points de métier » (déplacement seulement).

- **V12.0** (09/10/2026) · « La ville se souvient », 6 features + la signature surprise :
  - **Site** : bandeau « En ce moment en ville » (`ville.json` → nouveau bloc `now` : météo FR, heure, joueurs, quartiers
    chauds, prochain rendez-vous, dernière rumeur vérifiée, lieux de mémoire ; `.js-players` rempli sans code cfx) ;
    **candidature en 3 questions** (`#candidature`, `POST /gs_city/candidature` → webhook `gs_webhook_candidatures`
    sinon `gs_staff_webhook`, CORS + OPTIONS, 1 envoi / 10 min / IP, 30 / h, champs nettoyés, aucune mention Discord).
  - **gs_memoire (nouveau)** · la mémoire des lieux : cases de 40 m, événements sources (crime signalé, arrestation,
    mariage `gs_civil:server:married`, course `gs_races:server:won`, braquage `gs_heists:server:done`, guerre, plaque),
    table `gs_memoire_events`, `GlobalState.gsMemoire` (lieux ≥ 3 événements), passant qui parle (PNJ le plus proche,
    1 fois / 30 min / lieu), Radio Los Santos toutes les 25 min, **plaque automatique au 10e** (`gs_scars:Plaque`).
  - **Signature surprise · « Les échos »** : la nuit (22 h-5 h), près d'un lieu à ≥ 5 événements, des silhouettes
    translucides (locales) rejouent le genre dominant 40 s (crime, arrestation, mariage, course, braquage, guerre…).
  - **Registre des véhicules disparus** (`gs_insurance/server/lost.lua`) : dossier de vol jamais clos + 48 h → la voiture
    refait surface (casse 45 %, garage louche 35 %, enchères 20 %), rumeur + tuyau au propriétaire ; entité créée à
    l'approche avec sa plaque ; propriétaire au volant → `recovered`, indemnité reprise sans pénalité (plus de fraude).
  - **Faux papiers** (`gs_blackmarket/server/fake.lua`) : `gs_fake_id` / `gs_fake_driver` / `gs_fake_ppa` au marché noir,
    identité inventée à l'achat (metadata), double-clic = présenter 10 min (state `gsFake`, voisins prévenus) ;
    F4 loin du commissariat = fausse identité crue (`basic`), au commissariat = scanner → démasqué, casier, état effacé.
  - **Témoin protégé** (`gs_police/server/custody.lua`) : /droits → « Dénoncer un gang » : peine ÷ 2, gang prévenu
    sans nom (`gs_gangs:NotifyGang`), rumeur, table `gs_police_witness` (7 j), lieu sûr GPS ; témoin tué → alerte police,
    `witnessHeat` sur les membres en ligne, rumeur.
  - **Guerre de l'information** (`gs_gangs/server/ops.lua`, F9 → Opérations, grade ≥ 2, caisse) : brouillage caméras
    (350 m, 10 min, 5 000 $) et scanner police piraté (10 min, 8 000 $ : dispatch gs_wanted + 911 police fuitent vers le
    gang) ; traces remontées par la police au commissariat (`gs_cctv:traces`, 5 min d'analyse) ; exports `MembersOnline`,
    `NotifyGang`, `ScannerListeners`.
  - Tests : gs_memoire (16), gs_city_candidature (16), insurance (+8), police (+10), gangs (+8), blackmarket (+6).

- **V12.1** : 48 places en profil privé (`dev.cfg`) comme en public → bot et site affichent X/48.
- **V12.2** · Site : **couche cinéma** (`docs/site/index.html`, additive, aucun contenu ni sélecteur existant modifié) :
  grain de film + vignette + lignes de balayage, bandes letterbox (intro et titres de mission), caméra qui « pousse »
  sur l'accueil + aberration chromatique du titre, parallaxe au défilement (texte / décor / fondu), rail de chapitres
  à gauche (≥ 1320 px), numéros de chapitre fantômes par section, mots des accroches révélés un à un, skew lié à la
  vitesse de défilement (≤ 1,4°), barre du haut qui se cache en descendant vite, réticule qui suit la souris (ordinateur,
  ne remplace pas le curseur), profondeur CSS `animation-timeline: view()` (captures, mock, carte, chiffres), intro
  façon chargement de mission (Entrée / clic pour passer). Tout coupé par `prefers-reduced-motion`, souris seulement
  sur ordinateur. Une seule boucle rAF qui s'endort quand rien ne bouge. Vérifié dans le navigateur : 0 erreur.

- **V12.38** (13/10/2026) — **fusion** de la session Windows (V12.35 → V12.37, paquet de commits) et de la session web
  (V12.35 : site en mode léger, audit `docs/AUDIT_V12_35.md`). Aucun conflit de code : seuls les numéros de version,
  cette page et les PDF (régénérés) se croisaient. Suite de tests verte après fusion.

- **V12.37** (13/10/2026, poste Windows, 4 sous-agents relus + intégration) — retours du fondateur du 13/10 :
  - **Garages de métier « hors service » 3 fois sur 4 + notifications en rafale** : au point de service, la V12.36 avait DEUX
    interactions (zone + PNJ) pour une bascule aveugle → « Prise de service » puis « Fin de service », garage refusé. gs_jobs :
    un point = une interaction (le PNJ porte l'option, [E] reste), verrou anti-double-clic 1 s, prise de service par **état voulu**
    + anti-rebond 1,5 s (F6, /service, point, téléphone), messages exacts du garage (pas de métier actif / autre métier / hors
    service) et verrou pendant la sortie. Retouche Qbox ajoutée (METTRE-A-JOUR) : service et garage de qbx_police / qbx_ambulancejob
    neutralisés (même point que le nôtre à Mission Row ; motif absent = avertissement jaune). Tests jobs 124/124.
  - **Quitter la LSPD en gardant les armes** : l'équipement de l'armurerie est **prêté** : quantités fournies notées, reprises à la
    fin du service, au changement de métier, au licenciement / démission et à la déconnexion (reconnexion : 5 s après le chargement) ;
    ce qu'on avait avant reste, ce qui a été consommé n'est pas réclamé ; audit `armory_return`.
  - **Armes lourdes qui flottent dans le vide** : gs_details/holster.lua réécrit : objet gardé seulement s'il est encore accroché
    au corps ACTUEL (mort, à terre, tenue / personnage changé, déconnexion, arme en main ou donnée → retiré dans la seconde),
    modèle chargé avant création, attache vérifiée, balayage des orphelins 5 s, une seule boucle lente. **`/dosreglage`** (staff) :
    position des armes dans le dos en direct (±1 cm, ±2°, os) + « Copier le bloc Config.Back ». Tests holster 74/74.
  - **Dégâts adoucis** (demande : « pas trop réaliste ») : armes à feu −25 %, corps à corps −20 %, véhicules −30 %
    (`DAMAGE` dans gs_details/client/health.lua, réappliqué toutes les 5 s).
  - **PPA à 50 $ au Pôle Emploi / mairie** : retiré (retouche Qbox de qbx_cityhall) ; le vrai reste au comptoir Ammu-Nation (500 $).
  - **Interventions de tempête dans le vide** : créées à l'approche (< 150 m) sur la route la plus proche (≤ 60 m, collision
    attendue), blip et [E] sur la vraie position, retirées au-delà de 250 m ; console « aucune route à moins de 60 m » = point à
    caler. **Location** : 13 comptoirs (Sandy sorti du poste du shérif, 6 ajoutés « à caler »). Tests weather 72/72, rental 23/23.
  - **F11 → Déplacer un point : placement libre** (aperçu anneau + cap, réglages au clavier : hauteur, rotation, pas fins, comme
    les props ; pose vérifiée côté serveur, ≤ 60 m du staff) ; **« PNJ et objets »** : poser un PNJ (modèle, scénario) ou un objet
    (catalogue gs_builder) **relié à un métier ou un gang** (le point de métier / la planque le reprend ; un seul PNJ staff par
    cible) ou libre (ambiance), retrait ; table SQL `gs_staff_peds`, GlobalState `gsStaffPeds`, créés à proximité par gs_markers.
  - **Les points déplacés voyagent** : gs_bridge écrit aussi `gs_bridge/points-deplaces.json` (toutes les minutes, ou
    `/pointsexport` console / ACE admin) ; METTRE-A-JOUR garde celui du PC, METTRE-A-JOUR-OVH l'emporte, le VPS l'importe au
    démarrage (une fois par version du fichier, le PC est la référence, un serveur sans aucun point n'écrit jamais de fichier).
    Réponse à la question du fondateur : les points calés en jeu sont gardés aux mises à jour ET, désormais, repris sur OVH.
    Tests points_fichier 25/25.
  - Réponses sans code : crochetage = mini-jeu ox_lib, appuyer sur la touche **chiffre affichée (1 à 4)** (guide joueur) ; F6
    qui passe en vol libre = raccourci FiveM du compte (Paramètres → Raccourcis clavier → FiveM) ; jetons d'auto-tamponneuses =
    script tiers, lignes de console à fournir ; preuves (douilles, scanner, empreintes) couvertes par les tests, à valider en jeu.
  - À vérifier en jeu : fiche de backtest, session « 6b · V12.37 ».

- **V12.36** (13/10/2026, poste Windows, orchestration multi-agents + relecture) — corrections du 12/10 :
  - **Maps vraiment supprimées** : le retrait F11 « Retirer cette map » arrête la ressource ET supprime son dossier, enlève sa ligne
    d'addons.cfg et l'inscrit dans mods-retires.txt (avant : ligne commentée, dossier gardé, map réinstallée par IMPORTER-MODS).
    Nouvelle liste `RETIRED_PATTERNS` (plasmagame, plasmakart, plasmatron, villa_01, redline) à côté de `RETIRED_MAPS` : appliquée
    au démarrage (maps, scripts compagnons, addons.cfg, mods-retires.txt) et par l'importeur (`Test-Retired`, nom d'archive et de
    ressource). Console : « Map retirée (motif « redline ») : … ». `RESTORED_MAPS` / `$Restored` vidés (migration villa bunker
    terminée). Tests lecteur de maps 119/119.
  - **/optin** : le code et l'ACE « admin » (V12.15) sont justes ; la cause est que `permissions.cfg` n'arrivait jamais sur le VPS
    (exclu par METTRE-A-JOUR-OVH et par « roadline maj »). Désormais envoyé et installé (`permissions_maj`, staff ajouté à la main
    conservé), et la commande roadline du VPS est poussée avant la mise à jour. Après /optin un admin garde /tp /tpm /car /dv ;
    argent, métiers, gangs, personnages restent au fondateur (deny). check_cfg.py vérifie la chaîne d'ACE et la synchro VPS.
    DEVENIR-ADMIN explique les réponses : « Service staff : in. » = OK ; « out. » à chaque fois = permissions.cfg ancien.
  - **ox_target** : erreur « native 0xfcdff7b72d23a1ac » (HasEntityClearLosToEntity) à chaque Alt sur le build 3570 → retouche
    Qbox d'ox_target 1.18.1 (pcall autour de l'appel, ligne 212), appliquée par METTRE-A-JOUR ; comportement de ciblage inchangé.
  - **Mécano** : la personnalisation n'était jamais appliquée quand le client restait au volant (pas de main réseau, refus muet) et
    n'était pas gardée au garage (qbx_garages relit les mods chez le client). gs_tuning fusionne les réglages dans la carte grise
    (plaque, modèle, carburant, état gardés), les fait appliquer par le propriétaire réseau, exige le client descendu et à ≤ 30 m,
    et chaque refus a son message. Tests 41/41.
  - **Permis pour tout le monde** (`Config.FreeLicence`) : permis + carte accordés à la connexion (une seule carte), auto-école
    fermée (points, blip, code, examen), retrait / rendu par la police conservé et persistant ; quête de Max sans étape permis ni
    location (4 étapes) ; « Que faire ? », guide joueur, backtest à jour. Tests driving 57/57, quests 63/63.
  - **Événements** : « Course à super vitesse » et « Concours de super saut » retirés de F11 → Événements.
  - **Ferraille** : vraie scène (carcasses variées au sol, fouille accroupie puis dévissage clé en main, trouvailles décrites,
    carcasse dépouillée visible puis repousse). **PNJ aux points** : champ générique `ped` de gs_markers (une boucle lente commune,
    PNJ invincible qui porte l'interaction et suit le point déplacé) ; acheteurs et contremaîtres de gs_harvest, accueil /
    direction / garage des 20 métiers (39 PNJ) et Pôle Emploi. Caps à caler en jeu. Tests harvest 265/265, jobs 93/93.
  - 40 nouvelles propositions (n° 58 → 97) ajoutées à `docs/PROPOSITIONS.md`.
  - À vérifier en jeu : voir la fiche de backtest (session « V12.36 ») : retrait d'une map depuis F11, /optin sur le VPS après
    METTRE-A-JOUR-OVH, Alt sans erreur F8, mécano (client descendu), nouveau perso avec carte de permis, PNJ aux points, ferraille.

- **V12.35** (12/10/2026, poste Windows) — synchronisation GitHub sans commande à retenir (`docs/GITHUB.md`) :
  - **`POUSSER-GITHUB.bat`** (racine du clone, `scripts/windows/pousser-github.ps1`) : trouve Git, lit GitHub, propose de
    committer ce qui traîne, récupère l'avancée de l'autre session si c'est une avance rapide, s'arrête si les deux côtés ont
    avancé (jamais de force : fusion par Claude), lance `tests/run.sh` si les outils sont là, pousse les deux branches ;
    identification GitHub dans le navigateur à la première fois (Git Credential Manager).
  - **Paquet de commits** `livraison/ROADLINE-commits.bundle` + `scripts/linux/recevoir-bundle.sh` : les commits du PC avec
    leur historique pour la session distante (vérifie, fusionne, teste, pousse). Fin des commits « Synchronisation » géants.
  - Rappel : la villa 01 et les maps plasma sont retirées au démarrage ; le fondateur supprime à la main les mappings en trop.

- **V12.35 · session web** (12/10/2026, en parallèle de la V12.35 Windows) — « héberger le site sur le VPS ? il a l'air surchargé au chargement » + « audit global » :
  - Site : mesuré dans Chromium (défilement 4 s) : les effets plein écran (aurore floutée, grain, pluie, brouillard,
    backdrop-filter) divisent la fluidité par 2. **Mode léger automatique** (`html.lite`) : téléphone, ≤ 4 cœurs ou ≤ 4 Go,
    ou < 35 images/s après l'ouverture ; `?lite` / `?full` pour forcer. 0 erreur JS. Netlify gardé (CDN, ne charge pas le
    VPS) : à republier avec PUBLIER-SITE.bat.
  - **docs/AUDIT_V12_35.md** : vérifications, risques classés, réponse « site sur le VPS », où déposer les mods, check-list
    d'ouverture (dont `roadline public` le jour J : dev.cfg cache le serveur de la liste FiveM).

- **V12.34** (12/10/2026) — « j'ai supprimé les maps dans [addons], j'ai peur que METTRE-A-JOUR recharge tout » : c'était
  le cas. L'importeur (relancé par METTRE-A-JOUR dès qu'il change) réinstallait depuis mods-a-trier toute map absente de
  mods-retires.txt, et le serveur ne l'y note qu'à son démarrage. Maintenant IMPORTER-MODS lit aussi `RETIRED_MAPS` dans
  gs_admin/server/maps.js : une map retirée n'est jamais réinstallée (ni son script compagnon), et sa ligne de addons.cfg
  est enlevée. Test de bout en bout : 9/9. V12.33 (poste Windows) intégrée dans git juste avant (elle n'y était pas).

- **V12.33** (12/10/2026, poste Windows) — reprise depuis le zip « installation (18) » (= V12.29 de la session distante, contenu
  dans V12.31) : **fusion V12.32** de la session distante V12.9 → V12.31 avec la V12.8 locale (13 conflits : versions, PDF,
  CSV identique, site = couche V12.9 ajoutée, CONFIGURER-DISCORD = bienvenue gardée), suite verte, puis :
  - **Maps plasma retirées** (demande du 12/10) : laser game, karting (+ DLC) et plasmatron dans `RETIRED_MAPS` (supprimées au
    démarrage, jamais réimportées) ; villa moderne 01 déjà retirée et villa bunker gardée depuis la V12.31. Test 92/92.
  - **F4 police / EMS** : la touche ne restait plus muette : si une interface est ouverte (garde-robe, téléphone, inventaire)
    elle le dit ; si le joueur est police / EMS mais hors service, elle le dit ; si le personnage n'est pas chargé, elle le dit.
    **Garde-robe (U)** : l'interface doit confirmer l'ouverture en 3 s (`ready`), sinon elle se referme seule : plus aucun
    focus NUI bloqué qui empêchait F4 ; refus d'ouvrir si une autre interface a déjà le focus.
  - **Cayo Perico** : l'avion **atterrit** (approche 4 s train sorti, toucher des roues 60 m avant le comptoir, roulage 45 m
    freiné) au lieu de disparaître en plein vol ; à l'arrivée le joueur reste figé jusqu'à ce que **le sol soit chargé** sous
    ses pieds, puis est posé au niveau réel du sol (avant : 1,5 s d'attente aveugle → il traversait la carte).
  - `/optin` : vérifié dans le dépôt (V12.15 : ACE `admin` pour `group.admin` dans permissions.cfg) ; à tester en jeu avec un
    compte dans `group.admin` (secrets.cfg).

- **V12.31** (12/10/2026) — « des scripts ne démarrent pas alors que les mappings sont là ; retire la villa moderne 01,
  on garde le bunker » :
  - **Scripts compagnons** (importer-mods.ps1, étape 2b) : un script escrow dont le nom partage un mot (≥ 5 lettres, hors
    patoche / script / pack…) avec une map installée est installé avec elle, sous son nom d'origine, si ses dépendances
    (`dependency` / `dependencies` du fxmanifest, « /onesync » ignoré) sont présentes (`$Provides` : qb-core → qbx_core,
    qb-target / qtarget → ox_target, mysql-async → oxmysql) ou dans le même import (installées aussi). addons.cfg garde
    leurs lignes tant que leur dossier existe. Testé de bout en bout avec PowerShell 7 (faux packs map + script + lib).
  - Console du serveur : « Script de map activé mais NON démarré » (licence, dépendance, renommage).
  - Villa moderne 01 → `RETIRED_MAPS` ; villa bunker sortie de `RETIRED_MAPS` et de `mods-retires.txt` (`$Restored`),
    réinstallée depuis son archive gardée dans mods-a-trier, sans blip public (villa privée).
  - docs/MLO.md : état des maps payantes au 12/10, règles escrow mises à jour, tableau de diagnostic.

- **V12.30** (12/10/2026) — « je vois le blip du laser game mais pas le bâtiment, et aucun point pour tester l'activité ;
  rien dans la console » :
  - **Activités = scripts vendus à part.** Laser game, karting, auto-tamponneuses, foot, billard : la map n'est que le décor,
    le jeu est un script de l'auteur, rangé dans `mods-tri\scripts-a-verifier` et jamais installé (RoadLine n'a pas de script
    pour ces activités). `ACTIVITY` (maps.js) : sans ressource démarrée qui porte le mot-clé (plasmagame, plasmakart,
    bumpercar, soccer, billiard), console « DÉCOR SEUL », blip public « (bientôt) », ligne « Activité : … décor seul » dans F11.
  - **F11 → Mappings installés → « Contrôler les maps chez moi »** : pour chaque map, les modèles qui lui sont propres (posés
    par ses .ymap ET livrés en .ydr/.yft, lus à 24 octets de la position dans CEntityDef, hash `joaat`) sont cherchés chez
    le joueur (`IsModelInCdimage`) puis 4 sont chargés pour de vrai (`RequestModel`, 12 s max, relâchés). Verdicts : chargé /
    aucun modèle reçu (fichiers absents, cache) / reçus mais illisibles (licence Cfx de la map ou fichier abîmé) / pack
    incomplet / non testable d'ici. Résultat recopié dans la console du serveur (`gs_admin:mapCheckReport`, super-admin).
  - Tests : 8 de plus dans test_gs_maps.js (91).

- **V12.29** (12/10/2026) — « blips publics avec nom pour chaque mapping » : `PUBLIC` dans maps.js (nom, icône, couleur, ou
  false pour les lieux secrets : gang 2, garage clandestin, labo, villa 01, panneaux, extensions DLC, sous-sol MRPD) ;
  `client/mapblips.lua` les affiche (courte portée) à tous les joueurs, liste renvoyée à tous quand une map est arrêtée.
  Noms nettoyés (« patoche », « sub », « pack » retirés). Procédure « réparer un pack abîmé » dans IMPORTER_MODS.md.

- **V12.28** (12/10/2026) — « fais-le toi-même » : contrôle d'intégrité automatique au démarrage (gs_admin/maps.js, 20 s après,
  en arrière-plan) de TOUS les fichiers du jeu des maps démarrées. Un fichier tronqué (flux compressé interrompu : erreur zlib
  « unexpected end of file », seul critère, jamais de faux positif sur un fichier chiffré) → la map est arrêtée tout de suite et
  la console dit quoi faire. Rien n'est écrit : revérifiée à chaque démarrage, elle repart seule une fois le pack remplacé.
  Tests : 5 de plus dans test_gs_maps.js.

- **V12.27** (12/10/2026) — crash joueur « Invalid fixup, address is neither virtual nor physical (in patoche_beach_guard.ydr) » :
  fichier TRONQUÉ du pack patoche_beach_party (l'import avait signalé « Unexpected end of data » sur ce fichier, mais
  l'importeur l'avait installé quand même). IMPORTER-MODS vérifie désormais le code de retour de 7-Zip (≥ 2 = archive
  incomplète) : tous les mods de cette archive sont refusés (« archive incomplète… retélécharge-la ») et, s'ils étaient déjà
  installés, leur ligne de addons.cfg est désactivée d'office (« ## … désactivé par sécurité »), réactivée toute seule au
  prochain import réussi. Packs concernés au 12/10 : patoche_beach_party, patoche_soccer (installés), plasmatron, soccer_cloth.

- **V12.26** (12/10/2026) — retours en jeu : « la voiture nous tombe dessus », « les clés ne sont pas des objets », « nos tenues
  en objets, la personnalisation comme sur ces captures (perso en 3D, vêtements autour) » :
  - **Apparition dans le véhicule** : `Bridge:WarpIntoVehicle` (gs_bridge) = méthode de qbx_core : attendre que la plaque soit lue
    (véhicule créé chez le joueur), `SetPedIntoVehicle` répété 3 s, secours client `gs_bridge:client:warpInto` (véhicule à moins de
    15 m). Utilisé par `SpawnVehicle` (staff, location, quêtes, courses, gangs, auto-école) et le garage des métiers.
  - **Clés en objet** `gs_carkey` (gs_bridge/server/carkeys.lua) : à chaque clé donnée par qbx_vehiclekeys (état `keysList` du
    joueur : garage, concession, location, métier, staff, vol réussi), une « Clé — Marque Modèle » avec la plaque ; une par plaque,
    jamais recréée si donnée / jetée (mémoire par personnage). Double-clic à moins de 25 m : verrouille / déverrouille (SetLockState,
    bip + phares) et donne l'accès à qui la tient (prêter sa voiture = donner la clé). Test `test_gs_carkeys.lua` (10).
  - **Tenues** : « Enregistrer la tenue » dans la boutique (illenium-appearance) crée aussi un objet Tenue ; `/tenue` = plier.
  - **Garde-robe** (touche **U** — K est l'inventaire proche ; Ctrl+U reste le vol libre du staff —, `/garderobe`, menu radial
    Vêtements) : personnage en grand (caméra fixe, il tourne avec ← →, vues Corps / Visage / Jambes), 13 emplacements autour
    (chapeau, lunettes, boucles, masque, collier, montre, bracelet, haut + bras, t-shirt, gilet, sac, pantalon, chaussures). Clic sur
    une pièce portée → objet `gs_cloth` (image par type) ; clic sur un vêtement / une tenue du sac → enfilé, l'ancienne pièce revient
    dans le sac (place vérifiée avant, taille homme / femme vérifiée AVANT de retirer l'objet). Double-clic dans l'inventaire =
    enfiler. Valeurs « rien porté » dans `Config.Wardrobe` (gs_details). Bridge : `ListSlots`, `TakeSlot`. Test
    `test_gs_outfits.lua` (18), écran testé dans Chromium (1920 et 1280, 0 erreur).
  - Pas encore : vignettes photo de chaque coupe / vêtement dans le magasin (capture automatique de milliers d'images, à part).

- **V12.25** (12/10/2026) — « refais le tour des mappings, mets la doc à jour, fais-moi un site de la doc » :
  - Console au démarrage : `Map activée mais NON démarrée : … (état …)` pour chaque map active dans addons.cfg qui ne tourne
    pas (en jeu : bâtiment absent / chargement sans fin ; cause : licence Cfx du pack, .fxap manquant). Test `activeEnsures`.
  - Téléportation F11 vérifiée : toujours bornée (2,5 s + 3 s + 8 s max), elle ne peut pas causer un chargement infini.
  - **Site de la documentation** `docs/hub/index.html` (tools/doc_hub.py) : 30 documents en 5 catégories, recherche,
    backtest (56) et priorités (19) à cocher avec notes, export / import / rapport / impression, clair-sombre, mobile.
    Testé dans Chromium (0 erreur, cases gardées après rechargement, pas de débordement à 375 px).
  - Le site inclut aussi le **texte des 3 guides PDF** (joueur, RoadLine avec lieux et points, staff), repris des mêmes
    données que les PDF (capture des éléments reportlab, rien n'est recopié à la main) : consultables et cherchables.
  - Vérification globale : 2 882 tests verts, budget de performance tenu (67 ressources, 136 threads client).

- **V12.18** (12/10/2026) — « j'ai acheté de vrais mappings (packs Patoche), depuis FiveM crashe, rien n'apparaît » :
  - **Crash au lancement = erreur FiveM 506** (« Failure connecting to the Rockstar Games Launcher »), côté PC du joueur,
    avant toute connexion au serveur : launcher Rockstar en « mode Steam » (titre Steam inconnu), jeton expiré, dossier
    Documents Rockstar dans OneDrive. Rien à voir avec les maps ni le serveur (le .dmp ne contient que le launcher).
  - **Optimiseur de textures réparé** : le commit « fins de ligne CRLF normalisées » (b63e354) avait retiré des octets aux
    4 DLL de `tools/textures` (« Le module était censé contenir un manifeste de l'assembly »). DLL restaurées depuis 90e4dc9,
    `.gitattributes` : `*.dll`, images, `.ytd/.ydr/.yft/.ymap/.ybn/.ytyp`, zip, polices et sons en `binary` (seules ces 4 DLL
    étaient touchées : 211 images vérifiées).
  - **Packs payants (escrow Cfx `.fxap`)** dans IMPORTER-MODS : un pack protégé qui contient des fichiers du jeu (map,
    véhicule, vêtement) est installé même s'il embarque un petit script chiffré (avant : Shadow Complex, circuit, tenues
    soccer… refusés comme « script chiffré »). Fichiers jamais modifiés (pas d'optimisation de textures sur un pack protégé).
    Script payant seul : rangé dans scripts-a-verifier (plus « rejeté »), pas installé automatiquement. Script multi-framework
    (ESX + QBCore / Qbox) : plus classé « ESX ». Lignes « illisibles » d'un fichier chiffré : plus prises pour de
    l'obfuscation. Véhicule d'un pack protégé (auto-tamponneuse…) : pas ajouté à la concession.
  - **Faux positif « marque réelle »** : `golf` (la VW) attrapait « mini**golf** » → `(?<!mini)golf` (importeur et
    NETTOYER-MARQUES, listes identiques).
  - METTRE-A-JOUR-OVH : copie avec `-Force` (fichiers cachés compris).
  - FXServer récent : écriture disque interdite au JavaScript (« --allow-fs-write ») → maps.js écrit via `gs_admin/server/fsw.lua`
    (réservé à gs_admin, sous le dossier parent de server-data, chemins `//` acceptés). Fusion et boutons F11 réparés.
  - Écritures des maps (V12.19 → V12.23, testé sur le serveur) : Node bloqué (« --allow-fs-write »), export Lua introuvable
    depuis le JS de la même ressource, `package` absent en Lua FiveM, `io.open` refusé même dans un dossier existant →
    **`SaveResourceFile`** (API officielle FiveM) via un événement local `gs_admin:fsWrite`, io.open en secours. Le dossier
    `gsa_zz_fusion_occlusion/stream` est créé par METTRE-A-JOUR / l'installeur / METTRE-A-JOUR-OVH (git ne garde pas les
    dossiers vides, SaveResourceFile ne crée pas de dossier). Test : `tests/test_gs_fsw.lua`.
    **V12.24 : règle FXServer « write not allowed » = une ressource n'écrit que dans SON dossier.** gs_admin calcule la fusion
    et l'envoie (événement local `gsa_fusion:save`, accepté seulement de gs_admin, nom `*.ymap` simple) à
    `gsa_zz_fusion_occlusion/server.lua`, qui l'écrit dans son propre `stream/`. Test : `tests/test_gsa_fusion.lua`.
  - **Choix du 12/10** (`RETIRED_MAPS`, maps.js) : retirées au démarrage (PC et VPS) puis notées dans mods-retires.txt, archives
    gardées : Willie's, magasin d'alcool de Paleto, Moreo Gym, casse (anciennes gratuites), Benny's original (gardé : noir et
    blanc), villa bunker (gardé : villa 01), Digital Den (gardé : prison), Shadow Complex (gardé : plasmakart).
  - **REPARER-FIVEM.bat** (racine, autonome, administrateur) : erreur FiveM 506 / déconnexions Rockstar côté joueur. Ferme
    FiveM/GTA/Rockstar, décoche « exécuter en administrateur » (FiveM et launcher doivent avoir les mêmes droits : launcher
    « Could not do OpenProcess on parent process »), supprime `%LOCALAPPDATA%\DigitalEntitlements`, vide le cache FiveM
    (cache\game gardé), garde le dossier Rockstar de OneDrive sur le PC (attrib +P), resynchronise l'heure, signale un
    `IVPath` Steam alors que GTA vient du launcher Rockstar (corrigé si accord). Transmissible aux joueurs.
  - Archives tronquées au téléchargement (« Unexpected end of archive ») : patoche_beach_party, patoche_plasmatron,
    patoche_soccer, patoche_soccer_cloth → à retélécharger depuis le portail Cfx.

- **V12.17** (12/10/2026) — « retire-les totalement de ma base, en priorité » + « le E pour réapparaître ne marche pas » :
  - **Suppression définitive des maps** (F11, super-admin / fondateur, taper SUPPRIMER, journalisé `deleteallmaps`) :
    `deleteMapsOnDisk` (maps.js) efface les dossiers `[addons]/gsa_*` des vraies maps (.ymap/.ytyp/.ybn ; vêtements gardés),
    retire leurs lignes de `addons.cfg` (CRLF gardés), efface `mods-tri/maps/<nom>` et l'archive `mods-a-trier` de même nom
    (`cleanName` = Clean-Name de l'importeur), et ajoute les noms à `mods-retires.txt` ; IMPORTER-MODS les rejette
    (« retiré par le staff ») même dans une archive groupée. À faire sur le PC puis sur le VPS (même bouton).
  - **Réapparition [E]** : `qbx_medical` lit E une fois par seconde et appelle le serveur ; `qbx_ambulancejob` exige un lit
    libre (sinon « beds taken », rien ne se passe) et peut laisser `allowRespawn = false` après un passage au lit. Filet de
    sécurité `gs_services` : E maintenu 2 s → `AllowRespawn()` ; toujours mort 6 s après → `gs_services:respawn` (mort
    confirmé par le statebag, hors prison, 2 / 30 s) : téléporté devant l'hôpital le plus proche (Pillbox, Sandy, Paleto),
    500 $ (gratuit sans argent), réanimé. Tests : `test_gs_services.lua` 17, `test_gs_maps.js` 70.

- **V12.16** (12/10/2026) — décision de l'utilisateur : **retirer tous les mappings** (« tous bug : certains inexistants, d'autres
  font crash, je vais acheter un pack »). F11 → Mappings installés → **« Retirer TOUTES les maps »** (super-admin / fondateur,
  journalisé) : StopResource + lignes commentées dans `cfg/addons.cfg`, réversible ; vêtements et véhicules importés non touchés.
  Rien n'est effacé du PC sans accord (dossiers `[addons]\gsa_*` des maps et archives : à supprimer à la main si voulu).
  Docs nettoyées (guide du joueur, guide RoadLine, guide du staff, recette session 6). Les portes du sous-sol de Mission Row
  restent dans gs_interiors mais fermées et invisibles sans `gsa_mrpd_etendu` (`requires`).

- **V12.15** (12/10/2026) — retours en jeu :
  - Blips et menu : **vrais noms** des 14 maps (`LABELS` dans maps.js), plus le nom de fichier du mod.
  - **Retirer une map depuis F11** (super-admin / fondateur, journalisé `disablemap`) : StopResource + ligne de
    `cfg/addons.cfg` commentée (seule cette ligne, CRLF gardés) ; fusion d'occlusion devenue inutile supprimée au démarrage
    (`pruneFusions`, sinon elle masquerait la version de la map restante). Demande : retirer la map de Pyrite Avenue (Paleto),
    « inexistante et hors de la carte » ; coordonnées envoyées (1166.97, -27648.08) = océan, x proche du pack Redline
    (quartier « NULL » dans la liste) → l'utilisateur choisit lui-même dans F11 (magasin d'alcool de Paleto ou pack Redline).
  - **/optin ne marchait pas** : `qbx_core` exige l'ACE `admin` (`IsPlayerAceAllowed(src, 'admin')`), absente de
    permissions.cfg → `add_ace group.admin admin allow`. Sans ça, /optin ne faisait rien et les commandes Qbox répondaient
    « not opted in ».
  - Tests : `test_gs_maps.js` 62.

- **V12.14** (12/10/2026) — retours en jeu sur F11 → Mappings installés (16 entrées) :
  - **Monde et lieux réservé super-admin (4) et fondateur** : entrée F11, toutes les options, et côté serveur `movepoint`,
    `resetpoint`, `jobpoint`, `creategang`, `gangplace`, `gs_admin:mappings`, `gs_places` (StaffLevel 4) ; `gs_builder` déjà
    par ACE super-admin. `setgang` (rang d'un joueur, menu Joueurs) reste admin.
  - Vêtements importés (bikinis, robe d'été) n'apparaissent plus comme « habillage » : seules les ressources avec .ymap /
    .ytyp / .ybn sont des maps (13 maps). Quartier « NULL » (pack Redline, hors zone nommée) → code de zone ou « Hors quartier ».
  - **Erreur corrigée** : la V12.11 signalait les modèles dès 16 Mo ; la limite FiveM (et de l'importeur) est 48 Mo graphique /
    64 Mo système. Redline (45,3 Mo), Willie's (38 Mo) et le gym (26,5 Mo) sont sous la limite : plus d'avertissement.
  - Rien de définitivement irréparable dans les maps installées : Bahama Mamas et Fleeca sont des habillages d'intérieurs du jeu
    (pas de lieu propre, normal). Tests : `test_gs_maps.js` 55 (mutation vérifiée).

- **V12.13** (12/10/2026) — **conflits de maps réglés une fois pour toutes** (demande : « règle le conflit… garder de préférence
  le liquor ») : `maps.js` contient maintenant la fusion d'occlusion (même algorithme que l'outil Python, résultat identique
  au bit près vérifié sur le vrai fichier). 15 s après le démarrage : conflits `*_occl_*` fusionnés dans
  `[gtasoon]/gsa_zz_fusion_occlusion` (livrée vide, `ensure` en fin de resources.cfg), puis Stop/StartResource de cette
  ressource pour qu'elle passe après toutes les maps (la dernière lancée l'emporte). Idempotent (rien réécrit si identique).
  Fusion impossible → version préférée gardée (`PREFER` = `gsa_cfx_draft_pb_liquor_pack`). Plus besoin du fichier de Willie's.
  La ressource de fusion n'apparaît pas dans la liste F11. Tests : `test_gs_maps.js` 53 (dont 9 fusion, mutation vérifiée).

- **Documentation à jour (12/10/2026, V12.12)** : guide du joueur (secours et urgences, appli Urgences, /911p staff, alertes :
  chasse légale, vols de voiture, police IA seul en ville, shérif ; Discord /aide /ip /ticket ; /retoucheperso ; nouveaux lieux),
  guide du staff (pièges anti-triche, bannir / débannir, /annonce complet, Déplacer un point vérifié, conflits de maps, /policeia,
  Mission Row agrandi, bienvenue Discord), guide RoadLine (chapitre V12.4 → V12.12, table des 14 maps avec coordonnées lues
  dans les fichiers, intégrations Discord). **Fiche de backtest refaite** : 99 → 57 tests (32 bloquants), doublons fusionnés
  (bus ×3, Discord ×4, points ×3, police IA, site, Fleeca), validé retiré (backtest du 09/10, import des mods et console des
  maps du 12/10). La fiche du 10/10 renvoyée par l'utilisateur n'avait aucune case cochée : rien d'autre ne pouvait être retiré.
  `ROADLINE_Fiche_tests.pdf` (V10.1) et `ROADLINE_Reste_a_tester.pdf` (V7-V10) sont obsolètes : la seule recette est le backtest.

- **V12.12** (12/10/2026) — **premier conflit réel signalé par la console** : `cs1_occl_10.ymap` (occlusion de Paleto Bay) livré
  par `gsa_cfx_draft_pb_liquor_pack` ET `gsa_mlo_willies_supermarket` → l'un des deux intérieurs peut clignoter ou disparaître.
  - **`tools/maps/fusion_occlusion.py`** : lit le format Meta du jeu (table des blocs, CMapData, `boxOccluders` +128,
    `occludeModels` +144, sommets dans les blocs d'octets) et garde les occluders présents dans TOUTES les versions
    (jeu − retraits de A − retraits de B = A ∩ B), réécrits sur place (même taille, même en-tête RSC7). Vérifié sur le vrai
    fichier du magasin d'alcool (95 boîtes, 8 modèles : identique au bit près fusionné avec lui-même). Produit la ressource
    `zz_fusion_occlusion` (→ `gsa_zz_fusion_occlusion`, dernière dans addons.cfg trié, donc prioritaire).
  - `maps.js` : deux copies **identiques** ne sont plus un conflit ; un conflit couvert par `gsa_zz_fusion*` est « résolu »
    (vert en console et en F11).
  - **En attente** : `cs1_occl_10.ymap` de Willie's (dossier de la map sur le PC) pour produire la fusion.
  - Tests : `test_fusion_occlusion.py` (16, fichier fabriqué, mutation vérifiée), `test_gs_maps.js` 44.

- **V12.11** (12/10/2026) — 4 maps de plus vérifiées (Pillbox, Fleeca, gym Moreo, Vinewood) :
  - **Aucun conflit** entre les 7 maps reçues (aucun fichier du jeu remplacé deux fois).
  - **Mémoire réelle des modèles** lue dans l'en-tête RSC7 (`maps.js`, « page flags ») : au-delà de 16 Mo, signalé en F11 et en
    console. Le gym Moreo : `moreo_gym_shell.ydr` = 15,3 Mo sur le disque mais **26,5 Mo en mémoire** (l'importeur, qui ne regarde
    que le fichier, ne pouvait pas le voir) → risque de murs / textures invisibles sur PC modeste, à vérifier en jeu.
  - Map sans `.ymap` : distinguée entre **habillage** (`hp_fleeca` remplace les modèles des 6 agences Fleeca : coffre, guichets,
    collisions ; mêmes noms de modèles, aucun de nos scripts ne manipule ces portes) et map **vide**.
  - Points à recaler en jeu si besoin : Pillbox (8 points EMS / pharmacie / chirurgien, tous à z 43,3), Fleeca Legion (10 points :
    banque, braquages, quête). Gym et Vinewood : aucun point RoadLine.
  - **Licence Pillbox (phxlsmc) : CC BY-NC-ND** (pas d'usage commercial) → à remplacer si une boutique payante ouvre.
  - Archive du gym reçue avec 2 fichiers abîmés (envoi) : `asd.cwproj` (inutile) et `moreo_gym_lights.ydr` ; la copie du PC fait foi.
  - Tests : +8 (`test_gs_maps.js` : 40, mutations vérifiées). Recette session 1e : +3 tests (Pillbox, Fleeca, gym).

- **V12.10** (12/10/2026) — **les mappings se retrouvent tout seuls** :
  - Rapport IMPORTER-MODS du 12/10 : 14 maps installées (dont 3 protégées, achetées avec la clé Cfx du serveur), 3 vêtements,
    28 refusés (25 marques réelles), 2 scripts à relire (`burgershot`, Mission Row), 3 vêtements solo à convertir.
  - **F11 → Monde et lieux → Mappings installés** (`gs_admin/server/maps.js`, Node, lecture seule) : le serveur lit les `.ymap` de
    chaque map (`gsa_*` ou `this_is_a_map`), repère les objets posés (position + rotation de norme 1 + échelles) et en déduit le
    lieu ; priorité au fichier qui porte le nom de la map (le bâtiment, pas son garage), fichiers du jeu remplacés ignorés.
    Téléportation au sol de l'intérieur (pas sur le toit), blips pour soi, et **conflits** : même `.ymap` / `.ybn` / `.ytyp`
    remplacé par deux maps (une seule s'affiche). Ligne de synthèse en console au démarrage. Testé sur les 5 maps reçues :
    atelier TM (927, -1564), magasin d'alcool de Paleto (-161, 6325), commissariat de Vinewood (574, -11), sous-sol de Mission
    Row (444, -1000). `tests/test_gs_maps.js` (32 tests, mutations vérifiées).
  - **Mission Row agrandi** : le script `teleport` fourni (boucle toutes les 2 ms, anglais, `__resource.lua`) est remplacé par
    3 portes `gs_interiors` réservées à la police ; nouveau champ `requires` : porte fermée et invisible tant que la map
    (`gsa_mrpd_etendu`, livrée reconditionnée sans script) n'est pas démarrée, sortie toujours possible.
    `tests/test_gs_interiors.lua` (11 tests).
  - `NETTOYER-MARQUES.bat` : les copies triées (`mods-tri`) sont aussi reconnues par le nom de leurs fichiers, comme l'importeur
    (`mp_male_the_goat` lui échappait).
  - `moto_free_shell` : ne contient qu'une licence, aucune map.
  - Recette : session **1e** (5 tests). Doc : `IMPORTER_MODS.md` (« Où sont mes maps ? »), `ADMIN.md`, guide du staff.

- **V12.9** (11/10/2026, session web) — **synchronisation globale des deux sessions** (point de rencontre commun) :
  - La session Windows (V12.8) était partie du commit V12.7 : tout le travail de la session web (pots de miel, bans F11,
    bot V12.5, déplacement des points, alertes V12.7, `check_crimes.py`) y était déjà. 25 changements réels repris
    (bienvenue Discord, plancher police IA + `/policeia`, bus d'arrivée encore plus robuste, site V13, catalogues xlsx,
    57 propositions, docs Discord / véhicules), 18 fichiers qui ne différaient que par les fins de ligne gardés tels quels.
  - Corrigé à la fusion : `configurer-discord.ps1` contenait un retour chariot isolé qui collait l'écriture de
    `secrets.cfg` derrière le bloc « bienvenue » (le fichier n'était enregistré que si l'on réglait la bienvenue).
  - **Contrôle des doublons** (script de session, lecture seule) : aucune commande en double, aucun callback enregistré
    deux fois, aucun export déclaré deux fois, aucune clé en double dans un tableau Lua (3 alertes = faux positifs :
    affectations multiples `ok, msg = …`), aucun fichier en double dans les fxmanifest (`ui_page` + `files` = normal) ;
    les 3 événements `gs_social:client:*` écoutés aussi par `gs_phone` = voulu (fil social affiché dans le téléphone).
  - Sécurité revérifiée présente : `honeypot.lua` chargé, retouches Qbox `qbx_vehiclekeys` / `qbx_police` (`/911p`),
    déban F11, verrou Discord (`resolveGuild`, `NOT_HERE`), `/policeia` réservé `group.admin`.
  - **Site corrigé sur téléphone** : le bouton son ajouté en V13 poussait le bouton menu (☰) à moitié hors de l'écran
    (barre 21 px trop large à 390 px). Barre resserrée sous 480 px, logo réduit sous 380 px, son masqué sous 340 px ;
    logo du pied de page et grilles « En direct » / trois colonnes qui débordaient déjà à 320-360 px corrigés.
    Vérifié dans Chromium de 320 à 1440 px : plus de défilement horizontal, 0 erreur JavaScript.
  - Recette : session **1d** (5 tests : police IA seule en ville, `/policeia`, bus, bienvenue Discord, site V13).
    `docs/ALERTES.md` : plancher de signalement quand aucun policier n'est en service.
  - Suite complète verte : 2 688 tests Lua, 70 tests bot Discord. PDF régénérés, zips de livraison refaits.

- **V12.8** (11/10/2026, poste Windows) — **fusion des deux sessions** (locale V12.3b → V12.4 et distante V12.4 → V12.7, base commune
  V11.3) : 19 fichiers en conflit résolus à la main, les deux côtés conservés. Depuis la session locale : site V13 (SMS espacés, météo
  et heure de la ville en direct, son opt-in, Bowlby One, fluidité), police IA seule en ville (plancher de signalement + `/policeia`),
  message de bienvenue du bot Discord (`gs_discord_welcome_channel`, intent « Server Members » optionnel, repli propre), fiche de
  backtest refaite, 57 propositions (`docs/PROPOSITIONS.md`), catalogues véhicules et armes (`docs/ROADLINE_*.xlsx`, `tools/catalogues_xlsx.py`).
  Depuis la session distante : pots de miel, bannissements en jeu, `/help` `/ip` `/annonce` Discord, détection automatique du Discord,
  déplacement des points réparé (gs_markers, gs_quests, cabine), cohérence des alertes (`check_crimes.py`), audit bob74 / MLO,
  importeur (maps escrow). **Bus d'arrivée** : les deux correctifs combinés (sol chargé avant de poser le bus + bus figé/surveillé côté
  local, attente de la sortie réelle + calage au sol réel + GPS vers Max côté distant). Suite complète verte après fusion
  (70 tests bot Discord). Les features V13 en cours (cabines, distributeur, chantier, mur, tournoi…) restent hors du dépôt tant
  qu'elles ne sont pas terminées et testées.

- **V12.7** (11/10/2026) — audit des alertes et de la cohérence RP (`docs/ALERTES.md`) :
  - **Sain** : central unique `gs_wanted` (témoins, caméras, nuit, mémoire, police IA), les 24 appels utilisent un type
    existant, le shérif reçoit tout (`countsAs = 'police'`), tirs détectés côté serveur (un seul détecteur), EMS prévenus
    quand on est à terre (`qbx_ambulancejob` si EMS en service, secouriste IA sinon), annonces générales cohérentes.
  - **Corrigé** :
    1. Chasse : un chasseur AVEC permis dans la zone de chasse déclenchait « Coups de feu détectés » à chaque cerf.
       `Config.HuntingGrounds` + `Wanted.legalHunter`. Sans permis ou hors zone : alerte normale.
    2. Intitulés faux pour le policier : caméra peinte et transformateur saboté arrivaient en « Racket et dégradation
       de commerce », caisse d'un bar / d'une boutique en « Braquage de supérette ». Nouveaux types `vandalism`,
       `sabotage`, `shop_robbery` (propagés aux empreintes, vitres brisées et commerçants).
    3. Vols de véhicule (crochetage, fils) : `qbx_vehiclekeys` alertait par le canal `qbx_police` (2e interface, 75 %
       même sans témoin) et un car-jacking pouvait arriver deux fois. Retouche Qbox → `gs_wanted:server:vehicleTheft`,
       type `vehicle_theft`, un seul signalement par vol (20 s).
    4. `/911p` (`qbx_police`) : appel police sans téléphone, même menotté. Réservé au staff (retouche Qbox).
    5. « Que faire ? » : les conseils police ne s'affichaient pas pour un shérif.
  - Garde-fou : `tests/check_crimes.py` (25 types, 50 utilisations) dans `tests/run.sh`. +11 tests `gs_wanted`
    (dont mutation vérifiée). Recette : session 1c (8 tests). 2685 tests Lua, 65 bot Discord.

- **V12.6** (11/10/2026) — passe de correctifs (fin du développement de fonctionnalités) :
  - **Déplacer un point (F11) — 3 causes trouvées et corrigées** :
    1. `gs_markers` ne nettoyait pas les marqueurs d'une ressource qui redémarre : 6 ressources (magasins `gs_economy`,
       fourrière, justice, civil, lieux du staff, recherchés) gardaient leur **ancien point actif à l'ancien endroit**.
       Désormais chaque marqueur retient sa ressource et disparaît avec elle.
    2. `gs_quests` chargeait `points.lua` AVANT `quests.lua` : aucun personnage (Max, Big Sal, la Voix…) n'était
       déplaçable. Ordre corrigé + `Config.Characters`.
    3. La cabine de la Voix était ré-aimantée à 55 m vers la cabine d'origine. Placée par le staff → calage 8 m seulement.
  - **Preuve en jeu** : 6 s après « Placer ce point ici », le staff reçoit « ✅ Vérifié : <ressource> a redémarré avec la
    nouvelle position », ou un avertissement précis (pas redémarrée / redémarrée sans la position). Événement serveur
    local `gs_bridge:server:pointsLoaded` + export `CheckPoint`.
  - **Cabines** (demande du 04/10 : « pas contre des cabines ou téléphones muraux, aucune cohérence RP ») : interaction
    posée sur la cabine elle-même (plus de décalage dans le mur), avertissement console si aucune cabine n'est trouvée.
  - Arrivée en bus : GPS vers la position RÉELLE de Max (suit ses déplacements), doublon F11 supprimé.
  - Recette (`ROADLINE_Backtest_complet.pdf`) : session 1b (12 tests V12.4 → V12.6), 77 tests dont 31 bloquants ; flèches
    « → » enfin lisibles (Helvetica ne les avait pas).
  - Tests : +11 (scénario cabine / Max / confirmation), 2674 Lua, 65 bot Discord.

- **V12.5** (11/10/2026) — bot Discord réparé (retours du backtest) :
  - **Cause commune** de 3 symptômes : `gs_discord_guild` vide ou faux sur le VPS (l'outil le présentait comme facultatif).
    Résultat : `/ticket` et les commandes staff refusés avec « uniquement sur le Discord RoadLine » alors qu'on y était, et
    les anciennes commandes (`/help`, `/ip`) jamais nettoyées. **Correctif** : à la connexion, le bot lit la liste de ses
    Discords (READY) ; s'il n'est que sur un seul, c'est forcément RoadLine → adopté et signalé en console. Plusieurs
    Discords et réglage vide/faux → refus de deviner (protection conservée). Message d'erreur qui dit quoi corriger.
  - **`/help`** (alias de `/aide`) et **`/ip`** (adresse + `connect` F8) ajoutées. Toute commande inconnue répond l'aide,
    plus le site (c'était la cause de « /help donne le site »).
  - **`/annonce` publie enfin sur Discord** : `#annonces` (webhook), sinon le salon courant ; titre, `@everyone`/`@here`,
    1 800 caractères ; `en_jeu` pour l'afficher aussi en ville. Avant, elle n'envoyait qu'une annonce en jeu.
  - Réponses sorties dans `createAnswer()` (testable) : +21 tests (65 au total). `CONFIGURER-DISCORD` marque l'identifiant
    du serveur comme INDISPENSABLE ; diagnostic GERER-OVH : « réglé / NON RÉGLÉ » pour guild, rôle staff, #tickets, adresse.
  - Revérifié sans changement : statut en direct, annonces de redémarrage, résumé du soir (6 événements bien émis), Gazette,
    rendez-vous.

- **V12.4** (11/10/2026) — sécurité sur mesure et arrivée réparée :
  - **Pots de miel** (`gs_security/server/honeypot.lua`) : 27 appâts (23 events + 4 callbacks) enregistrés côté serveur et
    déclenchables par personne. Deux familles : des noms de frameworks qu'on n'utilise pas (ESX, vieux scripts fuités) que les
    menus de triche tentent en aveugle, et de fausses failles alléchantes (« donne-moi de l'argent », « passe-moi admin »).
    Toucher l'un des deux ne s'explique pas en jouant → bannissement définitif automatique. Réglage par convar `gs_honeypot`
    = `ban` (défaut) / `kick` / `log`. **Le staff n'est jamais banni** : il est signalé dans `#logs-staff` (erreur ou test).
  - **Zéro faux positif garanti par un test** (`tests/check_honeypot.py`, dans `tests/run.sh`) : aucun nom de piège ne doit
    apparaître ailleurs dans le dépôt. Si un jour on nomme un vrai event comme un piège, les tests refusent le push.
  - **Bannissements RoadLine, posés ET levés en jeu** (nouvelle table `gs_admin_bans`, par licence) : `F11 → Joueurs → Bannir`
    (durée en jours, 0 = définitif, motif obligatoire, double confirmation) et `F11 → Bannissements` (liste des bans actifs,
    recherche par pseudo ou licence, déban **même sur un joueur hors ligne**). Réservé au super-admin ; l'anti-abus s'applique
    (pas de sanction sur un staff de rang égal ou supérieur). txAdmin reste en place, mais ne sait pas débannir depuis le jeu.
  - **Message de refus clair à la connexion** (`gs_onboarding`) : un banni voit son motif, la date de fin et le lien Discord —
    vérifié **avant** la liste blanche, donc un banni whitelisté est bien refusé. Les peines écoulées s'effacent toutes seules.
  - **Bus d'arrivée corrigé** (`gs_onboarding/client/arrival.lua`) : la cause des deux bugs signalés était la même ligne —
    le perso était posé à `stop.z - 1.0`, soit **1 m sous le trottoir** : il traversait la map et réapparaissait n'importe où
    (donc jamais devant la mairie). On attend maintenant la sortie réelle du bus, le chargement des collisions, puis on cale
    sur le sol (`GetGroundZFor_3dCoord`). Bonus : itinéraire GPS tracé vers Max « le Guide » + notification d'accueil.
  - **`entityLockdown strict` : audité, documenté, PAS basculé** (`server/cfg/prod.cfg` et `dev.cfg`). 4 créations d'entités
    réseau côté client casseraient : garde du gros coup (`gs_heists`), téléphone en main (`gs_phone`), chien K9 (`gs_police`),
    garde-côtes (`gs_smuggling`). Le chemin de migration (les passer côté serveur) est écrit dans les deux cfg. `relaxed`
    bloque déjà les entités créées hors script : le gain est réel mais marginal, et le risque de casse à ~9 jours de
    l'ouverture ne l'est pas. **À faire après l'ouverture.**
  - **Audit `bob74_ipl`** (`docs/BOB74_IPL.md`, source 2.7.1 lue fichier par fichier) : RoadLine exploite **6 intérieurs
    sur ~90**. Inventaire complet avec les coordonnées exactes, 3 familles (sous la carte → porte `gs_interiors` ; en place
    → rien à téléporter ; coquille → routing bucket comme `gs_hideouts`), 12 portes recommandées branchées sur des
    ressources existantes (faux papiers, primes, Car Meet, casse, studio radio, agence, boîte de nuit…), blocs prêts à
    coller (`inside` exacts, `outside` à relever en jeu — déplaçables par F11 car `gs_interiors` inclut `points.lua`).
    **Rien n'est branché** : en attente du choix des portes.
  - **`docs/MLO.md`** : ordre de recherche (bob74 → coquille → MLO gratuit → MLO payant), les 5 contrôles (poids,
    licence, marques, chiffrement, performance), procédure `IMPORTER-MODS.bat`, sources acceptables, sites à proscrire.
  - **`check_honeypot.py` durci** : ne lit plus que les fichiers suivis par Git et ignore les copies de `honeypot.lua`.
    Avant, un colis de synchronisation dézippé dans le dépôt (ou `livraison/`) bloquait le push à tort.
  - **Pots de miel testés à l'exécution** (`tests/test_gs_honeypot.lua`, 16 vérifications) : piège → ban définitif,
    staff jamais banni ni expulsé, déclenchement côté serveur ignoré, modes `kick` / `log`, expulsion de secours si
    `gs_admin` est en panne. Les noms de pièges y sont relus depuis `GSSec.Honeypot`, jamais écrits en clair.
  - **Tests** : +23 assertions `gs_admin` (niveaux, durées, anti-abus, déban, liste, peine écoulée, ban auto staff/joueur).
    Suite complète verte : 2664 tests Lua, 44 tests bot Discord, 27 pièges vérifiés.

- **V12.3** (10/10/2026) :
  - **Bot Discord** : les administrateurs du Discord RoadLine ont les commandes staff (le serveur est vérifié avant, donc sûr) ;
    nouvelles commandes `/isoler id minutes motif`, `/liberer id`, `/reanimer id` (`Admin.remote` : jail / unjail / revive).
  - **Appli staff (web)** : boutons Isoler (minutes), Libérer, Réanimer ; même journal, mêmes sanctions publiques.
  - **Site** : `CONFIG.slots = 48` (0 = valeur annoncée par le serveur), titre de mission « Rejoindre » retiré (gardé pour
    Signatures), bandeau Weazel en direct (rumeur confirmée, quartier chaud, prochain rendez-vous, légende, fugitifs, lieux de
    mémoire en tête du bandeau), SMS en jeu pendant la visite (Max, Weazel, Inconnu, LSPD ; une fois par session). Seul le
    titre « recherché » reste en bas de page (demande utilisateur).
  - **Site, fluidité et police** (V12.3b) : grain animé par `transform` (plus de repaint plein écran), aurora `blur(44px)` +
    `will-change`, aurora et fenêtres de la skyline en pause quand l'accueil n'est plus à l'écran, étoiles dessinées avec un
    halo pré-calculé (plus de `shadowBlur` par étoile et par image). Police des titres de mission : Pricedown si déposée dans
    `docs/site/fonts/` (`pricedown.woff2` / `.ttf`), sinon **Bowlby One** (Google Fonts, préchargée), sinon Anton.
  - **Audit statique de la base** (script de session, lecture seule, 341 fichiers Lua, 66 ressources) : événements déclenchés
    sans récepteur, callbacks jamais enregistrés, exports absents ou appelés du mauvais côté, `Bridge:` / `Security:`
    inexistants, commandes et touches en double, fonctions globales définies deux fois, objets inconnus, fichiers hors
    fxmanifest, `Config.*` non définis, tables par joueur sans nettoyage, natives client en serveur et inversement,
    `%d` sur division. **Résultat : 0 bug, 0 doublon** (83 alertes brutes, toutes des faux positifs vérifiés : affectations
    multiples `Config.A, Config.B = …`, appels par table, nettoyage via `gs_bridge:server:playerUnloaded`).
  - **Fiche de backtest refaite** (`tools/backtest.py` → `docs/pdf/ROADLINE_Backtest_complet.pdf`, 65 tests, 23 bloquants) :
    ce que le backtest du 09/10 a couvert est retiré ; session 1 = à re-vérifier après correction, session 2 = nouveautés
    V11.4 → V12.3 jamais testées, sessions 3-6 = base jamais testée, staff, charge.
  - **Guides PDF régénérés** (`docs/pdf/`) : guide du joueur (V11.5 → V12 : 1 perso, bus, permis retiré, PPA, faux papiers,
    témoin protégé, véhicules disparus, mémoire des lieux, échos, porter, service par téléphone), guide du staff (VIP, mapping,
    points, tickets, isolement à distance, traces de gang, scanner des faux papiers), guide RoadLine complet (`pdf.py`).

## 6. Décisions en attente / pas encore faites

- **Mappings** : 14 maps importées. L'utilisateur fait le tour avec F11 → Mappings installés, recale nos points là où un MLO
  remplace un lieu existant (Pillbox, Fleeca, Pops Pills, Bahama Mamas, Willie's) et dit quels nouveaux lieux doivent
  avoir un blip et une fonction (atelier TM, magasin d'alcool de Paleto, commissariat de Vinewood, gym, bureau, garage
  clandestin, village abandonné…). `burgershot` (trop lourd pour le chat) : envoyer seulement ses scripts, sans `stream`.
- **Recette en jeu** : fiche `ROADLINE_Backtest_complet.pdf`, sessions **1b, 1c, 1d** en priorité, puis 2 à 6.
  Retours des bêta-testeurs attendus cette semaine → vague de corrections.
- **Discord** : créer les webhooks `#logs-staff` et `#sanctions`, le salon de bienvenue (et activer « Server Members
  Intent » dans le portail développeur si on veut le message de bienvenue), relancer CONFIGURER-DISCORD, puis GERER-OVH → 12.
- **Cabines téléphoniques** : refonte à discuter (missions et contacts depuis les vraies cabines de la map, plus de
  points posés).
- **Après l'ouverture** : `entityLockdown strict` (4 créations d'entités à passer côté serveur, chemin écrit dans
  `server/cfg/prod.cfg`), audit des ~300 points d'entrée réseau, mentor automatique, « 30 premières minutes ».
- **bob74_ipl** : 12 portes recommandées dans `docs/BOB74_IPL.md`, rien de branché tant que l'utilisateur n'a pas choisi.
- **Idées retenues pour plus tard** : arracher un distributeur (câble + voiture) ; les 57 propositions de
  `docs/PROPOSITIONS.md` (à trier par l'utilisateur).
- **Site** : photos des encadrés et bande-annonce à fournir ; police Pricedown à déposer dans `docs/site/fonts/` si voulue.
- Le guide du joueur (PDF) n'est volontairement **pas en ligne sur le site** : l'utilisateur veut en reprendre le design
  lui-même avant publication.
- **À faire par l'utilisateur pour la V11.4** : créer les webhooks `#logs-staff` et `#sanctions`, le salon `#tickets`,
  relancer CONFIGURER-DISCORD (identifiants + réautoriser le bot), puis GERER-OVH → 12.
- **V11.5 à vérifier en jeu** (backtest) : positions des caméras accrochées (sinon ajuster `heading` / `Config.Mount`),
  trajet du bus (`Config.Arrival.from` / `stop`), offsets des armes dans le dos (`Config.Back.slots`), PNJ acheteurs
  (`heading`), lisibilité des images du menu F11.
- **Backtest** : le food truck (corrigé en V11.5) et tout le retour du 09/10 sont à re-vérifier en jeu avec la nouvelle fiche
  (`ROADLINE_Backtest_complet.pdf`, session 1), puis les nouveautés V11.4 → V12.3 (session 2). Retours attendus avant la
  prochaine vague de corrections.
- **Site** : photos des encadrés à fournir par l'utilisateur (galerie), bande-annonce pas encore tournée ; police Pricedown à
  déposer dans `docs/site/fonts/` si voulue à l'identique (Bowlby One sinon).
- **Idées retenues pour plus tard** (demande du 10/10) : missions et contacts depuis les **vraies cabines téléphoniques** de la
  map (plus de points / blips posés), **arracher un distributeur** avec un câble et une voiture puis l'ouvrir au calme ; les
  57 propositions (signatures, modes, embellissement, gains rapides bêta) et les 12 questions de vision sont dans
  `docs/PROPOSITIONS.md` (à trier par l'utilisateur). **Ouverture bêta officieuse prévue dans quelques jours** (mi-octobre),
  officielle le 20/10/2026.
- Le guide du joueur (PDF) n'a volontairement **pas été mis en ligne sur le site** : l'utilisateur veut en reprendre
  le design lui-même avant publication.

## 7. Règles permanentes à respecter (rappel, ne jamais oublier)

- **Jamais de vraie marque** (risque de ban Cfx.re) : toujours des noms de véhicules/enseignes inventés ou ceux déjà
  dans GTA V.
- **Jamais de mot de passe ou secret en clair** dans les messages ni dans les fichiers commités (jetons, mots de
  passe VPS, clés API...). Les outils Windows masquent la saisie et écrivent dans `secrets.cfg` (jamais poussé).
- **Demander avant de supprimer quoi que ce soit.**
- Toujours pousser sur les **deux branches** (`feature/phase1-bridge` et `claude/gta-rp-architecture-stack-pbvdxz`).
- Zips de livraison : `livraison/ROADLINE-V12-installation.zip` (via `git archive --format=zip --prefix=gtasoon/ HEAD`)
  et `livraison/ROADLINE-site.zip` (contenu de `docs/site/`, doit inclure `img/`).
- Toujours faire tourner `bash tests/run.sh` avant de pousser (hook pre-push de toute façon bloquant).
- Attribution des commits : trailers `Co-Authored-By` et `Claude-Session` donnés par le système à chaque session
  (peuvent changer de modèle d'une session à l'autre : relire le system reminder du moment avant de committer).
- Tout est en **français**, ton direct et concis, sans jargon anglais inutile.

## 8. Repères techniques utiles pour repartir vite

- Tests : `bash tests/run.sh` (luac, `check_cfg.py`, `check_labels.py`, `check_links`, perf, marques, tests Lua,
  tests bot Discord Node). Mock Lua dans `tests/` : `CreateThread`/`Wait` no-op, horloge simulée, `W.players[src]`.
- PDF : `python3 tools/pdf.py` (guide/fiche de test/carte des points), `python3 tools/backtest.py` (fiche backtest),
  `python3 tools/bilan.py` (bilan de version), `python3 tools/guide_joueur.py` (guide joueur, lit
  `tools/data/vehicules_concession.json`), `python3 tools/guide_staff.py` (guide staff, importe `guide_joueur.py`).
- Site : `docs/site/index.html` (un seul fichier, tout inline). Carte : image `docs/site/img/carte-ls.webp`
  (atlas du jeu, zoom 2, stitché/recadré/redimensionné, calibration `px/py` par régression sur points de repère).
- Concession : réglages dans `scripts/windows/outils-communs.ps1` (fonction `Set-QboxOverrides`, tableau
  `$QboxPatches`, nouveau type de patch `prices` lisant `prix-vehicules.json`) — appliqués uniquement côté Windows
  (PowerShell), simulation de contrôle faite en Python dans ce conteneur faute d'environnement PowerShell.

---

## 9. PROMPT DE REPRISE — à coller dans une nouvelle conversation si celle-ci est perdue

```
Je reprends le projet RoadLine RP (serveur FiveM GTA RP 100 % français, Qbox/ox), dépôt harmoniev1/dddd,
branches feature/phase1-bridge et claude/gta-rp-architecture-stack-pbvdxz (toujours pousser sur les deux).

Lis d'abord docs/ETAT_PROJET.md à la racine du repo : il contient le récapitulatif complet et à jour de l'état
du projet (versions, infra, ce qui est livré, ce qui reste à faire, les règles permanentes). Prends-le comme
source de vérité pour le contexte, puis continue le travail à partir de la section « 6. Décisions en attente ».

Règles permanentes à ne jamais oublier : jamais de vraie marque (risque de ban Cfx.re), jamais de mot de passe
ou secret en clair, toujours demander avant de supprimer quoi que ce soit, tout en français, faire tourner
bash tests/run.sh avant de pousser, pousser sur les deux branches, régénérer les zips de livraison
(livraison/ROADLINE-V12-installation.zip et livraison/ROADLINE-site.zip) après un changement livrable.
Si une autre session Claude a travaillé en parallèle : comparer son colis au dépôt (en ignorant les fins de
ligne CRLF), fusionner sans rien perdre, vérifier les doublons, puis repartir de la version commune.

Contexte serveur : VPS OVH 57.129.170.173 (Ubuntu 24.04, mode txAdmin, profil privé pour l'instant), ouverture
officielle prévue le 20/10/2026 21h (Paris), version interne gs_version actuelle (voir server/server.cfg.example),
version publique affichée aux joueurs gs_public_version (actuellement « V4 · bêta », à ne pas réaligner sur la
version interne sans demande explicite).
```

---

*Ce fichier doit être mis à jour à la fin de chaque session de travail significative (nouvelle version, décision
importante, changement de contexte). Ne pas le laisser dériver : il doit toujours refléter l'état réel.*
