#!/usr/bin/env python3
"""Génère les PDF GTA SOON (docs/pdf) : carte des paquets cachés, présentation des fonctionnalités, reste à faire.
Usage : python3 scripts/docs/generer_pdfs.py   (nécessite reportlab et matplotlib)"""
import pathlib, re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'pdf'
OUT.mkdir(parents=True, exist_ok=True)

BG, PANEL, PINK, CYAN, TEXT, MUTED = '#0b0714', '#140c24', '#ff2e88', '#28e0ff', '#f3eaff', '#9b8bb8'
H1 = ParagraphStyle('h1', fontName='Helvetica-Bold', fontSize=22, leading=26, textColor=colors.HexColor(PINK), spaceAfter=10)
H2 = ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=14, leading=18, textColor=colors.HexColor(CYAN), spaceBefore=12, spaceAfter=6)
P = ParagraphStyle('p', fontName='Helvetica', fontSize=10, leading=14, textColor=colors.HexColor(TEXT))
SMALL = ParagraphStyle('s', parent=P, fontSize=8.5, leading=11, textColor=colors.HexColor(MUTED))
LI = ParagraphStyle('li', parent=P, leftIndent=12, bulletIndent=2)


def background(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(colors.HexColor(BG))
    canvas.rect(0, 0, A4[0], A4[1], fill=1, stroke=0)
    canvas.setFillColor(colors.HexColor(PINK))
    canvas.rect(0, A4[1] - 0.25 * cm, A4[0], 0.25 * cm, fill=1, stroke=0)
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(colors.HexColor(MUTED))
    canvas.drawString(1.5 * cm, 1 * cm, 'GTA SOON · document interne')
    canvas.drawRightString(A4[0] - 1.5 * cm, 1 * cm, f'page {doc.page}')
    canvas.restoreState()


def build(name, story):
    doc = SimpleDocTemplate(str(OUT / name), pagesize=A4, leftMargin=1.6 * cm, rightMargin=1.6 * cm, topMargin=1.6 * cm, bottomMargin=1.6 * cm,
                            title=name.replace('.pdf', ''), author='GTA SOON')
    doc.build(story, onFirstPage=background, onLaterPages=background)
    print('PDF :', OUT / name)


def bullets(items):
    return [Paragraph(i, LI, bulletText='•') for i in items]


def table(rows, widths, head=True):
    t = Table(rows, colWidths=widths, repeatRows=1 if head else 0)
    style = [
        ('FONT', (0, 0), (-1, -1), 'Helvetica', 8.5), ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor(TEXT)),
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor(PANEL)), ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#2a1a45')),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]
    if head:
        style += [('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2a1a45')), ('FONT', (0, 0), (-1, 0), 'Helvetica-Bold', 9),
                  ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor(CYAN))]
    t.setStyle(TableStyle(style))
    return t


