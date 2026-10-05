# Génère les PDF de docs/pdf : guide complet, fiche de tests, carte des points.
# Lancer depuis la racine : lua5.4 tools/points.lua && python3 tools/pdf.py
import json
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.graphics.shapes import Drawing, Rect, Circle, String, Line

VERSION = 'V11'
NEON = colors.HexColor('#28E0FF')
DARK = colors.HexColor('#0F091C')
PINK = colors.HexColor('#FF2E88')
GREY = colors.HexColor('#6B6380')

ss = getSampleStyleSheet()
H1 = ParagraphStyle('h1', parent=ss['Title'], textColor=DARK, fontSize=22, spaceAfter=6)
H2 = ParagraphStyle('h2', parent=ss['Heading2'], textColor=PINK, spaceBefore=10, spaceAfter=4)
H3 = ParagraphStyle('h3', parent=ss['Heading3'], textColor=DARK, spaceBefore=6, spaceAfter=2)
P = ParagraphStyle('p', parent=ss['BodyText'], fontSize=9.5, leading=12.5)
SMALL = ParagraphStyle('s', parent=P, fontSize=8, leading=10, textColor=GREY)


def table(rows, widths, header=True, font=8.5):
    cell = ParagraphStyle('c', parent=P, fontSize=font, leading=font + 2.5)
    head = ParagraphStyle('ch', parent=cell, textColor=colors.white, fontName='Helvetica-Bold')
    t = Table([[Paragraph(str(c), head if (header and i == 0) else cell) for c in r] for i, r in enumerate(rows)],
              colWidths=widths, repeatRows=1 if header else 0)
    style = [('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#CBBBEA')), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
             ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F4F0FC')])]
    if header:
        style += [('BACKGROUND', (0, 0), (-1, 0), DARK), ('TEXTCOLOR', (0, 0), (-1, 0), colors.white)]
    t.setStyle(TableStyle(style))
    return t


def bullets(items):
    return [Paragraph('• ' + i, P) for i in items]


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 7.5)
    canvas.setFillColor(GREY)
    canvas.drawString(15 * mm, 10 * mm, f'RoadLine RP · new generation · {VERSION}')
    canvas.drawRightString(doc.pagesize[0] - 15 * mm, 10 * mm, f'page {doc.page}')
    canvas.restoreState()


# ------------------------------------------------------------------------------------------------------------------
KEYS = [
    ['Touche', 'Action', 'Remarque'],
    ['F1', 'Téléphone', 'Vibe, banque, boulots, Carnet, Weazel, Commandes (pros), Inconnu (marché noir, contrats)'],
    ['F2 · TAB · 1 à 5', 'Inventaire · barre rapide · objets rapides', 'Double-clic ou Alt + clic = utiliser'],
    ['K', 'Inventaire proche', 'coffre, boîte à gants'],
    ['F3', 'Progression, quêtes, niveau', 'même touche pour fermer'],
    ['F4', 'Intervention', 'police / EMS en service (EMS : envoyer un secouriste IA)'],
    ['F5 · X · J · G', 'Emotes · annuler · pointer · effets', 'G = effets seulement pendant une emote à effets'],
    ['F6', 'Métiers', 'service, tenue, factures, direction, missions'],
    ['F7', 'Duo', ''],
    ['F9', 'Gang', 'caisse, membres, territoires, atelier, flotte'],
    ['F10 · F11', 'Panel staff · menu staff rapide', 'staff uniquement'],
    ['I', 'Aide des touches', ''],
    ['W (clavier français)', 'Menu radial', 'Moi (tenue en objet, chapeau, lunettes, masque, animations, factures…), Radio, Véhicule'],
    ['Alt gauche (appui simple)', 'Viser / interagir (ox_target)', 'choisir à la souris ; rappuie sur Alt pour fermer'],
    ['E', 'Interagir sur un point [E] · racketter un passant visé', 'caisse / guichet : le braquage démarre seul en visant'],
    ['N · ²', 'Parler · portée de la voix', 'crier (²) fait peur aux PNJ braqués'],
    ['Verr. Maj (maintenu)', 'Parler à la radio', 'après avoir réglé une fréquence'],
    ['H', 'Mains en l\'air (à pied) · démarrer sans clé (en voiture)', ''],
    ['L · B', 'Verrouiller le véhicule · ceinture', ''],
    ['Ctrl gauche', 'S\'accroupir', ''],
    ['G', 'Effacer un tag adverse (gangs) · appeler les secours à terre', ''],
    ['Ctrl+Y · Ctrl+U · Ctrl+O', 'TP marqueur · vol libre · noms et ID', 'staff en mode staff'],
    ['Espace / Retour', 'Passer le film du vol · annuler', ''],
]

TOOLS = [
    ['Fichier', 'Ce qu\'il fait'],
    ['INSTALLER.bat', 'Première installation sur le PC (MariaDB, FiveM, Qbox, RoadLine, base, raccourci DEMARRER.bat).'],
    ['METTRE-A-JOUR.bat', 'Nouvelle version : sauvegarde (fichiers + base), installe, réglages Qbox, mods en attente, sauvegardes programmées toutes les 6 h.'],
    ['CAPTURER-ERREURS.bat', 'Lance le serveur 2 min et ouvre C:\\GTASOON\\logs\\erreurs.txt (erreurs + 80 dernières lignes) : à envoyer en cas de souci.'],
    ['IMPORTER-MODS.bat', 'Véhicules, vêtements, maps (zip / rar / dlc.rpf) : tri, contrôle des marques, installation, concession. Lit aussi « Mon Drive\\GTA ».'],
    ['SAUVEGARDER-BDD.bat · RESTAURER-BDD.bat', 'Sauvegarde maintenant (30 gardées) · retour en arrière de toute la base ou d\'un seul joueur (l\'état actuel est sauvegardé avant).'],
    ['CONFIGURER-DISCORD.bat', 'Webhooks (statut, annonces), jeton du bot, identifiant du Discord : écrit secrets.cfg et ouvre l\'invitation du bot.'],
    ['PREPARER-OVH.bat', 'Mise en ligne sur le VPS OVH en un clic : base + serveur envoyés, installation automatique (docs/OVH.md).'],
    ['METTRE-A-JOUR-OVH.bat', 'Envoie la nouvelle version sur le VPS sans toucher sa base (sauvegardée avant) ; met d\'abord le PC à jour si besoin.'],
    ['GERER-OVH.bat', 'Le VPS depuis le PC, sans mot de passe : état + diagnostic, console, erreurs, marche / arrêt, public / privé, sauvegardes '
                      '(et copie quotidienne sur le PC), réglages Discord, heure du redémarrage, txAdmin, vérification Discord, codes et adresse '
                      'https du panneau staff. À l\'ouverture : met à jour le VPS et répare les fichiers d\'objets si besoin.'],
    ['DEVENIR-ADMIN · REPARER-LANCEUR · REPARER-MARIADB · VIDER-CACHE-FIVEM', 'Te mettre fondateur · « chemin introuvable » au démarrage · base qui ne démarre plus · ancien menu encore affiché.'],
]

