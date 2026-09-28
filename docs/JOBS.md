# gs_jobs — système multi-job

## Fonctionnalités
| Feature | Détail |
|---|---|
| Multi-job | jusqu'à `Config.MaxJobs` contrats par perso, bascule via **F6 / `/job`** |
| Service | au point de service (LSPD/EMS/Mécano) ou partout (jobs publics) ; changer de job = hors service |
| Direction | recrutement avec **consentement** (offre 60 s), grades, licenciement, caisse (dépôt/retrait) |
| Caisses société | table `gs_societies`, retraits atomiques (pas de solde négatif, pas de course) |
| Paie | toutes les 15 min, en service uniquement, par l'État ou la caisse ; anti-AFK ; allocation chômage |
| Garages | véhicule spawn **côté serveur**, 1 max par joueur, plaque au préfixe du job, clés auto, rendu en fin de service |
| Coffres | ox_inventory, restreints par job + grade + distance |
| Factures / amendes | stockées en BDD, `/factures` pour payer, 10 % à l'émetteur, reste à la caisse |
| Missions | taxi, livreur, éboueur : étapes choisies par le serveur, anti-TP, véhicule de service exigé |
| Actions véhicule | mécano : réparer (kit consommé), nettoyer ; durée vérifiée côté serveur |
| Pôle Emploi | rejoindre les jobs publics |
| Staff | `/gsjob add|remove|grade|list <id> [job] [grade]` (group.admin) |
| Audit | toutes les actions sensibles en table `gs_job_audit` + webhook Discord `gs_webhook_jobs` |

## Ajouter un job ([CONFIG])
Tout se passe dans `shared/jobs.lua` : copier un bloc, changer le nom, les grades, les points, les véhicules.
Aucun code à toucher. Les coords sont à caler en jeu (`Config.Debug = true` affiche les zones).

## Installation
1. `ensure gs_security`, `gs_bridge`, puis `gs_jobs` après qbx_core / ox_* (voir `server.cfg.example`).
2. Les tables se créent au démarrage (`sql/gs_jobs.sql` fourni pour une install manuelle).
3. **Qbox** (à vérifier sur docs.qbox.re à l'installation) :
   - retirer de `qbx_core/shared/jobs.lua` les jobs qu'on redéfinit (police, ambulance, mechanic, taxi…) sinon leurs salaires Qbox s'ajoutent aux nôtres ;
   - `maxJobsPerPlayer` dans la config qbx_core ≥ `Config.MaxJobs` + 1 ;
   - **ne pas installer `qbx_management`** (doublon avec notre menu Direction) ;
   - réserver le `/setjob` natif au fondateur : passer par `/gsjob` (sinon la réconciliation au login retire le job).
4. Item `repairkit` à déclarer dans `ox_inventory/data/items.lua` s'il n'existe pas :
   ```lua
   ['repairkit'] = { label = 'Kit de réparation', weight = 2500, stack = true, close = true },
   ```

## API pour les autres ressources (serveur)
```lua
exports.gs_jobs:HasJob(src, 'police', 2)      -- contrat police grade ≥ 2
exports.gs_jobs:IsOnDutyAs(src, 'ambulance')  -- job actif + en service
exports.gs_jobs:GetMemberships(src)           -- { police = 2, taxi = 0 }
exports.gs_jobs:AddSocietyMoney('mechanic', 500)
```

## Sécurité
Chaque event/callback : rate-limit → personnage chargé → job/grade/service → distance serveur → montants entiers bornés.
Le client n'envoie que des intentions (index de garage, id de facture) ; prix, salaires, étapes et gains sont calculés côté serveur.

## Tests
`./tests/run.sh` : syntaxe de tout le Lua + 62 tests de logique serveur (simulateur, pas le vrai jeu). Lancé aussi par la CI GitHub.

## Impact / risques / rollback
- Impact : nouvelle ressource, 4 tables préfixées `gs_`, aucune table Qbox modifiée.
- Risques : noms d'API Qbox/ox marqués `[API]` dans `gs_bridge` à confirmer ; coords approximatives.
- Rollback : retirer `ensure gs_jobs` ; tables conservées (backup avant `DROP`, voir `sql/gs_jobs.sql`).
