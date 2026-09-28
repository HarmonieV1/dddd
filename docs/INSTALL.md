# Installation du serveur de dev (local, Windows)

[CONFIG] Checklist Phase 0. Rien n'est exposé sur Internet : on joue en `localhost`.
Les écrans et menus exacts de txAdmin/Qbox évoluent : en cas de doute, docs.qbox.re et docs.fivem.net font foi.

## 1. Prérequis
- [ ] GTA V **Legacy** + client FiveM qui se lance (voir FAQ en bas)
- [ ] MariaDB (ou MySQL 8) : créer la base `gtasoon` et un utilisateur dédié (pas root)
- [ ] Git, et ce repo cloné

## 2. FXServer + txAdmin + Qbox
- [ ] Télécharger les artifacts serveur Windows (runtime.fivem.net, build "recommended")
- [ ] Lancer `FXServer.exe` → txAdmin s'ouvre sur `http://localhost:40120` → code PIN affiché en console
- [ ] Créer le compte admin txAdmin, choisir **Popular Recipes → Qbox**
- [ ] Clé de licence : keymaster.fivem.net (gratuite)
- [ ] Laisser la recipe installer les ressources et la BDD

## 3. Brancher GTA SOON sur la recipe
- [ ] Copier `server/resources/[gtasoon]` dans le dossier `resources/` du serveur
- [ ] Copier `server/cfg/` à côté du `server.cfg` du serveur
- [ ] `cfg/secrets.cfg.example` → `cfg/secrets.cfg`, remplir licence + chaîne MySQL (**jamais commité**)
- [ ] Remplacer le `server.cfg` de la recipe par `server/server.cfg.example` (garder une copie de celui de la recipe pour comparer les convars)
- [ ] Retirer `qbx_management` et `qbx_weathersync` du dossier resources (doublons, voir linter)
- [ ] Étapes Qbox de `docs/JOBS.md` (jobs en double, maxJobsPerPlayer, item repairkit)
- [ ] Ajouter ton identifiant `license:` en `group.admin` dans `cfg/secrets.cfg`

## 4. Premier démarrage
- [ ] Console : `[gs_jobs] prêt : 6 jobs chargés`, aucune ligne rouge
- [ ] Console : aucune erreur `[gs_bridge]` (sinon un nom d'API `[API]` est à corriger dans gs_bridge)
- [ ] En jeu : F8 → `connect localhost`
- [ ] `/gsjob add <ton id> police 4`, F6, prise de service, `/meteo RAIN 5`, `/heure 18 30`
- [ ] `resmon 1` : chaque ressource `gs_*` < 0,5 ms au repos

## 5. Avant chaque mise à jour
- [ ] `./tests/run.sh` vert (syntaxe, linter config, tests logique)
- [ ] `scripts/backup_db.sh` puis restart via txAdmin

## FAQ — FiveM ne détecte pas GTA
FiveM ne marche qu'avec **GTA V Legacy** (pas Enhanced). Installer Legacy (entrée séparée dans Steam/Epic,
inclus dans l'achat), le lancer une fois, supprimer `%localappdata%\FiveM`, réinstaller FiveM et
choisir le dossier **Legacy** (celui qui contient `GTA5.exe` et `PlayGTAV.exe`).