INTEGRATIONS = [
    ['Quoi', 'Comment ça marche'],
    ['Discord · bot RoadLine', 'Intégré au serveur (rien à installer) : présence « 12/48 citoyens », /statut, /rejoindre, /rdv, /site ; '
                              'commandes staff /joueurs, /geler, /expulser… réservées au rôle staff (gs_discord_staff_role).'],
    ['Discord · salons', 'Statut en direct (un message mis à jour chaque minute), annonces (ouverture, redémarrages, rendez-vous), '
                         'sanctions publiques (staff anonyme), miroir de Vibe, logs staff / métiers / boutique / anti-triche.'],
    ['Discord · rôles de métier', 'Le rôle Discord suit le métier en jeu (gs_discord_roles dans secrets.cfg : police=ID,ambulance=ID…).'],
    ['txAdmin', 'http://IP:40120 — pour le fondateur : console, bannissements, joueurs. Mise en route : GERER-OVH → 15 (PIN, « Existing server data » '
                '→ /home/fivem/server-data, OneSync On) ; mauvais compte Cfx.re : GERER-OVH → 22. Ne pas activer ses redémarrages programmés.'],
    ['VPS OVH', 'Commande « roadline » (ou GERER-OVH.bat) : etat, diagnostic, erreurs, discord, redemarrer, public / prive, sauvegarde(s), '
                'restaurer(-joueur), maj, retour, mode simple / txadmin, redemarrage-auto. Veille toutes les 2 min (alerte Discord + relance).'],
    ['Panneau staff (appli)', 'https://57-129-170-173.sslip.io/gs_admin/ (GERER-OVH → 21 une fois) : à installer sur le téléphone (Chrome : Installer '
                              'l\'application ; iPhone : Sur l\'écran d\'accueil). Joueurs, tickets, annonce. Sans console : c\'est l\'outil des modérateurs. '
                              'Un code par membre : GERER-OVH → 20 ; 5 essais ratés = 15 min de blocage. Lien « Espace staff » en bas du site.'],
    ['Site · carte en direct', 'https://57-129-170-173.sslip.io/gs_city/ville.json : quartiers, rendez-vous, légendes, timelapse 24 h (CONFIG.cityUrl, déjà réglé).'],
    ['Sauvegardes', 'Toutes les 6 h (PC : tâche Windows ; VPS : cron), 30 gardées, avant chaque mise à jour, retour d\'un seul joueur possible.'],
    ['Téléphone', 'Fait maison : Que faire, Messages, Contacts, Appel, Banque, Factures, Emploi, Urgences, Vibe, Weazel, Plans, Ville, Notes, Boulots, Inconnu.'],
    ['Photos (option)', 'screenshot-basic + hébergeur d\'images (gs_photo_* dans secrets.cfg) : vraies photos dans Vibe, l\'appareil photo et la bodycam.'],
    ['Weazel · Radio LS', 'Brèves automatiques et bandeau, journal écrit par les joueurs, Direct Weazel ; Radio Los Santos en voiture (sous-titres).'],
    ['Boutique Tebex', 'Cosmétiques seulement (zéro pay-to-win), réclamés en jeu avec /boutique (sv_tebexSecret dans secrets.cfg).'],
    ['Liste blanche', 'gs_whitelist "true" : candidature sur Discord avant d\'entrer (gs_discord_invite).'],
]

COMMANDS = [
    ['Commande', 'Pour quoi'],
    ['/touches · /regles · /report', 'aide des touches · règlement · ticket au staff'],
    ['/me · /do', 'actions RP affichées'],
    ['/radio [fréquence|off]', 'radio (aussi W → Radio)'],
    ['/taxi · /depanneur', 'appeler un taxi / un mécano'],
    ['/factures · /reputation · /saison · /quartiers', 'factures · réputation · passe de saison · ambiance des quartiers'],
    ['/retoucheperso', 'retoucher son perso (une seule fois)'],
    ['/boutique', 'boutique cosmétique (réclamer ses achats)'],
    ['/permis · /histoire', 'solde de points du permis · carnet du véhicule où tu es assis'],
    ['/mentor · /rencontres · /rumeurs', 'parrainage · collection des rencontres de la route · où entendre les rumeurs'],
    ['/droits · /cinema · /ralenti', 'garde à vue (avocat, silence, aveux) · mode cinéma pour les clips · ralenti pendant le tournage'],
    ['/cavale · /livrer · /legendes', 'fugitifs recherchés (primes) · livrer un fugitif · panthéon des cavales'],
    ['/contrat · /recap · /rdv', 'contrats signés (prêt, salaire, location) · ton récap du mois · rendez-vous de la semaine'],
    ['/racket', "gang : réclamer une protection à la caisse d'un commerce · patron : voir / arrêter de payer"],
    ['/quefaire · /radiols', "tout ce qu'on peut faire maintenant (aussi dans le téléphone : Que faire) · couper / rallumer Radio Los Santos"],
    ['/mandat · /tribunal', "police / juge : signalements de planques et mandats · affaires, pièces au dossier, verdicts"],
    ['/encheres', 'enchères de la fourrière (samedi 21 h) : lots, mises, dépôt des saisies (police)'],
    ['/dossier', 'police, juges, presse en service : la fiche d\'un citoyen (chacun sa vue)'],
    ['Staff', '/whitelist · /gsjob · /gsgang · /gsevent · /meteo · /builder · /economie · /faitdivers (les joueurs ne les voient pas)'],
    ['Staff · rumeurs', '/rumeurvraie storm|stash|crime · /rumeurfausse … (quand une rumeur est prête)'],
    ['Staff · mémoire', '/plaque <texte> : poser un lieu de mémoire (mariage, concert…) · /plaqueretirer : la plus proche (admin+)'],
    ['Staff sur Discord', '/joueurs · /geler · /degeler · /avertir · /expulser · /message · /annonce (rôle staff, réponses privées)'],
]


