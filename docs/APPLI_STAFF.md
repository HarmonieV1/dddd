# Appli staff RoadLine (V12.63)

Modérer la ville **sans être en jeu**, depuis une tablette, un téléphone ou un PC. L'appli est servie par le serveur FiveM
lui-même (ressource `gs_admin`) : rien à installer côté staff.

## Adresse et connexion
- Adresse : `https://<adresse https du VPS>/gs_admin/` (GERER-OVH → 21 pour l'adresse https), ou `http://IP:30120/gs_admin/`.
- Sur tablette / téléphone : menu du navigateur → **Ajouter à l'écran d'accueil** : elle s'ouvre comme une appli.
- Connexion : **ton pseudo staff** (il signe tes actions dans le journal : « Web · pseudo ») + **le mot de passe collectif**.
- Le mot de passe n'est envoyé qu'une fois : ensuite un jeton de session (12 h, tiré au hasard par le serveur).
- 5 mauvais mots de passe depuis une même connexion = blocage 15 min. Chaque connexion est notée dans le journal staff.

## Changer le mot de passe collectif (fondateur)
GERER-OVH.bat → **20** → **M** : saisie masquée, envoyée au VPS dans un fichier (jamais sur une ligne de commande, jamais dans
le dépôt). Les anciens codes personnels sont **effacés** et le serveur redémarre (1 min). Sur le PC local, on peut aussi écrire
la ligne `set gs_admin_web_password "…"` dans `server-data\cfg\secrets.cfg` (jamais committé).
- 6 caractères au moins, sans guillemet. Un mot de passe plus long est plus sûr : il donne accès aux bannissements.
- Les codes personnels (`gs_admin_web`, GERER-OVH → 20 → A / R) restent possibles en plus.

## Ce qu'on y trouve
| Onglet | Contenu |
|---|---|
| Tableau de bord | Joueurs en ville (courbe 24 h), staff en service, tickets, recherchés, isolés / gelés, carte en direct, derniers tickets, journal, annonce à la ville |
| Joueurs | Recherche et filtres (recherchés, isolés, staff, en service) ; fiche complète (métier, session, recherche, gang, argent, isolement, dossier staff) |
| Carte | Tous les joueurs en direct sur la carte de Los Santos (couleur = état) ; clic = fiche |
| Lives | Jusqu'à 4 écrans de joueurs en même temps (une image / 1,5 s), replays 30 s des tickets ouverts |
| Tickets | Prendre en charge, clôturer, ouvrir la fiche, replay |
| Sanctions | Bannis actifs, recherche, débannir |
| Journal | Toutes les actions du staff (jeu, Discord, appli) depuis le dernier redémarrage |

## Actions sur un joueur
- **Assistance** : soigner, réanimer, réparer le véhicule, effacer la recherche, téléporter (lieu de la liste ou à côté d'un joueur).
- **Contrôle** : geler / dégeler, message privé, note staff, isoler (minutes + motif), libérer.
- **Sanctions** : avertir, expulser, bannir (1, 3, 7, 14, 30 jours ou définitif) — motif obligatoire, publié dans #sanctions.
- Garde-fou : aucune sanction depuis l'appli sur un staff de rang **super-admin** ou plus (`Config.Web.protectLevel`).
- Lieux de téléportation : `gs_admin/shared/config.lua` → `Config.Web.places` (déplaçables via F11 → Déplacer un point).

## Technique
- Serveur : `gs_admin/server/web.lua` (API `POST /api`, fichiers de `web/dist`), jetons : `server/crypto.js`.
- Interface : `gs_admin/web/src/staff/` (React, compilée par Vite avec le panneau F10 : `npm run build` dans `gs_admin/web`).
- La carte (`web/src/shared/LiveMap.jsx`) est partagée avec l'onglet **Carte** du panneau F10.
