# RoadLine RP sur le VPS OVH

Ce guide explique comment passer du PC de développement au serveur officiel sur le VPS OVH, sous Ubuntu ou Debian.
Trois outils font tout le travail, en un double-clic chacun. Ta base de données n'est jamais écrasée sans ta confirmation.

| Quoi | Où | Quand |
|---|---|---|
| `PREPARER-OVH.bat` | PC | Une seule fois (première mise en ligne), ou pour renvoyer toute la base |
| `METTRE-A-JOUR-OVH.bat` | PC | À chaque nouvelle version (la base du VPS n'est jamais touchée) |
| `GERER-OVH.bat` | PC | Au quotidien : état, console, redémarrage, public/privé, sauvegardes, mode, retour arrière |
| `roadline …` | VPS (SSH) | Les mêmes commandes, à la main (pour les habitués) |

## 0. Avant de commencer (5 min)

1. **Espace client OVH** : Bare Metal Cloud → VPS → ton VPS.
   - Réinstalle-le en **Ubuntu 24.04** si ce n'est pas déjà le cas (image sans panneau).
   - Note l'**adresse IP**.
   - L'utilisateur est `ubuntu`. Aucun mot de passe à retenir : la connexion se fait par une clé (voir plus bas).
2. **Licence FiveM** : sur keymaster.fivem.net, crée une clé pour l'IP du VPS (ou réutilise la tienne).
   - Elle est déjà dans ton `secrets.cfg` si tu l'avais mise en local.
3. **Sur le PC** :
   - le serveur local est **fermé** ;
   - MariaDB tourne (la base doit être lisible) ;
   - **METTRE-A-JOUR.bat** a été lancé avec la dernière version.

## 1. Mise en ligne (une fois) : `PREPARER-OVH.bat`

L'outil te demande :
- l'**IP** et l'**utilisateur** du VPS (ces deux infos sont retenues pour les fois suivantes).

Il fait ensuite tout seul :

1. **Sauvegarde de ta base locale** dans `base.sql` (personnages, argent, inventaires, gangs, véhicules…).
2. **Copie de `server-data`**, sans cache ni journaux, dans une archive au format Linux.
3. **Envoi sur le VPS**. La copie locale contient la base et les secrets : elle est effacée du PC juste après.
4. **Installation sur le VPS** (`installer-ovh.sh`) :
   - installe MariaDB et le programme FiveM pour Linux (version recommandée) ;
   - crée la base `gtasoon` avec un **mot de passe aléatoire**. Ce mot de passe n'est jamais affiché ; il est gardé dans `/home/fivem/outils/.env` ;
   - **importe ta base**. Si le VPS contient déjà des personnages, il demande de taper `ECRASER`. Sans cette confirmation, la base du VPS est gardée, et une sauvegarde est faite avant tout import ;
   - ouvre le pare-feu : SSH, `30120` pour le jeu, `40120` pour txAdmin ;
   - crée un service qui **démarre le serveur tout seul** (OneSync activé, rien à configurer) et le relance après un plantage ou un redémarrage du VPS ;
   - programme une sauvegarde de la base toutes les 6 h ;
   - laisse le serveur en **profil privé** (caché de la liste, 16 places pour le backtest) pour que tu puisses tester d'abord.

> **Aucun mot de passe à taper** : au début, l'outil copie la « clé » de ton PC et te dit où la coller chez OVH
> (Réinstaller mon VPS → Ubuntu 24.04 → champ « Clé SSH » → coller → Confirmer). La fenêtre attend toute seule la fin
> de la réinstallation (5 à 10 min), puis enchaîne. Les mises à jour suivantes n'ont plus rien à demander.
>
> (Ancienne méthode, si tu préfères le mot de passe : il ne s'affiche pas quand tu le tapes (ni étoiles, ni chiffres) : c'est normal sous Linux. Tape-le
> (ou colle-le avec un clic droit dans la fenêtre), puis Entrée. Il n'est demandé qu'une fois : l'outil installe ensuite
> une clé de connexion, et les mises à jour ne le redemandent plus.)

**C'est tout : rien à configurer à la fin.** Le serveur est déjà lancé.

> txAdmin (panneau web, code PIN) n'est plus nécessaire. Si tu le veux plus tard : `GERER-OVH.bat` → **Mode txAdmin**
> (puis http://IP-DU-VPS:40120 avec le PIN affiché, « Existing server data » → `/home/fivem/server-data`, OneSync On).
> Pour revenir : `GERER-OVH.bat` → **Mode simple**.

Ensuite, en jeu : **F8** → `connect IP-DU-VPS:30120`.

## 2. Ouvrir au public

Une fois tes tests faits : `GERER-OVH.bat` → **Ouvrir au PUBLIC** (liste FiveM, 48 places, protections prod).
Pour une maintenance : **Repasser en PRIVÉ**. (En SSH : `sudo roadline public` / `sudo roadline prive`.)

Le choix est retenu : les mises à jour ne le changent pas.

> Au-delà de 48 joueurs, il faut un abonnement Cfx.re Element Club (Argentum ou plus) et augmenter `sv_maxclients` dans `cfg/prod.cfg`.

## 3. Mettre à jour (à chaque version) : `METTRE-A-JOUR-OVH.bat`

> **PC = test, VPS = officiel.** METTRE-A-JOUR.bat ne change que le serveur du PC (ta base locale, tes essais). Rien ne part sur le VPS
> tant que tu ne lances pas METTRE-A-JOUR-OVH.bat. Ce qui est envoyé : RoadLine, les autres ressources modifiées depuis le dernier envoi,
> les `cfg`. Jamais la base, ni `secrets.cfg` / `permissions.cfg` (réglages du VPS : option 12 si tu veux les remplacer).

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

Si une mise à jour pose problème : `GERER-OVH.bat` → **Revenir à la version précédente** (10 secondes).

## 4. Au quotidien : `GERER-OVH.bat`

Un menu sur le PC, sans mot de passe (connexion par la clé). Au lancement, il remet à jour la commande `roadline` du VPS
et termine tout seul une installation interrompue.

| N° | Option | Quand |
|---|---|---|
| 1 | État + diagnostic | Version en ligne, profil, service, port 30120, cause en clair si le serveur ne répond pas |
| 2 | Console | Les 60 dernières lignes |
| 3 | Erreurs de scripts | Backtest : erreurs depuis le démarrage, regroupées par ressource |
| 4 / 5 / 6 | Redémarrer / Arrêter / Démarrer | Maintenance |
| 7 / 8 | Public / Privé | Ouvrir (48 places, liste FiveM) ou cacher (16 places, testeurs) |
| 9 / 10 | Sauvegarder / Liste | Sauvegarde immédiate (sinon auto toutes les 6 h, 30 gardées) |
| 11 | Copier la dernière sauvegarde sur le PC | Copie de sécurité hors VPS (`C:\GTASOON\ovh\sauvegardes-vps`) |
| 12 | Envoyer mes réglages du PC | Après CONFIGURER-DISCORD (`secrets.cfg`) ; gardés côté VPS : base, codes du panneau staff, txAdmin, heure du redémarrage |
| 13 | Revenir à la version précédente | Une mise à jour pose problème |
| 14 / 15 | Mode simple / txAdmin | Démarrage direct (défaut) ou panneau txAdmin (port 40120) |
| 16 | Console du VPS | Pour les habitués |
| 17 | Vérifier Discord | Bot connecté ? Un message de test est posté dans chaque salon relié |
| 18 | Copie automatique sur ce PC | Tâche Windows : chaque jour à 12 h, 14 copies gardées dans `C:\GTASOON\ovh\sauvegardes-vps` |
| 19 | Heure du redémarrage quotidien | 06:00 par défaut (heure de Paris), annoncé en jeu ; `off` pour désactiver |
| 20 | Codes du panneau staff | Voir / ajouter / retirer l'accès d'un membre au panneau sur téléphone |
| 21 | Adresse https | Une fois : panneau staff installable comme une appli + carte en direct sur le site |
| 22 | txAdmin : mauvais compte | Mauvais compte Cfx.re lié ? Nouveau code PIN, la configuration du serveur est gardée |

**Tout seul sur le VPS (V11)** :
- **veille** toutes les 2 min : serveur injoignable 4 min → alerte dans le salon staff Discord et relance ; message quand il revient.
  Un arrêt volontaire (option 5) ne déclenche rien ;
- **redémarrage quotidien** à 6 h, annoncé en jeu 15, 5 et 1 min avant ;
- **sauvegardes** de la base toutes les 6 h (30 gardées), heure de Paris.

**txAdmin** (option 15) : l'outil affiche le code PIN et les 3 étapes (compte Cfx.re, « Existing server data » →
`/home/fivem/server-data`, OneSync On). Le bouton « Ouvrir txAdmin » apparaît alors dans le panneau staff mobile.
Retour au démarrage automatique : option 14.

Les mêmes commandes existent en SSH :

```
roadline etat                 version, profil, état, disque, mémoire
sudo roadline diagnostic      pourquoi le serveur ne répond pas · sudo roadline erreurs : erreurs de scripts
sudo roadline mode simple     démarrage direct (défaut) · sudo roadline mode txadmin : panneau web 40120
roadline logs                 dernières lignes de la console (roadline suivre : en direct)
sudo roadline redemarrer      redémarrer le serveur
sudo roadline sauvegarde      sauvegarde immédiate de la base (auto toutes les 6 h, 30 gardées)
sudo roadline sauvegardes     liste des sauvegardes
sudo roadline restaurer FICHIER              toute la base revient à cette heure (serveur arrêté)
sudo roadline restaurer-joueur FICHIER CID   un seul joueur (perso + véhicules) revient à cette heure
sudo roadline programme       mettre à jour le programme FiveM (version recommandée)
```

Les **bannissements** et la modération se font en jeu (menu admin), sur le panneau staff web ou par le bot Discord (section 5).

## 5. Modération depuis le téléphone

Deux façons, à combiner (plus txAdmin si tu l'as activé) :

1. **Panneau staff RoadLine** (une appli sur le téléphone) : joueurs, tickets, geler / dégeler, message, avertir, expulser, annonce, txAdmin.
   - **Une fois** : `GERER-OVH.bat` → **21** (adresse https gratuite, certificat automatique). L'adresse devient
     `https://57-129-170-173.sslip.io/gs_admin/` (l'IP du VPS avec des tirets).
   - **Pour chaque membre** : `GERER-OVH.bat` → **20** → A → son pseudo. Le code s'affiche une seule fois : donne-le-lui en privé.
     Le serveur redémarre (1 min). R → pseudo : retire l'accès.
   - **Installer l'appli** : ouvrir l'adresse dans Chrome (Android : menu ⋮ → « Installer l'application ») ou Safari (iPhone : Partager
     → « Sur l'écran d'accueil »). Icône « RL Staff », plein écran. Marche aussi dans un navigateur classique (PC compris).
   - Sans l'option 21, ça marche aussi en `http://vps-f2365fb1.vps.ovh.net:30120/gs_admin/` (raccourci simple, sans « vraie » appli).
   - Aussi en bas du site : lien « Espace staff ». 5 essais ratés depuis une même adresse la bloquent 15 minutes.
2. **Bot Discord** : `/joueurs`, `/geler`, `/degeler`, `/avertir`, `/expulser`, `/message`, `/annonce`.
   - Réservé aux administrateurs du Discord et au rôle indiqué dans `set gs_discord_staff_role "ID-DU-ROLE"` (secrets.cfg).
   - Réponses visibles par toi seul.

Toutes les actions sont journalisées (« Web · pseudo », « Discord · pseudo ») dans les logs staff.

## 6. Éditer un réglage sur le VPS

Le plus simple : modifie les réglages sur le PC (CONFIGURER-DISCORD.bat, `cfg\secrets.cfg`), puis `GERER-OVH.bat` → **12**.
Sinon, les fichiers à modifier sur le VPS sont `secrets.cfg` (codes, webhooks, jeton du bot) et `permissions.cfg` (staff). Utilise WinSCP ou FileZilla en SFTP, ou `sudo nano /home/fivem/server-data/cfg/secrets.cfg`, puis `GERER-OVH.bat` → **Redémarrer**.

## Dépannage

| Symptôme | Solution |
|---|---|
| « You are required to change your password » | Géré par l'outil : colle le mot de passe du mail OVH quand il le demande (une seule fois) |
| L'envoi est refusé / la fenêtre attend sans fin | Vérifie l'IP et l'utilisateur (`ubuntu`), et que la clé a bien été collée dans « Clé SSH » à la réinstallation |
| « ssh introuvable » | Paramètres Windows → Applications → Fonctionnalités facultatives → **Client OpenSSH** |
| Qbox ne démarre pas, erreur OneSync | `GERER-OVH.bat` → **Mode simple** (OneSync y est toujours activé) |
| On m'a parlé d'un code PIN txAdmin | Inutile en mode simple : `GERER-OVH.bat` → **Mode simple** |
| Le serveur n'apparaît pas dans la liste | Normal en profil privé : `GERER-OVH.bat` → **Ouvrir au PUBLIC** |
| Base vide après l'installation | La base du PC n'a pas pu être lue (MariaDB arrêté). Relance PREPARER-OVH avec MariaDB démarré, puis tape `ECRASER` |
| « Quitting: Ctrl-C pressed » dans la console | Relance `GERER-OVH.bat` : il corrige le service tout seul |
| METTRE-A-JOUR-OVH annonce une ancienne version | Il propose de mettre le PC à jour d'abord : réponds O |
| Une mise à jour casse quelque chose | `GERER-OVH.bat` → **Revenir à la version précédente**, puis **Console** pour voir l'erreur |
