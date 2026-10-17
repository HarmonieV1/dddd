# Point général avant l'ouverture (17/10/2026, V12.65)

> Ouverture prévue : **lundi 20/10/2026 à 21 h**. Bilan fait à partir du code, de la config et des scripts du VPS
> (rien n'a été vérifié en jeu par cette session). Pas de features ici : seulement ce qui manque, ce qui est à corriger
> ou à optimiser, et ce qui est prêt.

## Où on en est, en une phrase
La base est solide : 76 ressources maison, 4 194 tests verts, aucun secret dans le dépôt, tous les échanges joueur → serveur
protégés (limite de fréquence ou contrôle), SQL sans injection, tout en français, aucune vraie marque. Ce qui reste est surtout
**de l'exploitation** (passer en public, sauvegardes, test de charge, positions à caler) et **quelques failles de triche
précises** faciles à fermer.

## 🔴 À faire avant le 20/10 (bloquant ou risqué)
| # | Quoi | Pourquoi | Qui |
|---|---|---|---|
| 1 | **Passer le serveur en public** le jour J (`roadline public` ou GERER-OVH) | Le VPS tourne en profil privé (`exec cfg/dev.cfg`, caché de la liste FiveM, `mysql_ui` actif) | Toi |
| 2 | **Code cfx.re → site** (`cfxCode` dans `docs/site/index.html`) puis PUBLIER-SITE | Sans lui, le bouton « Rejoindre » du site retombe sur l'IP | Toi (code) + moi (site) |
| 3 | **48 places maximum** (`sv_maxclients 48`) | C'est le plafond gratuit OneSync. Au-delà : abonnement Cfx, puis changer la ligne | Toi (décision) |
| 4 | **Sauvegardes** : tester une restauration complète une fois ; activer la copie vers le PC (tâche planifiée GERER-OVH) ; ajouter la mémoire interne FiveM (KVP) aux sauvegardes | La base est sauvegardée toutes les 6 h mais **seulement sur le VPS** (≈ 7 jours gardés). Les réglages faits en jeu stockés hors base (points déplacés, bans à valider, événements programmés, tags, mobilier, favoris…) **ne sont dans aucune sauvegarde** | Moi (script) + toi (test) |
| 5 | **Failles de triche à fermer** : un tricheur peut écrire lui-même 3 valeurs que le serveur croit | `gsConfessed` / `gsSnitch` = peine de prison réduite (+ fausse protection de témoin) ; `gsFake` = faux papiers au contrôle routier (cache recherche et mandats) | Moi (petit correctif) |
| 6 | **Vente de drogue aux PNJ** acceptée sur un PNJ créé par le vendeur lui-même | Source d'argent pour un tricheur (bornée à 1 vente / 6 s) | Moi (petit correctif) |
| 7 | **Test de charge** : 10 joueurs ou plus, 45 min, `/perfserveur` + `resmon` | Jamais fait. Objectif : aucune ressource gs_ au-dessus de 0,5 ms en continu | Toi + testeurs |
| 8 | **Positions « à caler »** : 19 encore marquées dans le code (casino, piste d'atterrissage et Ludendorff, location, Dynasty 8, état civil, combats, tuning, planque Triads, assurance, caméras, animalerie…) + témoin du tribunal, fourgon, désert | Elles marchent mais peuvent être mal placées. F11 → Monde et lieux → Déplacer un point | Toi (en jeu) |
| 9 | **Tour des 40 maps payantes** et backtest ★★★ | Désactiver celles qui chargent sans fin | Toi (en jeu) |

## 🟠 À corriger vite (juste avant ou dans la semaine d'ouverture)
- **Plantations de cannabis** : une plante mûre ne meurt jamais ; dès qu'il y en a une, toute la liste est renvoyée à tous les
  joueurs chaque minute, et chaque plante fait une écriture en base par minute même sans changement. Avec le temps (persos
  abandonnés), ça grossit sans limite. En plus, un policier touche 150 $ pour une plante plantée une seconde avant (collusion
  possible avec un ami).
- **Lieux de mémoire** : à chaque redémarrage, tout l'historique (jusqu'à 5 000 événements) est rejoué, avec une mise à jour
  envoyée à tous à chaque événement ; et une plaque déjà posée peut être reposée → les plaques n'expirent jamais et la Gazette
  peut recevoir des doublons.
- **Chaque crime signalé** renvoie à tous les joueurs la carte complète des quartiers de gang et des lieux de mémoire. À
  regrouper (une mise à jour toutes les 5 à 10 s).
- **Limites qui repartent à zéro en se reconnectant** (ou en changeant de perso) : fouilles de poubelles par heure, délai entre
  deux braquages de supérette (le plafond par jour, lui, tient).
- **Lien Discord écrit deux fois** (`server.cfg` en `setr` avec https, `secrets.cfg` en `set` sans https, lu après) : la 2e ligne
  écrase la 1re et peut empêcher le client de le lire. En garder une seule.
- **Transfert en fourgon** : l'évasion se décide sur l'état du fourgon remonté par le jeu du détenu (connu, noté en V12.65).
- **Installation des ressources Qbox depuis une recette non figée** (`qbox.yaml` de la branche main) : une réinstallation près
  de l'ouverture peut ramener d'autres versions. Ne rien réinstaller d'ici lundi.

## 🟡 Docs à remettre d'aplomb
- `ETAT_PROJET.md` section 0 date du 12/10 (V12.25) : à réécrire avec ce bilan.
- Ancien script `scripts/backup_db.sh` encore cité (INSTALL, V1_CHECKLIST, ARCHITECTURE) au lieu de `roadline-bdd.sh`.
- « 16 places » écrit dans ETAT_PROJET alors que la config dit 48.
- L'**IP du VPS** et l'adresse http de l'appli staff sont écrites dans les docs (ETAT_PROJET, OVH) et le site : sans gravité si
  le dépôt GitHub est privé ; à retirer s'il devient public.

## 🟢 Optimisations (sans rien casser, après l'ouverture)
- Index en base sur les colonnes souvent filtrées (posts Néon par personnage, dossiers de justice, mandats actifs, sessions…).
- Loterie : compter les tickets en base au lieu de tous les charger ; verrou anti double-achat.
- 3 petites tables jamais vidées à la déconnexion (drone, demandes d'unité police, incidents staff) : quelques octets par
  joueur, à nettoyer.
- `gs_markers` : 13 ressources l'utilisent sans le déclarer ; le relancer seul fait disparaître leurs marqueurs (ne pas le
  relancer seul).
- Liste du staff : un joueur encore en chargement peut faire planter la liste une fraction de seconde (à protéger).
- Contrôle de performance automatique : il ne voit pas les mises à jour envoyées à tous dans une boucle ni les écritures en
  base répétées ; à enrichir.
- Textures > 32 Mo (DIAGNOSTIC-MODS) ; voitures jamais utilisées à retirer après une semaine de jeu (sur ton accord).
- `entityLockdown strict` après l'ouverture (audit fait, migration à prévoir).

## ✅ Prêt pour l'ouverture
- Installation PC + VPS en un clic, mises à jour (base sauvegardée avant), redémarrage auto si le serveur tombe (+ alerte
  Discord), redémarrage quotidien 06:00 annoncé en jeu.
- Config serveur : build 3570 forcé, ScriptHook interdit, `sv_pureLevel 1`, `entityLockdown relaxed`, ordre de démarrage
  correct, aucune ressource en double, licence et base uniquement dans `secrets.cfg` (jamais committé).
- Sécurité : aucun secret dans le dépôt ni l'historique, anti-triche + pièges, bans F11 / appli / Discord avec double
  validation, rangs vérifiés côté serveur (mapping et réglages = super-admin et fondateur).
- Staff : F11, F10, appli web installable, Lives, tickets, journal, chat staff, incidents.
- Gameplay, signatures, police / EMS / justice : complets et testés automatiquement.
- Boutique coupée (`Config.Enabled = false`) tant que les prix et la conformité Cfx ne sont pas validés : c'est le bon état.

## Ce qui ne dépend que de toi
Passage en public + code cfx, décision sur les 48 places, test de restauration, tour des maps et backtest en jeu, test de
charge avec les testeurs, positions à caler, bande-annonce (le site l'affiche dès qu'on lui donne l'identifiant YouTube),
code personnel fondateur pour l'appli (GERER-OVH → 20 → A, rang 5), Discord validé sur le VPS.
