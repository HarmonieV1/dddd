# Patch note — session du 16/10/2026 (V12.63, depuis le matin)

> Seulement ce qui a été fait pendant cette session (du correctif des Lives jusqu'à la journée North Yankton et au site).
> Ce qui précède (nuit du 15 au 16/10 : appli staff externe, outils OVH, mur des légendes, trêves, figure du coin, diaporama du
> site…) est dans `docs/PATCH_SESSION_15-10.md`. Version prête à coller sur Discord : `docs/PATCH_NOTE_V12.63_DISCORD.txt`.
> Installation : METTRE-A-JOUR → DIAGNOSTIC-MODS (O) → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH.
> Rien n'a encore été vu en jeu : fiche de backtest, sections **4j** à **4n**.

## 1. Pour les joueurs
| Nouveauté | Comment ça marche |
|---|---|
| **Journée North Yankton** | Un jour sur deux, le vol régulier de l'aéroport (LSIA) part pour la ville enneigée du prologue de GTA V au lieu de Cayo Perico. Le comptoir et le site indiquent le vol du jour ; retour quand tu veux au comptoir d'arrivée. |
| **Photomaton** (fête foraine) | À côté du guichet des jetons : une photo souvenir pour 3 jetons. Serrez-vous dans la cabine, chacun repart avec sa copie (à regarder ou accrocher au mur). |
| **Hommage peint** (gangs) | Avec une bombe de peinture, choisir « Un hommage » : « R.I.P. » et le nom d'un membre disparu, aux couleurs du gang. 24 h, ou pour toujours contre 1 000 $ de la caisse du gang. Un rival peut l'effacer (le gang est prévenu). |
| **Voisins vigilants** | `/voisins` dans ton quartier (hors gang) : prévenu des délits qui y sont signalés (sans position) ; plus vous êtes nombreux, plus le calme revient vite. |
| **Alcootest du shérif** | La nuit, quand aucun policier n'est en service, le shérif tient parfois un barrage sur les routes hors de la ville. Positif à partir de 2 verres : amende et points de permis. Fuir = refus d'obtempérer. |
| **Gestes selon l'objet** | Alt sur un lavabo (mains, visage), une douche, une fontaine (boire) ; dans la mer, E pour se rincer. Le sang et la saleté partent ; les secours peuvent nettoyer tes plaies. |
| **Poubelles** | Une seule option : la fouille animée (l'ouverture de l'inventaire de la benne a disparu). |
| **Courses sur mesure** | L'organisateur peut imposer un véhicule ; inscription à 15 m de lui ; sur la ligne, E relance le départ et X annule. |
| **Neige et chasses au trésor** | Le staff peut faire tomber la neige sur Los Santos (traces de pas et de pneus) et cacher une mallette : zone sur la carte, le premier qui la trouve l'empoche. |
| **Menus aux couleurs de RoadLine** | Menus, notifications, fenêtres et inventaire bordés de violet néon, titres en dégradé. |
| **Courses refaites** | Plus d'écran noir ni de téléportation : voiture prêtée livrée à côté de l'organisateur, GPS jusqu'à la ligne, [E] sur la ligne pour partir, [X] pour annuler. |
| **Vue d'ensemble sur C** | Caméra autour de ton perso, qui reste immobile. F6 reste le menu des métiers. |
| **Avis de recherche papier** | Petite affiche crème « RECHERCHÉ » lisible de près ; une affiche arrachée disparaît vraiment. |
| **Traces plus parlantes** | Couteau ou batte au sol selon l'arme, douilles par balle, flaques de sang par victime ; lieux de mémoire sans icône flottante. |
| **Organisateur de courses réparé** | Au volant de ta voiture près de lui, [E] ouvre enfin son menu (avant, rien ne se passait) ; à pied, [E] à côté de lui. |
| **Gangs** | Plus de gangs créés d'office (un gang naît d'un projet RP validé par le staff) ; territoires découpés en pâtés de maisons. |
| **Cyclone** | Vitesse maximale ramenée à 210 km/h. |
| **Coincé sous la carte** | Tu es ramené tout seul au dernier endroit sûr après 6 secondes. |
| **Vols plus beaux** | L'avion vire en douceur pour s'aligner sur la piste, se pose et roule ; tu sors devant le pilote du comptoir. |
| **North Yankton : sur place** | Location de 4x4, pick-up et berline enneigés à Ludendorff ; café chaud ; et personne ne te connaît : ta recherche y retombe plus vite. |
| **Métier : animalerie** | Pôle Emploi → Animalerie : remplis les gamelles avec un carton de la réserve, nettoie les cages, toilette les chiens, sers les clients au comptoir. Payé à chaque tâche ; les animaux sont dans la boutique. |
| **Site** | « ✈️ Vol du jour » dans « En ce moment en ville » (annonce dans le bandeau les jours North Yankton) ; journal « Nouveautés » mis à jour. |

