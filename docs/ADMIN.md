# Administration : txAdmin + gs_admin

| Outil | Pour quoi | Accès |
|---|---|---|
| **txAdmin** (web, `http://localhost:40120`) | restarts, console, backups, **bans** (base anti-contournement), whitelist, stats | comptes txAdmin |
| **Menu txAdmin en jeu** (`/tx`) | noclip, god, TP, spectate, freeze, véhicules, warn/ban, IDs au-dessus des têtes | permissions txAdmin |
| **gs_admin** (F10 / `/admin`) | tout ce qui est propre à notre RP : tickets, fiches, isolement, économie, contrats, météo, annonces | ACE `gs.admin.*` |

## gs_admin
- **Tickets** : les joueurs font `/report <message>` (1 ticket ouvert max, cooldown 2 min) ; le staff **en service** (`/staff` ou bouton) est notifié avec un son ; prendre, aller au joueur, ouvrir sa fiche, clôturer.
- **Fiche joueur** branchée sur tous nos systèmes : job actif + contrats, recherche (étoiles), duo, pseudo Néon, isolement, ping, durée de session ; + licence et historique staff (modo) ; + argent (admin).
- **Actions** (le serveur revérifie tout, motif obligatoire pour les sanctions) :
  - Helper : tickets, aller au joueur, fiche
  - Modo : amener, soigner, réanimer, réparer véhicule, figer, effacer la recherche, note staff, **avertir, isoler, expulser**
  - Admin : donner/retirer argent (plafond 100 000 $), donner item (plafond 100), ajouter/retirer contrat, météo, annonce
- **Anti-abus staff** : impossible de sanctionner un staff de niveau égal ou supérieur ; toute tentative sans le niveau est loggée.
- **Isolement (jail admin)** : cour de Bolingbroke, compte à rebours à l'écran, retour automatique en cellule en cas de fuite, **persiste à la déconnexion** (par licence).
- **Transparence** : avertissements, isolements, expulsions **et bans/warns/kicks txAdmin** publiés sur un salon public (`gs_webhook_sanctions`), staff anonyme.
- **Journal** : toutes les actions staff en BDD (`gs_admin_log`) + webhook staff + onglet Journal (modo+).

## Menu staff rapide (F11) — V2

Menu **cliquable à la souris** (chaque ligne porte sa propre action, sous-menus avec flèche, retour en haut à gauche). Les pouvoirs ne marchent **qu'en mode staff** (1re ligne),
et le couper coupe tout : vol, invisibilité, invincibilité, animal, spectate.

| Fonction | Niveau |
|---|---|
| Mode staff, noms et ID au-dessus des joueurs, aller à un joueur, copier ses coordonnées | Helper |
| Vol libre, invisible, invincible, se transformer en animal, TP au marqueur, spectate, amener, soigner, figer, supprimer un véhicule | Modérateur |
| Se mettre (ou mettre un joueur) un **métier et un grade**, dans un **gang**, faire apparaître un véhicule | Admin |
| **Points de métier** : déplacer service / coffre / armurerie / direction / garage à sa position (bâtiments fermés, futurs MLO) | Admin |
| **Items** : donner, retirer, poser au sol (sans motif) | Fondateur (`group.god`) |

Chaque action est revérifiée par le serveur (niveau, mode staff, cible) et journalisée (F10 → Journal, webhook staff).
Vol libre : ZQSD, Espace/Ctrl pour monter/descendre, Shift vite, Alt lent. Spectate : Retour pour arrêter.

## Donner les droits
Dans `cfg/secrets.cfg` : `add_principal identifier.license:XXXX group.helper` (ou `group.mod`, `group.admin`, `group.god` = fondateur).
Le plus simple pour toi : `DEVENIR-ADMIN.bat` (te met en `group.god`).
Hiérarchie : god > admin > mod > helper (chaque groupe hérite du précédent, voir `cfg/permissions.cfg`).

## Tests
`tests/test_gs_admin.lua` (50 tests) : niveaux, anti-abus, motifs, plafonds, tickets, isolement persistant, publication des sanctions.

## Mapping en jeu : gs_builder (`/builder`, groupe admin)
Placer n'importe quel objet du jeu, le déplacer, le tourner, le dupliquer, le supprimer. Sauvegardé en BDD, visible par tous.
- **Placer** : nom du modèle (ex. `prop_bench_01a`) ou favoris → l'objet suit ton viseur.
- **Contrôles** : `TAB` mode viser/précis · flèches déplacer · `PgUp/PgDn` hauteur · `Q/E` tourner · molette rotation fine ·
  `X` remettre droit · `G` poser au sol · `Shift` rapide · `Ctrl` précis · `Entrée` valider · `Retour` annuler.
- **Modifier** : « Modifier l'objet visé » ou « Objets à proximité » → déplacer / dupliquer / supprimer.
- **Planque de gang** : « Placer une planque de gang ici » (le coffre du gang est créé à ta position).
- Perf : chaque joueur ne crée localement que les objets à moins de 150 m (aucune entité réseau), 3000 objets max.
- Sécurité : tout est revalidé serveur (permission, nom de modèle, position, distance < 60 m), chaque action loggée.
- Noms des objets : bibliothèque en ligne « GTA V prop list » (ex. gta-objects.xyz) ou favoris dans `gs_builder/shared/config.lua`.
