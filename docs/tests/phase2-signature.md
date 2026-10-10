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

## gs_heists
- [ ] Supérette sans arme / sans assez de police → refus clair ; avec → barre, butin en argent sale
- [ ] Bijouterie : 6 vitrines, alarme → dispatch police immédiat et précis
- [ ] Même site juste après → « sous surveillance » (cooldown)
- [ ] Nuit + duo proche + quartier de son gang → butin plus gros

## gs_drugs
- [ ] Récolte → préparation → vente à un passant ; même passant = refus
- [ ] Vendre 10 fois au même endroit → le prix baisse ; revenir 1 h plus tard → prix normal
- [ ] Policier en service à côté → personne n'achète

## Perf
- [ ] resmon : chaque ressource < 0,5 ms au repos, 0 erreur console

Verdict : ✅ GO / ⚠️ GO avec réserves / ❌ NO GO + repro