## 2. Pour le staff
| Nouveauté | Où | Ce que ça change |
|---|---|---|
| **Lives : capture réparée** | F11 → Lives, appli → Lives | screenshot-basic patché pour les versions récentes de FiveM ; si la capture échoue, la raison s'affiche après 6 s au lieu d'une attente sans fin ; F8 `/livestest` teste la capture sur ton PC. |
| **Appli staff : rangs** | GERER-OVH → 20 → A | Code personnel avec rang (5 = fondateur : agit sur tout le monde ; sinon seulement sur les rangs inférieurs). Le mot de passe collectif reste au rang modérateur. Bannir = admin minimum. |
| **Carte des tickets** | appli → Carte | Anneau jaune sur l'auteur de chaque ticket ouvert. |
| **Coincé sous la carte** | F11 → Joueurs, F10, appli | Bouton « Coincé : ramener au dernier endroit sûr » (helper et plus), en plus du retour automatique. |
| **Destination du vol de l'île** | F11 → Monde et lieux | Alternance (un jour sur deux), Cayo ou North Yankton tous les jours ; les joueurs sur place sont rapatriés à l'aéroport ; soirée plage de Cayo seulement un jour Cayo. |
| **Courses : véhicule imposé** | F11 → Monde et lieux → Courses | Sur un brouillon ou une course existante. |
| **Forme des quartiers** | `/quartierforme <quartier> <angle> [taille] [allongement 0.4-2.5]` | Rectangles de pâtés de maisons. Créer un gang : F11 → Monde et lieux → Gangs. |
| **Lives plus fluides** | F11 → Lives, appli | Une image par seconde, sans scintillement, écran entier. |
| **Pistes des vols** | F11 → Déplacer un point | « Piste LSIA / Cayo Perico · toucher / arret » à caler si l'avion se pose à côté. |
| **Animalerie : postes** | F11 → Monde et lieux → Déplacer un point | « Animalerie · Comptoir / Réserve / Gamelles / Cages / Toilettage » à placer dans la boutique (sinon rangés autour de la map). |
| **North Yankton : points** | F11 → Déplacer un point | Location de Ludendorff, café, serveuse, shérif, comptoir du retour : à caler si besoin (seulement les jours North Yankton). |
| **Journal staff** | F10 → Journal | Hommages peints, coincés ramenés, choix de destination du vol. |
| **Mises en scène** (admin) | F11 → fiche → Mises en scène, F10 → fiche | Enlèvement en camionnette (= expulsion, écran noir) ; arrestation par un policier PNJ (plaqué, menotté, cellule de Mission Row). |
| **Événements rangés** | F11 → Événements | Rassemblements (+ rassemblement auto, soirée en club, salon de l'emploi), chasse au trésor (prime au premier), neige, effets « sur moi » (feux d'artifice, confettis, fumée). |
| **QG de gang** | F11 → Mappings installés → QG de gang | Changer les couleurs d'un QG de map (ex. Patoche Vagos → Ballas) chez tous les joueurs. |
| **Mises en scène fiabilisées** | F11 → fiche | Camionnette « speedo » posée à côté (plus de conduite IA, burrito3 importé au handling illisible écarté), policier qui arrive à coup sûr. |
| **Branding** | menus de base | Contour violet néon des Lives sur les menus F11, notifications, saisies, inventaire et F10 ; titres en dégradé RoadLine. |
| **Appli installable** | appli → écran de connexion | Bouton « 📲 Installer l'appli » (PC, Android) ou Partager → « Sur l'écran d'accueil » (iPhone) : icône au logo RoadLine, plein écran. |
| **Surveillance** (admin) | F11 → fiche, F10 → fiche, appli → fiche | Motif ; le staff en service est prévenu à chacune de ses arrivées ; 👁 dans les listes. |
| **Fermer les arrivées** (super-admin) | F11 → Modération avancée, F10 → Serveur, appli → Sanctions | Raid ou attaque : seul le staff entre, 60 min maximum, rouvre seul. |
| **Partis récemment → ban hors ligne** | mêmes endroits | Le joueur qui quitte juste après un RDM se bannit quand même (super-admin en jeu, admin dans l'appli). |
| **Contournement de ban** | automatique | Un nouveau compte qui arrive avec le PC ou le Discord d'un banni = alerte au staff (ou refus : `Config.Moderation.evasion`). |

## 3. Pour le fondateur (serveur, mods, docs)
| Quoi | Ce que ça change |
|---|---|
| **Démarrage plus rapide** | Plus de gel de ~11 s après chaque démarrage : les maps en conflit ne sont relancées que si leur ordre de démarrage n'est pas déjà le bon. |
| **DIAGNOSTIC-MODS** | **Même map en deux versions** (archive « _1 » retéléchargée) : la version _1 en pause, l'original déjà réglé reste ; section **textures / modèles ≥ 32 Mo** (IMPORTER-MODS allège déjà seul les .ytd > 48 Mo). |
| **Nouvelles maps du jour** | Shadow Complex revient (archive _1 ; la raison de son retrait — Plasmakart — n'existe plus) ; animalerie _1 = copie d'un pack déjà réglé → mise en pause par DIAGNOSTIC-MODS. |
| **Docs** | État des lieux avant l'ouverture (`docs/ETAT_DES_LIEUX_16-10.md`), propositions n° 167 à 246 (dont 45 nouvelles ce soir), guides, fiche de backtest (4j), documentation à jour. |

## 4. Encore à faire / à vérifier
- **Positions à caler en jeu** (F11 → Monde et lieux → Déplacer un point) : photomaton (gs_casino), postes de l'animalerie (gs_animalerie), location de Ludendorff (gs_rental), café et comptoir du vol retour à North Yankton (gs_world).
- **À confirmer en jeu** : Lives (F11 et appli), animations des gestes « visage » et « boire », décor et neige de North Yankton, barrage du shérif, hommage peint.
- **Code cfx.re** du serveur (txAdmin → tableau de bord, ou liste FiveM en mode public : GERER-OVH → 7) pour le bouton « Rejoindre » du site.
- **Code personnel fondateur** pour l'appli : GERER-OVH → 20 → A, rang 5.
