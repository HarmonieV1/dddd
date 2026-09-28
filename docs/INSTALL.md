# Installation du serveur de dev (local, Windows)

[CONFIG] Checklist Phase 0. Rien n'est exposé sur Internet : on joue en `localhost`.
Les écrans et menus exacts de txAdmin/Qbox évoluent : en cas de doute, docs.qbox.re et docs.fivem.net font foi.

## 1. Prérequis
- [ ] GTA V **Legacy** + client FiveM qui se lance (voir FAQ en bas)
- [ ] Git (ou GitHub Desktop), et ce repo cloné
- [ ] MariaDB, installé comme ci-dessous

### MariaDB en 5 minutes (obligatoire : Qbox y stocke persos, inventaires, contrats)
1. mariadb.org/download → version **LTS**, Windows x86_64, fichier `.msi`
2. Lancer l'installeur, tout laisser par défaut, sauf :
   - cocher **Modify password for database user 'root'** → choisir un mot de passe et **le noter**
   - laisser coché **Install as service** (MariaDB démarre avec Windows)
3. Terminer. C'est tout : pas besoin de créer la base à la main, la recipe txAdmin le fait.
4. Dans txAdmin, à l'étape base de données de la recipe : hôte `localhost`, port `3306`,
   utilisateur `root`, le mot de passe noté. (En local seulement ; en prod on utilisera un
   utilisateur dédié, pas root.)
5. Optionnel : HeidiSQL (installé avec MariaDB) pour voir les tables.

## 2. FXServer + txAdmin + Qbox
- [ ] Télécharger les artifacts serveur Windows (runtime.fivem.net, build "recommended")
- [ ] Lancer `FXServer.exe` → txAdmin s'ouvre sur `http://localhost:40120` → code PIN affiché en console
- [ ] Créer le compte admin txAdmin, choisir **Popular Recipes → Qbox**
- [ ] Clé de licence : keymaster.fivem.net (gratuite)
- [ ] Laisser la recipe installer les ressources et la BDD

## 3. Brancher GTA SOON sur la recipe (automatique)
- [ ] Double-cliquer sur `scripts/windows/brancher-gtasoon.bat` et choisir le dossier du serveur
      (celui qui contient `server.cfg` et `resources`). Le script :
      sauvegarde le cfg de la recipe, copie nos ressources et `cfg/`, crée `cfg/secrets.cfg` avec ta
      licence et ta connexion MySQL, met de côté les doublons, et liste ce qui manque.
      Non testé sur une vraie machine Windows : envoie la sortie à [DEV] si une ligne est rouge.
- [ ] Étapes Qbox de `docs/JOBS.md` (jobs en double, maxJobsPerPlayer, item repairkit)
- [ ] Ajouter ton identifiant `license:` en `group.admin` dans `cfg/secrets.cfg`
      (txAdmin → Players → ton joueur → identifiers)

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
Version complète pas à pas : [`FAQ_FIVEM.md`](FAQ_FIVEM.md). Résumé :
FiveM ne marche qu'avec **GTA V Legacy** (pas Enhanced), inclus dans l'achat (entrée séparée Steam/Epic).
1. Fermer FiveM (Gestionnaire des tâches).
2. Supprimer `%localappdata%\FiveM\FiveM.app\CitizenFX.ini` (désinstaller FiveM ne l'efface pas :
   c'est lui qui garde l'ancien chemin). Radical : supprimer tout `%localappdata%\FiveM`.
3. Relancer FiveM et donner le dossier qui contient **`GTA5.exe`**
   (s'il n'y a que `GTA5_Enhanced.exe`, c'est Enhanced, pas Legacy).
4. Toujours bloqué : noter le message exact + plateforme + liste des `.exe` du dossier du jeu.
