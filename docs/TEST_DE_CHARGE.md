# Test de charge RoadLine (V12.57)

But : savoir **avant l'ouverture du 20/10** si le serveur tient à plusieurs, et repérer ce qui le ralentit.

## Ce qu'il faut
- Le serveur du VPS en marche (profil privé ou public).
- Le plus de joueurs possible en même temps (bêta-testeurs, staff, amis) : 10 minimum, 20 à 30 idéal.
- Un membre du staff (admin) en jeu ou la console du VPS.

## Déroulé (environ 45 min)
1. **Avant** : `roadline etat` sur le VPS (mémoire, disque). Noter le chiffre.
2. En jeu (admin) ou en console : **`/perfserveur`**. La mesure démarre : une ligne par minute est écrite dans
   `resources/[gtasoon]/gs_vie/perf-serveur.log` (retard moyen de la boucle du serveur, 95 % des mesures sous X ms,
   pire retard, nombre d'accrocs de plus de 100 ms, nombre de joueurs).
3. **Scénario** (tout le monde en même temps, 10 min chacun) :
   - arrivée en bus + création de personnage pour 3-4 nouveaux ;
   - poursuite police (2 policiers, 3 voleurs) avec coups de feu ;
   - braquage de supérette + appel EMS ;
   - course de rue à 6 voitures ;
   - regroupement de 15 personnes au même endroit (mairie, Weazel) avec voix ;
   - fouille de poubelles, distributeurs, magasin de masques, porter quelqu'un.
4. **`/perfserveur stop`** : le bilan s'affiche (et à la fin du fichier).
5. **Après** : `roadline erreurs` (erreurs de scripts par ressource) et `roadline etat`.

## Lire le résultat
| Retard moyen | Pire retard | Verdict |
|---|---|---|
| < 5 ms | < 150 ms | Très bon : on peut ouvrir. |
| 5-20 ms | < 400 ms | Correct : regarder les minutes où ça monte (quel scénario ?). |
| > 20 ms ou accrocs fréquents | > 1 s | À corriger avant l'ouverture : envoyer le fichier perf-serveur.log + `roadline erreurs`. |

Côté joueurs : F8 → `resmon 1` montre les ressources qui coûtent le plus sur leur PC (au-dessus de 1 ms = à signaler).

## Après le test
Envoyer à Claude : `perf-serveur.log`, la sortie de `roadline erreurs`, et ce que les joueurs ont ressenti (lag, voix
coupée, voitures qui sautent). On corrige ce qui est le plus lent en premier.
