# Génère les PDF de docs/pdf : guide complet, fiche de tests, carte des points.
# Lancer depuis la racine : lua5.4 tools/points.lua && python3 tools/pdf.py
import json
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.graphics.shapes import Drawing, Rect, Circle, String, Line

VERSION = 'V6'
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
    ['F1', 'Téléphone', 'Vibe, banque, petits boulots, bourse…'],
    ['F2 · TAB · 1 à 5', 'Inventaire · barre rapide · objets rapides', 'Double-clic ou Alt + clic = utiliser'],
    ['K', 'Inventaire proche', 'coffre, boîte à gants'],
    ['F3', 'Progression, quêtes, niveau', ''],
    ['F4', 'Intervention', 'police / EMS en service'],
    ['F5 · X · J · G', 'Emotes · annuler · pointer · effets', 'G = effets seulement pendant une emote à effets'],
    ['F6', 'Métiers', 'service, tenue, factures, direction, missions'],
    ['F7', 'Duo', ''],
    ['F9', 'Gang', 'caisse, membres, territoires, atelier, flotte'],
    ['F10 · F11', 'Panel staff · menu staff rapide', 'staff uniquement'],
    ['I', 'Aide des touches', 'aussi /touches'],
    ['Z', 'Menu radial', 'radio, etc.'],
    ['Alt gauche (maintenu)', 'Viser / interagir (ox_target)', ''],
    ['E', 'Interagir sur un point [E] · braquer un PNJ visé', ''],
    ['N · ²', 'Parler · portée de la voix', 'crier (²) fait peur aux PNJ braqués'],
    ['Verr. Maj (maintenu)', 'Parler à la radio', 'après avoir réglé une fréquence'],
    ['H', 'Mains en l\'air (à pied) · démarrer sans clé (en voiture)', ''],
    ['L · B', 'Verrouiller le véhicule · ceinture', ''],
    ['Ctrl gauche', 'S\'accroupir', ''],
    ['G (près d\'un tag)', 'Effacer un tag adverse', 'gangs'],
    ['Ctrl+Y · Ctrl+U · Ctrl+O', 'TP marqueur · vol libre · noms et ID', 'staff en mode staff'],
    ['Espace / Retour', 'Passer le film du vol · annuler', ''],
]

