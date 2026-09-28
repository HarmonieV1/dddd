# GTA SOON (nom provisoire)

Serveur GTA RP francophone premium sur FiveM. Free Access au lancement, zéro pay-to-win, zéro main team.
Base Los Santos vanilla, finitions néon / sunset façon Vice City, touche FR.

- Fondateur / décideur final : **Alpha**
- Stack : FXServer + txAdmin, Qbox, ox_lib / ox_inventory / ox_target / oxmysql, pma-voice, NUI React + Vite, Supabase + Netlify, Make, Tebex
- Docs : [`docs/AGENTS.md`](docs/AGENTS.md) · [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/SECURITY.md`](docs/SECURITY.md) · [`docs/ROADMAP.md`](docs/ROADMAP.md)

## Structure
```
server/                  # config FXServer (server.cfg.example) + resources
  resources/[gtasoon]/   # nos ressources (préfixe gs_)
docs/                    # prompt maître, archi, sécu, roadmap
scripts/                 # backup BDD, outils
```

## Branches
`main` (prod) · `dev` (serveur de dev) · `feature/*`. Rien n'arrive en `main` sans validation d'Alpha.

## Démarrer (Phase 0)
1. Installer FXServer + txAdmin (recipe Qbox depuis txAdmin), MariaDB.
2. `cp server/server.cfg.example server/server.cfg` et remplir les secrets (jamais commités).
3. Lier `server/resources/[gtasoon]` dans `resources/`.
