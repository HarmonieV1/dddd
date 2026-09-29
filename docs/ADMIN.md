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
  - Admin : ajouter/retirer contrat, météo, annonce, section Fun
  - Super-admin : donner/retirer argent (plafond 100 000 $), donner item (plafond 100) — **motif obligatoire**, journalisé
  - Fondateur : promouvoir / rétrograder le staff, items sans motif, retirer / poser des items
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
| **Fun** (sur soi, events) : course rapide, super saut, endurance infinie, nage rapide, gravité lunaire, visions nocturne / thermique | Admin |
| **Items** : donner (motif obligatoire) · **Objets du décor** (placer / retirer une poubelle, un banc…) | Super-admin |
| **Items** sans motif, retirer, poser au sol · **Rang staff** d'un joueur (Joueurs → joueur → Rang) | Fondateur (`group.god`) |

**Raccourcis du mode staff** (Ctrl gauche maintenu) : `Ctrl+Y` TP au marqueur · `Ctrl+U` vol libre · `Ctrl+O` noms et ID.
Modifiables : Échap → Paramètres → Raccourcis clavier → FiveM.

Chaque action est revérifiée par le serveur (niveau, mode staff, cible) et journalisée (F10 → Journal, webhook staff).
Vol libre : ZQSD, Espace/Ctrl pour monter/descendre, Shift vite, Alt lent. Spectate : Retour pour arrêter.

## Donner les droits (V5)
- **Fondateur** : `DEVENIR-ADMIN.bat` (te met en `group.god`), ou `add_principal identifier.license:XXXX group.god` dans `cfg/secrets.cfg`.
  Un fondateur ne se crée jamais depuis le jeu.
- **Tout le reste, en jeu** : menu staff (F11) → Joueurs → le joueur → **Rang staff (fondateur)** → Helper / Modérateur / Admin /
  Super-admin / Joueur. Effet immédiat, enregistré en base (`gs_admin_ranks`), réappliqué à chaque démarrage.
  Seul le fondateur voit cette ligne ; super-admin et admin ne peuvent promouvoir personne.
- Hiérarchie : god (fondateur) > superadmin > admin > mod > helper (voir `cfg/permissions.cfg`).
- Un rang écrit à la main dans `secrets.cfg` ne peut pas être retiré depuis le jeu : préfère le menu.

## Tests
`tests/test_gs_admin.lua` (50 tests) : niveaux, anti-abus, motifs, plafonds, tickets, isolement persistant, publication des sanctions.

## Mapping en jeu : gs_builder (`/builder` ou menu staff → Objets du décor, super-admin et fondateur)
Placer n'importe quel objet du jeu, le déplacer, le tourner, le dupliquer, le supprimer. Sauvegardé en BDD, visible par tous.
- **Placer** : nom du modèle (ex. `prop_bench_01a`) ou favoris → l'objet suit ton viseur.
- **Contrôles** : `TAB` mode viser/précis · flèches déplacer · `PgUp/PgDn` hauteur · `Q/E` tourner · molette rotation fine ·
  `X` remettre droit · `G` poser au sol · `Shift` rapide · `Ctrl` précis · `Entrée` valider · `Retour` annuler.
- **Modifier** : « Modifier l'objet visé » ou « Objets à proximité » → déplacer / dupliquer / supprimer.
- **Retirer un objet de la map d'origine** (poubelle, banc, barrière…) : vise-le → « Retirer l'objet de la map visé » ; il
  disparaît pour tous. « Objets de la map retirés » les remet (500 max).
- **Planque de gang** : « Placer une planque de gang ici » (le coffre du gang est créé à ta position).
- Perf : chaque joueur ne crée localement que les objets à moins de 150 m (aucune entité réseau), 3000 objets max.
- Sécurité : tout est revalidé serveur (permission, nom de modèle, position, distance < 60 m), chaque action loggée.
- Noms des objets : bibliothèque en ligne « GTA V prop list » (ex. gta-objects.xyz) ou favoris dans `gs_builder/shared/config.lua`.
