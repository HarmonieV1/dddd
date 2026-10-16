# Patch récap — session de secours du 15-16/10/2026 (V12.59 → V12.63)

> Branche `claude/presence-check-f9jlgz` (pas encore fusionnée dans `feature/phase1-bridge`). Détail technique de chaque
> version : `docs/ETAT_PROJET.md` (historique). À tester en jeu : backtest sections **4d, 4e, 4f, 4g** (site de doc).
> Installation : METTRE-A-JOUR → DIAGNOSTIC-MODS (O) → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH.

## V12.59 — retours du backtest du 15/10
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Importeur de mods fiabilisé** | IMPORTER-MODS | Zips Google Drive en plusieurs morceaux, mods sans fxmanifest, doublons à l'octet près, dossiers et volumes `.7z.001` / `.part1.rar`, voitures avec leur script de noms, robes FiveM plus refusées à tort |
| **Balle dans la tête** | `gs_details` | Mort immobile (plus d'animation bizarre) ; casque : protège d'**une** balle seulement |
| **Arme dans le dos** | `gs_details` | Se ré-accroche toute seule |
| **Emotes rapides** | scully_emotemenu | Pavé numérique 1 à 5 ; **M** = se laisser tomber (ragdoll) ; `/vue` (caméra RP) |
| **Mémoire de la ville** | `gs_scars` | Sang + douilles là où quelqu'un tombe (plus de bougies), barrières après un braquage, tout s'efface en 24 h, texte discret |
| **Effets « sur moi »** | F11 → Événements | Super vitesse voiture, voiture sauteuse, arc-en-ciel, caméra ivre ; événements généraux hors RP retirés |
| **Persos GTA** | F11 | N'importe quel modèle par son nom |
| **Caméras** | `gs_cctv` | Boîtiers du décor peignables (gangs) ; au terminal LSPD : ← → caméra suivante |
| **Police IA** | `gs_wanted` | Poursuit vraiment (sans attendre de te voir), seulement sans policier joueur en service, jamais pour les braquages |
| **Bot Discord** | `gs_discord` | Accueils rattrapés, #statut expliqué, plus de « Joue à Qbox » (présence RoadLine) |
| **Site** | `docs/site` | Bandeau Weazel avec les vrais articles écrits en jeu |
| **Courses sur mesure** | `gs_races` | Correctifs de l'organisateur |

## V12.60 — outils et nouveautés du soir
| Quoi | Où | Ce que ça change |
|---|---|---|
| **DIAGNOSTIC-MODS.bat** | `scripts/windows` | Fichiers abîmés (crash « Invalid fixup »), vêtements en conflit, voitures en double, fichiers en double, lignes mortes ; corrections sûres avec copie |
| **Blips en double** | F11 → Monde et lieux | Repère et retire les blips posés deux fois |
| **Cimetière** | `gs_cimetiere` (nouveau) | Tombes, épitaphe, avis de décès (Weazel + Gazette), fleurs 25 $ ; F11 → Mort RP (le personnage n'est jamais supprimé) |
| **Cabines téléphoniques** | `gs_cabines` (nouveau) | Appel anonyme au central police ou tuyau à Weazel, 1 $ |
| **Lives staff** | `gs_lives` (nouveau) · `/lives` | Écran des joueurs dans des fenêtres déplaçables, journalisé |
| Propositions | `docs/PROPOSITIONS.md` | n° 132 à 146 (section D8) |

## V12.61 — premier jour, cabines, samedi, rapport staff
| Quoi | Où | Ce que ça change |
|---|---|---|
| **screenshot-basic** | `[gtasoon]` | Livré déjà compilé : Lives, photos Vibe, bodycam sans rien installer |
| **Appel masqué** | `gs_cabines`, `gs_phone` | Appeler un joueur depuis une cabine : il voit « Numéro masqué » |
| **Écoute police** | `gs_cabines` | Policier grade 2+ : cabine sur écoute 2 h (5 max), l'appel suivant arrive au central |
| **Rodéo du samedi** | `gs_wanted` | Samedi 20 h → 3 h : +1 étoile rodéos / vols de voiture, +1 patrouille IA, annonce en jeu + Discord |
| **Rapport staff** | `gs_discord` | Chaque jour à 4 h dans le salon staff : joueurs max, tickets, sanctions, alertes, Lives, crimes, morts RP ; `/rapportstaff` |
| **Premier jour** | `gs_quests` | Mairie → location → banque → Pôle Emploi → **téléphone acheté** à la supérette → Max ; plus de téléphone donné à l'arrivée |
| **Site** | `docs/site` | V1 → V4 condensées en « Les fondations », 39 signatures |

## V12.62 — idées choisies + relecture complète avant le backtest
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Lives en grille + TP** | `gs_lives` | ▦ range les fenêtres ; « ⇢ TP » sur une fenêtre = se téléporter près du joueur |
| **Replay 30 s** | `gs_lives`, `gs_admin` | `/report 12 …` : tant que le ticket est ouvert, ⏪ rejoue les 30 dernières secondes de l'auteur et du joueur nommé (en mémoire seulement) |
| **Scène de crime** | `gs_evidence` | Photo avec sang / douilles → au labo, pièce « Scène de crime » au dossier (recevable au tribunal) |
| **Poursuite filmée** | `gs_wanted`, `gs_city`, site | Hélico de la police IA à 3 ★ (projecteur la nuit), Weazel prévenu, « EN DIRECT » sur le bandeau du site (quartier seulement) |
| **Jetons de fête foraine** | `gs_casino` | Guichet Del Perro (à caler F11) + caisse du casino : 5 $ / repris 4 $, 10 jetons = 1 ticket à gratter, échange avec les jetons d'auto-tamponneuse |
| **Auto-tamponneuses** | `ox_items_gtasoon.lua` | Objet `bumpton` ajouté (l'achat échouait faute d'objet) ; à confirmer avec `shared/config.lua` du script si ça bloque encore |
| **Relecture (13 corrections)** | plusieurs | ← → des caméras ne fait plus expulser le policier ; mod mis en pause par le diagnostic plus réactivé ; une capture Lives par joueur ; rapport staff juste après un redémarrage ; mémoire bornée ; police IA (réglage lu, ordre au conducteur) ; cabines, effets staff, avis de décès |
| **METTRE-A-JOUR-OVH** | `scripts/windows` | Installation en tâche de fond sur le VPS (une coupure ne l'arrête plus), envoi interrompu repris sans renvoyer 1 Go, réussite bien reconnue |
| **DIAGNOSTIC-MODS** | `scripts/windows` | Met aussi en pause les **voitures en double** (copie la plus complète gardée, jamais une voiture unique perdue) |
| **Concessions** | `gs_showroom` | Véhicules d'exposition posés au sol ; « Changer le modèle » s'affiche tout de suite (avant : chargement sans fin si le vendeur restait collé) ; modèle introuvable signalé ; sans vendeur en service, un civil peut choisir le modèle exposé |
| **Console (backtest)** | `gs_discord`, `gs_wanted` | Erreur JSON du rapport staff et « invalid entity » de la police IA corrigées |
| **Docs** | guides, backtest « 4g », bilan, site | 40 signatures, guides joueur et staff à jour |

## V12.63 — appli staff externe et carte F10
| Quoi | Où | Ce que ça change |
|---|---|---|
| **Appli staff** | `gs_admin/web/src/staff`, `server/web.lua` | Tableau de bord pour tablette / téléphone / PC : joueurs, carte en direct, fiches, Lives hors jeu, tickets, sanctions, journal (`docs/APPLI_STAFF.md`) |
| **Mot de passe collectif** | GERER-OVH → 20 → M | Chacun se connecte avec son pseudo ; anciens codes effacés ; jamais dans le dépôt |
| **Toutes les actions** | `Admin.remote` | Soigner, réanimer, réparer, téléporter, geler, isoler, avertir, expulser, bannir (1-30 j / définitif), débannir, tickets, annonce |
| **Lives hors jeu** | `web.lua`, `gs_lives` | Écrans des joueurs dans l'appli (jusqu'à 4), replays 30 s des tickets |
| **F10** | `gs_admin/web` | Recompilé : onglet **Carte** avec les joueurs en direct |
| **Lives réparé** | `gs_lives` | Plus de « connexion » sans fin : capture faite chez le joueur et renvoyée par le réseau du jeu ; F11 et l'appli voient la même image |
| **Appli staff : connexion** | `gs_admin/server/crypto.js` | « Connexion indisponible (crypto du serveur) » corrigé : le fichier des jetons plantait au démarrage (nom en double avec maps.js) ; contrôle automatique ajouté |
| **Site** | `docs/site` | Diaporama de photos de la ville (glisser, animé, sans légende), bande-annonce TikTok, adresse du serveur affichée pour les testeurs, « Choisis ta vie » à jour |
| **Gazette en direct** | `gs_city`, `gs_wanted`, site | Le site montre l'édition de la semaine en cours (plus besoin d'attendre dimanche) ; poursuites filmées et avis de recherche comptés |
| **Lives : diagnostic** | `gs_lives` | Plus d'attente muette : la raison d'un échec s'affiche dans la fenêtre (F11 et appli) et dans la console ; « (toi : test) » pour vérifier seul |
| **Outils OVH** | `scripts/windows` | GERER-OVH ne plante plus (« roadline-envoi.txt en cours d'utilisation ») ; METTRE-A-JOUR-OVH ne renvoie plus les gros fichiers déjà présents sur le VPS (fini le 1 Go à chaque fois) ; avancée affichée pendant l'envoi (Mo, %, temps restant) ; envoi coupé **complété** au lieu d'être recommencé ; GERER-OVH ne renvoie la commande roadline que si elle a changé et ouvre le menu même si l'envoi échoue, sans plus jamais toucher au serveur pendant une mise à jour (verrou) |

## Encore en attente (côté fondateur)
- `shared/config.lua` du script des auto-tamponneuses si l'achat bloque encore ;
- dossier `mods-tri\a-convertir` (vêtements solo) en morceaux de 25 Mo — ou intégrer le convertisseur à IMPORTER-MODS après le backtest ;
- Emerus GTR et Tempesta widebody à retélécharger (archives coupées) ;
- positions à caler en jeu : guichet des jetons, carré du cimetière ;
- fusion dans `feature/phase1-bridge` sur accord.
