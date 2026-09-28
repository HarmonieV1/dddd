# [TEST] Plan de test — gs_weather, gs_wanted, gs_economy, gs_duo

## gs_wanted
- [ ] Tir en pleine rue de jour → signalement quasi certain, zone précise ; même tir la nuit dans le brouillard → souvent rien
- [ ] Tir au stand d'Ammu-Nation → jamais signalé
- [ ] Policier en service à côté → signalement immédiat, précis
- [ ] Étoiles visibles seulement après signalement, redescendent après ~2 min sans crime
- [ ] `/dispatch` refusé aux civils ; GPS fonctionne
- [ ] Abus : TriggerServerEvent('gs_wanted:server:shot') en boucle sans arme → rien

## gs_economy
- [ ] Acheter 20 eaux → prix ▲ ; attendre ~1 h → retour au prix normal
- [ ] `/meteoevent heatwave` → eau plus chère ; stop → prix normal
- [ ] Revendre beaucoup de ferraille → prix ▼
- [ ] Inventaire plein → achat refusé, pas débité
- [ ] Console au démarrage : liste des items absents d'ox_inventory (à déclarer ou retirer)

## gs_duo
- [ ] Proposer, refuser, accepter ; partenaire visible sur la carte à l'autre bout de la map
- [ ] Contrat : impossible seul sur l'étape ; à deux → payés tous les deux ; XP ↑
- [ ] Vol signalé à la police selon les témoins
- [ ] Déco du partenaire pendant un contrat → annulé proprement
- [ ] Rupture → impossible de refaire un duo pendant 1 h

## Perf
- [ ] resmon : chaque ressource < 0,5 ms au repos, 0 erreur console

Verdict : ✅ GO / ⚠️ GO avec réserves / ❌ NO GO + repro