def guide(points):
    doc = SimpleDocTemplate('docs/pdf/ROADLINE_Guide.pdf', pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='RoadLine RP · Guide complet', author='RoadLine RP')
    s = [Paragraph('RoadLine RP · Guide complet', H1),
         Paragraph(f'Tout ce qui est disponible sur le serveur ({VERSION}), comment y accéder, les outils et les intégrations. '
                   'Les nouveautés sont regroupées en trois grandes versions : V1 (la rue et les métiers), V2 (la ville a une mémoire), '
                   'V3 (une ville qui vit sans toi). '
                   'Serveur FiveM RP français (Qbox, ox_lib, ox_inventory, pma-voice).', P), Spacer(1, 4)]

    s += [Paragraph('1. Outils en un double-clic', H2)]
    s += [Paragraph('Toujours : clic droit sur le zip RoadLine → Extraire tout, puis ouvrir le dossier <b>gtasoon</b>.', P),
          table(TOOLS, [48 * mm, 132 * mm])]
    s += [Paragraph('Intégrations', H2), table(INTEGRATIONS, [40 * mm, 140 * mm])]

    s += [Paragraph('2. Touches', H2), table(KEYS, [38 * mm, 78 * mm, 64 * mm])]
    s += [Paragraph('3. Commandes utiles', H2), table(COMMANDS, [60 * mm, 120 * mm])]

    s += [PageBreak(), Paragraph('★ V11 · Bêta ouverte : la ville se raconte', H2)]
    s += bullets([
        "<b>Lieux de mémoire</b> : un casse de la banque ou de la bijouterie, la fin d'une cavale légendaire, un mariage posé par le staff… "
        "une <b>plaque</b> (couronne et bougie) reste sur place 30 jours. De près, le texte apparaît ; <b>[E] Lire la plaque</b> : un passant raconte.",
        "<b>La ville en timelapse</b> : sur le site, « Rejouer les dernières 24 h » montre en 30 secondes la tension des quartiers et les "
        "faits marquants (incidents, faits divers, rumeurs confirmées, verdicts, cavales, plaques). Jamais de position de joueur.",
        "<b>Serveur officiel</b> : en ligne 24 h/24 sur le VPS, redémarrage chaque matin à 6 h (annoncé en jeu 15, 5 et 1 min avant), "
        "veille toutes les 2 min (alerte Discord et relance si besoin), sauvegardes toutes les 6 h (et copie sur le PC).",
        "<b>Staff mobile</b> : une vraie appli sur le téléphone (https), onglets Joueurs / Tickets / Ville, cartes cliquables, bouton txAdmin. "
        "Les modérateurs n'ont ni console ni argent : txAdmin reste réservé au fondateur.",
    ])
    s += [PageBreak(), Paragraph('★ V3 · Tout frais : deux villes en une', H2)]
    s += bullets([
        "<b>Ville de jour, ville de nuit</b> : la nuit (22 h → 5 h), noctambules devant les clubs, feu de camp à Vespucci et <b>marchés de nuit</b> "
        "(food truck de Legion Square, jetée de Del Perro, Vinewood) ; le jour, musiciens et pêcheurs. Rien ne ferme : c'est du plus.",
        "<b>Les rumeurs deviennent vraies</b> : chez un barman, « Faire courir un bruit » (50 $). Assez de monde le répète ? Ça arrive : "
        "tempête, sale coup en ville (fait divers), ou un <b>sac de billets caché</b> quelque part (un seul gagnant). Tu peux aussi "
        "<b>raconter ta propre histoire</b> (100 $) : si le staff la retient, tous les barmans la racontent… et la scène peut se jouer.",
        "<b>Le fil de la ville</b> : chaque soir, un court résumé de la journée sur le Discord (crimes, arrestations, verdicts, légendes).",
        "<b>Alt</b> : un simple appui ouvre le ciblage (choisis à la souris), un deuxième le referme.",
        "<b>Le dossier du citoyen</b> (/dossier) : une seule fiche, trois regards. Police : casier, mandats, véhicules, gang ; juges : casier, "
        "affaires ; presse : verdicts publics, métiers, notoriété, articles.",
        "<b>Retours du backtest</b> : objets en français avec une image chacun, menu de barbier, vendeurs PNJ partout (braquables), "
        "tenue achetée = objet, alertes police (rue + GPS), aucun dégât en fonçant sur un joueur à pied.",
    ])
    s += [PageBreak(), Paragraph('★ V3 · Justice, presse et staff mobile', H2)]
    s += bullets([
        "<b>Caméras de surveillance</b> : 20 caméras en ville. La police consulte les passages (plaque, type de véhicule, heure) aux "
        "terminaux du commissariat ; une bombe de peinture aveugle une caméra (les gangs adorent).",
        "<b>Mandat de perquisition</b> (/mandat) : trop d'allées et venues dans une planque de gang ou une chambre de motel = les voisins "
        "préviennent la police. Demande au juge (ou juge de permanence si aucun juge en service), puis perquisition sur place : le coffre s'ouvre.",
        "<b>Preuves au tribunal</b> (/tribunal → l'affaire) : police et avocats versent une photo ou un scellé analysé, le juge retient ou "
        "écarte chaque pièce ; le verdict mentionne les pièces retenues.",
        "<b>Chantage à la photo</b> : une photo où l'on voit quelqu'un peut lui être montrée face à face contre de l'argent. Il paie : la "
        "photo lui est remise. Il refuse (ou ne répond pas) : elle fuite dans Weazel et les rumeurs.",
        "<b>Enchères de la fourrière</b> (/encheres, fourrière de Davis) : le samedi à 21 h, saisies de la police et voitures abandonnées "
        "envoyées à la fourrière. Mise bloquée en banque, remboursée si on te dépasse ; recette à la caisse de la police.",
        "<b>Direct Weazel</b> : une grosse poursuite passe en direct (bandeau pour toute la ville, hélicoptère de la chaîne au-dessus du "
        "suspect, journalistes en service payés sur place, brève de fin, Radio Los Santos).",
        "<b>Staff sur téléphone</b> : bot Discord (/joueurs, /geler, /degeler, /avertir, /expulser, /message, /annonce, rôle staff) et "
        "panneau web <b>/gs_admin/</b> (codes dans secrets.cfg). Bannissements : txAdmin.",
        "<b>Serveur officiel OVH</b> : PREPARER-OVH.bat (mise en ligne en un clic), METTRE-A-JOUR-OVH.bat (sans toucher la base), "
        "commande « roadline » sur le VPS. Guide : docs/OVH.md. <b>CAPTURER-ERREURS.bat</b> : enregistre les erreurs du démarrage.",
    ])
    s += [PageBreak(), Paragraph('★ V3 · Une ville qui vit sans toi', H2)]
    s += bullets([
        "<b>Que faire ?</b> (téléphone, ou /quefaire) : un seul point d'entrée. « En ce moment » (rendez-vous, ring ouvert, fugitifs, "
        "quartiers chauds, services en service, faits divers pour la police) puis Gagner ma vie / Côté obscur / Me détendre / Ma vie / Aide : "
        "chaque ligne est un bouton (GPS ou action), plus besoin de retenir 30 commandes.",
        "<b>Téléphone</b> : nouvelles applis Que faire, Plans (lieux favoris, partager sa position par SMS, bouton Itinéraire dans les "
        "messages), Ville (ambiance et standing des quartiers, météo), Notes ; notifications sur l'accueil (SMS, appels manqués, urgences), "
        "appels récents, 6 fonds d'écran, option « marcher téléphone ouvert » (le perso ne bouge pas quand on écrit). Plus léger : "
        "Vibe et Boulots chargés seulement à l'ouverture, aucun flou coûteux, zéro boucle téléphone rangé.",
        "<b>Le quartier évolue</b> : chaque quartier a un standing (à l'abandon → huppé). Les ventes des commerces et les vitrines réparées "
        "le font monter ; crimes, tags et trafics le font baisser. En déclin : déchets dans la rue, à ramasser (payé par la mairie). "
        "La recette des commerces suit (-15 % à +10 %). Brèves Weazel quand un quartier change.",
        "<b>La ville a ses propres criminels</b> : quand les joueurs ne commettent pas de crimes et qu'un policier est en service, "
        "des faits divers PNJ (cambriolage, corps retrouvé, délit de fuite, vandalisme) arrivent au central : GPS, scène, constatations "
        "payées (police, EMS si besoin), brève Weazel. Staff : F11 → Événements → Fait divers.",
        "<b>Radio Los Santos</b> (signature) : en voiture radio allumée, l'animateur raconte la ville en sous-titres (rendez-vous, fugitifs, "
        "faits divers, tempêtes, ring de la nuit sans adresse, météo, astuces). /radiols pour couper.",
        "<b>Les commerçants se souviennent</b> (signature) : 5 jours d'achats dans la même supérette = habitué (salué par son prénom, "
        "-5 %). Braquer à visage découvert = reconnu et refusé au comptoir 48 h ; masqué, personne ne te reconnaît.",
        "<b>Bot Discord</b> : intégré au serveur, rien à installer (voir docs/DISCORD.md : 5 étapes, une seule fois).",
    ])
    s += [PageBreak(), Paragraph('★ V2 · La ville porte ses cicatrices', H2)]
    s += bullets([
        "<b>Cicatrices de la ville</b> : bougies et ruban là où quelqu'un est tombé (quelques heures), vitrine brisée après un braquage "
        "(réparée par un joueur, payé comme ouvrier de la ville, jamais par l'auteur), fresque du gang qui gagne une guerre de quartier.",
        "<b>La cavale</b> : très recherché, tu deviens fugitif (affiches, prime qui grimpe). /cavale pour la liste, /livrer pour remettre un fugitif "
        "menotté à la police (prime au policier qui l'incarcère). Tenir assez longtemps = /legendes.",
        "<b>Appareil photo argentique</b> (quincaillerie) : la photo devient un objet (qui, quelles plaques, quel quartier) ; à accrocher au mur "
        "du commissariat ou à faire analyser au labo.",
        "<b>Cabines téléphoniques</b> : les missions « voix au téléphone » se passent maintenant à une vraie cabine ou un téléphone mural.",
        "<b>Fraude à l'assurance</b> : déclarer sa voiture volée (assurée depuis 24 h) ; l'expert recoupe avec le carnet : revu au volant ou "
        "voiture revendue = fraude (remboursement +50 %, casier, police prévenue). La police voit « déclaré volé » sur la plaque.",
        "<b>Combats clandestins</b> : un ring caché qui change d'adresse chaque jour (rumeurs), ouvert la nuit ; mise des deux combattants, "
        "paris des spectateurs, arbitrage serveur (K.-O., arme sortie = disqualifié, sortie du ring), la maison prend 10 %.",
        "<b>Racket</b> (/racket) : un gang propose une protection au patron d'un bar ; accepté = prélèvement chaque semaine ; refusé ou impayé = "
        "30 min pour casser la vitrine (dégâts sur la caisse, témoins).",
        "<b>La doublure</b> (bars uniquement) : au comptoir, le patron laisse un PNJ à son apparence qui sert quand personne n'est en service "
        "(50 % de la recette au lieu de 30 %). On peut la braquer arme en main (une fois toutes les 2 h).",
        "<b>Contrats signés</b> (/contrat) : prêt avec intérêts, salaire privé, location (le mariage reste à la mairie). Signature face à face, prélèvements automatiques, "
        "argent mis de côté si le bénéficiaire est absent, retard = +10 %, 2 retards = litige transmis aux juges et avocats en service.",
        "<b>Récap du mois</b> (/recap) : heures en ville, km, argent gagné, crimes, arrestations, combats, rencontres, photos, ton titre et ton classement ; "
        "le 1er du mois, « ton récap est prêt ».",
        "<b>Rendez-vous fixes</b> (/rdv) : mercredi des métiers, vendredi des courses, nuit des combats (samedi), road trip du dimanche ; rappel 30 min avant "
        "en jeu et sur Discord.",
        "<b>Staff</b> : anti-triche serveur (alertes seulement, staff exempté : vol libre et TP intacts) dans F11 → Anti-triche ; "
        "F11 → Statistiques de rétention (nouveaux, retour J+1 / 7 jours, abandon à la 1re session, durée des sessions, pic).",
    ])
    s += [PageBreak(), Paragraph('★ V2 · La ville a une mémoire (signatures)', H2)]
    s += bullets([
        '<b>La ville se souvient</b> : les témoins décrivent le suspect à la police, en texte brut (homme / femme, masqué, couvre-chef, sac, '
        'gilet, armé, type et couleur du véhicule, plaque partielle). Recroisé avec la même tenue ou la même voiture (plaque + couleur), '
        'il est reconnu plus vite. Changer de tenue, repeindre ou changer de véhicule brouille la piste. Un visage connu (réputation) peut être nommé.',
        '<b>Enquêtes avec preuves</b> : douilles (arme, n° de série), sang, empreintes (sans gants), traces de pneus, éclats de peinture. '
        'Police : lampe torche en visant → [E] mettre sous scellé → labo du commissariat (3 min). Nom seulement si la personne est fichée '
        '(F4 → Relever empreintes et ADN, ou incarcération) ; sinon un profil inconnu P-XXXXX qui relie les scènes. Gants et javel en quincaillerie, '
        'la pluie lave le sang et les pneus.',
        '<b>Rencontres de la route</b> : hors de la ville, rarement, une scène au bord de la route (auto-stoppeur, panne, accident, animal blessé, '
        'portefeuille, vendeur ambulant, contrôle du shérif). Rien n\'est signalé : on s\'arrête ou pas. Parfois dangereux (auto-stoppeur braqueur, '
        'fausse panne). L\'auto-stoppeur aidé peut revenir. Collection dans F3 → Carnet de route.',
        '<b>La ville parle</b> : barmans, pompiste, patronne du Hen House racontent les vrais événements (gratuit : vague ; payant : détails des témoins). '
        '<b>L\'indic\'</b> (pont de Davis, docks) vend les activités d\'un autre gang (livraisons au receleur, atelier, coups, position du receleur)… '
        'et peut balancer l\'acheteur.',
        '<b>Chaque voiture a une histoire</b> : kilomètres, accidents, propriétaires, peintures (/histoire au volant) ; la police voit aussi les crimes.',
        '<b>Prison vivante</b> (Bolingbroke) : petits boulots (peine réduite + tickets de cantine), cantine, trafiquant (outils contre tickets et cigarettes), '
        'évasion seulement à plusieurs, la nuit, avec des outils de fortune.',
        '<b>Météo événementielle</b> : pendant la tempête, routes fermées (barrières, logo) et interventions payées (arbres, véhicules en détresse).',
        '<b>Mentors</b> (/mentor) : un ancien (niveau 5+) parraine un nouveau ; s\'il reste 7 jours, primes pour les deux.',
        '<b>Permis à points</b> : 12 points, retirés par la police (F4 → Contrôle d\'identité) ou un refus d\'obtempérer ; à 0, retour à l\'auto-école.',
        '<b>Signes distinctifs</b> : les témoins décrivent aussi les tatouages visibles (visage sans masque, bras nus, torse nu).',
        '<b>Fausses plaques</b> (marché noir) : la voiture n\'est plus reliée à ses signalements ni à son carnet pendant 45 min ; '
        'mais « Vérifier une plaque » révèle que le châssis ne correspond pas. Remettre la vraie plaque avant de garer.',
        '<b>Shérif du comté</b> (Sandy Shores, Paleto) : métier distinct du LSPD, mêmes outils (F4, dispatch, preuves, prison).',
        '<b>Garde à vue et interrogatoire</b> (F4) : cellule du commissariat, salle d\'interrogatoire ; le suspect a ses droits (/droits) : '
        'avocat, silence, aveux (peine réduite de 30 %). Interrogatoire sans l\'avocat demandé = vice de procédure noté au rapport.',
        '<b>Chien K9</b> (F4 → Chien K9, grade 1+) : renifle un véhicule (coffre, boîte à gants, passagers) ou une personne : drogue, argent sale.',
        '<b>Contrebande maritime</b> : le docker du port de Paleto (la nuit, gang ou réputation de rue) confie une cargaison à repêcher en mer en bateau '
        'puis à décharger sur une plage ; radar côtier, garde-côtes IA s\'il n\'y a pas de police.',
        '<b>Mode cinéma</b> (/cinema) : interface masquée, bandes noires, filtres (cinéma, néon, noir et blanc), /ralenti : pour les clips.',
        '<b>Halloween sur la route</b> (du 24 octobre au 1er novembre) : rencontres plus fréquentes, auto-stoppeur fantôme, 13 citrouilles cachées (récompense).',
    ])
    s += [PageBreak(), Paragraph('4. Vie légale (V1 et suivantes)', H2)]
    s += bullets([
        '<b>Arrivée</b> : pas d\'appartement gratuit, apparition devant la mairie, quête « Ton premier jour » avec Max. Règlement à accepter.',
        '<b>Logement</b> : chambres de motel à la semaine (logo motel : Pink Cage 450 $, Sandy 300 $, Paleto 320 $ ; coffre + garde-robe), '
        'vrais logements chez l\'agent immobilier (Dynasty 8).',
        '<b>Métiers</b> (F6) : LSPD, EMS, mécano LS Customs, concession PDM, agence immobilière, auto-école, avocats, juge, Weazel News, '
        'mairie, psy, routier, bus, taxi, livreur, éboueur. Dépôts (bus, voirie, Post OP, routier) : « Prendre le poste ici » en un clic.',
        '<b>Bars</b> tenus par des joueurs : <b>Tequi-la-la</b>, <b>Vanilla Unicorn</b>, <b>Bahama Mamas</b> (préparation, caisse, prix du patron). '
        'Sans employé : un barman PNJ sert la carte de base. PNJ sur scène (danseuses, groupe, DJ).',
        '<b>Direction</b> : recruter (avec accord), grades, licencier, caisse, <b>salaires réglables</b> (entreprises privées), '
        '<b>primes</b>, <b>blanchiment</b> (plafonné au chiffre d\'affaires légal du jour, contrôle fiscal possible).',
        '<b>Mécano</b> : réparer (capot ouvert), pneus, remettre sur ses roues, nettoyer, livraisons de pièces, '
        '<b>personnalisation complète</b> du véhicule d\'un client (Alt → Personnaliser : performances, carrosserie, peinture, jantes, vitres, xénon). '
        'Double des clés des véhicules de service pour tous les métiers.',
        '<b>Récolte</b> : pêche, mine (pioche), bûcheron (hache), ferme, ferraille, chasse (permis à l\'Ammu-Nation de Paleto). Plusieurs arbres / '
        'rochers / tas par zone qui s\'épuisent et repoussent, vestiaire (tenue de travail), revente loin de la récolte (logos sur la carte).',
        '<b>Tenues en objets</b> : W → Moi → Vêtements → Plier ma tenue ; double-clic sur l\'objet pour l\'enfiler (échangeable, rangeable).',
        '<b>Armes légales</b> : permis de port d\'arme au comptoir Ammu-Nation (5 000 $, permis de conduire, casier propre).',
        '<b>Permis de conduire</b> (auto-école : théorie + pratique), <b>justice</b> (tribunal, avocat, verdicts), '
        '<b>mairie</b> (mariage, divorce), <b>banque</b> (guichets, distributeurs, plafonds), <b>bourse de la ville</b>.',
        '<b>Location</b> : vélos, scooters, citadines ; <b>bateaux</b> à la marina de LS et à la jetée de Cayo.',
    ])
    s += [Paragraph('5. Vie illégale', H2)]
    s += bullets([
        '<b>Braquage solo</b> : vise un caissier / guichetier Fleeca : ça démarre seul ; un passant : [E]. La peur monte avec l\'arme et la voix '
        '(crier = plus vite). L\'argent sale tombe en <b>sacs plastique à ramasser</b>. Police joueurs, sinon <b>patrouilles IA</b> qui te poursuivent.',
        '<b>Braquages</b> : supérettes, bijouterie Vangelico, Fleeca (police requise). <b>Gros coup en duo</b> : Fleeca Legion (pirate + conducteur).',
        '<b>Marché noir</b> (téléphone → Inconnu → Appeler le contact : RDV GPS, la nuit) : munitions, armes non déclarées, silencieux, crochets, gilets.',
        '<b>Munitions</b> : artisanales (gang, ferraille + cuivre) &lt; Ammu-Nation (permis, 120 / jour) &lt; marché noir.',
        '<b>Contrats</b> (téléphone → Inconnu → Contrats) : vol, braquage, livraison, vente, élimination (scène RP).',
        '<b>Gangs</b> (F9) : Families, Ballas, Vagos, Lost MC + organisations Cartel Madrazo et Triades. Caisse, territoires, tags, receleur, '
        'labo, atelier de munitions, flotte + garage (logo sur la carte pour les membres).',
        '<b>Drogues</b> : plantations, labos, vente. <b>Recherche intelligente</b> : témoins, caméras, précision, chaleur, police IA de relais, '
        'description du suspect et mémoire de la ville (V8).',
    ])
    s += [Paragraph('6. Social, loisirs, événements', H2)]
    s += bullets([
        '<b>Vibe</b> (réseau social) : posts, photos, stories, tendances, badges ; <b>Weazel News automatique</b> (braquages, courses, loto, événements).',
        '<b>Courses de rue</b> : organisateur PNJ (Legion Square) : chrono solo ou course à mise, voiture prêtée ou la tienne, grille de départ.',
        '<b>Casino</b> (roue, loto, tickets ; barman, croupiers), <b>carnet de route</b> et <b>Weazel</b> (téléphone), <b>saisons</b> (paliers, titres).',
        '<b>Cayo Perico</b> en accès libre : vol gratuit animé depuis LSIA, <b>vol retour</b> au comptoir de la piste (pilote, logo avion).',
        '<b>Événements staff en un clic</b> : course à super vitesse, chute lunaire, super saut, soirée boxe, course de rue gratuite, soirée plage Cayo.',
    ])
    s += [Paragraph('7. Staff', H2)]
    s += bullets([
        'Rangs : helper, modo, admin, super-admin, fondateur (seul le fondateur promeut, en jeu : F11 → Joueurs → Rang).',
        'F10 panel (tickets, fiches, sanctions publiques, isolement, journal) · F11 menu rapide en 5 catégories : Joueurs, Moi (pouvoirs, '
        'persos GTA, animaux, argent, items), Véhicules, Monde et lieux, Événements.',
        '<b>Déplacer un point</b> (F11 → Monde et lieux) : n\'importe quel point mal placé (récolte, magasins, bars, PNJ, courses…) se pose à ta position.',
        'Raccourcis : Ctrl+Y TP marqueur, Ctrl+U vol libre, Ctrl+O noms et ID (150 m, PV, « parle »), auto en spectate.',
        'Argent / items : super-admin minimum, motif obligatoire, tout est journalisé.',
    ])
    s += [Paragraph('8. Mods importés (Drive)', H2)]
    s += bullets([
        'Marques réelles (voitures, mode, police) refusées par l\'importeur : risque de retrait du serveur par Cfx.re / Rockstar. Préférer des versions « lore GTA ».',
        'Maps : pharmacie du centre, garage clandestin, supermarché Willie\'s, club Bahamas Mamas, bureau d\'entreprise, village abandonné.',
        'Vêtements : bikini (haut + bas), robe d\'été, 6 coiffures femme.',
    ])
    s += [Spacer(1, 6), Paragraph(f'{len(points)} points de carte configurés : voir « ROADLINE_Carte_points.pdf ».', SMALL)]
    doc.build(s, onFirstPage=footer, onLaterPages=footer)


