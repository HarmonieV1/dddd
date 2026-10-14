# Patch récap — session web du 14/10/2026 (V12.40 → V12.44)

> À garder pour le récap global de fin. Détail technique de chaque version : `docs/ETAT_PROJET.md` (historique).
> Rien de cette session n'a encore été essayé en jeu : backtest sections **6d, 6e, 6f, 6g** (site de doc).

## V12.40 — concessions, Benny's, courses, portes, gangs
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Concessions** (nouvelle ressource) | `gs_showroom` · F11 → Monde et lieux → Concessions | Le staff pose les véhicules d'exposition et le départ des essais ; Alt : prix, essai 2 min, achat ; le vendeur change le modèle |
| **Mécano Benny's** | `gs_tuning` | Menu complet (perfs, carrosserie, peinture RVB, jantes, néons…), le **client voit en direct**, animations réelles, **facture automatique** |
| **Courses sur mesure** | `gs_races` · F11 | Points posés par le staff, course éphémère (1 à 168 h) ou permanente |
| **Portes verrouillées** | F11 → ox_doorlock | Procédure + groupes conseillés (police, EMS, Benny's, concession, QG de gang) |
| **Territoires de gang** | `gs_gangs` | Visibles des seuls membres, couleur du gang, niveaux 0-3, 3 territoires max par gang, `/territoire`, **PNJ du gang** dans ses zones |
| Tempête | `gs_weather` | Véhicules et arbres posés au sol (plus en l'air) |
| Cayo | `gs_world` | Billet en espèces ou argent sale seulement |
| Benny's / blips / carte | `gs_jobs`, `maps.js`, `gs_hud` | Métier « Mécano Benny's », blips des maps devinés (plus de ronds blancs), « RoadLine RP » sur la carte Échap |
| Propositions | `docs/PROPOSITIONS.md` | n°98 à 107 (section D5) |

## V12.41 — achat concession, tir à la tête, caméras, boutique
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Achat concession** | `gs_showroom`, `gs_bridge` | Comme Qbox : véhicule à ton nom, **sorti** avec ses **clés**, toi au volant ; le staff change le modèle de loin |
| **Balle dans la tête** | `gs_details/client/health.lua` | À terre en un tir (casque = protégé), le reste inchangé |
| **Caméras LSPD en direct** | `gs_cctv` | Terminal du commissariat → « Voir en direct » (souris, zoom, REC) |
| **Boutique en jeu** | `gs_store` · `/boutique` | Interface aux couleurs du site + **RoadCoins** (Tebex, monnaie de boutique seulement). Toujours désactivée : prix et PLA à valider |

## V12.42 — labo, mobilier, arme dans le dos
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Labo** | `gs_evidence` | Scellés gardés en base et lus dans le sac (même ceux d'un collègue, même après redémarrage) |
| **Mobilier utilisable** (nouvelle ressource) | `gs_furniture` | Alt : s'asseoir, s'allonger, **rouler en fauteuil roulant** (objets du mapping F11 et de la ville) |
| **Arme dans le dos** | `gs_details/client/holster.lua` | Attache rigide : ne se balance plus, ne tombe plus |

## V12.43 — retours console et import du 14/10
| Quoi | Où | Ce que ça change |
|---|---|---|
| Erreur `lastVehicleCrime` | `gs_wanted/server/main.lua` | Variable déclarée avant usage (plus d'erreur à la déconnexion) |
| Erreur `GetPedDrawableVariation` | `gs_wanted` (client + `server/memory.lua`), `gs_economy` | Le serveur n'a pas ces fonctions : chaque joueur publie un résumé de sa tenue (`gsLook`), lu par les témoins et les commerçants |
| Erreur `Renewed-Banking` (soins) | retouche Qbox (`outils-communs.ps1`) | L'argent des soins va à la caisse EMS de gs_jobs |
| **Pop-up « prise de service / véhicule » en boucle** | retouche Qbox `qbx_police/client/job.lua` | Les zones service / garage de qbx_police (nouvelle version) sont neutralisées : un seul système (gs_jobs) |
| Conflits de maps Patoche | `gs_admin/server/maps.js` (`KEEP_ON_CONFLICT`) | Herbe → entrepôt, décor → billard (relancés en dernier) ; le stand de jeux perd un peu d'herbe / de décor |
| **Pack LSPD importé** | `gs_jobs/shared/jobs.lua` | 12 véhicules au garage de police, par grade (Scout, K9, moto, banalisées, blindé, Stalker) |
| Severo, Hachura | IMPORTER-MODS | Ajoutées seules au catalogue (catégorie « roadtrip ») : à exposer via F11 → Concessions |

## V12.44 — 2e import du 14/10
| Quoi | Où | Ce que ça change |
|---|---|---|
| Stand de jeux, circuit | `maps.js` (PUBLIC, ACTIVITY) | Blips « Stand de jeux » et « Circuit », scripts Patoche reconnus (sinon « décor seul » en console) |
| FastBox (colis) | `maps.js` | Pas de blip public : le script Patoche pose les siens (sa config) |
| Doublons de l'import | `importer-mods.ps1` | Même mod présent deux fois (zip d'origine + WeTransfer, pack / pack_1) : traité une seule fois |

## Ce qu'il reste à faire de ton côté
1. **METTRE-A-JOUR** (applique les retouches Qbox : pop-up police, soins), puis **METTRE-A-JOUR-OVH**.
2. **30 mods « à convertir »** (cheveux, robes, jeans au format solo) : envoie-moi le dossier `C:\GTASOON\mods-tri\a-convertir`
   (zip / WeTransfer), je les convertis en ajouts FiveM (cheveux renumérotés pour ne pas s'écraser). `male_hair_collection_vol_1`
   a un fichier de 27,8 Mo (> 16 Mo) : je l'allège ou on retire ce modèle.
3. `patoche_villa_bunker_script_pack` : il lui faut la ressource **`patoche_interact`** (dans ton portail Cfx « Granted Assets »,
   même compte que la clé du serveur) : elle n'était pas dans l'import du 14/10.
3 bis. **Props de récolte** : absents du rapport du 14/10 (aucune ligne). Vérifie le nom de leur archive dans `mods-a-trier`.
4. Rejeté : `lace_up_sweats` (vêtement des persos solo Franklin / Michael / Trevor).
5. Placer en jeu : points du métier mécano sur la map Benny's, véhicules d'exposition + départ des essais, portes `/doorlock`.
6. Backtest 6d → 6g.

## Nouvelles ressources de la session
`gs_showroom` (V12.40), `gs_furniture` (V12.42) — ajoutées dans `server/cfg/resources.cfg`.
