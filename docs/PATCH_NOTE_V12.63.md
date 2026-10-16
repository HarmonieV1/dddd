# Patch note — mise à jour du 16/10/2026 (V12.63)

> Tout ce qui a changé depuis le patch note du 15/10 (V12.59 → V12.62), soit de la nuit du 15 au 16/10 jusqu'au 16/10 au soir.
> Version interne **V12.63** (F11, console) ; les joueurs voient toujours la version publique (règle des deux numéros,
> `docs/ETAT_PROJET.md` §2). Version prête à coller sur Discord : `docs/PATCH_NOTE_V12.63_DISCORD.txt`.
> Installation : METTRE-A-JOUR → DIAGNOSTIC-MODS (O) → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH.
> Rien n'a encore été vu en jeu : à vérifier avec la fiche de backtest, sections **4h, 4i, 4j**.

## 1. Pour les joueurs

### Nouveaux lieux et activités
| Nouveauté | Comment ça marche |
|---|---|
| **Journée North Yankton** | Un jour sur deux, le vol régulier de l'aéroport (LSIA) part pour la ville enneigée du prologue de GTA V au lieu de Cayo Perico. Le comptoir et le site indiquent le vol du jour ; retour quand tu veux au comptoir d'arrivée. |
| **Photomaton** (fête foraine) | À côté du guichet des jetons : une photo souvenir pour 3 jetons. Serrez-vous dans la cabine, chacun repart avec sa copie (à regarder ou accrocher au mur). |
| **Mur des légendes** | Devant le commissariat de Mission Row : les noms de ceux qui ont tenu une cavale, le dernier écrit au-dessus. |

### La rue et les gangs
| Nouveauté | Comment ça marche |
|---|---|
| **Hommage peint** | Avec une bombe de peinture, un membre de gang choisit « Un hommage » : « R.I.P. » et le nom d'un disparu, aux couleurs du gang. 24 h, ou pour toujours contre 1 000 $ de la caisse du gang. Un rival peut l'effacer (le gang est prévenu). |
| **Trêve entre gangs** | Menu Gang → Trêves (cadres) : 48 h sans guerre. Mettre l'un des leurs à terre la rompt, et la réputation du gang fautif s'effondre dans toute la ville. |
| **Affiches de cavale** | Pendant une cavale, une affiche est collée là où elle a commencé. L'arracher coûte 300 $ d'amende (gratuit pour la police) ; recollée 30 min plus tard. |
| **Quartiers de gangs** | Les territoires suivent maintenant les pâtés de maisons (rectangles) au lieu de grands cercles. |
| **Gangs sur projet** | Plus de gangs créés d'office : un gang naît d'un projet RP validé par le staff (ticket). |

### Ton quartier
| Nouveauté | Comment ça marche |
|---|---|
| **Voisins vigilants** | `/voisins` dans ton quartier (hors gang) : tu es prévenu des délits qui y sont signalés (sans position), et plus vous êtes nombreux, plus le calme revient vite. |
| **Figure du coin** | Tes missions, achats et ventes dans un quartier font monter ta cote. Au-delà d'un seuil, les habitants te saluent et les commerces du quartier te font 5 % de remise. |
| **Avis du commerçant** | Un commerce braqué filmé par sa caméra affiche 24 h un avis avec une image floue du braqueur (deux détails de sa tenue, jamais son nom). |

### Police, route et vie quotidienne
| Nouveauté | Comment ça marche |
|---|---|
| **Alcootest du shérif** | La nuit, quand aucun policier n'est en service, le shérif tient parfois un barrage sur les routes hors de la ville. Positif à partir de 2 verres : amende et points de permis. Fuir = refus d'obtempérer. |
| **Fausse alerte** | Un faux appel à la police depuis une cabine coûte 2 500 $ si l'appel est retrouvé (cabine sur écoute ou filmée). |
| **Gestes selon l'objet** | Alt sur un lavabo (mains, visage), une douche, une fontaine (boire) ; dans la mer, E pour se rincer. Le sang et la saleté partent ; les secours peuvent nettoyer tes plaies. |
| **Poubelles** | Une seule option : la fouille animée (l'ouverture de l'inventaire de la benne a disparu). |
| **Courses sur mesure** | L'organisateur peut imposer un véhicule ; inscription à 15 m de lui ; sur la ligne, E relance le départ et X annule. |
| **Concessions** | Les véhicules d'exposition sont posés au sol ; tu peux faire défiler les modèles même sans vendeur en service. |
| **Cyclone** | Vitesse maximale ramenée à 210 km/h. |
| **Coincé sous la carte** | Tu es ramené tout seul au dernier endroit sûr après 6 secondes. |

### Le site
- Diaporama « La ville » (9 photos), bande-annonce, adresse du serveur affichée pour se connecter.
- La Gazette du site montre l'édition **de la semaine en cours** (cavales, poursuites filmées, avis de recherche) sans attendre dimanche.
- « En ce moment en ville » : le **vol du jour** (Cayo Perico ou North Yankton).
- Journal « Nouveautés » mis à jour.

## 2. Pour le staff

