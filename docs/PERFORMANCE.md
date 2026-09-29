# Budget de performance

Objectif : serveur fluide à 48 joueurs, **client < 0,10 ms par ressource gs_*** au repos dans `resmon`, et aucune ressource
au-dessus de **0,50 ms** en action (menu, course, braquage).

## Vérifié automatiquement (`tests/check_perf.py`, lancé par les tests et avant chaque envoi)
- toute boucle `while true do` a un `Wait` (sinon le jeu gèle) ;
- une boucle qui tourne à **chaque image** doit être justifiée par un commentaire « par frame » ; aujourd'hui : 4
  (densité PNJ — obligatoire pour GTA —, placement d'objet du builder, animation de la roue, bulles /me) ;
- côté serveur, pas de boucle infinie plus rapide que 250 ms ;
- au plus **12 threads client** et **2 boucles permanentes par image** par ressource.
`python3 tests/check_perf.py -v` affiche le tableau par ressource.

## Règles de conception suivies
- Pas de boucle par frame au repos : les boucles rapides ne tournent que pendant une action (course, examen, quête).
- Marqueurs : un seul fil pour tous (gs_markers), tri par distance toutes les 500 ms.
- Données partagées par `GlobalState` / state bags (pas d'events récurrents).
- Écritures en base regroupées (cumuls en mémoire, écriture toutes les 60 s : économie, réputation, territoires).
- Cayo Perico et les props (plants, roue) ne sont chargés qu'à proximité.

## À mesurer en jeu (test de charge)
1. `resmon 1` dans la console F8, se promener 5 min en ville : noter les 10 ressources les plus lourdes.
2. Même chose pendant une course, un braquage, un rassemblement Vibe.
3. Côté serveur : txAdmin → « Diagnostics » (temps des threads) avec 15 puis 30 joueurs.
4. Toute ressource au-dessus du budget → ticket « perf » avec la capture `resmon`.
