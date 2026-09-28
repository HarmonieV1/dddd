# GTA SOON (nom provisoire)

Serveur GTA RP francophone premium sur FiveM. Free Access au lancement, zéro pay-to-win, zéro main team.
Base Los Santos vanilla, finitions néon / sunset façon Vice City, touche FR.

- Fondateur / décideur final : **Alpha**
- Stack : FXServer + txAdmin, Qbox, ox_lib / ox_inventory / ox_target / oxmysql, pma-voice, NUI React + Vite, Supabase + Netlify, Make, Tebex
- Docs : [`docs/AGENTS.md`](docs/AGENTS.md) · [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/SECURITY.md`](docs/SECURITY.md) · [`docs/ROADMAP.md`](docs/ROADMAP.md) · [`docs/JOBS.md`](docs/JOBS.md) · [`docs/V1_RESOURCES.md`](docs/V1_RESOURCES.md) · [`docs/WEATHER.md`](docs/WEATHER.md) · **[`docs/INSTALL.md`](docs/INSTALL.md)**

## Structure
```
server/                  # server.cfg.example + cfg/ (secrets, convars, ressources, ACE, profils dev/prod)
  resources/[gtasoon]/   # nos ressources (préfixe gs_)
docs/                    # prompt maître, archi, sécu, roadmap
scripts/                 # backup BDD, outils
tests/                   # ./tests/run.sh : syntaxe + tests logique serveur
```

## Branches
`main` (prod) · `dev` (serveur de dev) · `feature/*`. Rien n'arrive en `main` sans validation d'Alpha.

## Démarrer
Suivre [`docs/INSTALL.md`](docs/INSTALL.md). Avant chaque déploiement : `./tests/run.sh`.
