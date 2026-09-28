# Ressources V1 : on récupère l'existant, on ne recode que le différenciant

[DEV] Règle : une ressource open-source maintenue et auditée > un script maison. On recode seulement
ce qui fait notre identité (features signature Phase 2) ou ce qui n'existe pas proprement.
Chaque ressource passe la checklist d'audit (`docs/SECURITY.md`) avant install. Noms et dépôts
à confirmer sur github.com/Qbox-project et github.com/overextended au moment de l'install.

| Besoin | Ressource | Source | Statut |
|---|---|---|---|
| Framework | qbx_core, ox_lib, oxmysql | Qbox / overextended | base |
| Inventaire, interactions | ox_inventory, ox_target | overextended | base |
| Voix / radio | pma-voice (+ radio Qbox) | AvarianKnight / Qbox | base |
| Création perso / spawn | sélection de perso intégrée à qbx_core (à confirmer), qbx_spawn | Qbox | à installer |
| Apparence / tenues | illenium-appearance | open-source | à installer |
| Clés / garages / concession | qbx_vehiclekeys, qbx_garages, qbx_vehicleshop | Qbox | à installer |
| Carburant | ox_fuel | overextended | à installer |
| Police (menottes, fouille, escorte) | qbx_policejob | Qbox | installer, **désactiver** son service/garage/coffres (gérés par gs_jobs) |
| EMS (mort, réanimation) | qbx_medical + qbx_ambulancejob | Qbox | idem |
| Mairie / papiers | qbx_cityhall | Qbox | installer, désactiver sa liste de jobs (Pôle Emploi = gs_jobs) |
| Banque | Renewed-Banking | open-source | à évaluer (overlap caisses société) |
| Téléphone | npwd (open-source) ou payant | — | décision Alpha |
| HUD | qbx_hud ou HUD maison NUI (DA néon) | — | Phase 2 |
| Boss menu / multijob | ~~qbx_management~~ | — | **remplacé par gs_jobs** |
| Multi-job, caisses, paie, factures, missions | **gs_jobs** | maison | ✅ fait |
| Anti-abus events, logs | **gs_security** | maison | ✅ fait |
| Météo / heure | ~~qbx_weathersync~~ → **gs_weather** | maison | ✅ fait |
| Dispatch / recherche | **gs_wanted** | maison | ✅ fait |
| Commerces / revente | **gs_economy** (remplace les shops statiques des supérettes) | maison | ✅ fait |
| Duo criminel | **gs_duo** | maison | ✅ fait |
| Boutique Tebex | **gs_store** (désactivée tant que la conformité PLA n'est pas validée) | maison | ✅ fait |

Maison en Phase 2 (identité) : réseau social in-game, companion web.
Faits : météo événementielle, wanted intelligent, économie dynamique, duo criminel lié (`docs/FEATURES.md`).