| Nouveauté | Où | Ce que ça change |
|---|---|---|
| **Appli staff externe** | adresse `/gs_admin/` (tablette, téléphone, PC) | Tableau de bord, carte en direct, fiches complètes, Lives hors jeu, tickets, sanctions (avertir → bannir / débannir), journal, annonce. Guide : `docs/APPLI_STAFF.md`. |
| **Connexion à l'appli** | GERER-OVH → 20 | **M** = mot de passe collectif (rang modérateur) ; **A** = code personnel avec rang (5 = fondateur : agit sur tout le monde ; sinon seulement sur les rangs inférieurs). Bannir = admin minimum. |
| **Carte en direct** | F10 → Carte, appli → Carte | Tous les joueurs en direct ; anneau jaune = auteur d'un ticket ouvert. |
| **Lives réparés** | F11 → Lives, appli → Lives | Capture faite chez le joueur et renvoyée par le réseau du jeu ; une seule capture partagée entre F11, l'appli et les replays ; si l'image ne vient pas, la fenêtre dit pourquoi ; ta ligne « (toi : test) » pour vérifier seul ; F8 `/livestest` pour tester ton PC. |
| **Coincé sous la carte** | F11 → Joueurs, F10, appli | Bouton « Coincé : ramener au dernier endroit sûr » (niveau helper) ; retour automatique après 6 s sous la carte. |
| **Destination du vol de l'île** | F11 → Monde et lieux | Alternance (un jour sur deux), Cayo tous les jours ou North Yankton tous les jours ; les joueurs sur place sont rapatriés à l'aéroport. Soirée plage de Cayo : seulement un jour Cayo. |
| **Courses : véhicule imposé** | F11 → Monde et lieux → Courses | Sur un brouillon ou une course existante. |
| **Forme des quartiers** | `/quartierforme <quartier> <angle> [taille] [allongement 0.4-2.5]` | Rectangles de pâtés de maisons. Gangs : F11 → Monde et lieux → Gangs. |
| **Fausse alerte** | Police : `/faussealerte <n°>` | Sur un appel anonyme de cabine : amende si l'appelant est retrouvé. |
| **Journal staff** | F10 → Journal | Hommages peints, voisins vigilants, coincés ramenés, choix de destination, actions de l'appli (« Web · pseudo »). |

## 3. Pour le fondateur (outils, serveur, mods)

| Quoi | Ce que ça change |
|---|---|
| **Démarrage plus rapide** | Plus de gel de ~11 s après chaque démarrage : les maps en conflit ne sont relancées que si leur ordre de démarrage n'est pas déjà le bon. |
| **METTRE-A-JOUR-OVH** | Ne renvoie plus les gros fichiers déjà présents sur le VPS (fini le 1 Go à chaque fois) ; avancée affichée (Mo, %, temps restant) ; envoi coupé **complété** au lieu d'être recommencé ; connexion en IPv4 (coupures en IPv6) ; repère un correctif du zip pas encore installé sur le PC et propose METTRE-A-JOUR avant l'envoi. |
| **GERER-OVH** | Ne plante plus (« fichier d'envoi en cours d'utilisation ») ; ne renvoie la commande roadline que si elle a changé ; ouvre le menu même si cet envoi échoue ; ne redémarre plus le serveur pendant une mise à jour (verrou). |
| **Appli staff : connexion** | « Connexion indisponible (crypto du serveur) » corrigé (fichier des jetons qui plantait au démarrage) + contrôle automatique pour que ça ne revienne pas. |
| **DIAGNOSTIC-MODS** | Copies en double mises en pause ; **même map en deux versions** (archive « _1 » retéléchargée) : la version _1 en pause, l'original déjà réglé reste ; section **textures / modèles ≥ 32 Mo** (IMPORTER-MODS allège déjà seul les .ytd > 48 Mo). |
| **Nouvelles maps du 16/10** | Shadow Complex revient (archive _1 ; la raison de son retrait — Plasmakart — n'existe plus) ; animalerie _1 = copie d'un pack déjà réglé → mise en pause par DIAGNOSTIC-MODS. |
| **screenshot-basic** | Patché pour les versions récentes de FiveM (rappel en https, repli http, demande traitée même si l'écran ne se redessine pas). |
| **Correctifs console** | Rapport staff (JSON), police IA (« invalid entity »). |

## 4. Encore à faire / à vérifier
- **Positions à caler en jeu** (F11 → Monde et lieux → Déplacer un point) : photomaton et guichet des jetons (gs_casino), comptoir du vol retour à North Yankton (gs_world), carré du cimetière.
- **À confirmer en jeu** : Lives (F11 et appli), animations des gestes « visage » et « boire », décor et neige de North Yankton, barrage du shérif, hommage peint.
- **Code cfx.re** du serveur (txAdmin → tableau de bord, ou liste FiveM en mode public : GERER-OVH → 7) : à donner pour le bouton « Rejoindre » du site.
- **Code personnel fondateur** pour l'appli : GERER-OVH → 20 → A, rang 5.
- **Test de charge** (10 joueurs ou plus, 45 min, `/perfserveur` et resmon) avant l'ouverture.
