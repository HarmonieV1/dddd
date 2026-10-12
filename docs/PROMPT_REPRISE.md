# Prompt de reprise — RoadLine RP (à coller dans une nouvelle session Claude)

> Copie tout ce qui est sous la ligne ci-dessous dans ta deuxième session. Mis à jour le 12/10/2026 (V12.31).

---

Tu reprends le développement de **RoadLine RP**, un serveur GTA RP FiveM **français** (base **Qbox / ox** : qbx_core,
ox_lib, ox_inventory, ox_target, oxmysql, illenium-appearance, qbx_vehiclekeys, pma-voice). Ouverture publique :
**20/10/2026 à 21 h** ; la **bêta est en cours**. Je m'occupe de la promo ; toi, des corrections, de la configuration et de
l'optimisation.

## Avant toute chose
1. Lis **`docs/ETAT_PROJET.md`** en entier (récap complet, historique V12.x, décisions) puis `docs/MLO.md` et
   `docs/IMPORTER_MODS.md` (maps payantes, scripts compagnons, diagnostic).
2. Vérifie que tu es à jour : `git fetch origin && git log -1 origin/feature/phase1-bridge` doit montrer
   « V12.31 : scripts compagnons des maps… » (ou plus récent).

## Règles permanentes (à respecter sans exception)
- **Tout en français** (code commenté, messages en jeu, docs, réponses).
- **Jamais de mot de passe ni de secret en clair** dans tes réponses ; **ne jamais committer `secrets.cfg`**.
- **Demande-moi avant de supprimer quoi que ce soit** (fichier, map, PDF, ressource).
- **Aucune vraie marque** (voitures, mode, police réelle) : risque de bannissement Cfx.re. Seulement le « lore GTA ».
- Lance **`bash tests/run.sh`** avant chaque push (un hook pre-push le fait aussi) : tout doit être vert.
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
  `gsa_zz_fusion_occlusion`, `RETIRED_MAPS`, `PUBLIC` = blips publics, `ACTIVITY`, contrôle d'intégrité) ;
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

## État au 12/10/2026 (V12.31)
- Récents : clés de véhicule en objet (`gs_carkey`), vêtements et tenues en objets + garde-robe (U), apparition fiable
  dans les véhicules, blips publics des maps, contrôle « chez moi » des maps (F11), scripts compagnons des maps payantes
  installés par IMPORTER-MODS, intégrité des maps vérifiée au démarrage, outil REPARER-FIVEM.bat, site de doc HTML.
- Maps : villa moderne 01 **retirée** (12/10), **villa bunker remise** ; retirées aussi : Willie's, alcool Paleto,
  Moreo Gym, casse, Benny's original, Digital Den, Shadow Complex. Désactivées (archives coupées, à retélécharger) :
  beach party, soccer / soccer_cloth, plasmatron.

## En attente (à reprendre avec moi)
1. **Maps** : relancer IMPORTER-MODS puis METTRE-A-JOUR-OVH ; lire RAPPORT-MODS.txt (scripts « INSTALLÉ … avec gsa_… »
   ou « il lui manque … ») et la console (« NON démarré », « DÉCOR SEUL », « Intégrité des maps »). F11 → Contrôler les
   maps chez moi. Corriger map par map selon ce qui sort.
2. **F4 police / EMS** « cassé » : j'attends le symptôme exact (lignes rouges F8, message « Réservé… en service », action
   qui échoue). La garde-robe ouverte bloque F4 (focus NUI).
3. **Doublons de lieux** (casino, concession, Ammu-Nation, Benny's, prison) : pour chacun, « nouveau » (map payante) ou
   « ancien » (lieu du jeu) → recaler nos points et retirer les blips en double.
4. **Prison / jail** : vérifier les coordonnées de cellule et de sortie avec la map prison (`/coords` si décalé).
5. Import incrémental (proposé, pas encore décidé).
6. Packs vêtements / coiffures : liens donnés, rien d'importé sans mon accord.
7. Après l'ouverture : entityLockdown strict, audit des ~300 points d'entrée réseau, refonte des cabines téléphoniques,
   miniatures du menu d'apparence, mises à jour ox_lib / ox_inventory / oxmysql.

Commence par me dire ce que tu as compris de l'état du projet en 5 lignes, puis attends ma demande.
