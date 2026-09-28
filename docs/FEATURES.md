# Features signature (Phase 2)

Toutes : validées côté serveur, rate-limitées, loggées, testées (`./tests/run.sh`), 0 boucle client au repos.
Réglages dans `shared/config.lua` de chaque ressource ([CONFIG]).

## gs_wanted — recherche intelligente
Un crime n'existe pour la police **que s'il est signalé**.
- **Chance de signalement** = base du crime + 12 %/témoin (PNJ vivants et joueurs dans 40 m),
  × heure (nuit ×0,6), × météo (brouillard ×0,6, orage ×0,7), × blackout ×0,6, × silencieux ×0,3,
  × notoriété (un visage connu se fait reconnaître). Un policier en service à 60 m = signalement certain.
- **Précision** : zone floue de ±250 m (aucun témoin, nuit) à ±20 m (foule, plein jour), plaque partielle
  (`GSO****`), délai d'appel de 40 s à 5 s.
- **Chaleur** (0-100) : étoiles néon affichées au suspect seulement quand il est signalé ; redescend si on se fait oublier.
- **Police** : alerte + zone sur la carte (90 s), `/dispatch` = 20 derniers signalements avec GPS.
- **Détection** : tirs et car-jacking (client, revérifiés serveur : arme réellement en main, rate-limit),
  explosions (serveur, invisible au client), + `exports.gs_wanted:ReportCrime(src, 'robbery', coords)` pour les futurs scripts.
- Stand de tir = zone sûre. Staff : `/effacerrecherche <id>`.

## gs_economy — économie dynamique
- Chaque achat fait monter le prix (demande), chaque revente le fait baisser (offre) ; retour progressif à l'équilibre.
- Bornes min/max par produit, prix affichés avec tendance ▲ / ▼.
- **Événements** : canicule → eau +60 %, tempête → kits de réparation +50 %…
- **Anti-arbitrage** : revente toujours strictement sous le prix d'achat (testé sur toutes les pressions).
- Supérettes, quincaillerie, ferrailleurs (ferraille, cuivre). Items absents d'ox_inventory désactivés au démarrage.
- API : `GetBuyPrice`, `GetSellPrice`, `RecordBuy`, `RecordSell` pour brancher d'autres commerces. Staff : `/marche`.

## gs_duo — duo criminel lié
- Duo formé avec consentement, persistant, un seul par personnage, 1 h de délai après une rupture.
- **Partenaire visible sur la carte** partout (position envoyée par le serveur, seulement au partenaire).
- **Contrats à deux** (F7 / `/duo`) : récupérer puis livrer une marchandise ; les **deux** doivent être sur chaque
  étape, anti-TP, le vol est signalé via gs_wanted (témoins, heure, météo).
- **Lien** : XP (contrats + temps passé ensemble) → 5 niveaux (Complices → Légendes) : paie +30 %,
  chaleur transmise au complice proche 50 % → 15 %.
- Nom de duo personnalisable (nettoyé).

## Liens entre features
`gs_weather` → visibilité de `gs_wanted` + prix de `gs_economy` ;
`gs_duo` → crimes vers `gs_wanted`, chaleur partagée ; `gs_jobs` → police en service pour le dispatch.

## Impact / risques / rollback
- Tables : `gs_economy`, `gs_duos` (créées au démarrage). gs_wanted : mémoire uniquement.
- Risques : coords et noms d'items à caler en jeu ; équilibrage des prix/chances à ajuster après la bêta.
- Rollback : retirer l'`ensure` concerné (gs_duo dépend de gs_wanted : les retirer dans l'ordre inverse).
