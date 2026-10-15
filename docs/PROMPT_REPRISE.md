# Prompt de reprise — RoadLine RP (à coller dans une nouvelle session Claude)

> Copie tout ce qui est sous la ligne ci-dessous dans ta deuxième session. Mis à jour le 15/10/2026 (V12.60).

---

Tu reprends le développement de **RoadLine RP**, un serveur GTA RP FiveM **français** (base **Qbox / ox** : qbx_core,
ox_lib, ox_inventory, ox_target, oxmysql, illenium-appearance, qbx_vehiclekeys, pma-voice). Ouverture publique :
**20/10/2026 à 21 h** ; la **bêta est en cours**. Je m'occupe de la promo ; toi, des corrections, de la configuration et de
l'optimisation.

## Avant toute chose
1. Lis **`docs/AUDIT_V12_35.md`** (état et risques au 12/10), puis **`docs/ETAT_PROJET.md`** en entier (récap complet, historique V12.x, décisions) puis `docs/MLO.md` et
   `docs/IMPORTER_MODS.md` (maps payantes, scripts compagnons, diagnostic).
2. Vérifie que tu es à jour : `git fetch origin && git log -1 origin/feature/phase1-bridge` doit montrer
   « V12.58 : bancs réglables pour tous, arme dans le dos, caméras peignables » (ou plus récent).

## Règles permanentes (à respecter sans exception)
- **Tout en français** (code commenté, messages en jeu, docs, réponses).
- **Jamais de mot de passe ni de secret en clair** dans tes réponses ; **ne jamais committer `secrets.cfg`**.
- **Demande-moi avant de supprimer quoi que ce soit** (fichier, map, PDF, ressource).
- **Aucune vraie marque** (voitures, mode, police réelle) : risque de bannissement Cfx.re. Seulement le « lore GTA ».
- Lance **`bash tests/run.sh`** avant chaque push (un hook pre-push le fait aussi) : tout doit être vert.
- Si l'utilisateur t'envoie `ROADLINE-commits.bundle` (commits du PC Windows) : `bash scripts/linux/recevoir-bundle.sh ROADLINE-commits.bundle`
  (vérifie, fusionne, teste, pousse). Sur le PC Windows, c'est `POUSSER-GITHUB.bat` (voir `docs/GITHUB.md`).
- Pousse sur **les deux branches** :
  `for b in feature/phase1-bridge claude/gta-rp-architecture-stack-pbvdxz; do git push origin "feature/phase1-bridge:$b"; done`
- Version : `gs_version` dans `server/server.cfg.example` et `VERSION` dans `tools/pdf.py` (+ `tools/backtest.py`,
  `tools/doc_hub.py`, `tools/guide_staff.py`, `tools/bilan.py`). Ajoute une entrée en tête de l'historique de
  `docs/ETAT_PROJET.md` à chaque version.
- Après une mise à jour : régénère les PDF (`python3 -B tools/pdf.py`, `backtest.py`, `bilan.py`, `guide_staff.py`,
  `guide_joueur.py`), puis livre :
  - `git archive --format=zip --prefix=gtasoon/ -o livraison/ROADLINE-V12-installation.zip HEAD`
  - `cp docs/hub/index.html livraison/ROADLINE-Documentation.html` (site de doc régénéré par `tests/run.sh`)
- Le guide joueur PDF n'est **pas** publié sur le site.
- Ne pas enchaîner les essais à l'aveugle : comprendre la cause, tester, puis livrer une seule fois.

## Organisation du dépôt
- Nos ressources : `server/resources/[gtasoon]/gs_*` (une cinquantaine : gs_bridge, gs_admin, gs_police, gs_jobs,
  gs_details, gs_phone…). Maps importées : `resources/[addons]/gsa_*` (sur le PC, pas dans git).
- Outils Windows : `scripts/windows/*.ps1` (+ `.bat` à la racine : METTRE-A-JOUR, METTRE-A-JOUR-OVH, IMPORTER-MODS,
  VIDER-CACHE-FIVEM, REPARER-FIVEM, NETTOYER-MARQUES). VPS Linux : `scripts/linux/roadline.sh`.
