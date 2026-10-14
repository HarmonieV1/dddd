# Patch récap — session web du 14/10/2026 (V12.40 → V12.49)

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
| **Backtest allégé** | `tools/backtest.py` (PDF + site de doc) | 31 tests au lieu d'environ 90 : seulement le récent jamais revu en jeu et l'obligatoire avant l'ouverture |
| Documentation | `ETAT_PROJET.md`, `PROMPT_REPRISE.md`, priorités du site de doc | « En attente » et priorités remis à jour (ce qui est fait retiré) |

## V12.45 — vêtements convertis, récolte
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Coiffures et tenues converties** | `livraison/vetements-convertis` (zips ROADTRIP-…, chacun < 30 Mo) | 7 coupes femme, 13 homme (dont 9 du pack TideFN : dreads, locks, boucles), 3 robes, sweat Lace Up, Knee Jeans : en plus de celles du jeu (rien remplacé) |
| Refusés | importeur + NETTOYER-MARQUES | Sac BOOMODS (logo YSL), Afro de Lamar (perso solo), dreadlocks Trycky (archive coupée) |
| **Récolte : céréales, tabac** | `gs_harvest` | Vrais plants (props BzZz), revente au marché de Grapeseed |
| **Récolte : pavot** (illégal) | `gs_harvest`, `gs_wanted` | Sans blip, alerte possible, receleur du port |

## V12.46 — robes, site, docs (fin de session)
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Pack de robes** | 3 zips `ROADTRIP-tenues_femme_3/4/5` | 28 robes (dans « sous-haut ») + 4 hauts, en plus du jeu (le mod d'origine remplaçait des vêtements) |
| **Site public** | `docs/site/index.html` | Carte **V5** « Dernière ligne droite avant l'ouverture » (concessions, Benny's, courses, territoires, enquêtes, mobilier, récolte, coiffures et robes) ; le teaser confidentiel devient **V6** |
| Site de doc, guide staff | priorités, section 6 | À faire mis à jour (zips à importer, récolte à vérifier) ; récolte et nouveaux vêtements expliqués au staff |
| Hachura « custom » | importeur | Rien à convertir : son dlc.rpf est lisible, IMPORTER-MODS l'ouvre seul (laisse l'archive d'origine dans mods-a-trier) |

## V12.47 — outil « magique » pour la base
| Quoi | Où | Ce que ça change |
|---|---|---|
| **REPARER-BDD.bat** | racine du dossier RoadLine | Pour `Unable to establish a connection to the database` (ECONNRESET) : un double-clic redémarre MariaDB, trouve la cause (disque plein, port pris par un autre MySQL, fichiers abîmés), répare sans rien supprimer, règle MariaDB pour qu'elle **se relance seule** si elle plante, puis relance le serveur |

