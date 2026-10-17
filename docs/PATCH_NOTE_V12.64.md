# Patch note — nuit du 16/10/2026 (V12.64)

> Suite directe de la V12.63 (`docs/PATCH_NOTE_V12.63.md`). Version prête à coller sur Discord : `docs/PATCH_NOTE_V12.64_DISCORD.txt`.
> Installation : METTRE-A-JOUR (ajoute les nouveaux objets dans ox_inventory) → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH.
> Rien n'a encore été vu en jeu : fiche de backtest, section **4q**.

## 1. Pour les joueurs
| Nouveauté | Comment ça marche |
|---|---|
| **🔴 Correctif : « on prend 0 dégâts »** | Après la protection d'arrivée (30 s en fantôme, à la connexion et à chaque réapparition), l'invincibilité n'était jamais retirée : tout le monde restait intouchable, police IA comme fusillade. Elle est maintenant retirée à la fin de la protection, avec un filet de sécurité (seul le pouvoir « Invincible » du staff la garde). |
| **Salle de sport** | Muscle Beach (blip), la cour de Bolingbroke et la plage de Sandy Shores : [E] au point de la salle, choisis un exercice (pompes, abdos, haltères, yoga, course sur place, 20 s animées). Trois exercices différents en 15 min = **séance terminée** : 6 h de bonus d'endurance (plus de souffle au sprint et en apnée, récupération plus rapide). Gratuit, gardé même après une reconnexion. |
| **Piratage de distributeur** | Avec un **boîtier de piratage** (marché noir, 2 800 $), [Alt] sur un distributeur → « Pirater le distributeur » : tu branches le boîtier (étincelles), puis mini-jeu sur la tablette (touches au bon moment). Réussi : le distributeur crache des billets 15 s (450 à 950 $ en argent sale, +25 % la nuit). Raté : l'alarme sonne. La caméra du distributeur peut te filmer (le visage, sauf masque). Le boîtier peut griller ; un distributeur vidé reste surveillé 45 min. |
| **Pot-de-vin** | Face à la police IA à 1 ★ ([E] près de l'agent) : « Glisser un billet » et tu choisis la somme. L'agent a son prix et ne le dit pas : trop peu, il le prend mal (une étoile de plus) ; accepté, il regarde ailleurs… mais une enquête des affaires internes peut s'ouvrir (une ligne au casier). Aux **contrôles du shérif** et à **l'alcootest** aussi : la moitié de l'amende en liquide, ni amende ni points s'il accepte ; refusé, l'amende est majorée. |
| **Drone de repérage (gangs)** | Au marché noir, réservé aux gangs (15 000 $, 2 par jour) ; seuls les membres confirmés (pas les recrues) savent le piloter. Double-clic sur l'objet : tu restes sur place, tablette en main, et tu voles (ZQSD/WASD, Espace / Ctrl, souris, molette pour zoomer, E vision de nuit, X pour le rappeler). Portée 140 m, batterie 2 min. **Abattable** (deux balles) : perdu s'il tombe. Le radar de la police peut le repérer. |

## 2. Pour le staff et la police
| Nouveauté | Où | Ce que ça change |
|---|---|---|
| **Lives fluides** | F11 → Lives, appli → Lives | Images réduites chez le joueur filmé (960 px de large, WebP) : 4 à 6 fois plus légères. Flux continu tant qu'une fenêtre est ouverte (≈ 2 à 3 images/s, compteur « img/s » dans la barre), l'image suivante est préparée pendant que tu regardes la précédente ; l'appli ne retélécharge jamais la même image. Personne n'est filmé quand aucune fenêtre n'est ouverte. |
| **screenshot-basic plus léger pour tous** | — | Il ne recopiait l'écran **à chaque image chez tous les joueurs**, même sans capture (FPS perdus). Maintenant : seulement quand une capture est demandée (Lives, photos, bodycam). Photos et bodycam gardent la pleine taille. |
| **Drone de surveillance (police)** | F4 → Drone de surveillance, ou `/drone` (en service) | Portée 260 m, batterie 4 min, vision de nuit **et thermique**. **[G]** sur un suspect au centre de l'image : tous les collègues en service le suivent sur la carte 60 s (position rafraîchie toutes les 5 s, jamais son nom). Abattable aussi. Radar : alerte « drone non identifié » (zone floue) quand un drone de gang vole. |
| **Corruption au casier** | F4 → Casier | Un pot-de-vin découvert ajoute « Corruption d'un agent (… $) · enquête des affaires internes » au casier (par « Affaires internes »). Aucune amende automatique : à la police de s'en saisir. |
| **Journal staff** | F10 → Journal | Piratages de distributeur (réussis ou ratés), pots-de-vin (acceptés, refusés, enquête), drones (décollage, abattu, suspect marqué). |

Relecture du code avant livraison (corrigé) : fenêtres Lives qui pouvaient renvoyer des demandes en double (risque d'expulsion
du staff par l'anti-flood avec 4 fenêtres) ; menu du shérif qui pouvait rester bloqué ; drone abattu en une seule balle d'une
rafale (et tirs simulables) ; distributeur « neuf » en décalant la position d'un mètre ; piratage / exercice restés en plan ;
photo perdue si elle tombait pendant un Lives (file d'attente dans screenshot-basic).

## 3. Pour le fondateur (serveur, objets, docs)
- **Nouvelle ressource** `gs_drone` (ajoutée à `server/cfg/resources.cfg` après gs_police).
- **Nouveaux objets** (METTRE-A-JOUR les ajoute) : `gs_atm_hacker` (Boîtier de piratage) et `gs_drone` (Drone de repérage). Tous deux au marché noir.
- **Nouveau crime** relié au central : « Piratage de distributeur » (gs_wanted, chaleur 18 : police IA à 1 ★ sans policier en service).
- `screenshot-basic/dist/ui.html` : rendu à la demande + option `maxWidth` (repère « RoadLine V12.64 » dans le fichier).
- Réglages : `gs_lives` (Config.Every, MaxWidth, Encoding, Lease), `gs_bank` (Config.Hack), `gs_wanted` (Config.NpcPolice.negotiate.bribe),
  `gs_roadside` (Config.Bribe), `gs_drone` (Config.Types), `gs_vie` (Config.Gym).
- Tests : 85 contrôles en plus (Lives, distributeur, pot-de-vin, drone, salle de sport), toute la suite est verte.
- Docs : `PROPOSITIONS.md` (206, 227, 230 et 231 livrées ; **30 nouvelles idées** liées à la ville et aux signatures, n° 247 à 276), backtest 4q, guides.

## 4. Encore à faire / à vérifier en jeu
- Lives : vérifier la fluidité avec 2 ou 3 fenêtres (compteur « img/s ») ; si un joueur affiche « format WebP indisponible », il passe tout seul en JPEG.
- Photos (appareil argentique, Vibe) et bodycam : vérifier qu'elles marchent toujours (screenshot-basic modifié).
- Animations : brancher le boîtier (distributeur), tablette, exercices de la salle ; drone : maniabilité, collisions, vision thermique.
- Points des salles de sport à caler si le marqueur tombe à côté (F11 → Déplacer un point n'y est pas encore : `gs_vie/shared/config.lua`, Config.Gym.places).
