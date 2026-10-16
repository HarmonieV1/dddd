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
| Armurerie | équipement de service **prêté** (V12.37) : repris à la fin du service, au changement de métier, au licenciement / à la démission et à la déconnexion ; seulement les quantités fournies (ce qu'on avait avant reste, ce qui a été consommé n'est pas réclamé) ; reconnexion : repris 5 s après le chargement |
| Points (V12.37) | une seule interaction par point (le PNJ porte l'option ox_target, [E] reste), verrou anti-double-clic 1 s, prise de service par **état voulu** + anti-rebond 1,5 s (plus de « Prise » puis « Fin de service » en double), garage : messages exacts (pas de métier actif / autre métier / hors service) et verrou pendant la sortie |
| Factures / amendes | stockées en BDD, `/factures` pour payer, 10 % à l'émetteur, reste à la caisse |
| Missions | taxi, livreur, éboueur : étapes choisies par le serveur, anti-TP, véhicule de service exigé |
| Actions véhicule | mécano : réparer (kit consommé), nettoyer ; durée vérifiée côté serveur |
| Pôle Emploi | rejoindre les jobs publics |
| Staff | `/gsjob add|remove|grade|list <id> [job] [grade]` (group.admin) |
| Audit | toutes les actions sensibles en table `gs_job_audit` + webhook Discord `gs_webhook_jobs` |

## Animalerie (V12.63, ressource `gs_animalerie`)
Emploi public `animalerie` (Pôle Emploi, service n'importe où, payé à la tâche par la ville, sur le compte en banque). Dans la
boutique de la map Patoche : animaux exposés (visibles de tous), **Réserve** (carton de croquettes porté) → **Gamelles**,
**Cages** (balai), **Toilettage**, **Comptoir** (un client toutes les 2 min 30 à 5 min pour l'employé en service, pourboire possible).
Attente entre deux mêmes tâches, distance et service vérifiés par le serveur ; XP de métier au plus toutes les 10 min.
Postes : F11 → Monde et lieux → Déplacer un point → « Animalerie · … » (tant qu'ils ne sont pas placés, ils se rangent autour de
la position de la map lue par gs_admin). Réglages : `gs_animalerie/shared/config.lua` (paies, durées, animaux, clients).

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
`./tests/run.sh` : syntaxe, linters (config, liaisons entre ressources) et tests de logique serveur (simulateur, pas le vrai jeu). Lancé aussi par la CI GitHub.

## Impact / risques / rollback
- Impact : nouvelle ressource, 4 tables préfixées `gs_`, aucune table Qbox modifiée.
- Risques : noms d'API Qbox/ox marqués `[API]` dans `gs_bridge` à confirmer ; coords approximatives.
- Rollback : retirer `ensure gs_jobs` ; tables conservées (backup avant `DROP`, voir `sql/gs_jobs.sql`).
