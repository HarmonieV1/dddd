# Micro-guide du staff RoadLine RP (PDF interne, 4 pages) : rangs, outils, tickets, sanctions, faire vivre la ville.
# Lancer depuis la racine : python3 tools/guide_staff.py → docs/pdf/ROADLINE_Guide_staff.pdf
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
import guide_joueur as G

OUT = 'docs/pdf/ROADLINE_Guide_staff.pdf'


def page(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(G.DARK)
    canvas.rect(0, A4[1] - 7 * mm, A4[0], 7 * mm, stroke=0, fill=1)
    canvas.setFillColor(G.PINK)
    canvas.setFont(G.BOLD, 7.5)
    canvas.drawString(15 * mm, A4[1] - 4.8 * mm, 'ROADLINE RP · GUIDE DU STAFF · CONFIDENTIEL')
    canvas.setFont(G.FONT, 7.5)
    canvas.setFillColor(G.GREY)
    canvas.drawString(15 * mm, 9 * mm, 'Document interne : ne pas partager aux joueurs.')
    canvas.drawRightString(A4[0] - 15 * mm, 9 * mm, f'page {doc.page}')
    canvas.restoreState()


def build():
    P, H1, H2, H3, LEAD, SMALL, KICK = G.P, G.H1, G.H2, G.H3, G.LEAD, G.SMALL, G.KICK
    t, b, st = G.table, G.bullets, G.steps
    s = [Paragraph('STAFF', KICK), Paragraph('Le micro-guide du staff', H1),
         Paragraph('Tout ce qu\'il faut pour modérer RoadLine en 10 minutes de lecture. Notre boulot : que les joueurs passent une bonne '
                   'soirée et que les règles soient les mêmes pour tous. <b>Calme, neutre, rapide, et toujours avec une trace.</b>', LEAD),
         Spacer(1, 6)]

    s += [Paragraph('1. Les rangs', H2)]
    s += [t([['Rang', 'Ce que tu peux faire'],
             ['Helper', 'Tickets (prendre, répondre, clore), aller au joueur, lire sa fiche, mode staff (noms et ID).'],
             ['Modérateur', '+ amener, soigner, réanimer, figer, spectate, vol libre, invisible, réparer / supprimer un véhicule, effacer une recherche, '
              'note staff, <b>avertir, isoler, expulser</b>. Valider les rumeurs (/rumeurvraie, /rumeurfausse).'],
             ['Admin', '+ métiers et gangs (soi ou un joueur), apparition de véhicules, points de métier, météo, annonces, événements, '
              '/plaque, /gazettepublier, statistiques.'],
             ['Super-admin', '+ donner de l\'argent (100 000 $ max) ou des objets (100 max), <b>motif obligatoire</b> ; objets du décor.'],
             ['Fondateur', '+ rangs du staff, txAdmin (console, bans longs), VPS (GERER-OVH).']],
            [28 * G.mm, 152 * G.mm])]
    s += [Paragraph('Un rang se donne en jeu par le fondateur : F11 → Joueurs → le joueur → Rang staff. On ne sanctionne jamais un staff '
                    'de rang égal ou supérieur (le serveur refuse et le journalise).', SMALL)]

    s += [Paragraph('2. Tes outils', H2)]
    s += [t([['Outil', 'À quoi il sert'],
             ['F11 · menu staff rapide', 'Le couteau suisse en jeu : Joueurs, Moi, Véhicules, Monde et lieux, Événements, Anti-triche. '
              'Les pouvoirs ne marchent qu\'en <b>mode staff</b> (1re ligne) ; le couper coupe tout.'],
             ['Raccourcis (mode staff)', 'Ctrl+Y : TP au marqueur · Ctrl+U : vol libre · Ctrl+O : noms et ID · Retour : quitter le spectate'],
             ['F10 · panel', 'Tickets, fiches joueurs complètes, sanctions, journal, et <b>Carte</b> : tous les joueurs en direct (V12.63).'],
             ['Appli staff (tablette, téléphone, PC)', 'Adresse /gs_admin/ du serveur (« Ajouter à l\'écran d\'accueil » = une appli). Ton <b>pseudo</b> + le '
              '<b>mot de passe collectif</b> (donné par le fondateur). Tableau de bord, carte en direct, fiches, Lives (écrans des joueurs, replays des tickets), '
              'soigner, réanimer, réparer, téléporter, geler, isoler, avertir, expulser, <b>bannir</b> (1 à 30 jours ou définitif), débannir, tickets, annonce. '
              'Tout est signé « Web · ton pseudo » dans le journal. 5 mauvais mots de passe = 15 min de blocage.'],
             ['Bot Discord', '/joueurs, /geler, /degeler, /avertir, /expulser, /message, <b>/annonce</b> (texte, titre, mention @everyone / @here, en_jeu pour l\'afficher aussi en ville), <b>/isoler, /liberer, /reanimer</b> (rôle staff ou admin du Discord) quand tu n\'es pas en jeu. Joueurs : /aide (/help), /ip, /ticket, /fermer.'],
             ['txAdmin', 'Réservé au fondateur.']],
            [40 * G.mm, 140 * G.mm])]

    s += [Paragraph('3. Traiter un /report', H2)]
    s += st(['Passe <b>en service</b> (/staff) : tu reçois les tickets avec un son.',
             '<b>Prends</b> le ticket (les autres voient qu\'il est pris) et réponds au joueur : « Je regarde ça ».',
             '<b>Observe avant d\'agir</b> : spectate ou mode staff invisible, fiche du joueur, demande les clips. Ne coupe pas une scène qui tourne bien.',
             '<b>Décide</b> : rien à signaler, rappel à l\'ordre, ou sanction (motif obligatoire, voir barème).',
             '<b>Clos</b> le ticket avec une phrase claire. Un cas compliqué : passe la main à un rang au-dessus, sans débattre devant les joueurs.'])
    s += [G.tip('En scène : intervenir en HRP le moins possible. Un message privé ou une pause demandée poliment vaut mieux qu\'une téléportation.')]

    s += [PageBreak(), Paragraph('4. Sanctions', H2)]
    s += [t([['Faute', 'Première fois', 'Récidive'],
             ['Écart léger (HRP en scène, micro, conduite irréaliste)', 'Rappel / avertissement', 'Avertissement'],
             ['Freekill, carkill, metagaming, powergaming', 'Avertissement ou isolement', 'Ban 1 à 3 jours (fondateur)'],
             ['Déconnexion pour fuir une scène, règles de braquage contournées', 'Isolement + avertissement', 'Ban 3 à 7 jours'],
             ['Harcèlement, propos haineux', 'Expulsion + rapport au fondateur', 'Ban définitif'],
             ['Triche, exploitation de bug, argent réel, double compte', 'Ban définitif (fondateur)', '—']],
            [80 * G.mm, 50 * G.mm, 50 * G.mm])]
    s += b(['<b>Motif obligatoire</b>, précis et neutre (« Freekill sur un PNJ du Vanilla, 21 h 40, clip de X »).',
            'Les sanctions sont publiées dans #sanctions <b>sans ton nom</b>. Tout est journalisé (F10 → Journal).',
            '<b>Isolement</b> : cour de Bolingbroke, compte à rebours, il tient même après une déconnexion.',
            'Jamais de sanction sur un ami, un membre de ta faction, ou un joueur avec qui tu es en scène : passe la main.',
            'Une contestation ne se règle pas en jeu : « Fais un ticket Discord avec ton clip ».'])
    s += [Paragraph('Anti-triche (F11 → Anti-triche)', H3)]
    s += [Paragraph('Le serveur signale (téléportation, vitesse impossible, arme interdite, argent anormal, carkill probable) mais <b>ne sanctionne jamais '
                    'seul</b>. Toi, tu vérifies : spectate, Aller à, fiche, journal. Doute = fondateur. Le staff en mode staff est exempté (vol, invisible, TP).', P)]
    s += [Paragraph('<b>Seule exception : les pièges.</b> 27 faux événements qu\'aucun script ne déclenche, mais que les menus de triche essaient : '
                    'les toucher = <b>bannissement définitif automatique</b> (« PIÈGE » dans #logs-staff). Un membre du staff n\'est jamais banni, seulement signalé. '
                    'Pendant les tests, le fondateur peut passer en simple signalement (<i>gs_honeypot "log"</i>).', P)]
    s += [Paragraph('Bannir et débannir (super-admin)', H3)]
    s += b(['<b>F11 → Joueurs → le joueur → Bannir</b> : durée en jours (0 = définitif), motif obligatoire, double confirmation. Publié dans #sanctions.',
            '<b>F11 → Bannissements</b> : liste des bans en cours, recherche par pseudo ou licence, <b>Débannir</b> (même hors ligne).',
            'Le banni voit à la connexion son motif, la date de fin et le lien Discord. Les peines écoulées s\'effacent seules.'])

    s += [Paragraph('5. Faire vivre la ville', H2)]
    s += [t([['Quoi', 'Comment', 'Rang'],
             ['Événements prêts', 'F11 → Événements (soirée plage à Cayo, départ du road trip, météo, Halloween…)', 'Admin'],
             ['Bonus serveur', '/gsevent start double_xp 60 · /gsevent start lucky 60 (minutes)', 'Admin'],
             ['Fait divers PNJ', 'F11 → Événements → Fait divers PNJ (police en service obligatoire)', 'Admin'],
             ['Rumeurs qui deviennent vraies', 'Alerte reçue → /rumeurvraie storm|stash|crime ou /rumeurfausse (10 min pour décider)', 'Modo'],
             ['Rumeurs des joueurs', 'F11 → Événements → Rumeurs des joueurs → Valider, Valider + brève Weazel, ou Écarter', 'Modo'],
             ['Lieux de mémoire', '/plaque Mariage de X et Y (sur place) · /plaqueretirer', 'Admin'],
             ['Gazette', '/gazettepublier : publie tout de suite (sinon dimanche 20 h tout seul)', 'Admin'],
             ['Enchères', '/encheres : ouvrir ou clore une vente (sinon samedi 21 h 30)', 'Admin'],
             ['Gangs', '/gsgang create… après validation du projet RP en ticket', 'Admin']],
            [38 * G.mm, 120 * G.mm, 22 * G.mm], font=8.2)]
    s += [Paragraph('Un point mal placé (transformateur, ring, vendeur, PNJ…) : F11 → Monde et lieux → <b>Déplacer / retirer un point</b> (filtre par ressource ; '
                    'super-admin : retirer du jeu, réversible). Points de métier : menu dédié. Tout est gardé aux mises à jour.', SMALL)]
    s += [Paragraph('6. Nouveautés V11.4 → V12.63 pour le staff', H2)]
    s += [t([['Quoi', 'Comment'],
             ['Lives (V12.60)', 'F11 → Lives ou /lives : liste des joueurs, WATCH = son écran dans une fenêtre déplaçable (4 au plus). ✕ = jouer en gardant les fenêtres. Chaque visionnage est écrit dans le journal staff.'],
             ['Appli staff externe (V12.63)', 'Modérer sans être en jeu (tablette) : voir ci-dessus. Mot de passe collectif changé par le fondateur : GERER-OVH → 20 → M (efface les anciens codes).'],
             ['Lives grille / TP / replay (V12.62)', '▦ = toutes les fenêtres en grille ; « ⇢ TP » sur une fenêtre = se téléporter près du joueur. ⏪ (joueurs liés à un ticket ouvert : l\'auteur, et le joueur nommé par « /report 12 … ») = ses 30 dernières secondes d\'écran, gardées en mémoire tant que le ticket est ouvert, effacées à la fermeture.'],
             ['Poursuite filmée (V12.62)', 'Police IA à 3 étoiles : un hélico tourne au-dessus du suspect. Le site affiche « EN DIRECT » (quartier seulement, jamais le nom). /policeia 3 pour tester.'],
             ['Jetons de fête foraine (V12.62)', 'Guichet à la salle de jeu de Del Perro (à caler : F11 → Déplacer un point, gs_casino) et à la caisse du casino. Ticket d\'un script d\'activité (auto-tamponneuses…) : l\'ajouter dans Config.Fair.exchange (gs_casino) pour l\'échanger 1 pour 1.'],
             ['Mort RP (V12.60)', 'F11 → Joueurs → le joueur → Mort RP : tombe au cimetière + avis de décès (Weazel, Gazette). Le personnage n\'est PAS supprimé. F11 → Monde et lieux → Cimetière : poser / retirer.'],
             ['Mods (V12.60)', 'DIAGNOSTIC-MODS.bat : fichiers abîmés, vêtements en conflit, voitures en double ; O = corrections sûres. F11 → Monde et lieux → Blips en double.'],
             ['Nouveautés V12.63', 'Mur des légendes (gs_wanted, Config.Fugitive.legendWall, devant Mission Row : F11 → Déplacer un point). Affiches de cavale arrachables (300 $ hors police). Trêves de gangs (menu Gang → Trêves ; rupture = −15 influence partout, journal staff). Figure du coin (gs_city, Config.Figure). Avis du commerçant après un braquage filmé (gs_stickup, 24 h). Police : /faussealerte [n°] sur un appel anonyme de cabine.'],
             ['Appli staff : rangs (V12.63)', 'Mot de passe collectif = modérateur. GERER-OVH → 20 → A : code personnel avec rang (5 = fondateur : agit sur tout le monde ; sinon seulement sur les rangs inférieurs). Bannir = admin minimum.'],
             ['Courses sur mesure (V12.63)', 'F11 → Monde et lieux → Courses : « Véhicule imposé » (brouillon ou course existante). Sur la ligne : E relance le départ, X annule.'],
             ['Quartiers de gangs (V12.63)', 'Rectangles de pâtés de maisons. /quartierforme <quartier> <angle> [taille] [allongement 0.4-2.5]. Plus de gangs créés d\'office : F11 → Monde et lieux → Gangs.'],
             ['Lives : tester seul (V12.63)', 'F8 → /livestest : teste la capture sur TON PC (sans le serveur). F11 → Lives : ta propre ligne « (toi : test) ». Si l\'image ne vient pas, la fenêtre (et l\'appli) dit pourquoi ; console : « [gs_lives] capture impossible ».'],
             ['Cabines (V12.61)', 'Appels anonymes (police, Weazel, numéro masqué) tracés dans le journal staff (abus). Police grade 2+ : Alt sur une cabine → mettre sur écoute (mandat RP), 2 h.'],
             ['Rapport de fin de soirée (V12.61)', 'Chaque jour à 4 h dans le salon staff Discord (gs_webhook_staff) : joueurs max, tickets, sanctions, alertes, Lives, crimes, morts RP. /rapportstaff en console = tout de suite.'],
             ['Effets sur moi (V12.59)', 'F11 → Événements → Effets sur moi : super vitesse en voiture, voiture sauteuse, arc-en-ciel, caméra ivre. Persos GTA → Autre perso (nom du modèle).'],
             ['VIP (2 personnages)', 'F11 → Joueurs → le joueur → VIP (fondateur). Tout le monde a 1 personnage ; staff super-admin+ et VIP en ont 2.'],
             ['Mapping', 'F11 → Monde et lieux → Mapping : catalogue par catégorie (mobilier, chantier, éclairage, végétation, stands, plage, police), placement à la souris, retrait d\'objets de la map.'],
             ['Mappings installés', 'F11 → Monde et lieux → Mappings installés : chaque map ajoutée avec son quartier (lu dans ses fichiers), clic = téléportation dedans, blips pour soi, conflits entre deux maps signalés.'],
             ['Items et véhicules', 'F11 → Items : par catégorie avec image + recherche (munitions enfin donnables). Véhicules : catalogue Qbox par catégorie.'],
             ['Permis et PPA', 'F4 → Contrôle d\'identité → Permis : délivrer / rendre / retirer le permis de conduire (motif au casier), port d\'arme (carte PPA remise ou reprise), chasse.'],
             ['Faux papiers', 'Un contrôle F4 loin du commissariat affiche la fausse identité (« contrôle visuel »). Au commissariat, le scanner démasque : casier automatique.'],
             ['Témoin protégé', 'Un suspect en garde à vue peut dénoncer un gang (/droits) : peine ÷ 2, protection 7 jours, lieu sûr. La police est prévenue. S\'il meurt : alerte, chaleur sur le gang.'],
             ['Opérations de gang', 'Brouillage de caméras et scanner piraté laissent une trace : terminal du commissariat → « Remonter la source » (5 min d\'analyse).'],
             ['Tickets Discord', '/ticket ouvre un fil privé dans #tickets (joueur + rôle staff) ; /fermer le clôt. Candidatures du site : webhook #candidatures.'],
             ['Isolement à distance', 'Bot : /isoler id minutes motif · /liberer id · /reanimer id. Appli staff : boutons Isoler / Libérer / Réanimer. Publié dans #sanctions, journalisé.'],
             ['Déplacer un point', 'F11 → Monde et lieux → Déplacer / retirer un point : 6 s après « Placer ce point ici », message « Vérifié : la ressource a redémarré avec la nouvelle position » (sinon un avertissement précis).'],
             ['Mappings : conflits', 'Console au démarrage : les conflits d\'occlusion (*_occl_*) sont fusionnés tout seuls (vert = résolu). Rouge = autre conflit : à signaler à Claude ou garder une des deux maps. Jaune = modèle au-delà de la limite FiveM (48 Mo graphique / 64 Mo système).'],
             ['Contrôler les maps', 'F11 → Mappings installés → « Contrôler les maps chez moi » : bâtiment chargé, aucun modèle reçu (réimporter / VIDER-CACHE-FIVEM), reçus mais illisibles (licence Cfx du pack ou fichier abîmé), pack incomplet. Copie dans la console du serveur. Activité sans son script (laser game, karting…) : « décor seul ».'],
             ['Supprimer les maps', 'F11 → Mappings installés → « Supprimer définitivement toutes les maps » (taper SUPPRIMER) : dossiers, lignes de addons.cfg, copies et archives effacés, noms dans mods-retires.txt (jamais réinstallés). Sur le PC ET sur le VPS.'],
             ['Retirer une map', 'F11 → Monde et lieux → Mappings installés → « Retirer TOUTES les maps » ou la map → Retirer cette map : arrêtée, dossier supprimé du disque, ligne enlevée de cfg/addons.cfg, notée dans mods-retires.txt, jamais réimportée (V12.36). À faire sur le serveur du PC, puis METTRE-A-JOUR-OVH.'],
             ['/optin (Qbox)', 'Bascule le « service admin » de Qbox, exigé par ses commandes (/tp, clés de véhicule…). Fonctionne pour admin et plus depuis la V12.15.'],
             ['Monde et lieux', 'Toute la catégorie F11 (lieux publics, points, points de métier, gangs, décor, mappings, coordonnées) est réservée au <b>super-admin et au fondateur</b>, aussi côté serveur.'],
             ['Alertes police', 'Toutes les alertes passent par le central (docs/ALERTES.md) : tirs, armes blanches, vols de voiture, braquages… Chasseur avec permis en zone de chasse : pas d\'alerte. /911p réservé au staff.'],
             ['Police IA', 'Seul en ville : un crime sérieux est signalé au moins 6 fois sur 10. <b>/policeia 1-5</b> (admin) la déclenche sur toi pour la tester.'],
             ['Discord', 'Message de bienvenue des nouveaux membres (salon réglé dans CONFIGURER-DISCORD, option « Server Members Intent » du portail Discord).'],
             ['Placement libre', 'F11 → Monde et lieux → Déplacer un point → Placement libre : flèches / pavé 8-5-4-6 = 10 cm, PgUp-PgDn = hauteur 5 cm, Q-E = ±5°, Maj = ×5, G = au sol, Tab = viser à la souris, Entrée = valider, Retour = annuler (V12.38).'],
             ['PNJ et objets du staff', 'F11 → Monde et lieux → PNJ et objets posés par le staff : Ajouter un PNJ (modèle, scénario) ou un objet (catalogue), relié à un métier (accueil / direction / garage : il remplace le PNJ prévu et porte l\'interaction), à un gang (planque) ou libre ; Retirer celui que je vise. 200 max, un seul PNJ staff par cible (V12.38).'],
             ['Points : PC → VPS', 'V12.37 : les points déplacés sont gardés aux mises à jour ET copiés sur le VPS par METTRE-A-JOUR-OVH (fichier gs_bridge/points-deplaces.json, écrit toutes les minutes ou /pointsexport). Cale tout sur le PC : OVH suit.'],
             ['/dosreglage', 'Armes dans le dos : règle en direct la position (±1 cm, ±2°, os 24818 / 24816), « Copier le bloc Config.Back » puis coller dans gs_details/shared/config.lua et restart gs_details. Plus d\'arme qui flotte après une mort ou un changement de tenue (V12.38).'],
             ['Dégâts adoucis', 'V12.37 : armes à feu −25 %, corps à corps −20 %, véhicules −30 % (gs_details/client/health.lua, DAMAGE). 1.0 = valeurs du jeu.'],
             ['Tempête', 'Interventions (véhicule en détresse, arbre, barrière) créées à l\'approche, posées sur la route la plus proche. Console « aucune route à moins de 60 m du point » = point à déplacer (F11 → Points, nommés « Véhicule · … »).'],
             ['Concessions', 'V12.40 : F11 → Monde et lieux → Concessions : véhicules d\'exposition (admin+) : place-toi, « Exposer un véhicule ICI », puis « Départ des essais ICI » sur la route. Les joueurs essaient 2 min et achètent ; le vendeur en service change le modèle.'],
             ['Courses sur mesure', 'V12.40 : F11 → Courses de rue sur mesure : points posés à ta position (30 m mini), 3 à 30 points, éphémère (1 à 168 h) ou permanente.'],
             ['Portes verrouillées', 'V12.40 : F11 → Portes verrouillées : ouvre /doorlock (ox_doorlock). Groupes : police + sheriff (cellules, commissariat), ambulance, mechanic, cardealer, le gang pour son QG.'],
             ['Territoires', 'V12.40 : visibles des seuls membres de gang ; niveaux 0-3 selon l\'influence, 3 territoires max par gang ; /territoire id -3..3 (admin) ajoute un bonus (perdu au redémarrage).'],
             ['Mobilier', 'V12.42 : bancs, chaises, lits, matelas, fauteuil roulant posés au F11 (ou de la ville) : Alt → S\'asseoir / S\'allonger / Rouler. Mauvaise hauteur : pendant la pose PgUp/PgDn et flèches, la ligne à recopier dans Config.Furniture (gs_furniture) s\'affiche en F8.'],
             ['Boutique et RoadCoins', 'V12.41 : /boutique = vitrine en jeu. Test console : gsstore_deliver TEST-1 roadcoins_500 <id fivem du joueur> (crédit immédiat). Remboursement : gsstore_revoke TEST-1. Jamais de commande boutique en jeu (refusée même admin).'],
             ['Base injoignable', 'V12.47 : console « [oxmysql] Unable to establish a connection to the database » (ECONNRESET) sur le PC : REPARER-BDD.bat (redémarre MariaDB, explique la cause, la relance seule si elle plante, relance le serveur).'],
             ['Forme des territoires', 'V12.56 : /quartierforme <quartier> <angle 0-90> [taille 40-200 m] (admin) : tourne les cases pour suivre les rues (carte des gangs), gardé au redémarrage. Ex. /quartierforme canals 37'],
             ['Prison : musculation', 'V12.53 : Pompes, Abdos, Haltères, Tractions dans la cour (détenus). Mal placés : F11 → Déplacer un point (gs_police).'],
             ['Arrivée protégée', 'V12.50 : 30 s fantôme à la connexion et après une réapparition ; points d\'apparition = zones sans coups ni tirs (Config.SpawnProtection dans gs_onboarding). Un troll qui frappe ailleurs : sanction normale.'],
             ['Voix', 'V12.51 : portées 2 / 6 / 14 m (gs_radio, Config.VoiceRanges). Spam de coups : 1 coup / 0,8 s. Un joueur qui n\'entend plus le jeu quand on parle : REPARER-SON.bat (réglage Windows Communications).'],
             ['Récolte', 'V12.45 : champs d\'orge, houblon, maïs, plantation de tabac (Grapeseed, revente au marché) ; pavot sans blip (crime « culture illicite », receleur du port). Champ mal placé : F11 → Déplacer un point (ressource gs_harvest).'],
             ['Nouveaux vêtements', 'V12.45-46 : 9 collections ROADTRIP (coupes homme / femme, robes, jeans) en plus de celles du jeu : IMPORTER-MODS les installe. Un joueur ne les voit pas : VIDER-CACHE-FIVEM.'],
             ['Caméras en direct', 'V12.41 : terminal de vidéosurveillance (police en service) → une caméra → Voir en direct. Peinte à la bombe ou black-out : image noire.'],
             ['Location', '13 comptoirs (Sandy devant le 24/7, plus dans le poste du shérif ; Grapeseed, Harmony, Vinewood, Vespucci, aéroport, Pillbox ajoutés, « à caler » via F11 → Déplacer un point).']],
            [38 * G.mm, 142 * G.mm], font=8.2)]

    s += [Paragraph('7. La déontologie du staff', H2)]
    s += b(['<b>Le mode staff, c\'est pour modérer.</b> Jamais de pouvoir (vol, TP, argent, objets) pour ton personnage ou tes amis.',
            '<b>Neutralité</b> : en jeu, tu es un joueur comme les autres. Tes infos de staff (fiches, journal, positions) ne servent jamais à ton RP.',
            '<b>Confidentialité</b> : codes, captures du panel, discussions staff et identités restent entre nous. Ton code d\'appli est personnel.',
            '<b>Ton calme</b> : on explique, on ne se moque pas, on ne menace pas. Un joueur énervé reçoit une réponse courte et polie.',
            '<b>En cas de doute, on demande.</b> Un ticket qui attend 5 minutes vaut mieux qu\'une mauvaise sanction.'])
    s += [Paragraph('8. Quand ça casse', H2)]
    s += b(['Serveur tombé : l\'alerte arrive dans le salon staff au bout de 4 min et il se relance tout seul. Sinon : fondateur.',
            'Bug qui rapporte de l\'argent ou des objets : on note qui, quand, combien, et on prévient le fondateur (retour en arrière d\'un seul joueur possible).',
            'Joueur bloqué (sous la carte, dans un mur) : mode staff → Amener, ou le TP à un lieu sûr. Notez-le dans le ticket.'])
    s += [Spacer(1, 6), Paragraph('<i>« La ville se souvient » : le staff aussi. Chaque action laisse une trace, et c\'est ce qui protège tout le monde, toi compris.</i>', SMALL)]

    doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='RoadLine RP · Guide du staff', author='RoadLine RP')
    doc.build(s, onFirstPage=page, onLaterPages=page)
    print(f'PDF généré : {OUT}')


if __name__ == '__main__':
    build()