COMMANDS = [
    ['Commande', 'Pour quoi'],
    ['/touches · /regles · /report', 'aide des touches · règlement · ticket au staff'],
    ['/radio [fréquence|off]', 'radio (aussi Z → Radio)'],
    ['/contact · /contrats', 'marché noir (gang ou réputation de rue) · contrats entre joueurs'],
    ['/depanneur · /taxi · /commandes', 'appeler un mécano / un taxi · carnet des employés en service'],
    ['/carnet · /saison · /reputation', 'carnet de route · passe de saison · réputation'],
    ['/factures · /job · /duo · /gang', 'factures à payer · menus (aussi F6, F7, F9)'],
    ['/me · /do', 'actions RP affichées'],
    ['/boutique', 'boutique cosmétique (réclamer ses achats)'],
    ['/moniteur', 'auto-école (moniteur)'],
    ['/economie', 'tableau de bord de l\'économie (admin)'],
    ['/builder', 'décor : placer / retirer des objets (super-admin)'],
    ['/whitelist · /gsjob · /gsgang · /gsevent · /meteo', 'outils staff'],
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
        '<b>Logement</b> : chambres de motel à la semaine (Pink Cage 450 $, Sandy 300 $, Paleto 320 $ ; coffre + garde-robe), '
        'vrais logements chez l\'agent immobilier (Dynasty 8).',
        '<b>Métiers</b> (F6) : LSPD, EMS, mécano LS Customs, concession PDM, agence immobilière, auto-école, avocats, juge, Weazel News, '
        'bar, restaurant, mairie, psy, routier, bus, taxi, livreur, éboueur. Contrats multiples (3), grades, tenues, garages, missions animées.',
        '<b>Direction</b> : recruter (avec accord), grades, licencier, caisse, <b>salaires réglables</b> (entreprises privées), '
        '<b>primes</b>, <b>blanchiment</b> (plafonné au chiffre d\'affaires légal du jour, contrôle fiscal possible).',
        '<b>Mécano</b> : réparer (capot ouvert), pneus, remettre sur ses roues, nettoyer, livraisons de pièces, carnet /depanneur. '
        'Double des clés des véhicules de service pour tous les métiers.',
        '<b>Activités libres</b> : pêche, mine, bûcheron, ferme, <b>ferrailleur</b>, chasse (permis). Petits boulots au téléphone.',
        '<b>Permis de conduire</b> (auto-école : théorie + pratique), <b>justice</b> (tribunal, avocat, verdicts), '
        '<b>mairie</b> (mariage, divorce), <b>banque</b> (guichets, distributeurs, plafonds), <b>bourse de la ville</b>.',
        '<b>Location</b> : vélos, scooters, citadines ; <b>bateaux</b> à la marina de LS et à la jetée de Cayo.',
    ])
    s += [Paragraph('5. Vie illégale', H2)]
    s += bullets([
        '<b>Braquage solo de PNJ</b> : vise un passant / caissier / guichetier Fleeca → [E]. La peur monte avec l\'arme et la voix '
        '(crier = plus vite). Toujours signalé (police joueurs, sinon police IA). Plafonds anti-farm.',
        '<b>Braquages</b> : supérettes, bijouterie Vangelico, Fleeca (police requise). <b>Gros coup en duo</b> : Fleeca Legion (pirate + conducteur).',
        '<b>Marché noir</b> (/contact, la nuit, planque qui tourne) : munitions, armes non déclarées, silencieux, crochets, gilets ; prix selon la rareté.',
        '<b>Munitions</b> : artisanales (gang, ferraille + cuivre) &lt; Ammu-Nation (permis, 120 / jour) &lt; marché noir.',
        '<b>Contrats</b> (/contrats) : vol, braquage, livraison, vente, élimination (scène RP) ; récompense bloquée puis versée.',
        '<b>Gangs</b> (F9) : caisse, territoires et guerres, tags, receleur, labo, atelier de munitions, <b>flotte choisie par le chef + 1 véhicule perso</b>.',
        '<b>Drogues</b> : plantations, labos, vente. <b>Recherche intelligente</b> : témoins, caméras, précision, chaleur, police IA de relais.',
    ])
    s += [Paragraph('6. Social, loisirs, événements', H2)]
    s += bullets([
        '<b>Vibe</b> (réseau social) : posts, photos, stories, tendances, badges ; <b>Weazel News automatique</b> (braquages, courses, loto, événements).',
        '<b>Courses de rue</b> classées, <b>casino</b> (roue, loto hebdo), <b>carnet de route</b> (itinéraires, spots photo), <b>saisons</b> (paliers, titres).',
        '<b>Cayo Perico</b> en accès libre : vol gratuit animé depuis LSIA ([Espace] = rapide), bateaux, <b>soirée DJ sur la plage</b> (staff).',
        '<b>Événements staff en un clic</b> : course à super vitesse, chute lunaire, super saut, soirée boxe, course de rue gratuite, soirée plage Cayo.',
    ])
    s += [Paragraph('7. Staff', H2)]
    s += bullets([
        'Rangs : helper, modo, admin, super-admin, fondateur (seul le fondateur promeut, en jeu : F11 → Joueurs → Rang).',
        'F10 panel (tickets, fiches, sanctions publiques, isolement, journal) · F11 menu rapide (mode staff, vol libre, invisible, spectate, animal, '
        'métiers et gangs de test, véhicules, points de métier, Fun, événements, décor, items).',
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
    ('Démarrage', [
        'Fenêtre « Serveur GTA SOON » sans ligne ROUGE (noter les ressources en jaune)',
        'F8 → connect localhost ; création de perso → apparition mairie (pas de choix d\'appartement)',
        'Règlement affiché puis accepté ; GPS vers Max ; quête « Ton premier jour »',
    ]),
    ('Touches (aucun doublon)', [
        'I / F1 / F2 / F3 / F5 / F6 / F7 / F9 : chaque touche ouvre UN seul menu',
        'H à pied = mains en l\'air ; H en voiture PNJ = démarrer sans clé ; X annule une emote',
        'Double-clic sur une bouteille d\'eau dans l\'inventaire = elle est bue',
        'Radio : Z → Radio → fréquence 42 → parler avec Verr. Maj ; « Qui est sur le canal »',
    ]),
    ('Vie légale', [
        'Location vélo (mairie) puis bateau (marina) ; rendu du véhicule',
        'Motel Pink Cage : louer 1 semaine, entrer, coffre, garde-robe, sortir',
        'Métier mécano (F11 → Me mettre un métier) : service, pneus, remettre sur roues, mission pièces',
        'Direction : salaires, prime, blanchiment (faire d\'abord une facture payée)',
        'Carnet : /depanneur depuis un 2e perso ou un ami → /commandes côté mécano',
    ]),
    ('Vie illégale', [
        'Viser un passant avec une arme → [E] → crier (²) : la jauge monte plus vite ; baisser l\'arme = fuite',
        'Braquer la caisse d\'une supérette (caissier) → argent sale ; la police IA arrive si aucun LSPD',
        '/contact (se mettre dans un gang d\'abord) la nuit : acheter des munitions ; prix qui montent',
        'F9 → Atelier : munitions artisanales (ferraille + cuivre du ferrailleur)',
        '/contrats : publier, accepter avec un ami, valider',
        'F9 (chef) → Flotte du gang + véhicule perso → garage du gang',
    ]),
    ('Monde et événements', [
        'Aéroport LSIA → vol pour Cayo : film, [Espace] pour passer, arrivée sur l\'île, retour',
        'F11 → Événements → Soirée plage Cayo : sono, danseurs, musique ; brève Weazel dans Vibe',
        'F11 → Événements → Chute lunaire / Course super vitesse : effet dans la zone, fin propre',
        'Casino : roue ; loto (ticket)',
    ]),
    ('Staff', [
        'F11 → mode staff → Ctrl+Y (TP marqueur), Ctrl+U (vol libre), Ctrl+O (noms, PV, « parle »)',
        'Spectate d\'un joueur : noms et ID activés automatiquement',
        '/builder : placer un banc, retirer une poubelle de la map, la remettre',
        'Rang : promouvoir un ami modo puis le rétrograder',
    ]),
    ('Mods importés', [
        'Vêtements : bikini, robe d\'été, coiffures femme (fin des listes en boutique)',
        'Maps : aller à la pharmacie (104, -15, 72) et au garage clandestin (-60, -1211, 30)',
        'Noter tout ce qui clignote, disparaît ou fait chuter les FPS (resmon 1 dans F8)',
    ]),
    ('À noter pendant le test', [
        'Points [E] impossibles à atteindre (ex. pharmacie près du poste de police du centre) : F11 → Copier mes coordonnées',
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
