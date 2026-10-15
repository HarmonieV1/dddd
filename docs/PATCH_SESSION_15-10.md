# Patch récap — session de secours du 15/10/2026 (V12.59 → V12.62)

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
| **Docs** | guides, backtest « 4g », bilan, site | 40 signatures, guides joueur et staff à jour |

## Encore en attente (côté fondateur)
- `shared/config.lua` du script des auto-tamponneuses si l'achat bloque encore ;
- dossier `mods-tri\a-convertir` (vêtements solo) en morceaux de 25 Mo — ou intégrer le convertisseur à IMPORTER-MODS après le backtest ;
- Emerus GTR et Tempesta widebody à retélécharger (archives coupées) ;
- positions à caler en jeu : guichet des jetons, carré du cimetière ;
- carte F10 en direct (après le test du gros patch) ; fusion dans `feature/phase1-bridge` sur accord.
