# Appli staff RoadLine (V12.63)

Modérer la ville **sans être en jeu**, depuis une tablette, un téléphone ou un PC. L'appli est servie par le serveur FiveM
lui-même (ressource `gs_admin`) : rien à installer côté staff.

## Adresse et connexion
- Adresse : `https://<adresse https du VPS>/gs_admin/` (GERER-OVH → 21 pour l'adresse https), ou `http://IP:30120/gs_admin/`.
- **L'installer comme une vraie appli** (icône au logo RoadLine, plein écran, sans barre d'adresse) — rien à télécharger
  sur un store, pas de site à part : c'est le VPS qui la sert, à la même adresse https.
  - **PC (Chrome / Edge)** : bouton « 📲 Installer l'appli » sur l'écran de connexion (ou icône d'installation dans la barre
    d'adresse) → elle apparaît dans le menu Démarrer / sur le bureau, et s'ouvre dans sa propre fenêtre.
  - **Android (Chrome)** : même bouton, ou menu ⋮ → **Installer l'application**.
  - **iPhone / iPad (Safari)** : bouton Partager → **Sur l'écran d'accueil**.
  - Il faut l'adresse **https** (GERER-OVH → 21) : en http par l'IP, les navigateurs refusent l'installation.
  - Une mise à jour du serveur met l'appli installée à jour toute seule (rien à réinstaller).
- Connexion : **ton pseudo staff** (il signe tes actions dans le journal : « Web · pseudo ») + **le mot de passe collectif**.
- Le mot de passe n'est envoyé qu'une fois : ensuite un jeton de session (12 h, tiré au hasard par le serveur).
- 5 mauvais mots de passe depuis une même connexion = blocage 15 min ; plus de 30 échecs en 15 min sur tout le serveur =
  connexions suspendues 15 min et alerte au staff. Chaque connexion est notée dans le journal staff (avec l'adresse).
- **https obligatoire** dès que l'adresse https est activée (GERER-OVH → 21) : les connexions en clair par le port 30120 sont
  refusées (sinon, sur un wifi public, le mot de passe pourrait être lu).
- Mot de passe changé ou code retiré = toutes les sessions ouvertes avec l'ancien se ferment.

## Changer le mot de passe collectif (fondateur)
GERER-OVH.bat → **20** → **M** : saisie masquée, envoyée directement à la commande du VPS (ni fichier, ni ligne de commande,
jamais dans le dépôt). Les anciens codes personnels sont **effacés** et le serveur redémarre (1 min). Sur le PC local, on peut aussi écrire
la ligne `set gs_admin_web_password "…"` dans `server-data\cfg\secrets.cfg` (jamais committé).
- 6 caractères au moins (12 conseillés : il donne accès aux bannissements), sans guillemet, `\` ni `;`.
- Les codes personnels (`gs_admin_web`, GERER-OVH → 20 → A / R) restent possibles en plus.

## Ce qu'on y trouve
| Onglet | Contenu |
|---|---|
| Tableau de bord | Joueurs en ville (courbe 24 h), staff en service, tickets, recherchés, isolés / gelés, carte en direct, derniers tickets, journal, annonce à la ville |
| Joueurs | Recherche et filtres (recherchés, isolés, staff, en service) ; fiche complète (métier, session, recherche, gang, argent, isolement, dossier staff) |
| Carte | Tous les joueurs en direct sur la carte de Los Santos (couleur = état) ; clic = fiche ; anneau jaune = auteur d'un ticket ouvert (V12.63) |
| Lives | Jusqu'à 4 écrans de joueurs en même temps (une image / 1,5 s), replays 30 s des tickets ouverts |
| Tickets | Prendre en charge, clôturer, ouvrir la fiche, replay |
| Sanctions | Bannis actifs, recherche, débannir |
| Journal | Toutes les actions du staff (jeu, Discord, appli) depuis le dernier redémarrage |

## Rangs dans l'appli (V12.63)
- **Mot de passe collectif** = rang **modérateur** (2), quel que soit le pseudo tapé (un pseudo ne prouve rien).
- **Code personnel avec un rang** : GERER-OVH → 20 → **A** → pseudo → rang (5 = fondateur, 4 = super-admin, 3 = admin…).
  Le code s'affiche une fois : se connecter avec ce code (le pseudo est celui du code).
- Un rang agit sur les joueurs et sur le staff de **rang inférieur** ; le **fondateur agit sur tout le monde**.
- Rang minimum par action (`Config.Web.actionLevel`) : message, note, soigner, réanimer, réparer, avertir, tickets = 1 ;
  geler, isoler, expulser, téléporter, effacer la recherche = 2 ; bannir, débannir, annonce = 3.
- Changer le mot de passe collectif garde les codes avec rang (efface seulement les anciens codes sans rang).

## Actions sur un joueur
- **Assistance** : soigner, réanimer, réparer le véhicule, effacer la recherche, téléporter (lieu de la liste ou à côté d'un joueur),
  **coincé : dernier endroit sûr** (V12.63 : le jeu retient la dernière position au sol ; à défaut la place de Legion Square,
  `Config.Unstuck` ; retour automatique après 6 s sous la carte ; même bouton dans F10 et F11 → Joueurs).
- **Contrôle** : geler / dégeler, message privé, note staff, isoler (minutes + motif), libérer.
- **Sanctions** : avertir, expulser, bannir (1, 3, 7, 14, 30 jours ou définitif) — motif obligatoire, publié dans #sanctions.
- Garde-fou : aucune sanction ni téléportation depuis l'appli sur un membre du staff, quel que soit son rang (`Config.Web.protectLevel`).
  Les durées (isolement, bannissement) doivent être des nombres entiers.
- Lieux de téléportation : `gs_admin/shared/config.lua` → `Config.Web.places` (déplaçables via F11 → Déplacer un point).

## Technique
- Serveur : `gs_admin/server/web.lua` (API `POST /api`, fichiers de `web/dist`), jetons : `server/crypto.js`.
- Interface : `gs_admin/web/src/staff/` (React, compilée par Vite avec le panneau F10 : `npm run build` dans `gs_admin/web`).
- La carte (`web/src/shared/LiveMap.jsx`) est partagée avec l'onglet **Carte** du panneau F10.
- Les écrans (Lives) viennent de gs_lives (export `Capture`) : la même capture sert à F11, aux replays et à l'appli. Le joueur
  regardé doit avoir screenshot-basic (livré dans `[gtasoon]`, rien à installer).
