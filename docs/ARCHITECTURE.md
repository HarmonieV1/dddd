# Architecture (v0 — à valider par Alpha)

[DEV] Principe : **logique métier découplée du framework** pour rester portable, **données centralisées** (MariaDB en jeu, Supabase pour web/companion).

## Couches
| Couche | Rôle | Techno |
|---|---|---|
| Runtime | serveur de jeu, restarts, backups, bans | FXServer + txAdmin |
| Framework | joueurs, jobs, gangs, inventaire | Qbox, ox_lib, ox_inventory, ox_target, oxmysql |
| Voix | proximité, radio, téléphone | pma-voice |
| Ressources maison (`gs_*`) | features signature | Lua + NUI React/Vite |
| Web | vitrine, WL future, companion, auth | Netlify + Supabase |
| Automatisation | logs staff, annonces, sync | webhooks Discord + Make |
| Monétisation | cosmétiques / confort | Tebex |

## Règles de découplage
- Chaque feature = une ressource `gs_<nom>` avec `server/` (logique + validation), `client/` (affichage, input), `shared/` (config).
- Accès framework via une fine couche d'adaptation (`gs_bridge`, à créer Phase 1) : le reste du code n'appelle jamais `qbx_core` directement → portage possible.
- Le client n'envoie que des **intentions** ; le serveur décide.

## Flux données
Jeu (oxmysql/MariaDB) → événements serveur → webhook/Make → Discord / Supabase (companion, réseau social in-game → Discord/TikTok).
Supabase n'a jamais d'accès direct à la BDD de jeu : seulement via endpoint serveur signé.

## Ordre des `ensure` (cible)
`oxmysql` → `ox_lib` → `qbx_core` → `ox_inventory` → `ox_target` → `pma-voice` → `gs_security` → `gs_*`.
À confirmer avec docs.qbox.re à l'installation (l'ordre exact dépend de la version).

## Note impact / risques / rollback
- Impact : aucun code de jeu encore, structure et conventions seulement.
- Risques : dérive de version Qbox/ox (figer les versions dans un `manifest` de déploiement) ; couplage si on saute `gs_bridge`.
- Rollback : revert du commit ; pour la BDD, restore du dernier dump (`scripts/backup_db.sh`).

## Questions ouvertes pour Alpha
1. Nom définitif / préfixe de ressources (`gs_` provisoire) ?
2. Hébergeur (anti-DDoS, NVMe) et slots visés au lancement ?
3. Repo unique (jeu + web) ou séparé pour le companion/vitrine ?
