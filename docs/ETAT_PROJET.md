# État du projet RoadLine RP — récapitulatif complet (à jour au 09/10/2026)

Ce document sert de **point de sauvegarde** : si une conversation avec Claude est perdue, compressée ou doit reprendre
ailleurs, tout ce qu'il faut savoir est ici. Il est versionné avec le code (`git log` en garde aussi l'historique).
En bas de ce fichier : un **prompt prêt à coller** dans une nouvelle conversation pour repartir sans rien perdre.

---

## 1. Identité du projet

**RoadLine RP** : serveur FiveM GTA RP **100 % français**, bâti sur **Qbox/ox** (qbx_core, ox_inventory, ox_lib,
ox_target...). Dépôt : `harmoniev1/dddd`. Ressources maison dans `server/resources/[gtasoon]/gs_*` (65 ressources).
Positionnement : **Free Access, zéro pay-to-win**, une ville qui vit même sans les joueurs, beaucoup de systèmes
exclusifs (« ce que tu ne trouveras nulle part ailleurs »).

**Branches à jour** (toujours pousser sur les deux) :
- `feature/phase1-bridge`
- `claude/gta-rp-architecture-stack-pbvdxz`

**Dernier commit poussé** : `2c1c335` — « V11.3 : salle Luxe et concession nettoyée, IP masquée jusqu'à l'ouverture,
version publique V4, règlement Discord, guide du staff ».

## 2. Versions : interne vs publique (important, piège classique)

Depuis la V11.3, il y a **deux numéros de version différents**, volontairement :
- `gs_version` (convar, `server.cfg.example`) = **V12.3** → version technique interne, vue par le staff (F11, console,
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
- `PREPARER-OVH.bat`, `CAPTURER-ERREURS.bat`, `SAUVEGARDER-BDD.bat` / `RESTAURER-BDD.bat`, `IMPORTER-MODS.bat`,
  `DEVENIR-ADMIN.bat`, `PUBLIER-SITE.bat`

**Piège vécu cette session** : l'utilisateur a demandé « c'est quoi mon adresse cfx » en croyant qu'elle existait déjà
— elle n'existe pas tant que le serveur n'est pas passé en public au moins une fois. Résolu en utilisant l'IP directe
en attendant.

## 5. Ce qui a été livré, dans l'ordre (V1 → V11.5)

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
  20 propositions de signatures sont dans la réponse du 10/10 (à trier par l'utilisateur).
- Le guide du joueur (PDF) n'a volontairement **pas été mis en ligne sur le site** : l'utilisateur veut en reprendre
  le design lui-même avant publication.

## 7. Règles permanentes à respecter (rappel, ne jamais oublier)

- **Jamais de vraie marque** (risque de ban Cfx.re) : toujours des noms de véhicules/enseignes inventés ou ceux déjà
  dans GTA V.
- **Jamais de mot de passe ou secret en clair** dans les messages ni dans les fichiers commités (jetons, mots de
  passe VPS, clés API...). Les outils Windows masquent la saisie et écrivent dans `secrets.cfg` (jamais poussé).
- **Demander avant de supprimer quoi que ce soit.**
- Toujours pousser sur les **deux branches** (`feature/phase1-bridge` et `claude/gta-rp-architecture-stack-pbvdxz`).
- Zips de livraison : `livraison/ROADLINE-V11-installation.zip` (via `git archive --format=zip --prefix=gtasoon/`)
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
(livraison/ROADLINE-V11-installation.zip et livraison/ROADLINE-site.zip) après un changement livrable.

Contexte serveur : VPS OVH 57.129.170.173 (Ubuntu 24.04, mode txAdmin, profil privé pour l'instant), ouverture
officielle prévue le 20/10/2026 21h (Paris), version interne gs_version actuelle (voir server/server.cfg.example),
version publique affichée aux joueurs gs_public_version (actuellement « V4 · bêta », à ne pas réaligner sur la
version interne sans demande explicite).
```

---

*Ce fichier doit être mis à jour à la fin de chaque session de travail significative (nouvelle version, décision
importante, changement de contexte). Ne pas le laisser dériver : il doit toujours refléter l'état réel.*
