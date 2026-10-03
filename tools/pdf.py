# Génère les PDF de docs/pdf : guide complet, fiche de tests, carte des points.
# Lancer depuis la racine : lua5.4 tools/points.lua && python3 tools/pdf.py
import json
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.graphics.shapes import Drawing, Rect, Circle, String, Line

VERSION = 'V7'
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
    canvas.drawString(15 * mm, 10 * mm, f'ROADTRIP · new generation · {VERSION}')
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
    ['Z', 'Menu radial', 'Moi (tenue en objet, chapeau, lunettes, masque, animations, factures…), Radio, Véhicule'],
    ['Alt gauche (maintenu)', 'Viser / interagir (ox_target)', ''],
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

COMMANDS = [
    ['Commande', 'Pour quoi'],
    ['/touches · /regles · /report', 'aide des touches · règlement · ticket au staff'],
    ['/me · /do', 'actions RP affichées'],
    ['/radio [fréquence|off]', 'radio (aussi Z → Radio)'],
    ['/taxi · /depanneur', 'appeler un taxi / un mécano'],
    ['/factures · /reputation · /saison · /quartiers', 'factures · réputation · passe de saison · ambiance des quartiers'],
    ['/retoucheperso', 'retoucher son perso (une seule fois)'],
    ['/boutique', 'boutique cosmétique (réclamer ses achats)'],
    ['Staff', '/whitelist · /gsjob · /gsgang · /gsevent · /meteo · /builder · /economie (les joueurs ne les voient pas)'],
]


def guide(points):
    doc = SimpleDocTemplate('docs/pdf/ROADTRIP_Guide.pdf', pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='ROADTRIP · Guide complet', author='ROADTRIP')
    s = [Paragraph('ROADTRIP · Guide complet', H1),
         Paragraph(f'Tout ce qui est disponible sur le serveur ({VERSION}), comment y accéder, et les outils. '
                   'Serveur FiveM RP français (Qbox, ox_lib, ox_inventory, pma-voice).', P), Spacer(1, 4)]

    s += [Paragraph('1. Installer, mettre à jour, importer', H2)]
    s += bullets([
        '<b>Toujours</b> : clic droit sur le zip ROADTRIP → Extraire tout, puis ouvrir le dossier <b>gtasoon</b>.',
        '<b>INSTALLER.bat</b> : première installation. <b>METTRE-A-JOUR.bat</b> : nouvelle version (sauvegarde auto, relance le serveur). '
        'Il importe aussi automatiquement les mods posés dans C:\\GTASOON\\mods-a-trier.',
        '<b>IMPORTER-MODS.bat</b> : véhicules, vêtements, maps (zip / rar / dlc.rpf) → tri, contrôle, installation, concession. '
        'Lit aussi « Mon Drive\\GTA » si Google Drive pour ordinateur est installé.',
        '<b>REPARER-LANCEUR.bat</b> : « le chemin d\'accès spécifié est introuvable » au démarrage. '
        '<b>DEVENIR-ADMIN.bat</b> : te met fondateur. <b>SAUVEGARDER-BDD.bat</b>, <b>REPARER-MARIADB.bat</b>.',
    ])

    s += [Paragraph('2. Touches', H2), table(KEYS, [38 * mm, 78 * mm, 64 * mm])]
    s += [Paragraph('3. Commandes utiles', H2), table(COMMANDS, [60 * mm, 120 * mm])]

    s += [PageBreak(), Paragraph('4. Vie légale', H2)]
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
        '<b>Tenues en objets</b> : Z → Moi → Vêtements → Plier ma tenue ; double-clic sur l\'objet pour l\'enfiler (échangeable, rangeable).',
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
        '<b>Drogues</b> : plantations, labos, vente. <b>Recherche intelligente</b> : témoins, caméras, précision, chaleur, police IA de relais.',
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
    s += [Spacer(1, 6), Paragraph(f'{len(points)} points de carte configurés : voir « ROADTRIP_Carte_points.pdf ».', SMALL)]
    doc.build(s, onFirstPage=footer, onLaterPages=footer)


# ------------------------------------------------------------------------------------------------------------------
TESTS = [
    ('Avant de commencer', [
        'NETTOYER-MARQUES.bat (une fois), puis METTRE-A-JOUR.bat : fenêtre du serveur sans ligne ROUGE',
        'Si F3 / F5 font encore deux choses : Échap → Paramètres → Raccourcis → FiveM, vérifier F3 = Progression',
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
        'Tenue en objet : Z → Moi → Vêtements → Plier ma tenue ; double-clic sur l\'objet ; retour civil sans perso chauve',
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
    doc = SimpleDocTemplate('docs/pdf/ROADTRIP_Fiche_tests.pdf', pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='ROADTRIP · Fiche de tests', author='ROADTRIP')
    s = [Paragraph('ROADTRIP · Fiche de tests', H1),
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
    doc = SimpleDocTemplate('docs/pdf/ROADTRIP_Carte_points.pdf', pagesize=landscape(A4), leftMargin=12 * mm, rightMargin=12 * mm,
                            topMargin=12 * mm, bottomMargin=14 * mm, title='ROADTRIP · Carte des points', author='ROADTRIP')
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
    s = [Paragraph('ROADTRIP · Carte des points', H1), Paragraph(f'{len(points)} points configurés (positions des fichiers de config, à caler en jeu si besoin).', P), d,
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
    print('PDF générés : docs/pdf/ROADTRIP_Guide.pdf, ROADTRIP_Fiche_tests.pdf, ROADTRIP_Carte_points.pdf')