# ------------------------------------------------------------------------------------------------------------------
TESTS = [
    ('Avant de commencer', [
        'NETTOYER-MARQUES.bat (une fois), puis METTRE-A-JOUR.bat : fenêtre du serveur sans ligne ROUGE',
        'Si F3 / F5 font encore deux choses : Échap → Paramètres → Raccourcis → FiveM, vérifier F3 = Progression',
    ]),
    ('V10.1 · Nouveautés', [
        "Police en service au terminal du commissariat : caméras, passages récents, recherche par plaque ; bombe de peinture sur une caméra → hors service",
        "Visiter souvent une planque : signalement « voisins » à la police ; /mandat → demande → juge (ou attente du juge de permanence) → perquisition sur place",
        "/tribunal → une affaire ouverte : verser une photo puis un scellé analysé ; le juge retient / écarte ; verdict : pièces retenues mentionnées",
        "Photo d'un joueur → menu de la photo → Faire chanter : il paie (photo remise) ou refuse (brève Weazel + rumeur)",
        "Policier : déposer une saisie à la fourrière ; mettre en fourrière une voiture PNJ ; staff : /encheres → ouvrir ; enchérir à 2, surenchère remboursée",
        "Grosse poursuite (5 étoiles) : bandeau EN DIRECT, hélicoptère au-dessus du suspect ; journaliste en service sur place payé ; fin : brève",
        "Discord : /joueurs puis /geler un joueur (rôle staff) ; téléphone : http://IP:30120/gs_admin/ avec un code",
    ]),
    ('V10 · Nouveautés', [
        "Téléphone → Que faire : « En ce moment » cohérent ; chaque section ; un bouton GPS pose bien le point, un bouton action ouvre le bon menu",
        "Téléphone : Plans (enregistrer ici, GPS, partager ma position à un contact → bouton Itinéraire chez lui), Ville, Notes",
        "Téléphone : appel manqué → notification sur l'accueil + Récents ; Réglages → fond d'écran, marcher téléphone ouvert (écrire : le perso ne bouge pas)",
        "Braquer plusieurs fois à South LS : /quartiers → « en déclin » ; des déchets apparaissent, les ramasser (payé)",
        "Ventes au bar : le quartier monte (/quartiers), recette du commerce en hausse",
        "Policier en service, ville calme : un fait divers arrive (ou F11 → Événements → Fait divers) ; GPS, scène, [E] constatations",
        "En voiture radio allumée : sous-titres Radio Los Santos (rappel de rendez-vous, fugitif, fait divers) ; /radiols",
        "Acheter 5 jours différents dans la même supérette : « habitué » ; la braquer sans masque puis revenir : refusé",
        "CONFIGURER-DISCORD.bat puis relance : bot en ligne, /statut, /rdv sur Discord",
    ]),
    ('V9 · Nouveautés', [
        "Mourir (ou se faire tuer) : bougies au sol ; braquer une supérette : vitrine brisée, la réparer avec un autre perso (payé)",
        "Gagner une guerre de gang : fresque dans le quartier",
        "Monter très haut en recherche : affiche de fugitif, /cavale ; se faire livrer menotté (/livrer) puis incarcérer : prime au policier",
        "Appareil photo (quincaillerie) : photo d'un joueur et d'une voiture → objet photo (description) ; l'accrocher au commissariat, l'analyser",
        "Mission « voix au téléphone » : le point est sur une vraie cabine / un téléphone mural",
        "Assurer sa voiture, attendre 24 h, déclarer le vol ; la conduire ensuite → fraude détectée ; police : plaque « déclarée volée »",
        "La nuit : trouver le ring (rumeurs), s'inscrire à deux, parier avec un 3e joueur, combattre à mains nues (sortir une arme = disqualifié)",
        "/racket à la caisse d'un bar (membre de gang) : le patron reçoit l'offre ; refuser → « Faire passer le message » casse la vitrine",
        "Patron du bar au comptoir : « Laisser ma doublure » → PNJ à son apparence ; acheter (libre-service) ; la braquer avec un autre perso",
        "/contrat : prêt entre deux joueurs face à face → copie papier dans le sac, argent versé ; Mes contrats : échéances et prochain prélèvement",
        "/recap : ce mois-ci, mois dernier, biographie ; /rdv : programme de la semaine",
        "F11 → Anti-triche (alertes) et Statistiques de rétention ; vol libre / TP staff : aucune alerte",
        "SAUVEGARDER-BDD.bat (programmer toutes les 6 h), puis RESTAURER-BDD.bat → un seul joueur (sur un perso de test)",
        "CONFIGURER-DISCORD.bat : salon #statut mis à jour, message « La ville est ouverte » au démarrage ; le bot passe en ligne avec le serveur → /statut, /rdv",
    ]),
    ('V8 · Signatures', [
        'Braquer avec un masque et une voiture bleue : la police reçoit « Homme, masqué, armé, Voiture (bleu), plaque 4X…»',
        'Recommencer avec la même tenue : « Même tenue que le signalement n°X » ; changer de tenue + repeindre : plus de lien',
        'Tirer, se blesser, braquer sans gants : douilles, sang, empreintes visibles à la lampe torche (policier en service, en visant)',
        'Mettre sous scellé ([E]) → labo du commissariat → résultat après 3 min (profil inconnu, puis nom une fois fiché par F4)',
        'Gants (quincaillerie) : plus d\'empreintes ; javel : traces effacées autour',
        'Rouler 10-20 min hors de la ville : une rencontre au bord de la route (s\'arrêter, ou passer son chemin)',
        'Prendre un auto-stoppeur et le déposer à sa ville (GPS) ; F3 → Carnet de route : rencontre cochée',
        'Barman du Yellow Jack : « Quoi de neuf ? » puis « Ce que tu sais vraiment » ; l\'indic\' du pont de Davis (gang)',
        '/histoire au volant de sa voiture : kilomètres, accidents, repeintes ; police : Vérifier une plaque → historique',
        'Prison : se faire incarcérer → boulots (peine réduite, tickets), cantine, trafiquant ; évasion à deux la nuit avec outils',
        '/meteoevent storm (staff) : routes fermées, interventions payées (mécano ou kit de réparation)',
        '/mentor avec un perso niveau 5+ (disponible) et un nouveau (demande / accepter) ; /permis ; F4 → retirer des points',
        'Tatouages visibles (bras nus, visage) dans la description ; cachés avec masque / manches longues',
        'Fausse plaque (marché noir) : poser, braquer (pas de lien), Vérifier une plaque (police) → châssis différent ; la retirer',
        'Shérif : prendre le service à Sandy Shores / Paleto, F4 identique à la police',
        'F4 → Garde à vue → /droits côté suspect (avocat, aveux) → Interrogatoire → Incarcérer (peine réduite si aveux)',
        'F4 → Chien K9 : sortir, renifler un véhicule avec de la drogue dans le coffre, puis une personne',
        'Contrebande : docker du port de Paleto la nuit → bateau → caisses en mer → plage → argent sale',
        '/cinema (3 styles) et /ralenti ; /halloween on (staff) : citrouilles et auto-stoppeur fantôme',
        'Boutique de vêtements et création de perso : plus de t-shirt blanc sous les vestes / sweats / robes ; idem en enfilant une tenue en objet',
    ]),
    ('Démarrage et confort', [
        'Création de perso : « Visage de base 1 / 2 », « Ressemblance », « Teint », « Origines » ; pas de carte d\'identité au départ',
        'F3 ouvre / ferme la progression ; F5 = emotes seulement ; F11 = menu staff',
        'Double-clic eau / sandwich : consommé, pas de coup de poing dans le vide juste après',
        'Inventaire : images des objets (tomate, pioche, hache, pochons, alcools, tenue…)',
        'Supérette : acheter 3 articles d\'affilée (le menu reste ouvert) ; jerrican d\'essence en quincaillerie',
        'Points [E] discrets (petit cercle, visible de près) ; commandes / : seulement les utiles en tant que joueur',
    ]),
    ('Vie légale', [
        'Coiffeur, tatoueur, chirurgien (Pillbox), boutique de vêtements : vendeur PNJ + [E] qui ouvre le menu',
        'Ammu-Nation : permis de port d\'arme au comptoir (5 000 $) puis acheter un pistolet',
        'Récolte : bois (plusieurs arbres, hache en main), mine (pioche), ferme, ferraille ; un nœud s\'épuise et repousse',
        'Vestiaire de récolte (tenue de travail / civile) ; revente au logo indiqué (pas à côté)',
        'Chasse : permis au comptoir Ammu-Nation de Paleto ; viande et cuir à la boucherie de Paleto',
        'Dépôts bus / voirie / Post OP : « Prendre le poste ici » puis garage puis F6 → Mission',
        'Bars : Tequi-la-la, Vanilla Unicorn, Bahama Mamas (sans employé : barman PNJ, carte de base)',
        'Mécano en service : Alt sur la voiture d\'un ami → Personnaliser → Valider ; la voiture ressort du garage personnalisée',
        'Tenue en objet : W → Moi → Vêtements → Plier ma tenue ; double-clic sur l\'objet ; retour civil sans perso chauve',
        'Marina : essai d\'un bateau → retour sur le ponton ; motel Pink Cage trouvé grâce au logo',
    ]),
    ('Vie illégale', [
        'Supérette : viser le caissier → le braquage démarre seul ; sacs d\'argent sale au sol à ramasser',
        'Sans policier joueur : patrouilles IA avec agents (gyrophares, poursuite), plus de voitures vides',
        'Téléphone → Inconnu → Appeler le contact (gang ou réputation de rue) ; → Contrats',
        'Gangs : Families, Ballas, Vagos, Lost MC, Cartel Madrazo, Triades ; logo du garage du gang (membre)',
    ]),
    ('Monde, loisirs, secours', [
        'Cayo : vol aller, comptoir retour (pilote + logo), vol retour',
        'Casino : roue bien dans son cadre ; barman, caisse, croupiers ; Vanilla : danseuses ; Tequi-la-la : groupe sur scène',
        'Courses : organisateur (Legion Square) → circuit → voiture prêtée → grille → points sur la route → voiture reprise',
        'Bandeau Weazel News rouge (flash info, article, brève de braquage)',
        'À terre sans EMS : [G] secours IA ; EMS en service : F4 → Envoyer un secouriste IA',
    ]),
    ('Staff', [
        'F11 : Joueurs, Moi (persos GTA, animaux, argent super-admin), Véhicules, Monde et lieux, Événements (fusionnés)',
        'TP au marqueur : arrivée au sol (plus dans le ciel)',
        'Monde et lieux → Déplacer un point : déplacer un acheteur ou un arbre mal placé, puis le remettre',
    ]),
    ('À noter pendant le test', [
        'Points encore mal placés : les déplacer en jeu (F11 → Déplacer un point) et me dire lesquels',
        'FPS en ville / à Cayo / dans une map importée ; erreurs F8 (captures)',
    ]),
]


