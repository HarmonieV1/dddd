# Sécurité (défensive)

## Règles non négociables
1. Ne jamais faire confiance au client : argent, items, jobs validés côté serveur.
2. Chaque `RegisterNetEvent` sensible : vérif `source`, rate-limit, distance, job/permission → helper `gs_security`.
3. ACE strictes (`add_ace` / `add_principal`), rien de `allow` global.
4. Aucun secret dans le repo : `server.cfg` et `.env` ignorés, `server.cfg.example` avec placeholders.
5. Actions sensibles loguées vers webhook Discord staff (URL en convar, jamais en dur).
6. Backups BDD automatiques + rollback documenté à chaque déploiement.
7. Anti-DDoS côté hébergeur.

## Checklist audit script tiers (avant install)
- [ ] Origine et licence claires (pas de fuite / leak)
- [ ] grep : `PerformHttpRequest`, `load(`, `loadstring`, `assert(load`, `os.execute`, `io.popen`, base64/hex suspects
- [ ] Code obfusqué ou fichiers `.dll`/binaires inattendus → refus
- [ ] Events serveur : validation source/params ? sinon patch avant merge
- [ ] Ajouts `server_script` cachés dans `fxmanifest`
- [ ] Test sur dev avec console propre + resmon

## Interdits
Cheats, exploits, contenu Rockstar/IP tierce, loot boxes, monnaie in-game payante.