# 1. Paquets cachés ---------------------------------------------------------------------------------------------------
def packages_pdf():
    cfg = (ROOT / 'server/resources/[gtasoon]/gs_quests/shared/config.lua').read_text(encoding='utf-8')
    block = cfg[cfg.index('points = {'):]
    block = block[:block.index('},\n}')]
    pts = [tuple(float(v) for v in m) for m in re.findall(r'vec3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)', block)]
    hints = ['Jetée de Del Perro', 'Plage de Vespucci', 'Aéroport de Los Santos', 'Port (Elysian Island)', 'Terminal portuaire',
             'Cypress Flats', 'Grove Street', 'Centre-ville (Textile City)', 'Toit de la Maze Bank Tower', 'Vinewood Hills',
             'Observatoire Galileo', 'Panneau Vinewood', 'Aérodrome de Sandy Shores', 'Sandy Shores', 'Ferme de Grapeseed',
             'Grapeseed', 'Paleto Bay', 'Sommet du mont Chiliad', 'Forêt de Paleto', 'Côte est (falaises)']
    zones = [('LOS SANTOS', -400, -1300), ('VINEWOOD', 300, 700), ('SANDY SHORES', 1700, 3600), ('GRAPESEED', 1900, 4800),
             ('PALETO BAY', -150, 6400), ('MONT CHILIAD', 500, 5400), ('OCÉAN PACIFIQUE', -3200, 1500), ('ALAMO SEA', 900, 4000)]

    fig, ax = plt.subplots(figsize=(7.2, 9.6), dpi=150)
    fig.patch.set_facecolor(BG)
    ax.set_facecolor('#100a1c')
    ax.set_xlim(-4000, 4400)
    ax.set_ylim(-4000, 8000)
    ax.set_aspect('equal')
    for x in range(-4000, 4401, 1000):
        ax.axvline(x, color='#2a1a45', lw=0.5)
    for y in range(-4000, 8001, 1000):
        ax.axhline(y, color='#2a1a45', lw=0.5)
    for label, x, y in zones:
        ax.text(x, y, label, color='#5b4a80', fontsize=9, ha='center', fontweight='bold', alpha=0.9)
    for i, (x, y, _) in enumerate(pts, 1):
        ax.scatter(x, y, s=180, color=PINK, edgecolors=CYAN, linewidths=1.5, zorder=3)
        ax.text(x, y, str(i), color='white', fontsize=7, ha='center', va='center', fontweight='bold', zorder=4)
    ax.tick_params(colors=MUTED, labelsize=6)
    for s in ax.spines.values():
        s.set_color('#2a1a45')
    ax.set_title('Carte schématique (coordonnées du jeu, x / y)', color=TEXT, fontsize=10)
    img = OUT / '_carte_paquets.png'
    fig.savefig(img, facecolor=BG, bbox_inches='tight')
    plt.close(fig)

    rows = [['#', 'Lieu (indice)', 'x', 'y', 'z']]
    for i, (x, y, z) in enumerate(pts, 1):
        rows.append([str(i), hints[i - 1] if i <= len(hints) else '', f'{x:.1f}', f'{y:.1f}', f'{z:.1f}'])
    story = [
        Paragraph('Les 20 paquets cachés', H1),
        Paragraph('Clin d\'œil aux premiers GTA : 20 colis invisibles sur la carte, qui apparaissent seulement quand on passe à '
                  'moins de 40 m. +50 XP chacun, 2 500 XP + 5 000 $ et le badge « Collectionneur » pour les 20. '
                  'Positions à caler en jeu (F11 → Copier mes coordonnées) avant toute communication publique.', P),
        Spacer(1, 8), Image(str(img), width=15 * cm, height=15 * cm * 9.6 / 7.2 * 0.72),
        PageBreak(), Paragraph('Coordonnées exactes', H2), table(rows, [1 * cm, 7 * cm, 2.6 * cm, 2.6 * cm, 2.2 * cm]),
        Spacer(1, 10), Paragraph('Idée marketing : dévoiler un indice par jour sur Discord (« le 9e colis surplombe toute la ville… »), '
                                 'et un classement des chasseurs dans le panel et sur le réseau social.', SMALL),
    ]
    build('GTASOON_paquets_caches.pdf', story)
    img.unlink()


# 2. Fonctionnalités (marketing) --------------------------------------------------------------------------------------
FEATURES = [
    ('Arrivée en ville', [
        'Création du personnage (homme / femme, visage, cheveux, vêtements), apparition au choix sur la carte (mairie, Legion, Del Perro, motels, Sandy, Paleto).',
        'Max le Guide accueille chaque nouveau : Pôle Emploi, location de véhicules, premiers dollars.',
        'Location immédiate : BMX, vélo, scooter, mini citadine, petite décapotable, à partir de 15 $.',
    ]),
    ('Progression façon « vieux GTA »', [
        'XP et 50 niveaux, bonus à chaque niveau, annonces plein écran « NIVEAU 4 » / « MISSION RÉUSSIE ».',
        'Histoires différentes selon qu\'on joue un homme (Big Sal, le parrain à l\'ancienne) ou une femme (Mama Rosa et son cercle).',
        'La Voix : des missions reçues dans une cabine téléphonique. 20 paquets cachés à collectionner.',
        '3 défis du jour, série de connexions récompensée, titres (Nouveau venu → Mythe) et badges affichés sur le réseau social.',
    ]),
    ('Métiers', [
        'Multi-job avec contrats, prise de service, salaires, caisse de société, factures, garages et coffres.',
        'Police : contrôle d\'identité, plaque, amende, alcootest, menottes, escorte, fouille, casier, prison, fourrière, herse, radar, renforts.',
        'EMS : réanimer, soigner, porter, ambulance. Mécano, taxi, livreur, éboueur, concession.',
        'Vestiaire avec tenues selon le grade, armurerie de service gratuite et limitée.',
    ]),
    ('Une ville qui ne s\'arrête jamais', [
        'Pas d\'EMS connecté ? Un secouriste PNJ vient te relever. Pas de policier ? La police du jeu prend le relais.',
        'Météo dynamique avec événements (canicule, tempête), économie à prix variables selon l\'offre et la demande.',
        'Recherche intelligente : un crime n\'est connu que s\'il est vu ou entendu (témoins, heure, météo).',
    ]),
    ('Côté illégal', [
        'Drogue de la récolte à la vente : vente directe aux passants, mode « deal » où les clients viennent à toi, receleur de nuit pour la vente en gros.',
        'Gangs vivants : territoires et influence, tags à la bombe, QG, garage aux couleurs, labos dans des intérieurs secrets.',
        'Braquages de supérette, bijouterie et banque ; duo criminel lié.',
    ]),
    ('Petits détails qui changent tout', [
        'Menu radial véhicule (portes, capot, moteur, places, vitres), ceinture avec éjection, mains en l\'air, /me et /do.',
        'Kits de réparation et de nettoyage utilisables par tous, alcool avec ivresse, cigarettes (briquet requis).',
        'Vendeurs PNJ dans chaque supérette, marqueurs néon au sol, touche [E] partout.',
    ]),
    ('Téléphone et réseau social', [
        'Téléphone : messages, contacts, appels, banque, factures, emploi, urgences.',
        'Réseau social intégré (pseudo, posts, likes, mentions, titres de progression).',
    ]),
    ('Staff et confiance', [
        'Panel staff compact (tickets, fiches, sanctions publiques et anonymes, journal) + menu pouvoirs F11.',
        'Tout est vérifié côté serveur (anti-triche), sanctions publiées en transparence sur Discord.',
        'Boutique 100 % cosmétique, zéro pay-to-win.',
    ]),
]