def fiche():
    doc = SimpleDocTemplate('docs/pdf/ROADLINE_Fiche_tests.pdf', pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='RoadLine RP · Fiche de tests', author='RoadLine RP')
    s = [Paragraph('RoadLine RP · Fiche de tests', H1),
         Paragraph(f'Coche au fur et à mesure ({VERSION}). Pour chaque problème : capture + coordonnées (F11 → Copier mes coordonnées).', P)]
    for title, items in TESTS:
        rows = [['OK', 'À tester', 'Remarque']] + [['[  ]', i, ''] for i in items]
        s += [KeepTogether([Paragraph(title, H2), table(rows, [10 * mm, 120 * mm, 50 * mm])])]
    doc.build(s, onFirstPage=footer, onLaterPages=footer)


# ------------------------------------------------------------------------------------------------------------------
CATS = {
    'gs_jobs': ('Métiers', colors.HexColor('#28E0FF')), 'gs_economy': ('Commerces', colors.HexColor('#FFC400')),
    'gs_quests': ('Quêtes', colors.HexColor('#5AFF8C')), 'gs_harvest': ('Récolte', colors.HexColor('#8BC34A')),
    'gs_heists': ('Braquages', colors.HexColor('#FF2E88')), 'gs_stickup': ('Braquages', colors.HexColor('#FF2E88')),
    'gs_gangs': ('Gangs', colors.HexColor('#A06EFF')), 'gs_drugs': ('Illégal', colors.HexColor('#E53935')),
    'gs_blackmarket': ('Illégal', colors.HexColor('#E53935')), 'gs_races': ('Courses', colors.HexColor('#FF9800')),
    'gs_rental': ('Location', colors.HexColor('#00BFA5')), 'gs_world': ('Cayo / monde', colors.HexColor('#2196F3')),
    'gs_hideouts': ('Motels', colors.HexColor('#795548')),
    'gs_evidence': ('Police scientifique', colors.HexColor('#4FD8FF')), 'gs_rumors': ('Rumeurs / indic\'', colors.HexColor('#A24BFF')),
    'gs_police': ('Prison', colors.HexColor('#FF2340')), 'gs_weather': ('Tempête', colors.HexColor('#607D8B')),
    'gs_roadside': ('Route', colors.HexColor('#FFD23F')),
}
MLO = [
    ['Map importée', 'Coordonnées', 'Source'],
    ['Pharmacie du centre-ville (Pops Pills)', '104.41, -15.07, 72.35', 'fichier « lisez-moi » du mod'],
    ['Garage clandestin + casse', '-59.97, -1211.09, 30.0', 'fichier « lisez-moi » du mod'],
    ['Bureau d\'entreprise', '~ -643, -490, 34', 'estimé depuis les fichiers de la map'],
    ['Club Bahamas Mamas', '~ -1388, -586, 30', 'emplacement du club du jeu'],
    ['Supermarché Willie\'s', 'à relever en jeu', 'F11 → Copier mes coordonnées'],
    ['Village abandonné', 'à relever en jeu', 'F11 → Copier mes coordonnées'],
]


