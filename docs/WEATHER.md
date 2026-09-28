# gs_weather — météo & heure (feature signature)

| Feature | Détail |
|---|---|
| Heure synchronisée | ancrage serveur + calcul local : **0 trafic réseau récurrent** |
| Golden hour | coucher de soleil 18h-21h allongé à 12 min réelles (DA néon/sunset), journée ~49 min |
| Météo réaliste | graphe de transitions pondéré, pas de saut soleil → orage, transition 45 s |
| Événements | tempête tropicale (vent, blackout possible), canicule, brouillard ; annonce en jeu + Discord |
| API | `exports.gs_weather:GetWeather()`, `GetEvent()`, `IsBlackout()`, `GetGameTime()` + events serveur `gs_weather:server:eventStarted/eventEnded` pour l'économie, le wanted, les EMS… |
| Staff | `/meteo <type> [min]`, `/meteoevent <storm|heatwave|fog|stop>`, `/heure h m`, `/figerheure`, `/blackout` |
| Compat | remplace qbx_weathersync ; écoute `qb-weathersync:client:DisableSync/EnableSync` (sélection de perso) |

Réglages : `shared/config.lua` (profil de journée, durées, probabilités, textes d'annonce).

## [TEST]
- [ ] Deux clients : même heure et même météo à la minute près
- [ ] `/meteoevent storm` → annonce, orage, blackout possible (phares des véhicules toujours allumés)
- [ ] Sélection de perso : ciel dégagé, puis météo réelle au spawn
- [ ] resmon client `gs_weather` ≈ 0,0x ms

## Impact / risques / rollback
- Impact : aucune BDD, état en mémoire (redémarre à `StartTime` / `StartWeather`).
- Risques : conflit si une autre ressource de météo tourne (bloqué par le linter).
- Rollback : retirer `ensure gs_weather`, remettre qbx_weathersync.
