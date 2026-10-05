# Roadmap · où on en est, où on va

*Mis à jour le 05/10/2026 au soir · **V11.2** prête (V11 en ligne sur le VPS OVH · bêta privée, 16 places).*

## Où on en est
| Brique | État |
|---|---|
| **Jeu** | Qbox/ox, 66 ressources RoadLine, **24 signatures**, 2 500+ tests automatiques au vert |
| **Serveur officiel** | VPS OVH (Ubuntu 24.04, 12 Go RAM, 96 Go disque) ; démarrage auto, veille (alerte Discord + relance), redémarrage 6 h annoncé, sauvegardes 6 h + copie quotidienne sur le PC |
| **Outils** | PC = test (METTRE-A-JOUR), VPS = officiel (METTRE-A-JOUR-OVH) ; GERER-OVH : 22 options, sans mot de passe |
| **Modération** | Appli staff sur téléphone (https, codes par membre) pour les modérateurs ; menu F11 en jeu ; bot Discord ; txAdmin réservé au fondateur |
| **Site** | Bêta ouverte, adresse de connexion, carte en direct + timelapse 24 h branchés sur le VPS, lien Espace staff |
| **Docs** | Guide, fiche de backtest (81 tests, 26 bloquants), bilan V11, OVH / ADMIN / DISCORD / FEATURES à jour |

## Où on va
| Quand | Objectif | Contenu |
|---|---|---|
| **Cette semaine** | **Backtest** | Fiche PDF ; chaque jour : GERER-OVH → 3 (erreurs) + captures avec le n° du test ; je corrige au fil de l'eau |
| **Semaine prochaine** | **V11.1 · Appli staff v2** | Voir ci-dessous (boutons, raccourcis, fiches joueurs, sanctions). Fait (V11.2) : écran de chargement complet, jurés, Gazette, black-out, vraie carte sur le site |
| **Avant l'ouverture** | **V12 · Ouverture** | Corrections du backtest, passage en public (code cfx.re, liste FiveM), whitelist ou non, nom de domaine, 2 signatures « waouh » |
| **Après l'ouverture** | **Saison 1** | Événements staff, élections, contenus du mois, boutique (après validation PLA) |

## V11.1 · Appli staff v2 (proposition précise)
**Accueil en tuiles** (gros boutons, pas une barre de recherche) :
- **En ville** : nombre de joueurs, staff en service, tickets ouverts, alertes anti-triche.
- **Tickets** : priorité (nouveau, pris, en retard), puis « Je prends », « Répondre » ou « Clore ».
- **Alertes** : carkill, téléportation, argent suspect. Un appui ouvre la fiche du joueur concerné.
- **Annonce** : modèles prêts (« redémarrage dans 10 min », « événement à Legion Square »…).

**Fiche joueur** (un appui sur un joueur) : identité RP, temps de jeu, métier et gang, **historique des sanctions**, notes du staff. Actions en boutons de couleur :
- **Geler** et **Message** ;
- **Avertir**, avec les motifs fréquents déjà proposés ;
- **Expulser** ;
- **Bannir** (1 jour, 3 jours, 7 jours ou définitif), réservé aux admins.

**Filtres en pastilles** : tous, nouveaux joueurs, police / EMS, gangs, signalés, gelés.

**Journal** : qui a fait quoi, et quand (« Web · pseudo »), consultable par les admins.