## V12.48 — rapport d'import du 14/10 08:22
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Villa bunker** | importeur | `patoche_interact` était installé sous un autre nom (gsa_patoche_interact_pack) : son script ne le trouvait pas. Il est maintenant installé sous son vrai nom, et le script de la villa avec lui |
| Lace Up, « hair », natt_hair5 | importeur | Reconnus comme déjà convertis (plus « refusé » ni installé en double) ; l'ancien natt_hair5 n'est plus démarré |
| Afro de Lamar | importeur | Refusé avec sa vraie raison (personnage de l'histoire) |

## V12.49 — coiffeur
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Blush** | coiffeur (personnages femme) | Fard à joues + couleur, à côté des sourcils, du maquillage et du rouge à lèvres |

**Les 9 zips de vêtements à importer** : `coiffures_homme_2`, `_3`, `_4` · `coiffures_femme_3` · `tenues_femme_1` à `_5`.

## Ce qu'il reste à faire de ton côté
1. **METTRE-A-JOUR** (applique les retouches Qbox : pop-up police, soins), puis **METTRE-A-JOUR-OVH**.
2. **Vêtements convertis** : copie les 9 zips `ROADTRIP-…` dans `C:\GTASOON\mods-a-trier`, puis IMPORTER-MODS et
   METTRE-A-JOUR-OVH. Pack Tide et robes faits ; reste `male_hair_collection_vol_1` (optionnel) : à m'envoyer en morceaux 7-Zip de 25 Mo.
3. `patoche_villa_bunker_script_pack` : il lui faut la ressource **`patoche_interact`** (dans ton portail Cfx « Granted Assets »,
   même compte que la clé du serveur) : elle n'était pas dans l'import du 14/10.
3 bis. **Props de récolte** : reçus et branchés (V12.45) ; points des champs à vérifier en jeu (F11).
4. `lace_up_sweats` : finalement converti (c'est un vêtement femme MP, mal classé par l'importeur).
5. Placer en jeu : points du métier mécano sur la map Benny's, véhicules d'exposition + départ des essais, portes `/doorlock`.
6. Backtest allégé : 31 tests (onglet Backtest du site de doc / PDF), ★★★ d'abord.

## Nouvelles ressources de la session
`gs_showroom` (V12.40), `gs_furniture` (V12.42) — ajoutées dans `server/cfg/resources.cfg`.

## V12.50 (15/10) — retours du matin
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Tatouages** | retouches illenium (METTRE-A-JOUR) | Menu en français ; tatouage payé = gardé même sans « Sauvegarder » ; payé une seule fois |
| **Voix** | retouche pma-voice + REPARER-SON.bat | On s'entend en « Normal » (6 m) ; le son du jeu ne baisse plus pendant le vocal (réglage Windows, chez chaque joueur) |
| **Garde-robe (U)** | gs_details | La pièce s'enfile tout de suite ; une pièce d'un pack non chargé reste dans le sac au lieu d'être perdue |
| **« Spawn patate »** | gs_onboarding | 30 s de protection à l'arrivée et après une réapparition ; pas de coups ni de tirs aux points d'apparition |
| Propositions | docs/PROPOSITIONS.md (D6) | n° 108 à 117 : signatures et scripts maison gratuits |

## V12.51 (15/10) — voix, duo, coups
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Voix** | gs_radio (export officiel pma-voice) | Portées 2 / 6 / 14 m posées de façon fiable (quelle que soit la version de pma-voice), modes en français sur le HUD, radio coupée à la mort |
| **[E] qui restait** | gs_duo, gs_jobs | Après la livraison (duo) ou la fin d'une mission de métier, le texte [E] disparaît bien |
| **Spam de coups** | gs_onboarding | Un coup de poing toutes les 0,8 s au plus (fini l'enchaînement au clic) |

## V12.52 (15/10) — son du vocal pour tous
| Quoi | Où | Ce que ça change |
|---|---|---|
| **/son** | gs_onboarding, écran de chargement | Chaque joueur voit en jeu comment régler Windows (30 s) : commande /son, guide Que faire ? → Aide, rappel aux 3 premières connexions, astuce au chargement. Plus besoin de distribuer REPARER-SON |

## V12.53 (15/10) — stand de jeux, jetons, musculation
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Stand de jeux** | gs_admin (maps.js) | Ses stands étaient dans un fichier de décor donné au billard : rendu au stand ; l'entrepôt garde son herbe |
| **Jetons (auto-tamponneuses…)** | IMPORTER-MODS | Les objets qu'un script importé attend (jetons, tickets) sont ajoutés à l'inventaire s'ils manquent |
| **Musculation en prison** | gs_police | Pompes, abdos, haltères, tractions : peine réduite, meilleure forme |

## V12.54 (15/10) — arme dans le dos, caméra mécano
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Arme lourde dans le dos** | gs_details | Plus de copie figée en l'air : chaque joueur dessine les armes des autres chez lui seulement |
| **Caméra du menu mécano** | gs_tuning | On tourne autour du véhicule (flèches / Z Q S D, molette, clic droit + souris) pendant le menu |
