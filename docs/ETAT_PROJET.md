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
- `gs_version` (convar, `server.cfg.example`) = **V11.3** → version technique interne, vue par le staff (F11, console,
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
  - Les commandes staff du bot (`/joueurs /geler /degeler /avertir /expulser /message /annonce`) sont autorisées à
    **quiconque a le rôle Discord configuré dans `gs_discord_staff_role`, OU quiconque a la permission Discord
    « Administrateur »** (même hors staff en jeu). L'utilisateur a été prévenu de ce deuxième cas et réfléchit à
    resserrer ça (proposition faite : exiger uniquement le rôle staff, pas encore demandée/appliquée).

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

## 5. Ce qui a été livré, dans l'ordre (V1 → V11.3)

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

## 6. Décisions en attente / pas encore faites

- **Resserrer les commandes staff du bot Discord** au seul rôle `gs_discord_staff_role` (retirer le passe-droit
  « Administrateur Discord ») : proposé à l'utilisateur, **pas encore confirmé ni implémenté**.
- **Webhooks manquants** : `gs_staff_webhook` et `gs_webhook_sanctions` à créer côté Discord et renseigner.
- **Bug signalé par l'utilisateur, pas encore corrigé** : le **food truck de Legion Square** (marché de nuit,
  `gs_nightcity`, `Config.Markets`) — le PNJ vendeur est bien présent et vendable, mais **le modèle du camion
  (food truck) ne s'affiche pas devant lui**. À investiguer : `gs_nightcity/client/*.lua`, vérifier si un prop de
  camion est censé être spawné à côté du PNJ marchand, ou si c'est juste le PNJ qui a été déplacé sans son décor.
  L'utilisateur est en plein backtest solo + avec 1-2 joueurs et doit envoyer d'autres retours.
- **Backtest en cours** chez l'utilisateur (lui + 1-2 joueurs). Des retours supplémentaires sont attendus avant la
  prochaine vague de corrections.
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
