# FAQ — FiveM ne se lance pas (« We could not detect a valid GTA V Legacy installation »)

FiveM ne fonctionne **qu'avec GTA V Legacy**. Enhanced est inclus dans le même achat, mais FiveM ne sait pas l'utiliser.
Fais les étapes **dans l'ordre**, sans en sauter. À chaque étape, relance FiveM pour tester.

---

## Étape 1 — Vérifier QUELLE version est vraiment installée (2 min)
C'est la cause n°1 : la version qui « reste » est souvent Enhanced, pas Legacy.

1. Ouvre le dossier du jeu :
   - **Steam** : Bibliothèque → clic droit sur le jeu → *Gérer* → *Parcourir les fichiers locaux*
   - **Epic** : Bibliothèque → `…` sur le jeu → *Gérer* → icône dossier
   - **Rockstar Launcher** : Paramètres → *Mes jeux installés* → GTA V → *Ouvrir le dossier*
2. Regarde les `.exe` du dossier :

| Tu vois | C'est | FiveM marche ? |
|---|---|---|
| `GTA5.exe` + `PlayGTAV.exe` | **Legacy** | ✅ oui |
| `GTA5_Enhanced.exe` | Enhanced | ❌ non → installer Legacy (étape 2) |

3. Note le chemin complet du dossier (ex : `C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V`).

## Étape 2 — Installer Legacy si besoin
- **Steam** : dans la bibliothèque, cherche **« Grand Theft Auto V Legacy »** (entrée séparée d'Enhanced). Installer.
- **Epic** : sur la page du jeu, choisir l'édition **Legacy** à l'installation.
- **Rockstar Launcher** : GTA V → choisir **Legacy**.
- Lance **une fois** GTA V Legacy normalement jusqu'au menu (ça finit l'installation et le Social Club), puis ferme-le.

## Étape 3 — Faire oublier l'ancien chemin à FiveM (cause n°2)
Désinstaller FiveM **ne supprime pas** ses réglages : il garde le chemin d'Enhanced.
1. Ferme FiveM **et** vérifie dans le Gestionnaire des tâches (Ctrl+Maj+Échap) qu'aucun `FiveM` ne tourne.
2. Touche Windows + R → colle `%localappdata%\FiveM\FiveM.app` → Entrée.
3. Supprime le fichier **`CitizenFX.ini`** (c'est lui qui contient `IVPath=…`, le chemin du jeu).
4. Relance FiveM → il demande le dossier du jeu → donne **le dossier noté à l'étape 1** (celui avec `GTA5.exe`).

## Étape 4 — Réparer les fichiers du jeu (cause n°3 : installation incomplète)
- **Steam** : clic droit → *Propriétés* → *Fichiers installés* → *Vérifier l'intégrité des fichiers du jeu*
- **Epic** : `…` → *Gérer* → *Vérifier*
- **Rockstar** : Paramètres → GTA V → *Vérifier l'intégrité*
Puis refaire l'étape 3.

## Étape 5 — Réinstallation propre de FiveM (si toujours bloqué)
1. Désinstaller FiveM.
2. Supprimer **tout** le dossier `%localappdata%\FiveM`.
3. Retélécharger FiveM depuis **fivem.net** uniquement.
4. Le lancer en tant qu'administrateur la première fois, donner le dossier Legacy.

## Étape 6 — Cas particuliers
- **Jeu sur un disque externe / réseau** ou dans un dossier synchronisé OneDrive : déplacer le jeu sur un disque interne.
- **Antivirus** qui bloque FiveM : ajouter `%localappdata%\FiveM` en exception.
- **Deux versions installées en même temps** : ça marche, mais il faut bien donner le dossier Legacy à l'étape 3.

## Toujours bloqué ? Envoie ces 4 infos à [DEV]
1. Le **message d'erreur exact** (capture d'écran idéale)
2. La plateforme : Steam, Epic ou Rockstar
3. La **liste des `.exe`** du dossier du jeu (étape 1)
4. Le contenu de `CitizenFX.ini` s'il existe encore (ligne `IVPath=`)

Pendant ce temps, rien n'empêche d'avancer côté serveur : FXServer, txAdmin, MariaDB et nos ressources
tournent **sans** GTA installé (docs/INSTALL.md). Le client ne sert qu'à se connecter pour tester.
