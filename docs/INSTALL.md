# Installation du serveur de dev (local, Windows)

[CONFIG] Checklist Phase 0. Rien n'est exposé sur Internet : on joue en `localhost`.
Les écrans et menus exacts de txAdmin/Qbox évoluent : en cas de doute, docs.qbox.re et docs.fivem.net font foi.

## 0. Liens officiels (ne télécharger que là)
| Quoi | Lien |
|---|---|
| **MariaDB** (recommandé) | https://mariadb.org/download/ → version **LTS**, Windows, x86_64, **MSI** |
| Alternative : XAMPP (MariaDB + panneau, local uniquement) | https://www.apachefriends.org/ |
| Alternative : MySQL 8 | https://dev.mysql.com/downloads/installer/ |
| HeidiSQL (voir la base, souvent installé avec MariaDB) | https://www.heidisql.com/download.php |
| Serveur FiveM (artifacts Windows, prendre « Latest Recommended ») | https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/ |
| Clé de licence serveur (gratuite) | https://portal.cfx.re (anciennement keymaster.fivem.net) |
| Doc Qbox (recipe, ressources) | https://docs.qbox.re |
| Doc FiveM / txAdmin | https://docs.fivem.net |
**Un seul** serveur de BDD à la fois (MariaDB OU XAMPP OU MySQL) : ils utilisent tous le port 3306.

## Ce qu'il faut pour tester concrètement
1. MariaDB installé (ci-dessous) · 2. artifacts FXServer · 3. clé de licence · 4. recipe Qbox dans txAdmin ·
5. `brancher-gtasoon.bat` · 6. te donner le groupe admin · 7. te connecter avec FiveM (F8 → `connect localhost`).
**Tester à 2** (duo, embauche, factures) : ton pote doit pouvoir joindre ton PC. Le plus simple et sans ouvrir de port :
un VPN privé gratuit type **Tailscale** (vous l'installez tous les deux, il se connecte à ton IP Tailscale).
Sinon : ouvrir le port 30120 TCP+UDP sur ta box (moins sûr).

## Premier lancement en 6 étapes (version simple)
1. **txAdmin n'est pas un logiciel à part** : il est inclus dans le serveur FiveM. Télécharge les artifacts
   (lien ci-dessus, fichier `server.7z` du build « Latest Recommended »), extrais-le dans `C:\FXServer\server`.
2. Double-clic sur `C:\FXServer\server\FXServer.exe` : une fenêtre noire s'ouvre et ton navigateur affiche
   **txAdmin** (`http://localhost:40120`). Un **code PIN** s'affiche dans la fenêtre noire : entre-le.
3. Connecte ton compte Cfx.re, choisis un mot de passe admin, puis **Popular Recipes → Qbox**.
   Base de données : hôte `localhost`, utilisateur `root`, le mot de passe MariaDB noté.
4. Quand la recipe a fini : lance `scripts/windows/brancher-gtasoon.bat` et choisis le dossier du serveur créé par txAdmin
   (celui qui contient `server.cfg`, souvent dans `C:\FXServer\txData\...`).
5. Dans txAdmin : bouton **Start** (ou Restart). Laisse la fenêtre noire ouverte.
6. **Se connecter** : lance FiveM, puis appuie sur **F8** dans le menu principal de FiveM : une console s'ouvre en haut,
   tape `connect localhost` et Entrée. (Alternative sans F8 : onglet « Localhost / Direct connect » du menu FiveM, adresse `localhost`.)

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
- [ ] Étapes Qbox de `docs/JOBS.md` (jobs en double, maxJobsPerPlayer)
- [ ] **Items** : copier le contenu de `server/ox_items_gtasoon.lua` dans `resources/[ox]/ox_inventory/data/items.lua`
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
