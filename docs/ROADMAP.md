# Roadmap · où on en est

*Mis à jour le 05/10/2026 · version **V10.2** en ligne sur le VPS OVH (profil privé, backtest).*

## Fait
- **Serveur** : Qbox/ox, 66 ressources RoadLine (`gs_*`), 19 signatures. Tests automatiques au vert : 2458 contrôles Lua + 20 du bot.
- **VPS OVH** (Ubuntu 24.04) :
  - le serveur démarre tout seul et redémarre après un plantage ;
  - la base du PC est importée ;
  - sauvegardes de la base toutes les 6 h ;
  - pare-feu configuré, connexion par clé (aucun mot de passe).
- **Outils PC**, en un double-clic :
  - `PREPARER-OVH` : première mise en ligne ;
  - `METTRE-A-JOUR-OVH` : mise à jour, en vérifiant que la version du PC correspond à celle du zip ;
  - `GERER-OVH` : état, diagnostic, erreurs, marche/arrêt, public/privé, sauvegardes, réglages, retour arrière.
- **Docs** : guide joueur et fiche de backtest en PDF (`docs/pdf`), `OVH.md`, `ADMIN.md`, `DISCORD.md`, `FEATURES.md`, site vitrine.

## Priorités

| Priorité | Quoi | Statut |
|---|---|---|
| **P0 · cette semaine** | Backtest (≈ 1 semaine) avec la fiche de test PDF ; chaque jour : `GERER-OVH` → 3 (erreurs), et me remonter captures + numéro du test | En cours |
| **P0** | Copie de sécurité de la base sur le PC (`GERER-OVH` → 11) au moins une fois par jour pendant le backtest | À faire par le staff |
| **P1 · après le backtest** | Modération : txAdmin installé à côté du mode simple ; panneau staff web responsive (téléphone) ; bot Discord branché sur le VPS (`CONFIGURER-DISCORD` puis `GERER-OVH` → 12) | À faire |
| **P1** | Corriger les retours du backtest (tri : bloquant → gênant → confort) | À venir |
| **P2 · avant l'ouverture** | Infrastructure : sauvegardes copiées hors du VPS automatiquement, alerte Discord si le serveur tombe, redémarrage programmé (ex. 6 h), nom de domaine (connect roadline…) | À faire |
| **P2** | Profil public : vérifier `sv_authMinTrust` / `sv_forceIndirectListing` (prod.cfg), whitelist si besoin (`gs_whitelist`) | À décider |
| **P3 · lancement** | Ouverture publique (`GERER-OVH` → 7), boutique `gs_store` après validation PLA, communication, streamers | Plus tard |

## Pistes de nouvelles signatures (à valider)
1. **Les jurés de Los Santos** : pour un vrai procès, des citoyens tirés au sort reçoivent une convocation sur leur téléphone. Ils votent, et le verdict tombe dans le fil de la ville.
2. **La Gazette du dimanche** : chaque semaine, un journal mis en page est généré tout seul à partir des faits divers, des verdicts, des rumeurs vérifiées et des légendes. Il est publié sur le site et sur Discord.
3. **Élections municipales** : chaque mois, des candidats font campagne et les citoyens votent. Le maire choisit 2 ou 3 leviers réels : taxe des commerces, prime des enquêtes, couvre-feu des quartiers chauds.
4. **Héritage** : à la mort définitive d'un personnage, son testament (biens, véhicules, lettre) revient aux héritiers désignés. Une tombe avec son épitaphe apparaît au cimetière et sur le site.
5. **Ville en timelapse** : la carte vivante du site rejoue les dernières 24 h (crimes, interventions, rumeurs) en 30 secondes.
6. **Lieux de mémoire** : un événement marquant (gros braquage, fusillade, mariage) laisse une plaque ou un graffiti persistant sur place, et un PNJ en parle.

## Rappels
- Jamais de vraie marque, ni de mot de passe dans les fichiers ou les messages.
- Avant chaque mise à jour du VPS : METTRE-A-JOUR sur le PC, test rapide, puis METTRE-A-JOUR-OVH.