def features_pdf():
    story = [Paragraph('GTA SOON · Ce que la ville propose', H1),
             Paragraph('Serveur roleplay francophone, néon et sunset. Tout ce qui est listé ici est codé et testé par des tests '
                       'automatiques ; les tests en jeu sont en cours (bêta).', P)]
    for title, items in FEATURES:
        story += [Paragraph(title, H2)] + bullets(items)
    story += [Paragraph('À venir (V4 et plus)', H2)] + bullets([
        'Logement (appartements de départ, maisons), banque et distributeurs avec interface, métiers « farm » (pêche, chasse, mine, bûcheron, fermier, trucker, bus).',
        'Commerces tenus par des joueurs (restaurants, bars, garages), base de données police (mandats, rapports), courses de rue classées, guerres de territoire déclarées.',
        'Pass de saison cosmétique, titres exclusifs, plaques et néons personnalisés.',
    ])
    story += [Spacer(1, 8), Paragraph('Phrases d\'accroche : « Une ville qui vit même quand tu n\'es pas là. » · « Ton histoire commence à la mairie, '
                                      'pas dans un menu. » · « Zéro pay-to-win. Ici on gagne en jouant. »', SMALL)]
    build('GTASOON_fonctionnalites.pdf', story)


# 3. Reste à faire / à tester -----------------------------------------------------------------------------------------
def todo_pdf():
    tests = [
        ('Connexion', 'Nouveau perso homme + femme, spawn sur la carte, Max le Guide, location, F2 progression'),
        ('Menus', 'Marcher avec un menu ouvert (F11, F4, supérette) ; caméra bloquée pendant le menu'),
        ('Police', 'F4 : identité, plaque, amende, alcootest, menottes, escorte, véhicule, fouille, casier, prison, fourrière, herse, radar, renforts'),
        ('EMS', 'Réanimer (trousse), soigner (bandage), porter, ambulance ; secours IA sans EMS'),
        ('Vestiaires', 'Tenues police / EMS / mécano / concession par grade, retour tenue civile'),
        ('Armurerie', 'Déplacer l\'armurerie LSPD hors du mur (F11 → Points de métier)'),
        ('Gangs', 'Créer un gang (F11), planque et garage, tags, receleur de nuit, labos ×2'),
        ('Détails', 'Z radial véhicule, B ceinture, X mains en l\'air, /me /do, kits, cigarettes, alcool'),
        ('Économie', 'Supérettes avec vendeurs, cavistes, quincailleries, icônes d\'items'),
        ('Staff', 'F10 compact, F11 complet, sanctions, journal'),
    ]
    todo = [
        ('Calage en jeu', 'Coordonnées : paquets, personnages de quête, comptoirs, vendeurs, portes de labos, garages de gangs, vestiaires'),
        ('Tenues', 'Vérifier les numéros de vêtements des uniformes dans le menu vêtements et corriger jobs.lua'),
        ('Nom du réseau social', 'Choisir le nouveau nom (propositions : Glow, Pulse, Vibe, Blink)'),
        ('Boutique', 'Relire le PLA Cfx de septembre 2026 ; choisir les 1ers packs cosmétiques ; config Tebex'),
        ('V4', 'Logement, banque, métiers farm, commerces joueurs, base de données police, courses, guerres de gangs'),
        ('Ouverture', 'Discord (rôles → staff), règlement, liste blanche / file d\'attente, sauvegardes automatiques de la base'),
    ]
    story = [Paragraph('GTA SOON · Reste à faire et à tester', H1),
             Paragraph('À cocher au fur et à mesure. Chaque ligne rouge en console ou comportement bizarre : capture + message à [DEV].', P),
             Paragraph('Tests en jeu (bêta V3.1)', H2), table([['Domaine', 'À vérifier', 'OK ?']] + [[a, Paragraph(b, P), ''] for a, b in tests], [3 * cm, 12 * cm, 1.8 * cm]),
             Paragraph('Reste à faire', H2), table([['Sujet', 'Détail']] + [[a, Paragraph(b, P)] for a, b in todo], [3.6 * cm, 13.2 * cm])]
    build('GTASOON_reste_a_faire.pdf', story)


if __name__ == '__main__':
    packages_pdf()
    features_pdf()
    todo_pdf()
