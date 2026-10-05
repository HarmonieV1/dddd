# RoadLine RP sur le VPS OVH

Ce guide explique comment passer du PC de développement au serveur officiel sur le VPS OVH, sous Ubuntu ou Debian.
Deux outils font tout le travail, en un double-clic chacun. Ta base de données n'est jamais écrasée sans ta confirmation.

| Quoi | Où | Quand |
|---|---|---|
| `PREPARER-OVH.bat` | PC | Une seule fois (première mise en ligne), ou pour renvoyer toute la base |
| `METTRE-A-JOUR-OVH.bat` | PC | À chaque nouvelle version (la base du VPS n'est jamais touchée) |
| `roadline …` | VPS (SSH) | Gestion au quotidien : état, logs, redémarrage, public/privé, sauvegardes, retour arrière |

## 0. Avant de commencer (5 min)

1. **Espace client OVH** : Bare Metal Cloud → VPS → ton VPS.
   - Réinstalle-le en **Ubuntu 24.04** si ce n'est pas déjà le cas (image sans panneau).
   - Note l'**adresse IP**.
   - L'utilisateur est `ubuntu`, et son mot de passe arrive par mail (ou le premier mot de passe défini).
2. **Licence FiveM** : sur keymaster.fivem.net, crée une clé pour l'IP du VPS (ou réutilise la tienne).
   - Elle est déjà dans ton `secrets.cfg` si tu l'avais mise en local.
3. **Sur le PC** :
   - le serveur local est **fermé** ;
   - MariaDB tourne (la base doit être lisible) ;
   - **METTRE-A-JOUR.bat** a été lancé avec la dernière version.

## 1. Mise en ligne (une fois) : `PREPARER-OVH.bat`

L'outil te demande :
- l'**IP** et l'**utilisateur** du VPS (ces deux infos sont retenues pour les fois suivantes) ;
- le **mot de passe du VPS** au moment de l'envoi. Il est demandé par SSH : Windows ne le garde pas.

Il fait ensuite tout seul :

1. **Sauvegarde de ta base locale** dans `base.sql` (personnages, argent, inventaires, gangs, véhicules…).
2. **Copie de `server-data`**, sans cache ni journaux, dans une archive au format Linux.
3. **Envoi sur le VPS**. La copie locale contient la base et les secrets : elle est effacée du PC juste après.
4. **Installation sur le VPS** (`installer-ovh.sh`) :
   - installe MariaDB, le programme FiveM pour Linux (version recommandée) et txAdmin ;
   - crée la base `gtasoon` avec un **mot de passe aléatoire**. Ce mot de passe n'est jamais affiché ; il est gardé dans `/home/fivem/outils/.env` ;
   - **importe ta base**. Si le VPS contient déjà des personnages, il demande de taper `ECRASER`. Sans cette confirmation, la base du VPS est gardée, et une sauvegarde est faite avant tout import ;
   - ouvre le pare-feu : SSH, `30120` pour le jeu, `40120` pour txAdmin ;
   - crée un service qui redémarre tout seul après un plantage ou un redémarrage du VPS ;
   - programme une sauvegarde de la base toutes les 6 h ;
   - laisse le serveur en **profil privé** (caché de la liste, 8 places) pour que tu puisses tester d'abord.

> **Le mot de passe ne s'affiche pas quand tu le tapes** (ni étoiles, ni chiffres) : c'est normal sous Linux. Tape-le
> (ou colle-le avec un clic droit dans la fenêtre), puis Entrée. Il n'est demandé qu'une fois : l'outil installe ensuite
> une clé de connexion, et les mises à jour ne le redemandent plus.

**À la fin, 3 étapes à faire à la main dans txAdmin** (le PIN est un code à 4 chiffres qui prouve que c'est bien toi
qui installes ; il s'affiche à la fin de PREPARER-OVH, ou en SSH avec `roadline pin`) :
1. Ouvre `http://IP-DU-VPS:40120` et entre le **code PIN** affiché. Crée ton compte admin, lié à ton compte Cfx.re.
2. Choisis **« Existing server data »**, avec le dossier `/home/fivem/server-data` et le fichier `server.cfg`.
3. Va dans **Settings → FXServer → OneSync : On**, puis **Save** et **Start**.

Ensuite, en jeu : **F8** → `connect IP-DU-VPS:30120`.

## 2. Ouvrir au public

Une fois tes tests faits sur le VPS, connecte-toi en SSH (`ssh ubuntu@IP`) :

```
sudo roadline public     # liste FiveM, 48 places, protections du profil prod
sudo roadline prive      # repasser en privé (maintenance, tests)
```

Le choix est retenu : les mises à jour ne le changent pas.

> Au-delà de 48 joueurs, il faut un abonnement Cfx.re Element Club (Argentum ou plus) et augmenter `sv_maxclients` dans `cfg/prod.cfg`.

## 3. Mettre à jour (à chaque version) : `METTRE-A-JOUR-OVH.bat`

1. Sur le PC : **METTRE-A-JOUR.bat** avec le nouveau zip, puis un test rapide en local.
2. **METTRE-A-JOUR-OVH.bat**.

L'outil envoie :
- tout RoadLine (`[gtasoon]`) ;
- les fichiers des autres ressources modifiés depuis le dernier envoi (réglages Qbox, nouveaux mods importés) ;
- les fichiers `cfg`.

Sur le VPS, il :
- **sauvegarde la base** ;
- arrête le serveur, installe la mise à jour et redémarre (environ 30 s de coupure) ;
- garde les **3 versions précédentes**.

**Jamais envoyés** : `secrets.cfg` et `permissions.cfg` (le staff et les clés du VPS restent ceux du VPS), ni la base.

Si une mise à jour pose problème : `sudo roadline retour` remet la version d'avant en 10 secondes.

## 4. Au quotidien (SSH)

```
roadline etat                 état, disque, mémoire
roadline logs                 dernières lignes de la console (roadline suivre : en direct)
sudo roadline redemarrer      redémarrer le serveur
sudo roadline sauvegarde      sauvegarde immédiate de la base (auto toutes les 6 h, 30 gardées)
sudo roadline sauvegardes     liste des sauvegardes
sudo roadline restaurer FICHIER              toute la base revient à cette heure (serveur arrêté)
sudo roadline restaurer-joueur FICHIER CID   un seul joueur (perso + véhicules) revient à cette heure
sudo roadline programme       mettre à jour le programme FiveM (version recommandée)
```

Le **redémarrage programmé** (par exemple 6 h et 18 h), les **bannissements** et la **console à distance** se gèrent dans **txAdmin**. Il marche aussi sur téléphone.

## 5. Modération depuis le téléphone

Trois façons, à combiner :

1. **txAdmin** (`http://IP:40120`) : bannir, expulser, avertir, console, redémarrages. C'est le plus complet.
2. **Panneau staff RoadLine** (`http://IP:30120/gs_admin/`) : joueurs en ville, geler/dégeler, message, avertir, expulser, annonce.
   - Sur le téléphone : Partager → « Sur l'écran d'accueil » pour l'utiliser comme une appli.
   - Les codes se mettent dans `cfg/secrets.cfg` du VPS, avec un code par membre du staff (12 caractères minimum) :
     `set gs_admin_web "Alpha:un-code-tres-long,Modo2:un-autre-code-long"`
   - 5 essais ratés depuis une même adresse la bloquent 15 minutes.
3. **Bot Discord** : `/joueurs`, `/geler`, `/degeler`, `/avertir`, `/expulser`, `/message`, `/annonce`.
   - Réservé aux administrateurs du Discord et au rôle indiqué dans `set gs_discord_staff_role "ID-DU-ROLE"` (secrets.cfg).
   - Réponses visibles par toi seul.

Toutes les actions sont journalisées (« Web · pseudo », « Discord · pseudo ») dans les logs staff.

## 6. Éditer un réglage sur le VPS

Les fichiers à modifier sur le VPS sont `secrets.cfg` (codes, webhooks, jeton du bot) et `permissions.cfg` (staff). Utilise WinSCP ou FileZilla en SFTP, ou `sudo nano /home/fivem/server-data/cfg/secrets.cfg`, puis `sudo roadline redemarrer`.

## Dépannage

| Symptôme | Solution |
|---|---|
| L'envoi est refusé | Vérifie l'IP, l'utilisateur (`ubuntu` ou `debian`) et le mot de passe du VPS. Teste à la main : `ssh ubuntu@IP` |
| « ssh introuvable » | Paramètres Windows → Applications → Fonctionnalités facultatives → **Client OpenSSH** |
| Qbox ne démarre pas, erreur OneSync | txAdmin → Settings → FXServer → **OneSync : On** |
| Le serveur n'apparaît pas dans la liste | Normal en profil privé : `sudo roadline public` |
| Base vide après l'installation | La base du PC n'a pas pu être lue (MariaDB arrêté). Relance PREPARER-OVH avec MariaDB démarré, puis tape `ECRASER` |
| Une mise à jour casse quelque chose | `sudo roadline retour`, puis `roadline logs` pour voir l'erreur |