**Droits** : helper, modo et admin voient des boutons différents selon leur rang (le même rang qu'en jeu).

**Confort** : thème RoadLine, vibration sur les nouveaux tickets, mode sombre, utilisable d'une main.

## 20 idées de signatures (à trier)
Note : 1 = rapide, 3 = gros chantier. ★ = branché sur ce qui existe déjà.

**La ville raconte**
1. ✅ **Les jurés de Los Santos** ★ (2) — pour un vrai procès, 5 citoyens tirés au sort reçoivent une convocation sur leur téléphone. Ils écoutent, ils votent, et le verdict tombe dans le fil de la ville.
2. ✅ **La Gazette du dimanche** ★ (2) — un journal mis en page tout seul (faits divers, verdicts, légendes, plaques, photos Weazel), publié sur le site et sur Discord.
3. **Le grand livre de Los Santos** ★ (2) — une page publique par personnage marquant (avec son accord) : biographie, légendes, plaques. Un « wiki » du serveur qui s'écrit en jouant.
4. **La galerie Weazel** ★ (1) — les photos de presse choisies par les journalistes sont exposées sur le site, avec légende et signature.

**La ville réagit**

5. ✅ **Black-out de quartier** (2) — saboter un transformateur plonge un quartier dans le noir (lumières, feux, caméras). C'est une occasion pour le crime, et les électriciens de la ville réparent.
6. **La ville a peur** ★ (1) — après une fusillade ou un gros casse, les PNJ fuient la zone, les commerces baissent le rideau une heure et la radio en parle.
7. **Files d'attente vivantes** ★ (1) — des PNJ font la queue devant les commerces qui marchent. Le succès se voit dans la rue.
8. **Avis clients** ★ (2) — les clients (joueurs et PNJ) notent les commerces dans le téléphone. Les étoiles font venir ou fuir la clientèle PNJ.

**La rue et la justice**

9. **Les objets ont un passé** ★ (2) — bijoux, montres et armes gardent leur historique. Le receleur paie moins cher un objet « trop connu », et c'est une preuve au tribunal.
10. **Le portrait-robot** ★ (2) — un témoin joueur compose le visage d'un suspect (coiffure, couleurs, signes distinctifs), et la police l'affiche au commissariat.
11. **La bourse aux tuyaux** (2) — les indics vendent des informations (convoi, planque, rendez-vous) avec un indice de fiabilité. Certaines sont fausses.
12. **Convois officiels** (3) — transferts de fonds ou de prisonniers annoncés à l'avance. La police les protège, les braqueurs les préparent.

**La vie civile**

13. **Élections municipales** (3) — campagne, débats Weazel, vote. Le maire actionne 3 vrais leviers : taxe des commerces, couvre-feu, budget de la police.
14. **Appels d'offres de la mairie** ★ (2) — chaque semaine, un chantier public est mis aux enchères. L'entreprise de joueurs qui le décroche le construit vraiment sur la carte (gs_builder).
15. **Courrier et lettres** (2) — des lettres papier (objet) avec cachet, un facteur joueur, des lettres anonymes et des colis suspects.
16. **Pompes funèbres et héritage** (3) — un métier de croque-mort, des cérémonies, le testament, une tombe avec son épitaphe (et la page au grand livre).

**Le jeu dans le jeu**

17. **Fantômes de la route** ★ (2) — la voiture fantôme du meilleur temps de la semaine sur le road trip et les courses.
18. **Réputation de quartier** ★ (2) — chaque joueur est « connu » dans certains quartiers : les PNJ le saluent, se méfient de lui ou appellent la police plus vite.
19. **Caméra de plateau Weazel** (3) — un mode réalisateur pour les directs : plans fixes, ralentis, bandeau, à suivre sur Twitch.
20. **Soirées à thème du serveur** ★ (1) — une nuit par mois avec une règle spéciale (années 80, tempête, coupure générale), annoncée sur le site et dans l'écran de chargement.

**Notre sélection pour l'ouverture** : ✅ les jurés (1), ✅ la Gazette (2), ✅ le black-out de quartier (5) ; restent la ville a peur (6) et les objets ont un passé (9).

## Rappels
- Jamais de vraie marque, ni de mot de passe dans les fichiers ou les messages.
- PC = test, VPS = officiel : METTRE-A-JOUR, test rapide, puis METTRE-A-JOUR-OVH (il vérifie la version et répare ce qu'il faut).