- Sur le PC : `C:\GTASOON\` (server-data, `mods-a-trier` = archives à importer, `mods-tri` = tri + RAPPORT-MODS.txt,
  `mods-tri\scripts-a-verifier`, `mods-retires.txt`).
- Lecteur de maps : `gs_admin/server/maps.js` (scan des .ymap, conflits d'occlusion fusionnés dans
  `gsa_zz_fusion_occlusion`, `RETIRED_MAPS` + `RETIRED_PATTERNS` (V12.36 : retrait par motif), `PUBLIC` = blips publics, `ACTIVITY`, contrôle d'intégrité) ;
  menu staff F11 → Monde et lieux → Mappings installés (`gs_admin/client/quick.lua`).

## Pièges FXServer déjà rencontrés (ne pas refaire)
- Node `fs` en écriture bloqué (`--allow-fs-write`) ; Lua `io.open` en écriture refusé ; `package` absent en Lua FiveM.
- Export JS → Lua de la MÊME ressource : « No such export » → utiliser des événements locaux avec callback.
- Une ressource n'écrit (SaveResourceFile) que dans **son propre dossier** (« write not allowed »).
- Fichier .ydr tronqué = crash client « Invalid fixup… » → archive coupée, à retélécharger.
- Packs escrow (.fxap) : ne marchent qu'achetés avec le compte Cfx.re lié à la clé du serveur.

## Touches en jeu
F1 téléphone, F2 inventaire, F3 progression, F4 intervention (police / EMS), F5 emotes, F6 métiers, F7 duo, F9 gang,
F10/F11 staff, I aide, K inventaire proche, W radial, H mains en l'air, L verrouiller, B ceinture, **U garde-robe**.

## État au 15/10/2026 (V12.60)
- Récents : clés de véhicule en objet (`gs_carkey`), vêtements et tenues en objets + garde-robe (U), apparition fiable
  dans les véhicules, blips publics des maps, contrôle « chez moi » des maps (F11), scripts compagnons des maps payantes
  installés par IMPORTER-MODS, intégrité des maps vérifiée au démarrage, outil REPARER-FIVEM.bat, site de doc HTML.
- Maps : villa moderne 01 **retirée** (12/10), **villa bunker remise** ; retirées aussi : laser game, karting (+ DLC),
  plasmatron (V12.33), Willie's, alcool Paleto, Moreo Gym, casse, Benny's original, Digital Den, Shadow Complex.
  `RETIRED_MAPS` (noms exacts) + `RETIRED_PATTERNS` (motifs : plasmagame, plasmakart, plasmatron, villa_01, redline) dans maps.js = source
  unique : le serveur les supprime au démarrage, le retrait F11 supprime aussi le dossier, IMPORTER-MODS ne les réinstalle jamais (V12.36).
- **V12.37 (13/10)** : gs_jobs (une interaction par point, service par état voulu + anti-rebond, garage : messages exacts, armurerie
  prêtée et reprise), gs_details (holster réécrit, `/dosreglage`, `DAMAGE` adouci), gs_weather (interventions créées à l'approche sur
  la route), gs_rental (13 comptoirs), gs_admin / gs_bridge / gs_markers (placement libre, « PNJ et objets » reliés aux métiers / gangs,
  table `gs_staff_peds`), gs_bridge/server/points_fichier.lua (`points-deplaces.json` : les points déplacés passent du PC au VPS via
  METTRE-A-JOUR-OVH ; gardé par METTRE-A-JOUR et « roadline maj »), retouches Qbox : PPA retiré de qbx_cityhall, service / garage de
  qbx_police et qbx_ambulancejob neutralisés (motif à confirmer sur la version installée : avertissement jaune si absent).
- **V12.40 (14/10)** : `gs_showroom` (véhicules d'exposition posés par le staff, essai 2 min, achat), mécano Benny's (aperçu
  en direct pour le client, animations, facture), courses sur mesure (F11), portes `/doorlock` (F11), territoires de gang
  visibles des seuls membres + niveaux + population, tempête posée au sol, Cayo en espèces / argent sale, blips de maps devinés,
  « RoadLine RP » sur la carte Échap. Rien n'a encore été essayé en jeu : backtest section 6d.
- **V12.41 (14/10)** : achat concession = véhicule sorti avec clés (comme Qbox), staff change le modèle de loin ; balle dans
  la tête = à terre ; caméras LSPD en direct au terminal ; boutique en jeu (`/boutique`, gs_store/web/boutique.html) aux couleurs
  du site + **RoadCoins** (docs/BOUTIQUE.md). Boutique toujours désactivée : prix et contenus des packs à définir avec moi.
- **V12.42 (14/10)** : labo réparé (scellés gardés en base, lus dans le sac), mobilier utilisable (Alt : s'asseoir, s'allonger,
  rouler en fauteuil roulant ; `Config.Furniture` dans gs_furniture, hauteurs à caler en jeu), arme dans le dos en attache rigide.
- **V12.43 (14/10)** : erreurs console corrigées (gs_wanted, soins Qbox), pop-up police en boucle (retouche qbx_police
  job.lua), conflits Patoche tranchés, pack LSPD au garage police. Récap de la session : **`docs/PATCH_SESSION_14-10.md`**.
  En attente : 30 mods « à convertir » (dossier mods-tri\a-convertir à m'envoyer), `patoche_interact` pour la villa bunker.
- **V12.45 (14/10)** : mods solo convertis en ajouts FiveM (`tools/vetements/README.md` : noms dlc déjà pris, suivants
  `gsahommef` / `gsafemmei`) → 9 zips `ROADTRIP-…` à passer par IMPORTER-MODS ; récolte céréales, tabac (légal) et pavot
  (illégal, sans blip, receleur du port, crime `drug_cultivation`) avec les props BzZz (`gsa_9a13b85…`).
- **V12.46 (14/10)** : pack de robes (dresspack) converti en 3 collections, carte **V5** sur le site public (teaser
  confidentiel passé en V6), priorités du site de doc, guide staff, patch de session final (`docs/PATCH_SESSION_14-10.md`).
- **V12.47 (14/10)** : REPARER-BDD.bat pour « Unable to establish a connection to the database » (MariaDB redémarrée,
  cause lue dans son journal, relance automatique si elle plante, serveur relancé).
- **V12.48 (14/10)** : importeur : bibliothèque réclamée par un script installée sous son vrai nom (patoche_interact →
  villa bunker), mods déjà convertis prioritaires (lace_up_sweats, hair, natt_hair5_fivem), refus manuels ($Refused).
- **V12.49 (14/10)** : blush au coiffeur (femme). Corps féminins au choix : jamais reçus ; cardigan cœur et chignon à convertir.
- **V12.50 (15/10)** : tatouages (français, payé = gardé), voix (portées, atténuation Windows via REPARER-SON), garde-robe U
  (enfilé d'abord), protection d'arrivée anti-« spawn patate » (gs_onboarding), propositions D6 n° 108-117.
- **V12.51 (15/10)** : voix par l'export pma-voice (gs_radio/client/voice.lua), [E] du duo / des missions qui restait, anti-spam
  de coups (0,8 s). Voix = priorité n°1 de l'ouverture : à tester à 2-3 joueurs.
- **V12.52 (15/10)** : /son (aide vocale en jeu, rappel aux 3 premières connexions, écran de chargement). Stand de jeux
  Patoche « pas good » : symptôme à préciser (décor cassé par le conflit de ymap tranché V12.43, script, ou armes du stand).
- **V12.53 (15/10)** : stand de jeux (conflit de ymap rendu au stand + ordre de relance), objets des scripts importés ajoutés
  à ox_inventory par IMPORTER-MODS (jetons d'auto-tamponneuses), musculation en prison.
- **V12.54 (15/10)** : armes dans le dos en objets locaux (plus de copie réseau figée), caméra libre dans le menu mécano.
- **V12.55 (15/10)** : salles de jeu (3 blips aux positions du fondateur, zones sans police). En attente : nom du crash du
  jeu du clown, retour sur les jetons des auto-tamponneuses (rapport IMPORTER-MODS).
- **V12.56 (15/10)** : territoires de gang en cases alignées sur les rues (/quartierforme), propositions D7 n° 118-131.
- **V12.57 (15/10)** : phase 1 D7 — gs_vie (poubelles, se laver, démarche blessée, passagers bavards, porter / otage,
  /perfserveur), distributeurs snacks / café, magasin de masques, ENVOYER-PLACEMENTS.bat. Phase 2 prévue : 119 cimetière,
  128 cabines, 129 audit réseau / entityLockdown, peut-être 122 fausse monnaie.
- **V12.60 (15/10, session de secours)** : DIAGNOSTIC-MODS.bat (mods abîmés / en conflit, corrections sûres), F11 blips en double,
  gs_cimetiere (tombes, avis de décès, fleurs), gs_cabines (appel anonyme police / Weazel), gs_lives (écrans des joueurs, staff).
- **V12.59 (15/10, session de secours, branche `claude/presence-check-f9jlgz`)** : IMPORTER-MODS fiabilisé (zips Drive en
  morceaux, mods sans fxmanifest, doublons, dossiers / volumes, voitures avec script de noms, robes FiveM), tête = mort immobile,
  casque 1 balle, arme dans le dos ré-accrochée seule, emotes rapides Pavé num. 1-5, M = ragdoll, /vue, traces de sang / douilles
  (24 h), effets « sur moi » (super vitesse voiture…), caméras du décor peignables + ← → au terminal, police IA qui poursuit
  (pas pour les braquages), bot Discord (rattrapage des accueils, #statut expliqué, plus « Joue à Qbox »), bandeau Weazel du site,
  courses sur mesure. Détail : docs/ETAT_PROJET.md.
- **V12.58 (15/10)** : /meubleregle (bancs : réglage gardé pour tous), arme dans le dos bien placée dès le rangement,
  caméras de rue peignables (portée 5 m, bombe utilisée dessous).
- Deux sessions Claude (web + poste Windows) : V12.33 puis V12.37 du poste Windows intégrées par la session web (V12.38 =
  fusion). Côté Windows : POUSSER-GITHUB.bat (docs/GITHUB.md) pour envoyer directement sur GitHub. Désactivées (archives coupées, à retélécharger) :
  beach party, soccer / soccer_cloth, plasmatron.

## En attente (à reprendre avec moi) — mis à jour le 14/10
1. **Dernier gros mod** (optionnel) : `male_hair_collection_vol_1` (134 Mo, un .ydd de 27,8 Mo à alléger) : à envoyer en
   volumes 7-Zip de 25 Mo. Tous les autres mods « à convertir » sont faits (9 zips ROADTRIP, `tools/vetements/README.md`).
1 bis. **Personnalisation conseillée mais jamais reçue** (liens donnés le 14/10, rien importé) : visages « Improved Females »
   (github zfbx/improved-females, change toutes les femmes), corps « Muscular Body for MP Female » (jinxmods, au choix),
   « Improved Lower Body for MP Female 2.0 » (page gta5-mods d'origine). À convertir (petits) : `natt_s_heart_cardigan`,
   `long_hair_with_a_bun_by_jaagoda`. Coupes dont la couleur du coiffeur ne s'applique pas partout (shader `ped_alpha`) :
   Buzzcut Fade ×2 (coiffures_homme_2 n°1-2, pas teintables), dreadlocks Suthyland et 6 coupes TideFN (une partie fixe).
2. **Récolte** : points des champs (céréales, tabac, pavot) à caler en jeu via F11 si besoin.
3. **patoche_interact** : importé le 14/10 ; V12.48 l'installe sous son vrai nom au prochain IMPORTER-MODS. Scripts billard /
   football : à remettre dans mods-a-trier. `mp25_muscular` (vêtement installé) : vérifier qu'il ne change pas tous les corps.
4. **À caler en jeu** : points du mécano sur la map Benny's, véhicules d'exposition + départ des essais, portes `/doorlock`,
   hauteurs du mobilier (lignes F8 envoyées par le fondateur → `gs_furniture/shared/config.lua`).
5. **Doublons de lieux** (casino, concession, Ammu-Nation, prison) et **coordonnées de la prison** à vérifier.
6. **Boutique** : prix, packs, RoadCoins, adresse Tebex et conformité PLA avant `Config.Enabled = true`.
7. Après l'ouverture : entityLockdown strict, audit des ~300 points d'entrée réseau, cabines téléphoniques, skate en
   location, mises à jour ox_lib / ox_inventory / oxmysql.

## Ce qu'a fait la session web le 12/10 (V12.17 → V12.34), en bref
- Maps payantes (escrow) : import réparé, archives coupées refusées (7-Zip ≥ 2), intégrité vérifiée au démarrage, fusion
  d'occlusion écrite par `gsa_zz_fusion_occlusion` (seul dossier autorisé), blips publics, contrôle « chez moi » (F11),
  scripts compagnons installés avec leur map, maps retirées jamais réimportées (V12.35).
- Joueurs : apparition dans le véhicule fiable, clés en objet, vêtements / tenues en objets, garde-robe (U).
- Outils : REPARER-FIVEM.bat (erreurs FiveM / Rockstar côté joueur), site de doc HTML (`livraison/ROADLINE-Documentation.html`).
- La V12.33 du poste Windows (maps plasma retirées, F4 qui explique ses refus, garde-robe sans focus bloqué, atterrissage
  à Cayo) est intégrée dans git.

## Si tu n'as pas accès au dépôt git
Le paquet de transfert contient `ROADLINE-V12-installation.zip` (= le dépôt en V12.34, sans secrets), `ETAT_PROJET.md`,
`MLO.md`, `IMPORTER_MODS.md` et le site de doc. Travaille dans ce zip et, à la fin, renvoie-moi un zip complet + la liste
des fichiers modifiés pour que l'autre session les reprenne.

Commence par me dire ce que tu as compris de l'état du projet en 5 lignes, puis attends ma demande.
