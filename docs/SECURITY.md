# Sécurité (défensive)

## Règles non négociables
1. Ne jamais faire confiance au client : argent, items, jobs validés côté serveur.
2. Chaque `RegisterNetEvent` / `lib.callback.register` : rate-limit (vérifié par `tests/check_links.py`), puis source, distance, job/permission.
3. ACE strictes (`add_ace` / `add_principal`), rien de `allow` global.
4. Aucun secret dans le repo : `server.cfg` et `cfg/secrets.cfg` ignorés, fichiers `.example` avec placeholders (vérifié par `tests/check_cfg.py`).
5. Actions sensibles loguées vers webhook Discord staff (URL en convar, jamais en dur).
6. Backups BDD automatiques (`SAUVEGARDER-BDD.bat`) + rollback documenté à chaque déploiement (`METTRE-A-JOUR.bat` sauvegarde avant).
7. Anti-DDoS côté hébergeur (voir plus bas).

## Audit V3.1 : ce qui protège le serveur

| Menace | Protection en place | Où |
|---|---|---|
| **Injection SQL** | Toutes les requêtes passent des paramètres `?` (oxmysql). Le linter refuse toute requête construite par concaténation `..` | `tests/check_links.py` (règle n°2) |
| **Exécution de code injecté** | Aucun `load` / `loadstring` côté serveur, refusé par le linter | `tests/check_links.py` (règle n°3) |
| **Spam d'events (flood, mini-DDoS applicatif)** | Rate-limit par joueur et par action ; au-delà de 60 refus en 30 s, le joueur est **expulsé** et journalisé | `gs_security/server/main.lua` |
| **Menus de triche : armes données / retirées à distance, éjection de véhicule** | Events natifs `giveWeaponEvent`, `removeWeaponEvent`, `removeAllWeaponsEvent`, `clearPedTasksEvent` bloqués + journal | `gs_security/server/anticheat.lua` |
| **Explosions en rafale / invisibles** | Plus de 4 explosions en 10 s bloquées, explosions invisibles bloquées | idem |
| **Lag volontaire (particules)** | `ptFxEvent` limité | idem |
| **Se démenotter / fausse escorte (client qui écrit son state bag)** | Valeur serveur de référence, modification client annulée et journalisée | `gs_police/server/main.lua` |
| **Argent / items dupliqués** | Tout gain passe par le serveur (distance, durée réelle, stock, cooldown) ; actions en deux temps (début / fin) pour les récoltes, braquages, réparations | chaque ressource `gs_*` |
| **Téléportation / missions trichées** | Vitesse crédible entre deux étapes de mission (> 270 km/h = annulée) | `gs_jobs/server/missions.lua` |
| **Abus de pouvoir staff** | Niveaux ACE, mode staff obligatoire, jamais de sanction sur un staff de niveau égal ou supérieur, tout journalisé (BDD + Discord), sanctions publiques | `gs_admin` |
| **Entités créées par les clients** | `sv_entityLockdown relaxed`, `sv_filterRequestControl 2`, sons et explosions réseau coupés | `cfg/dev.cfg`, `cfg/prod.cfg` |
| **ScriptHook / fichiers de jeu modifiés** | `sv_scriptHookAllowed 0`, `sv_pureLevel 1` | `server.cfg.example` |
| **Fuite de secrets** | Linter qui cherche licences, webhooks et chaînes de connexion commités | `tests/check_cfg.py` |
| **Perte de données** | Sauvegarde zip avant chaque mise à jour + sauvegarde quotidienne planifiée de la base | `METTRE-A-JOUR.bat`, `SAUVEGARDER-BDD.bat` |

Limites honnêtes : un anti-triche serveur ne voit pas tout ce qui se passe **dans** le client (aimbot, ESP, noclip local).
Pour ça : staff actif (spectate F11), signalements `/report`, et plus tard un anti-triche reconnu (à auditer comme tout script tiers).

## DDoS : ce qui se règle chez l'hébergeur (pas dans le code)
Une attaque DDoS sature la connexion **avant** d'atteindre FiveM : aucune ligne de Lua ne peut l'arrêter.
1. **Héberger chez un fournisseur avec anti-DDoS « jeu »** qui filtre l'UDP : OVHcloud (Game / VPS avec Anti-DDoS Game),
   ou un hébergeur FiveM spécialisé. Un PC à la maison n'est pas protégé : à réserver aux tests.
2. **Ne pas diffuser l'IP** : on partage le lien `cfx.re/join/…`, jamais l'IP. En prod, tester `sv_forceIndirectListing` (cfg/prod.cfg).
3. **Pare-feu** : n'ouvrir que le port du serveur (30120 TCP/UDP) et, pour txAdmin, restreindre le port 40120 à ton IP.
4. **txAdmin** : mot de passe fort + authentification à deux facteurs, pas de compte partagé.
5. **Discord** : rôles staff limités, jamais de webhook collé dans un salon public.

## Checklist audit script tiers (avant install)
- [ ] Origine et licence claires (pas de fuite / leak)
- [ ] grep : `PerformHttpRequest`, `load(`, `loadstring`, `assert(load`, `os.execute`, `io.popen`, base64/hex suspects
- [ ] Code obfusqué ou fichiers `.dll`/binaires inattendus → refus
- [ ] Events serveur : validation source/params ? sinon patch avant merge
- [ ] Ajouts `server_script` cachés dans `fxmanifest`
- [ ] Test sur dev avec console propre + resmon

## Interdits
Cheats, exploits, contenu Rockstar/IP tierce, loot boxes, monnaie in-game payante.