def carte(points):
    doc = SimpleDocTemplate('docs/pdf/ROADLINE_Carte_points.pdf', pagesize=landscape(A4), leftMargin=12 * mm, rightMargin=12 * mm,
                            topMargin=12 * mm, bottomMargin=14 * mm, title='RoadLine RP · Carte des points', author='RoadLine RP')
    W, H = 250 * mm, 160 * mm
    x0, x1, y0, y1 = -4200.0, 6000.0, -6000.0, 8200.0
    d = Drawing(W, H)
    d.add(Rect(0, 0, W, H, fillColor=colors.HexColor('#0B1A2A'), strokeColor=None))
    sx, sy = W / (x1 - x0), H / (y1 - y0)
    for lx, ly, name in [(-300, -900, 'Los Santos'), (1800, 3700, 'Sandy Shores'), (-200, 6400, 'Paleto Bay'), (4840, -5170, 'Cayo Perico'), (-1040, -2740, 'LSIA')]:
        d.add(String((lx - x0) * sx, (ly - y0) * sy + 8, name, fontSize=8, fillColor=colors.white))
    seen = {}
    for e in points:
        if not (x0 < e['x'] < x1 and y0 < e['y'] < y1):
            continue
        label, col = CATS.get(e['res'], ('Autres', colors.HexColor('#B0BEC5')))
        seen[label] = col
        d.add(Circle((e['x'] - x0) * sx, (e['y'] - y0) * sy, 1.6, fillColor=col, strokeColor=None))
    yy = H - 12
    for label, col in sorted(seen.items()):
        d.add(Circle(W - 70 * mm, yy + 3, 3, fillColor=col, strokeColor=None))
        d.add(String(W - 66 * mm, yy, label, fontSize=8, fillColor=colors.white))
        yy -= 11
    s = [Paragraph('RoadLine RP · Carte des points', H1), Paragraph(f'{len(points)} points configurés (positions des fichiers de config, à caler en jeu si besoin).', P), d,
         PageBreak(), Paragraph('Maps importées', H2), table(MLO, [90 * mm, 70 * mm, 90 * mm])]
    rows = [['Ressource', 'Point', 'x', 'y', 'z']]
    for e in points:
        rows.append([e['res'].replace('gs_', ''), e['path'].split('.', 2)[-1][:70], f"{e['x']:.1f}", f"{e['y']:.1f}", f"{e['z']:.1f}"])
    s += [Paragraph('Tous les points', H2), table(rows, [28 * mm, 150 * mm, 22 * mm, 22 * mm, 18 * mm], font=7)]
    doc.build(s, onFirstPage=footer, onLaterPages=footer)


if __name__ == '__main__':
    pts = json.load(open('tools/points.json', encoding='utf-8'))
    guide(pts)
    fiche()
    carte(pts)
    print('PDF générés : docs/pdf/ROADLINE_Guide.pdf, ROADLINE_Fiche_tests.pdf, ROADLINE_Carte_points.pdf')
