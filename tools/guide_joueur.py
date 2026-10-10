# Guide du joueur RoadLine RP (PDF public, « tuto » en jeu) : tout ce qu'on peut faire en ville, où, quand, combien, comment.
# Lancer depuis la racine : python3 tools/guide_joueur.py → docs/pdf/ROADLINE_Guide_du_joueur.pdf
# Valeurs relevées dans les configs du serveur (server/resources/[gtasoon]/*/shared/config.lua) ; catalogue de la concession :
# tools/data/vehicules_concession.json (liste des véhicules de base Qbox + boutiques qbx_vehicleshop).
# Version PUBLIQUE : V4 (la numérotation interne V11.x reste pour le staff).
import json
import os
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether,
                                CondPageBreak)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

VERSION = 'V4 · bêta'
OUT = 'docs/pdf/ROADLINE_Guide_du_joueur.pdf'

# Police avec flèches et symboles (DejaVu si présente), sinon Helvetica
FONT, BOLD = 'Helvetica', 'Helvetica-Bold'
for reg, bold in (('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'),
                  ('C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/segoeuib.ttf')):
    if os.path.exists(reg) and os.path.exists(bold):
        pdfmetrics.registerFont(TTFont('G', reg))
        pdfmetrics.registerFont(TTFont('GB', bold))
        from reportlab.pdfbase.pdfmetrics import registerFontFamily
        registerFontFamily('G', normal='G', bold='GB', italic='G', boldItalic='GB')
        FONT, BOLD = 'G', 'GB'
        break

NEON = colors.HexColor('#28E0FF')
DARK = colors.HexColor('#0F091C')
PINK = colors.HexColor('#FF2E88')
VIOLET = colors.HexColor('#A24BFF')
GREY = colors.HexColor('#6B6380')
SOFT = colors.HexColor('#F4F0FC')

ss = getSampleStyleSheet()
H1 = ParagraphStyle('h1', parent=ss['Title'], fontName=BOLD, textColor=DARK, fontSize=24, leading=28, spaceAfter=4, alignment=0)
KICK = ParagraphStyle('k', fontName=BOLD, fontSize=8.5, textColor=PINK, leading=11, spaceBefore=2)
H2 = ParagraphStyle('h2', parent=ss['Heading2'], fontName=BOLD, textColor=PINK, fontSize=14, spaceBefore=10, spaceAfter=4)
H3 = ParagraphStyle('h3', parent=ss['Heading3'], fontName=BOLD, textColor=DARK, fontSize=11, spaceBefore=7, spaceAfter=2)
P = ParagraphStyle('p', parent=ss['BodyText'], fontName=FONT, fontSize=9.5, leading=13)
LEAD = ParagraphStyle('lead', parent=P, fontSize=10.5, leading=14.5, textColor=colors.HexColor('#2A2340'))
SMALL = ParagraphStyle('s', parent=P, fontSize=8, leading=10, textColor=GREY)
TIP = ParagraphStyle('tip', parent=P, fontSize=9, leading=12, textColor=DARK, backColor=colors.HexColor('#E9FBFF'),
                     borderColor=NEON, borderWidth=0.8, borderPadding=6, spaceBefore=6, spaceAfter=8)
WARN = ParagraphStyle('warn', parent=TIP, backColor=colors.HexColor('#FFF0F6'), borderColor=PINK)


def money(n):
    return f"{n:,}".replace(',', '\u202f') + ' $'


def rng(a, b=None):
    if isinstance(a, (list, tuple)):
        a, b = a
    return money(a) if b is None or a == b else f"{money(a)} à {money(b)}"


def table(rows, widths, font=8.5, header=True):
    cell = ParagraphStyle('c', parent=P, fontSize=font, leading=font + 2.6)
    head = ParagraphStyle('ch', parent=cell, textColor=colors.white, fontName=BOLD)
    t = Table([[Paragraph(str(c), head if (header and i == 0) else cell) for c in r] for i, r in enumerate(rows)],
              colWidths=widths, repeatRows=1 if header else 0)
    st = [('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#CBBBEA')), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
          ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, SOFT]), ('TOPPADDING', (0, 0), (-1, -1), 2.5),
          ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5)]
    if header:
        st += [('BACKGROUND', (0, 0), (-1, 0), DARK)]
    t.setStyle(TableStyle(st))
    return t


def bullets(items):
    return [Paragraph('• ' + i, P) for i in items]


def steps(items):
    return [Paragraph(f'<font color="#FF2E88"><b>{i + 1}.</b></font> {s}', P) for i, s in enumerate(items)]


def tip(text):
    return Paragraph('<b>Astuce</b> · ' + text, TIP)


def warn(text):
    return Paragraph('<b>Attention</b> · ' + text, WARN)


def chapter(num, title, intro):
    return [PageBreak(), Paragraph(f'CHAPITRE {num}', KICK), Paragraph(title, H1),
            Paragraph(intro, LEAD), Spacer(1, 6)]


W = 180 * mm  # largeur utile


# ------------------------------------------------------------------------------------------------------------------
def cover(canvas, doc):
    w, h = A4
    canvas.saveState()
    canvas.setFillColor(DARK)
    canvas.rect(0, 0, w, h, stroke=0, fill=1)
    # coucher de soleil
    canvas.setFillColor(colors.HexColor('#FF8A5C'))
    canvas.circle(w / 2, h * 0.36, 62 * mm, stroke=0, fill=1)
    canvas.setFillColor(colors.HexColor('#FFC08F'))
    canvas.circle(w / 2, h * 0.36, 48 * mm, stroke=0, fill=1)
    canvas.setFillColor(DARK)
    for k in range(9):  # bandes du soleil
        y = h * 0.36 - 10 * mm - k * 6.5 * mm
        canvas.rect(0, y, w, 1.2 * mm + k * 0.35 * mm, stroke=0, fill=1)
    canvas.rect(0, 0, w, h * 0.36 - 64 * mm, stroke=0, fill=1)
    # skyline
    canvas.setFillColor(colors.HexColor('#1B1030'))
    import random
    random.seed(4)
    x = 0
    while x < w:
        bw = random.uniform(8, 22) * mm
        bh = random.uniform(12, 55) * mm
        canvas.rect(x, h * 0.36 - 64 * mm, bw, bh, stroke=0, fill=1)
        x += bw
    canvas.setFillColor(colors.white)
    canvas.setFont(BOLD, 44)
    canvas.drawString(18 * mm, h - 45 * mm, 'ROADLINE')
    canvas.setFillColor(PINK)
    canvas.drawString(18 * mm + canvas.stringWidth('ROADLINE ', BOLD, 44), h - 45 * mm, 'RP')
    canvas.setFillColor(NEON)
    canvas.setFont(BOLD, 13)
    canvas.drawString(18 * mm, h - 56 * mm, 'GUIDE DU JOUEUR')
    canvas.setFillColor(colors.HexColor('#C9BFE6'))
    canvas.setFont(FONT, 11)
    for i, line in enumerate(['Tout ce qu\'on peut faire à Los Santos : où, quand, combien, comment.',
                              'Métiers, récolte, recettes, concession, commerces, illégal, justice,',
                              'et tout ce que la ville fait sans toi.']):
        canvas.drawString(18 * mm, h - 68 * mm - i * 6 * mm, line)
    canvas.setFont(FONT, 9)
    canvas.setFillColor(colors.HexColor('#8F84AD'))
    canvas.drawString(18 * mm, 16 * mm, f'{VERSION} · discord.gg/8y2sX7EvZN · roadlinerp.netlify.app')
    canvas.drawString(18 * mm, 22 * mm, 'Les prix bougent avec le marché : ce guide donne les prix de base.')
    canvas.restoreState()


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(DARK)
    canvas.rect(0, A4[1] - 7 * mm, A4[0], 7 * mm, stroke=0, fill=1)
    canvas.setFillColor(NEON)
    canvas.setFont(BOLD, 7.5)
    canvas.drawString(15 * mm, A4[1] - 4.8 * mm, 'ROADLINE RP · GUIDE DU JOUEUR')
    canvas.setFont(FONT, 7.5)
    canvas.setFillColor(GREY)
    canvas.drawString(15 * mm, 9 * mm, f'RoadLine RP · {VERSION} · prix de base (le marché les fait bouger)')
    canvas.drawRightString(A4[0] - 15 * mm, 9 * mm, f'page {doc.page}')
    canvas.restoreState()


# ------------------------------------------------------------------------------------------------------------------
CAT_FR = {'sports': '★ Luxe · Sportives', 'super': '★ Luxe · Supercars', 'compacts': 'Compactes', 'sedans': 'Berlines', 'coupes': 'Coupés', 'suvs': 'SUV', 'offroad': 'Tout-terrain',
          'muscle': 'Muscle cars', 'sportsclassics': 'Sportives classiques', 'motorcycles': 'Motos', 'vans': 'Vans et utilitaires',
          'cycles': 'Vélos', 'boats': 'Bateaux', 'planes': 'Avions', 'helicopters': 'Hélicoptères'}
SHOP_FR = {'pdm': 'Premium Deluxe Motorsport (Pillbox Hill)', 'boats': 'Marina (bateaux)', 'air': 'Aéroport (avions et hélicoptères)'}
CAT_ORDER = ['sports', 'super', 'cycles', 'compacts', 'sedans', 'coupes', 'muscle', 'sportsclassics', 'suvs', 'offroad', 'vans', 'motorcycles', 'boats', 'planes', 'helicopters']


def build():
    data = json.load(open('tools/data/vehicules_concession.json', encoding='utf-8'))
    shops = data['shops']
    s = []

    # ---- Sommaire ----
    s += [Spacer(1, 1), PageBreak(), Paragraph('SOMMAIRE', KICK), Paragraph('Bienvenue à Los Santos', H1),
          Paragraph('Ce guide te dit <b>explicitement</b> ce qu\'il y a sur le serveur et comment le faire, comme un tuto : tu cherches '
                    'une activité, tu regardes ce qu\'il faut (outil, permis, argent, horaire), où aller, et ce que ça rapporte. '
                    'Les prix sont ceux <b>de base</b> : l\'économie de RoadLine est vivante, ils montent quand tout le monde achète la même '
                    'chose et redescendent quand ça se calme.', LEAD), Spacer(1, 8)]
    toc = [['', 'Chapitre', 'Ce que tu y trouves'],
           ['1', 'Premiers pas', 'Arrivée, papiers, permis, téléphone, touches, commandes'],
           ['2', 'L\'argent', 'Banque, salaires, économie vivante, réputation, remises'],
           ['3', 'Véhicules', 'Concession, crédit, essais, assurance, tuning, location, fourrière (catalogue complet en annexe)'],
           ['4', 'Métiers libres', 'Routier, bus, taxi, livreur, éboueur : sans entretien, payés à la course'],
           ['5', 'Métiers sous contrat', 'Police, shérif, EMS, mécano, concession, immobilier, presse, bars, justice…'],
           ['6', 'Récolte', 'Pêche, mine, bûcheron, ferraille, ferme, chasse : outils, lieux, butin, revente'],
           ['7', 'Recettes et fabrication', 'Cocktails, munitions artisanales, transformation, plantations'],
           ['8', 'Commerces', 'Supérettes, cavistes, quincailleries, pharmacies, Ammu-Nation, marchés de nuit'],
           ['9', 'Activités et loisirs', 'Petits boulots, quêtes, défis, courses, road trips, casino, combats, logement'],
           ['10', 'Le côté obscur', 'Marché noir, drogue, braquages, duo, contrebande, gangs, blanchiment'],
           ['11', 'Justice et police', 'Comment la police te trouve, amendes, garde à vue, procès, jurés, prison'],
           ['12', 'Une ville qui vit sans toi', 'Quartiers, black-out, rumeurs, Gazette, faits divers, nuit, événements'],
           ['A', 'Annexe · catalogue', 'Tous les véhicules en vente, avec leur prix']]
    s += [table(toc, [12 * mm, 45 * mm, 123 * mm], font=9)]
    s += [Spacer(1, 10), Paragraph('Les règles d\'or', H3)]
    s += bullets(['<b>Roleplay avant tout</b> : un personnage crédible, pas de tuerie gratuite (freekill), pas d\'infos hors jeu (metagaming).',
                  '<b>Valeur de la vie</b> : sous la menace d\'une arme, ton personnage obéit.',
                  '<b>Zones calmes</b> : pas de crime à l\'hôpital, au commissariat, à la mairie ni au Pôle Emploi.',
                  '<b>Zéro pay-to-win</b> : la boutique ne vend que du style. Tout le reste se gagne en jouant.',
                  'Un souci ? <b>/report</b> en jeu : le staff le reçoit tout de suite.'])

    # ---- 1. Premiers pas ----
    s += chapter(1, 'Premiers pas', 'Tu arrives en ville <b>en bus</b>, à l\'arrêt de la mairie (un seul personnage par joueur), sans voiture et sans permis. En une heure de jeu, tu peux avoir '
                 'tes papiers, ton permis, un premier boulot et un scooter. Suis Max « le Guide » : il t\'attend devant la mairie.')
    s += [Paragraph('Ton premier jour (quête de Max)', H3)]
    s += steps(['Parle à <b>Max « le Guide » Delgado</b> devant la mairie (Rockford Hills).',
                '<b>Mairie</b> : papiers et état civil.',
                '<b>Banque Fleeca de Legion Square</b> : ton compte. Les distributeurs sont partout en ville.',
                '<b>Pôle Emploi</b> (centre-ville, près de Legion Square) : choisis un premier boulot (F6).',
                '<b>Auto-école</b> (Strawberry) : passe ton permis.',
                '<b>Location de la mairie</b> : un scooter en attendant.',
                'Reviens voir Max : <b>300 XP et 500 $</b>.'])
    s += [Paragraph('Le permis de conduire', H3)]
    s += [table([['Étape', 'Prix', 'Comment'],
                 ['Code', money(500), '10 questions tirées au hasard, 8 bonnes réponses pour réussir (nouvel essai 5 min après un échec).'],
                 ['Conduite', money(1000), 'Parcours en ville avec la voiture-école : 80 km/h maximum, 3 fautes au plus (excès, accrochage).'],
                 ['Retrait', 'Police', 'Pas de points : une infraction grave et la police te <b>retire le permis</b> (carte reprise, motif au casier). Pour le récupérer : l\'auto-école, ou décision de la police.']],
                [28 * mm, 22 * mm, 130 * mm])]
    s += [tip('Un moniteur de l\'auto-école (joueur) peut aussi te faire passer un examen en RP.')]
    s += [Paragraph('Les touches', H3)]
    keys = [['Touche', 'À quoi ça sert'],
            ['F1', 'Téléphone : Que faire ?, messages, banque, factures, Vibe, Weazel, boulots, plans, ville…'],
            ['F2 · TAB · 1 à 5', 'Inventaire · barre rapide (double-clic = utiliser)'],
            ['F3', 'Progression : niveau, quêtes, défis du jour, badges'],
            ['F5 · X', 'Animations (emotes) · annuler'],
            ['F6', 'Métiers : prise de service (aussi par téléphone, de n\'importe où, ou /service), tenue, factures, missions, direction'],
            ['F7 · F9', 'Duo criminel · Gang'],
            ['W (clavier français)', 'Menu rapide : tenue, accessoires, radio, véhicule, factures'],
            ['Alt (appui simple)', 'Interagir avec ce que tu regardes (PNJ, portes, véhicules, objets)'],
            ['E', 'Action sur un point [E]'],
            ['N · ²', 'Parler · portée de la voix (chuchoter, normal, crier)'],
            ['H · L · B', 'Mains en l\'air · verrouiller le véhicule · ceinture'],
            ['I', 'Aide des touches en jeu']]
    s += [table(keys, [40 * mm, 140 * mm])]
    s += [Paragraph('Les commandes utiles', H3)]
    cmds = [['Commande', 'Ce qu\'elle fait'],
            ['/quefaire', 'Tout ce qui se passe maintenant en ville, avec le GPS (aussi dans le téléphone)'],
            ['/rdv', 'Le programme des rendez-vous de la semaine'],
            ['/factures', 'Payer tes factures et amendes'],
            ['/recap · /reputation', 'Ton récap du mois · tes trois réputations'],
            ['/quartiers', 'L\'ambiance de chaque quartier'],
            ['/gazette', 'La Gazette de la semaine'],
            ['/histoire', 'Au volant : l\'historique public de la voiture (avant d\'acheter une occasion)'],
            ['/rumeurs · /legendes', 'Ce qui se raconte · les légendes de Los Santos'],
            ['/mentor', 'Choisir un parrain (nouveaux joueurs)'],
            ['/droits', 'En garde à vue : avocat, silence, aveux, dénoncer un gang (témoin protégé)'],
            ['/porter', 'Porter un carton, une caisse, une pizza… (aussi W → Moi → Porter)'],
            ['/permis', 'Ton permis est-il valide ?'],
            ['/jury', 'Rouvrir ta convocation de juré'],
            ['/report', 'Prévenir le staff']]
    s += [table(cmds, [40 * mm, 140 * mm])]

    # ---- 2. Argent ----
    s += chapter(2, 'L\'argent', 'Trois poches : le <b>liquide</b> (dans l\'inventaire), la <b>banque</b> (carte, téléphone) et '
                 'l\'<b>argent sale</b> (un objet, issu du crime). La police peut saisir l\'argent sale ; il se blanchit ou se dépense au marché noir.')
    s += [table([['Où', 'Plafond', 'Remarque'],
                 ['Distributeur', f'{money(5000)} par retrait · {money(15000)} par jour', 'Partout en ville'],
                 ['Guichet de banque', f'{money(100000)} par opération · {money(250000)} par jour',
                  'Fleeca (Legion Square, Hawick, Burton, Rockford Plaza, Chumash, Route 68, Sandy Shores), Pacific Standard, Blaine County (Paleto)'],
                 ['Téléphone (Banque)', f'virements jusqu\'à {money(1000000)}', 'Entre joueurs, avec historique']],
                [35 * mm, 60 * mm, 85 * mm])]
    s += [Paragraph('Comment on gagne sa vie', H3)]
    s += bullets(['<b>Salaire</b> : versé <b>toutes les 15 minutes</b> si tu es en service (et que tu bouges : pas de paie pour un joueur AFK).',
                  '<b>Allocation</b> : 50 $ par paie pour les sans-emploi.',
                  '<b>Missions</b> (métiers libres) : payées à l\'étape et au kilomètre, plus un bonus de fin.',
                  '<b>Niveau</b> : chaque niveau gagné rapporte 150 $ × le niveau atteint (niveau 10 = 1 500 $), jusqu\'au niveau 50.',
                  '<b>Connexion quotidienne</b> : 50 XP par jour d\'affilée (jusqu\'à 7), et 1 000 $ par semaine complète.'])
    s += [Paragraph('L\'économie vivante', H3)]
    s += [Paragraph('Chaque achat fait monter le prix d\'un produit, chaque revente le fait baisser, et le marché revient doucement à '
                    'l\'équilibre (toutes les 10 min). La météo s\'en mêle : pendant une <b>canicule</b>, l\'eau coûte jusqu\'à 60 % de plus ; '
                    'pendant une <b>tempête</b>, les kits de réparation et les bandages s\'envolent. L\'appli <b>Bourse</b> du téléphone suit '
                    'l\'indice des prix, le carburant, les métaux, l\'immobilier et la richesse de la ville.', P)]
    s += [Paragraph('La réputation (trois jauges de 0 à 1 000)', H3)]
    s += [table([['Jauge', 'Comment elle monte', 'Ce qu\'elle t\'apporte'],
                 ['Légale', 'Missions (+5), quêtes (+10), récolte (+2), achats, locations, reventes',
                  'Remise en magasin : 3 % (300), 6 % (600), 10 % (900). Les vendeurs te saluent par ton prénom dès 300.'],
                 ['Rue', 'Ventes discrètes (+3), braquages (+10), courses (+5)',
                  'Drogue mieux payée : +5 % (300), +10 % (600), +15 % (900). Accès au marché noir dès 15.'],
                 ['Média', '+1 par like reçu sur Vibe', 'Badge influenceur (25 abonnés), visage connu… les témoins te reconnaissent plus vite !']],
                [22 * mm, 70 * mm, 88 * mm])]
    s += [Paragraph('Paliers : Inconnu (0), Connu (100), Respecté (300), Réputé (600), Légende (900).', SMALL)]
    s += [tip('<b>Les commerçants se souviennent</b> : achète dans le même magasin plusieurs jours différents et tu deviens un habitué '
              '(5 % de remise, jusqu\'à 25 %). Un braqueur à visage découvert est reconnu et se fait refuser au comptoir pendant 48 h.')]

    # ---- 3. Véhicules ----
    s += chapter(3, 'Véhicules', 'Pas de voiture au départ : location, puis concession quand tu as le permis et les moyens. Chaque '
                 'voiture a son carnet (kilomètres, accidents, propriétaires) : on sait ce qu\'on achète.')
    s += [table([['Boutique', 'Ce qu\'on y trouve', 'Nombre de modèles'],
                 [SHOP_FR['pdm'], 'Vélos, compactes, berlines, coupés, muscle cars, sportives classiques, SUV, tout-terrain, vans, motos, la <b>salle Luxe</b> '
                  '(sportives et supercars) et la catégorie <b>★ Imports RoadLine</b> (modèles exclusifs du serveur)',
                  str(sum(len(v) for v in shops['pdm'].values())) + ' + imports'],
                 [SHOP_FR['boats'], 'Jet-skis, semi-rigides, hors-bords, yachts, voilier, remorqueur', str(len(shops['boats']['boats']))],
                 [SHOP_FR['air'], 'ULM, avions de tourisme, hydravions, jets d\'affaires, hélicoptères civils', str(sum(len(v) for v in shops['air'].values()))]],
                [55 * mm, 100 * mm, 25 * mm])]
    s += [Paragraph('Acheter une voiture, pas à pas', H3)]
    s += steps(['Va à la concession avec ton <b>permis</b>. Regarde les modèles exposés ou ouvre le catalogue au comptoir (Alt).',
                '<b>Essai gratuit</b> : quelques minutes au volant, puis la voiture revient seule.',
                'Paie comptant (banque) ou à <b>crédit</b> : 10 % d\'apport minimum, jusqu\'à 24 échéances, au bureau des financements.',
                'La voiture arrive à ton nom avec ses clés. Range-la dans un <b>parking public</b> (garages sur la carte).',
                'Un <b>vendeur de la concession</b> (joueur) peut te conseiller, faire une reprise ou une remise : c\'est son métier.'])
    s += [Paragraph('Après l\'achat', H3)]
    s += [table([['Service', 'Prix', 'Détail'],
                 ['Assurance Mors Mutual (Rockford Hills)', '4 % du prix par semaine', f'Entre {money(300)} et {money(25000)}. Assuré : fourrière à 25 % du tarif. '
                  'Vol déclaré : 60 % du prix remboursé après 45 min d\'enquête (assuré depuis 24 h, une fois toutes les 2 semaines). '
                  'Fausse déclaration = remboursement + 50 % d\'amende.'],
                 ['Néons (LS Customs, Burton, aéroport, Beeker\'s Paleto)', money(800), '9 couleurs (Rose Vice, Cyan, Violet, Or sunset…)'],
                 ['Plaque personnalisée', money(2500), '2 à 8 caractères (pas de préfixe de service, pas d\'insulte)'],
                 ['Réparation', 'facture du mécano', 'Moteur et carrosserie (kit), pneus, remettre sur ses roues, nettoyage'],
                 ['Kit de réparation · avancé', f'{money(250)} · {money(900)}', 'En quincaillerie : pour te dépanner seul']],
                [55 * mm, 35 * mm, 90 * mm])]
    s += [Paragraph('Location', H3)]
    s += [table([['Véhicule', 'Prix', 'Durée']] +
                [[n, money(p), f'{m} min'] for n, p, m in [('BMX', 15, 30), ('Vélo de ville', 20, 45), ('Scooter', 45, 45),
                                                          ('Mini citadine (2 places)', 90, 60), ('Petite décapotable', 140, 60),
                                                          ('Jet-ski (marinas)', 80, 30), ('Semi-rigide (marinas)', 150, 45), ('Hors-bord (marinas)', 260, 45)]],
                [80 * mm, 30 * mm, 70 * mm])]
    s += [Paragraph('Points de location : mairie, Legion Square, Del Perro, Sandy Shores, Paleto Bay ; bateaux : marina de Los Santos et '
                    'jetée de Cayo Perico. Rends le véhicule au comptoir avant la fin (alerte 5 min avant).', SMALL)]
    s += [Paragraph('Fourrière et enchères', H3)]
    s += [Paragraph('Véhicule mal garé ou saisi : il part à la fourrière de Davis. <b>Chaque samedi à 21 h 30, pendant 30 minutes</b>, '
                    'la fourrière vend aux enchères les véhicules abandonnés (mise de départ : 25 % du prix catalogue) et les saisies de la '
                    'police. Surenchère : +5 % (50 $ minimum) ; la mise est bloquée sur ton compte. Les invendus reviennent à 80 % la semaine suivante.', P)]
    s += [tip('Avant d\'acheter une occasion à un joueur : monte au volant et tape <b>/histoire</b>. Kilomètres, accidents, repeintures et '
              'anciens propriétaires s\'affichent.')]
    s += [Paragraph('Aller à Cayo Perico', H3)]
    s += [Paragraph('Vol régulier <b>gratuit</b> au comptoir de l\'aéroport de Los Santos (LSIA), retour au comptoir de la piste de l\'île. '
                    'Ou en bateau (location à la jetée de Cayo).', P)]

    s += [Paragraph('Voiture volée : le registre des disparus', H3)]
    s += bullets(['Déclare le vol à <b>Mors Mutual</b> (véhicule assuré depuis 24 h). Si elle n\'est pas retrouvée en <b>48 h</b>, elle refait surface : '
                  'à la casse, dans un garage louche, ou aux enchères de la fourrière du samedi. Une rumeur circule et tu reçois un tuyau.',
                  'Va la chercher : son <b>carnet</b> (kilomètres, accidents, propriétaires) est intact. Si tu reprends le volant, l\'assurance '
                  'récupère l\'indemnité versée, <b>sans pénalité</b>. Rouler avec une voiture « volée » sans la déclarer retrouvée reste une fraude.'])

    # ---- 4. Métiers libres ----
    s += chapter(4, 'Métiers libres', 'Sans entretien : tu prends le métier au <b>Pôle Emploi</b> (centre-ville), tu sors le véhicule de service '
                 'au dépôt, tu prends ton service (F6) et tu enchaînes les missions. Tu peux cumuler <b>3 contrats</b> en même temps.')
    s += [table([['Métier', 'Dépôt', 'Véhicule', 'Mission', 'Paie'],
                 ['Routier', 'Port de Los Santos (Elysian)', 'Porteur', '2 étapes : charger, décharger',
                  f'{rng(150, 250)} par étape + {money(180)}/km + {money(150)} de bonus'],
                 ['Chauffeur de bus', 'Dépôt de bus (Mission Row)', 'Bus', '5 arrêts', f'{rng(70, 110)} par arrêt + {money(40)}/km + {money(120)}'],
                 ['Taxi', 'Downtown Cab Co. (Mirror Park)', 'Taxi', 'Prendre et déposer un client', f'{money(140)}/km + {money(60)}'],
                 ['Livreur Post OP', 'Dépôt Post OP (port)', 'Fourgon', '3 colis chez les commerçants', f'{rng(180, 260)} par colis + {money(100)}'],
                 ['Éboueur', 'Dépôt de la voirie (Strawberry)', 'Benne', '4 tournées de poubelles', f'{rng(120, 180)} par arrêt + {money(80)}']],
                [26 * mm, 40 * mm, 18 * mm, 42 * mm, 54 * mm], font=8)]
    s += bullets(['20 secondes de pause entre deux missions ; le véhicule de service doit rester près de toi (40 m).',
                  'Chaque mission terminée : <b>25 XP</b> et +5 de réputation légale.',
                  'Le <b>mercredi de 21 h à 23 h</b> (Mercredi des métiers) : +25 % d\'XP.',
                  'Taxi et dépanneuse : les clients joueurs peuvent t\'appeler (/taxi, /depanneur) : tu vois la demande avec /commandes.'])
    s += [tip('Le taxi rapporte surtout sur les longues courses (140 $ du kilomètre) ; le livreur, sur les tournées rapides en ville.')]

    # ---- 5. Métiers sous contrat ----
    s += chapter(5, 'Métiers sous contrat', 'Ces métiers se décrochent auprès de la <b>direction</b> (joueurs) : candidature, entretien, '
                 'embauche. Le salaire tombe toutes les 15 minutes en service ; la direction peut le régler de 0,5 à 2 fois la base et donner des primes.')
    jobs = [['Métier', 'Grades et salaire (par paie)', 'Ce que tu fais'],
            ['LSPD (Mission Row)', 'Cadet 350 · Officier 450 · Sergent 550 · Lieutenant 650 · Capitaine 800',
             'Patrouilles, contrôles, enquêtes (preuves, labo), amendes jusqu\'à 25 000 $, garde à vue, mandats, chien K9, radar, herses.'],
            ['Shérif du comté (Sandy Shores)', 'Adjoint stagiaire 350 → Shérif 800', 'Le même travail que la LSPD, dans le comté.'],
            ['EMS (Pillbox)', 'Stagiaire 350 · Ambulancier 450 · Infirmier 550 · Médecin 650 · Chef 750',
             'Réanimer, soigner, factures de soins jusqu\'à 5 000 $, interventions sur les faits divers.'],
            ['Mécano LS Customs (La Mesa)', 'Apprenti 250 · Mécanicien 350 · Chef d\'atelier 450 · Patron 550',
             'Réparer, pneus, remorquage (dépanneuse, plateau), commandes par téléphone, factures jusqu\'à 15 000 $, tuning complet.'],
            ['Concession PDM', 'Stagiaire 200 · Vendeur 300 · Chef des ventes 400 · Directeur 500', 'Vendre, reprendre, faire essayer (factures jusqu\'à 500 000 $).'],
            ['Dynasty 8 (immobilier)', 'Agent stagiaire 200 · Agent 300 · Directeur 450', 'Créer et vendre ou louer des logements.'],
            ['Auto-école', 'Moniteur 250 · Directeur 400', 'Leçons de conduite, examens en RP, délivrer le permis.'],
            ['Cabinet d\'avocats', 'Stagiaire 200 · Avocat 350 · Associé 500', 'Défendre en garde à vue et au tribunal, honoraires jusqu\'à 50 000 $.'],
            ['Tribunal', 'Juge 450 · Président 600', 'Procès, verdicts, mandats, jurys de citoyens, litiges de contrats.'],
            ['Weazel News', 'Pigiste 150 · Journaliste 280 · Rédacteur en chef 450',
             'Articles (/journal : 400 $ à la rédaction par article), flash info, direct pendant les poursuites (150 $/min sur place).'],
            ['Bars : Tequi-la-la, Vanilla Unicorn, Bahama Mamas', 'Serveur 150 · Barman 220 · DJ / danse 260 · Gérant 350 à 400',
             'Préparer les cocktails (chapitre 7), encaisser, animer. Sans employé : libre-service PNJ.'],
            ['Mairie', 'Agent d\'état civil 250 · Adjoint 400 · Maire 600', 'Mariages, papiers, vie de la ville.'],
            ['Psychologue', 'Psychologue 250 · Psychiatre 400', 'Séances (jusqu\'à 5 000 $).']]
    s += [table(jobs, [40 * mm, 62 * mm, 78 * mm], font=8)]
    s += [Paragraph('Les patrons (menu Direction) gèrent les embauches, les salaires, les primes et la caisse. Les commerces peuvent '
                    'aussi <b>blanchir</b> de l\'argent (chapitre 10)… à leurs risques.', SMALL)]

    # ---- 6. Récolte ----
    s += chapter(6, 'Récolte', 'Libre, sans embauche : achète l\'outil en <b>quincaillerie</b> (La Mesa ou Senora), va sur place, '
                 'appuie sur [E] devant un arbre, un rocher, un tas ou un rang de légumes. Chaque point s\'épuise après quelques récoltes '
                 'et repousse en 5 minutes : bouge d\'un point à l\'autre. L\'outil casse parfois (3 %).')
    harvest = [['Activité', 'Outil (prix)', 'Où', 'Ce que tu récoltes', 'Où revendre'],
               ['Pêche', 'Canne à pêche (120 $)', 'Jetée de Del Perro, Chumash, Alamo Sea, Paleto',
                'Poisson (1-2), parfois thon ou ferraille', 'Poissonnerie de Del Perro'],
               ['Mine', 'Pioche (180 $)', 'Carrière Davis Quartz (désert de Senora)',
                'Pierre (2-4), minerai de fer (1-2), cuivre, pépite d\'or (rare)', 'Ferrailleur de Cypress Flats'],
               ['Bûcheron', 'Hache (160 $)', 'Forêt de Paleto', 'Bûches (2-3)', 'Scierie de Paleto'],
               ['Ferraille', 'aucun', 'Rogers Salvage (La Puerta) et casse de Sandy Shores', 'Ferraille (2-4), cuivre (1-2)', 'Ferrailleur de Cypress Flats'],
               ['Ferme', 'aucun', 'Champs de Grapeseed', 'Tomates (2-4), pommes de terre (2-4)', 'Marché de Grapeseed'],
               ['Chasse', 'Couteau de chasse (140 $) + fusil et permis', 'Forêts au sud de Paleto', 'Viande (2-4), cuir', 'Boucherie de Paleto']]
    s += [table(harvest, [20 * mm, 32 * mm, 43 * mm, 45 * mm, 40 * mm], font=8)]
    s += [Paragraph('Prix de revente (par unité)', H3)]
    s += [table([['Produit', 'Prix', 'Produit', 'Prix'],
                 ['Poisson', rng(25, 40), 'Ferraille', 'env. 12 $ (marché)'],
                 ['Thon', rng(90, 140), 'Cuivre', 'env. 30 $ (marché)'],
                 ['Bûche', rng(20, 28), 'Pierre', 'env. 8 $ (marché)'],
                 ['Tomate', rng(6, 9), 'Minerai de fer', 'env. 34 $ (marché)'],
                 ['Pomme de terre', rng(5, 8), 'Pépite d\'or', 'env. 170 $ (marché)'],
                 ['Viande', rng(40, 60), 'Cuir', rng(55, 80)]],
                [40 * mm, 50 * mm, 40 * mm, 50 * mm])]
    s += [Paragraph('Les métaux suivent le marché : si tout le monde revend du cuivre, son prix baisse (jusqu\'à 30 % de sa valeur). '
                    'Le ferrailleur est loin des casses exprès : prévois un véhicule.', SMALL)]
    s += [Paragraph('La chasse, en détail', H3)]
    s += steps(['Achète le <b>permis de chasse (750 $)</b> au comptoir de l\'Ammu-Nation de Paleto.',
                'Achète le <b>mousquet</b> (1 500 $) et ses munitions (8 $) à l\'Ammu-Nation, et un couteau de chasse.',
                'Va dans les forêts au sud de Paleto : cerfs et sangliers apparaissent autour de toi.',
                'Abats l\'animal, approche-toi et dépèce-le au couteau (6 s).',
                'Revends à la boucherie de Paleto, ou garde la viande pour les restaurants des joueurs.'])
    s += [warn('Dépecer sans permis, c\'est du <b>braconnage</b> : un crime qui peut être signalé à la police.')]
    s += [tip('La récolte compte pour les <b>défis du jour</b> (« Pêche, mine, coupe du bois ou chasse 5 fois ») et donne de la réputation légale. '
              'Une tenue de travail est disponible au vestiaire de chaque activité.')]

    # ---- 7. Recettes ----
    s += chapter(7, 'Recettes et fabrication', 'Tout ce qui se fabrique en ville, avec ce qu\'il faut, où et combien de temps.')
    s += [Paragraph('Cocktails (bars des joueurs)', H3)]
    s += [Paragraph('Au plan de travail du bar (employé en service). Les ingrédients sont dans la réserve du bar, achetés en supérette ou chez les cavistes.', P)]
    s += [table([['Boisson', 'Ingrédients', 'Temps', 'Prix de vente (Tequi-la-la · Vanilla · Bahama)'],
                 ['Cocktail Vice', '1 vodka + 1 Sprunk', '5 s', '45 $ · 60 $ · 55 $'],
                 ['Whisky-cola', '1 whisky + 1 Sprunk', '4 s', '40 $ · 50 $ · 45 $'],
                 ['Bière (revendue telle quelle)', '1 bière achetée en gros', '—', '15 $ · 18 $ · 16 $']],
                [35 * mm, 40 * mm, 15 * mm, 90 * mm])]
    s += [Paragraph('Sans employé en service, un barman PNJ sert la carte de base (bière, Sprunk, eau) au prix fort. Le patron peut aussi '
                    'laisser sa <b>doublure</b> (un PNJ à son image) tenir le comptoir : meilleure recette… mais elle peut être braquée.', SMALL)]
    s += [Paragraph('Munitions artisanales (atelier des gangs)', H3)]
    s += [Paragraph('Dans la planque du gang, à partir de la ferraille et du cuivre récoltés. Moins cher que le marché noir ; plafond de '
                    '600 cartouches par gang et par jour.', P)]
    s += [table([['Munitions', 'Ferraille', 'Cuivre', 'Temps', 'Grade minimum'],
                 ['9 mm (×20)', '6', '2', '15 s', 'Membre'],
                 ['.45 (×20)', '7', '3', '15 s', 'Membre'],
                 ['Cartouches (×10)', '6', '2', '15 s', 'Membre'],
                 ['5,56 (×30)', '12', '5', '25 s', 'Bras droit']],
                [45 * mm, 25 * mm, 25 * mm, 25 * mm, 60 * mm])]
    s += [Paragraph('Transformation (drogue)', H3)]
    s += [table([['Produit', 'Récolte (où)', 'Transformation', 'Vente (par sachet)'],
                 ['Cannabis', 'Champ sauvage près de Grapeseed : 1 à 3 feuilles', '3 feuilles → 1 sachet (8 s), arrière-boutique de Sandy Shores', rng(70, 120)],
                 ['Cocaïne', 'Serre de Grapeseed : 1 à 2 feuilles de coca', '4 feuilles → 1 sachet (12 s), dans un labo', rng(160, 240)]],
                [22 * mm, 55 * mm, 68 * mm, 35 * mm], font=8)]
    s += [Paragraph('Les gangs qui possèdent un <b>labo</b> produisent deux fois plus. Récolter au champ sauvage donne parfois une graine (30 %).', SMALL)]
    s += [Paragraph('Plantations', H3)]
    s += steps(['Achète une <b>graine</b> (150 $) au vendeur louche près du champ de Grapeseed, un <b>pot</b> (20 $) et de l\'<b>engrais</b> (45 $) en quincaillerie.',
                'Plante dehors (pas en intérieur, pas sur la route) ; 6 plants au maximum.',
                '<b>Arrose</b> (une bouteille d\'eau) : un arrosage tient 25 min ; sans eau pendant 30 min, le plant meurt.',
                'Il pousse en 45 min (3 stades visibles de tous), 1,5 fois plus vite avec engrais.',
                'Récolte : 8 à 12 feuilles et 1 ou 2 graines.'])
    s += [warn('Tout le monde peut récolter un plant mûr (vol possible), et un policier en service qui le détruit touche une prime.')]

    # ---- 8. Commerces ----
    s += chapter(8, 'Commerces', 'Les vendeurs sont derrière le comptoir : approche-toi et appuie sur Alt. Prix de base ci-dessous ; ils bougent avec la demande.')
    s += [table([['Rayon', 'Articles (prix de base)'],
                 ['Supérettes (12 en ville et dans le comté)', 'Eau 5 · Sprunk 7 · café 6 · boisson énergisante 9 · burger 12 · sandwich 9 · chips 5 · donut 6 · '
                  'bière 8 · vin 25 · cigarettes 15 · briquet 5 · bandage 40 · téléphone 450 · ticket à gratter 100'],
                 ['Cavistes Rob\'s Liquor (6)', 'Bière 8 · vin 25 · vodka 35 · whisky 45, et l\'essentiel de la supérette'],
                 ['Pharmacies (Pops Pills, hall de Pillbox)', 'Antidouleurs 60 · bandage 40 · eau · boisson énergisante'],
                 ['Quincailleries (La Mesa, Senora)', 'Kit de réparation 250 · avancé 900 · kit de nettoyage 25 · gants 60 · javel 45 · appareil photo argentique 350 · '
                  'jerrican 60 · bombe de peinture 40 · pot 20 · engrais 45 · canne à pêche 120 · pioche 180 · hache 160 · couteau de chasse 140 · '
                  'crochet 150 · radio 300 · jumelles 150 · téléphone 450'],
                 ['Marchés de nuit (22 h-5 h) : Legion Square, jetée de Del Perro, Vinewood', 'Sandwich 35 · café 15 · donut 12 · chips 10 · énergisante 20 · bière 18'],
                 ['Vendeur ambulant (sur la route, hors de la ville)', 'Sandwich 20 · eau 8 · café 12 · bandage 90 · kit de réparation 320 · gants 80']],
                [52 * mm, 128 * mm], font=8.2)]
    s += [Paragraph('Ammu-Nation (9 en ville et dans le comté)', H3)]
    s += [table([['Article', 'Prix', 'Il faut'],
                 ['Couteau · batte · lampe torche', '200 · 100 · 80 $', 'rien'],
                 ['Pistolet compact · pistolet', '1 800 · 2 500 $', 'permis de port d\'arme'],
                 ['Fusil à pompe', '5 500 $', 'permis de port d\'arme'],
                 ['Munitions 9 mm · .45 · cartouches (l\'unité)', '6 · 7 · 12 $', 'permis de port d\'arme'],
                 ['Lampe pour arme', '350 $', 'permis de port d\'arme'],
                 ['Mousquet · munitions (l\'unité)', '1 500 · 8 $', 'permis de chasse']],
                [70 * mm, 40 * mm, 70 * mm])]
    s += bullets(['<b>Permis de port d\'arme : 5 000 $</b> au comptoir de n\'importe quel Ammu-Nation. Il faut le permis de conduire et un casier propre '
                  '(pas recherché, pas de crime récent). La police peut le retirer.',
                  'Plafond légal : <b>1 arme et 120 munitions par jour</b> et par personnage. Les armes du comptoir sont enregistrées à ton nom.',
                  'Stands de tir (Pillbox, Cypress Flats) : tu peux t\'entraîner sans être signalé.'])
    s += [Paragraph('Vêtements, coiffeur, tatoueur', H3)]
    s += [Paragraph('Boutiques de vêtements, coiffeurs (menu de barbier : coupe, couleur, barbe, sourcils, maquillage — 150 $) et tatoueurs sont sur la carte. '
                    'Une tenue achetée devient un <b>objet Tenue</b> dans l\'inventaire : tu t\'habilles où tu veux (menu W → Moi).', P)]

    # ---- 9. Activités ----
    s += chapter(9, 'Activités et loisirs', 'Pas besoin de métier pour gagner de l\'argent ou de l\'XP : la ville propose toujours quelque chose. '
                 'Le réflexe : <b>téléphone → Que faire ?</b>')
    s += [Paragraph('Petits boulots (appli Boulots)', H3)]
    s += [table([['Boulot', 'Principe', 'Paie'],
                 ['Livraison express', 'Récupérer un colis en A, le livrer en B (au moins 700 m), avec ton propre véhicule', f'{money(80)} + {money(110)}/km'],
                 ['Passeur (illégal)', 'Même chose avec de la marchandise louche ; signalé à la police 1 fois sur 3', f'{money(200)} + {money(260)}/km, en argent sale']],
                [35 * mm, 100 * mm, 45 * mm])]
    s += [Paragraph('3 offres toutes les 5 min, 15 min pour finir. Les offres s\'adaptent : tempête (×1,5), nuit (×1,25 pour les passeurs), '
                    'événement (×1,3), quartier chaud (×1,6, plus risqué).', SMALL)]
    s += [Paragraph('Quêtes, défis et progression (F3)', H3)]
    s += [table([['Quoi', 'Comment', 'Récompense'],
                 ['Ton premier jour', 'Max devant la mairie', '300 XP · 500 $'],
                 ['Big Sal (3 quêtes : pizza, recouvrement, le port)', 'Personnages masculins, après le premier jour', 'jusqu\'à 500 XP · 1 000 $ · badge'],
                 ['Mama Rosa (3 quêtes : look, ragots, nuit néon)', 'Personnages féminins, après le premier jour', 'jusqu\'à 500 XP · 1 000 $ · badge'],
                 ['La Voix au bout du fil', 'Niveau 3 : une cabine de Legion Square sonne…', '800 XP · 1 500 $ · badge'],
                 ['Défis du jour', '3 défis tirés au sort chaque jour', '150 XP chacun ; les 3 : +300 XP, 500 $, 1 ticket à gratter'],
                 ['Paquets cachés', '20 colis dans tout l\'État, invisibles sur la carte', '50 XP chacun ; tous : 2 500 XP et 5 000 $'],
                 ['Saison (8 semaines)', 'L\'XP gagnée remplit la piste de saison', 'Argent, tickets, titres (piste gratuite pour tous)']],
                [55 * mm, 70 * mm, 55 * mm], font=8.2)]
    s += [Paragraph('Titres par niveau : Nouveau venu, Habitué (3), Débrouillard (5), Figure locale (8), Pointure (12), Vétéran (18), '
                    'Légende urbaine (25), Icône de Los Santos (35), Mythe (50).', SMALL)]
    s += [Paragraph('Courses de rue', H3)]
    s += [Paragraph('L\'<b>organisateur</b> attend à Legion Square. Trois circuits : Sprint centre-ville, Boucle des plages, Descente de Vinewood. '
                    'Chrono solo gratuit, ou course à plusieurs : <b>500 $ de mise</b>, 90 % de la cagnotte redistribuée (70/30 à deux, 60/30/10 à trois et plus). '
                    'Il prête une voiture identique à tous (Sultan, Futo, Elegy, Banshee) ou tu prends la tienne. '
                    'Une course à plusieurs est signalée à la police 3 fois sur 10.', P)]
    s += [Paragraph('Road trips et rencontres de la route', H3)]
    s += bullets(['<b>Carnets de route</b> : La côte Ouest (400 XP), Vinewood au coucher du soleil (350 XP), Le grand Nord de Blaine (500 XP). '
                  'Étapes, anecdotes et spots photo. Titres : Routard, Explorateur, Globe-trotteur.',
                  '<b>Road trip du mois</b> : un carnet différent chaque mois ; le premier fini rapporte XP ×2 et 2 500 $, +25 % par équipier en convoi.',
                  '<b>Rencontres de la route</b> (hors de Los Santos, en roulant) : auto-stoppeur (150-450 $), voiture en panne (250-600 $), '
                  'accident (300-700 $), animal blessé, portefeuille perdu (le rendre : 400-900 $), vendeur ambulant, contrôle du shérif. '
                  'Certaines sont des pièges, surtout la nuit.'])
    s += [Paragraph('Casino Diamond', H3)]
    s += bullets(['<b>Roue de la fortune</b> : 1 tour gratuit par jour. Lots de 750 $ à 25 000 $ (jackpot), XP, tickets, kits.',
                  '<b>Ticket à gratter</b> (100 $, supérettes) : jusqu\'à 10 000 $ ; 10 tickets par jour au plus.',
                  '<b>Loto</b> : ticket à 100 $ à la caisse (10 par semaine), tirage le <b>dimanche à 20 h</b>, 3 gagnants (60/25/15 % de la cagnotte).'])
    s += [Paragraph('Combats clandestins', H3)]
    s += [Paragraph('Une adresse différente chaque jour, la nuit (21 h-5 h), que les barmans et les rumeurs laissent filer. Mises des combattants : '
                    '500, 1 000, 2 500 ou 5 000 $ ; les spectateurs parient (100 à 10 000 $) pendant 60 s. K.-O. ou sortie du ring = défaite ; '
                    'la maison prend 10 %. Grande soirée le <b>samedi de 22 h à minuit</b>.', P)]
    s += [Paragraph('Se loger', H3)]
    s += [table([['Où', 'Prix', 'Détail'],
                 ['Motel Pink Cage (Vinewood)', '450 $ / semaine', 'Chambre, coffre (40 places), garde-robe ; jusqu\'à 4 semaines d\'avance'],
                 ['Motor Motel (Sandy Shores)', '300 $ / semaine', 'Idem'],
                 ['Dream View Motel (Paleto Bay)', '320 $ / semaine', 'Idem'],
                 ['Appartements et maisons', 'selon le bien', 'Achat ou location auprès des agents Dynasty 8']],
                [55 * mm, 35 * mm, 90 * mm])]
    s += [Paragraph('Vie civile', H3)]
    s += bullets(['<b>Mariage</b> à la mairie : 1 000 $ chacun (divorce : 2 500 $).',
                  '<b>Contrats signés</b> (face à face) : prêt d\'argent, salaire privé, location. Le serveur prélève les échéances ; '
                  'retard = +10 %, deux retards = litige devant un juge.',
                  '<b>Mentors</b> : dès le niveau 5, deviens parrain ; un nouveau qui reste 7 jours vous rapporte 2 500 $ (parrain) et 1 000 $ (filleul).',
                  '<b>Vibe</b> (réseau social) : un hashtag repris par 5 personnes déclenche un rassemblement en ville (150 XP) ; les photos à la golden hour (18-20 h) donnent 100 XP.',
                  '<b>Prison</b> : même là, on peut travailler (cour, laverie, cuisine) pour réduire sa peine et gagner des tickets de cantine.'])

    # ---- 10. Illégal ----
    s += chapter(10, 'Le côté obscur', 'Le crime paie… si personne ne le signale. À RoadLine, la police ne sait que ce que les témoins, les caméras '
                 'et les preuves lui disent (chapitre 11). Tout ici rapporte de l\'<b>argent sale</b>.')
    s += [warn('Respecte le règlement : une scène RP avant toute violence, jamais dans les zones calmes, et la valeur de la vie de ton personnage.')]
    s += [Paragraph('Le marché noir', H3)]
    s += bullets(['<b>Accès</b> : membre d\'un gang, ou réputation de rue ≥ 15.',
                  '<b>Quand</b> : la nuit seulement (20 h-6 h, heure du jeu). <b>Où</b> : le contact change de planque toutes les 2 heures '
                  '(entrepôts, ruelles, casses…) : demande à la rue, ou par l\'appli <b>Inconnu</b> du téléphone.',
                  'Payé en argent sale ; en liquide propre, c\'est 40 % plus cher. Stock limité, réapprovisionné à 4 h ; plus il part, plus c\'est cher. '
                  'Une arme non déclarée par jour et par personne. -10 % si la planque est dans ton territoire.'])
    s += [table([['Article', 'Prix de base', 'Article', 'Prix de base'],
                 ['Munitions 9 mm (×20)', '220 $', 'Pistolet compact', '4 500 $'],
                 ['Munitions .45 (×20)', '260 $', 'Pistolet', '6 000 $'],
                 ['Cartouches (×10)', '300 $', 'Micro-SMG (gangs)', '18 000 $'],
                 ['Munitions 5,56 (×30)', '650 $', 'Fusil à canon scié (gangs)', '14 000 $'],
                 ['Munitions 7,62 (×30)', '750 $', 'Silencieux (pistolet)', '8 000 $'],
                 ['Crochet · avancé', '150 · 900 $', 'Chargeur grande capacité', '3 000 $'],
                 ['Gilet pare-balles', '2 500 $', 'Fausse plaque', '3 500 $']],
                [45 * mm, 45 * mm, 45 * mm, 45 * mm])]
    s += [Paragraph('Vendre de la drogue', H3)]
    s += bullets(['Vise un passant et propose (3 sachets maximum par vente), ou tape <b>/deal</b> à un coin de rue : les clients viennent à toi (un toutes les 20 à 40 s).',
                  'Refus 1 fois sur 4 (plus sous la pluie) ; <b>refus systématique</b> si un policier en service est à moins de 60 m.',
                  'Bonus : nuit (+15 %), ton territoire (+20 %), réputation de rue (jusqu\'à +15 %). Malus : territoire rival (-15 %), '
                  'quartier saturé (jusqu\'à -45 % si tout le monde y vend).'])
    s += [Paragraph('Les braquages', H3)]
    s += [table([['Cible', 'Policiers en service', 'Butin', 'Pause entre deux'],
                 ['Supérettes (Strawberry, Grove, Mirror Park, Sandy)', '1', '700 à 1 400 $ (Sandy : 800 à 1 600 $)', '30 min'],
                 ['Bijouterie Vangelico (6 vitrines)', '3', '900 à 1 500 $ par vitrine', '1 h'],
                 ['Fleeca Legion Square (3 coffres)', '4', '2 500 à 4 200 $ par coffre', '1 h 30'],
                 ['Gros coup en duo : Fleeca (pirate + conducteur)', '4', '9 000 à 14 000 $, partagés 50/50', '2 h']],
                [62 * mm, 28 * mm, 55 * mm, 35 * mm], font=8)]
    s += bullets(['Butin +15 % la nuit, +20 % pendant une tempête ou le brouillard, +15 % dans ton territoire.',
                  '<b>Braquage solo</b> : vise un caissier (supérette) ou un guichetier (6 agences Fleeca) : le braquage démarre seul. '
                  'L\'argent tombe en sacs sur le comptoir. Caisse : 280-650 $ ; guichet : 550-1 100 $ ; racket d\'un passant : 25-140 $.',
                  '<b>La peur</b> : plus tu cries (²), plus la victime cède vite. Si tu baisses ton arme, elle s\'enfuit et appelle la police.',
                  'Plafond : 6 braquages solo par heure, 5 000 $ par jour.',
                  '<b>Gros coup en duo</b> : le pirate coupe l\'alarme au terminal (20 s, échec 15 %), le conducteur vide les deux coffres, '
                  'puis fuite : 900 m en 4 min, ensemble.'])
    s += [Paragraph('Duo criminel (F7)', H3)]
    s += [Paragraph('Deux personnages se lient. Le lien progresse avec le temps passé ensemble et les contrats : Complices → Associés → '
                    'Partenaires → Inséparables → Légendes (jusqu\'à +30 % de paie, chaleur moins partagée). Contrats à deux : 900 à 1 400 $ '
                    'chacun, les deux doivent être sur chaque étape (docks, hangar, entrepôt → Paleto, Grapeseed, Chumash).', P)]
    s += [Paragraph('Contrebande maritime', H3)]
    s += [Paragraph('Le contact du port de Paleto (21 h-5 h ; gangs ou réputation de rue ≥ 300) te confie une cargaison à repêcher en mer '
                    '<b>en bateau</b> puis à décharger sur une plage, en 25 min : <b>3 500 à 5 500 $</b>. Au chargement, le radar côtier '
                    'donne l\'alerte une fois sur deux ; sans police joueur, les garde-côtes prennent le relais.', P)]
    s += [Paragraph('Les gangs (F9)', H3)]
    s += bullets(['Les gangs sont créés par le staff. Six existent : Families (Grove Street), Ballas (Davis), Vagos (Rancho), Lost MC (East Vinewood), '
                  'Cartel Madrazo et Triades (organisations).',
                  'Grades : Recrue, Membre, Bras droit (recrute), Chef (caisse). 25 membres au plus.',
                  '<b>Territoires</b> : présence, tags (bombe de peinture) et crimes font monter l\'influence ; la police la fait baisser. '
                  'Le gang qui tient un quartier touche <b>600 $ par heure</b>.',
                  '<b>Guerres</b> déclarées : 5 000 $, 10 min de préavis, 20 min de combat ; le vainqueur prend le quartier (et sa fresque).',
                  '<b>Racket</b> des commerces de joueurs : 500 à 5 000 $ par semaine ; refus = vitrine cassée.',
                  '<b>Receleur</b> : vente en gros la nuit (10 à 50 objets), +35 %, adresse qui change toutes les heures.',
                  'Atelier de munitions (chapitre 7), garage et flotte aux couleurs du gang.'])
    s += [Paragraph('Blanchir et brouiller les pistes', H3)]
    s += bullets(['<b>Blanchiment</b> : par le menu Direction d\'un commerce. 30 % de commission, délai de 30 min, plafond lié au chiffre d\'affaires '
                  'légal du jour, et un risque de contrôle fiscal.',
                  '<b>Fausse plaque</b> (marché noir) : la voiture n\'est plus reliée à ses signalements pendant 45 min… mais un policier qui vérifie '
                  'le numéro de châssis voit la fraude.',
                  '<b>Gants</b> (pas d\'empreintes), <b>javel</b> (effacer des traces), changer de tenue ou repeindre la voiture : la ville oublie au bout de 2 h.',
                  '<b>Contrats</b> entre joueurs (/contrats) : vol, livraison, élimination (scène RP obligatoire)… récompense bloquée à la publication, 5 % de commission.'])
    s += [Paragraph('La cavale', H3)]
    s += [Paragraph('Très recherché, tu peux entrer en <b>cavale</b> (/cavale) : avis de recherche placardés, prime pour qui te livre. '
                    'Tiens 2 heures de jeu sans te faire prendre et tu deviens une <b>légende</b> de Los Santos (et peut-être une plaque).', P)]

    s += [Paragraph('Faux papiers', H3)]
    s += bullets(['Au marché noir : fausse <b>carte d\'identité</b>, faux <b>permis de conduire</b>, faux <b>permis de port d\'arme</b>, chacun avec une identité inventée.',
                  'Double-clic pour le <b>présenter</b> (10 min) : les joueurs à côté voient le faux nom, et un contrôle de police <b>loin du commissariat</b> le croit.',
                  'Au <b>commissariat</b>, le scanner démasque tout : vraie identité, mention au casier, et le papier ne sert plus. Choisis où tu te fais contrôler.'])
    s += [Paragraph('Gangs : la guerre de l\'information', H3)]
    s += bullets(['F9 → Opérations (bras droit ou chef, payé par la caisse du gang) : <b>brouiller les caméras</b> du quartier 10 min (5 000 $), '
                  'ou <b>pirater le scanner police</b> 10 min (8 000 $) : tous les membres en ligne entendent les signalements et les appels au 911.',
                  'Chaque opération laisse une <b>trace</b> : depuis l\'ordinateur du commissariat, la police remonte jusqu\'au gang après 5 minutes d\'analyse.'])

    # ---- 11. Justice ----
    s += chapter(11, 'Justice et police', 'Comment la ville apprend un crime, et ce qui t\'attend ensuite.')
    s += [Paragraph('Comment la police te trouve', H3)]
    s += bullets(['Un crime n\'est connu que s\'il est <b>signalé</b> : témoins (PNJ et joueurs à 40 m), caméras (10 lieux sensibles), policier à portée.',
                  'Les <b>coups de feu</b> et les coups d\'arme blanche sont toujours signalés (rue et GPS, sans description). Un silencieux réduit le risque.',
                  'La nuit, le brouillard, la pluie et les <b>black-out</b> réduisent la visibilité.',
                  'Les témoins décrivent ce qu\'ils ont vu : sexe, véhicule, masque, chapeau, sac, gilet, tatouages visibles. Jamais ton nom… sauf si tu es célèbre.',
                  'Les <b>preuves</b> restent sur place : douilles, sang, empreintes (sans gants), traces de pneus, éclats de peinture. '
                  'La police les relève à la lampe et les analyse au labo.',
                  'Sans policier joueur en service, la <b>police IA</b> prend le relais (1 à 4 étoiles).'])
    s += [Paragraph('Ce que risque un suspect', H3)]
    s += [table([['Étape', 'Ce qui se passe'],
                 ['Contrôle', 'Identité (contrôle visuel ; au commissariat, le scanner démasque les faux papiers), fouille, retrait de permis, amende (/factures). Refuser d\'obtempérer est un délit.'],
                 ['Témoin protégé', 'En garde à vue, /droits → <b>dénoncer un gang</b> : peine divisée par deux. Le gang apprend que « quelqu\'un a parlé », jamais qui ; la police te protège 7 jours (lieu sûr sur le GPS). Si tu tombes pendant ce temps, le gang est dans le viseur.'],
                 ['Garde à vue', 'Jusqu\'à 30 min à Mission Row. /droits : avocat, silence, aveux (peine réduite de 30 %).'],
                 ['Procès', 'Devant un juge, avec avocat. Pour un vrai procès, le juge peut convoquer un <b>jury de 5 citoyens</b> tirés au sort : '
                  'le verdict suit leur vote (les jurés touchent 100 $).'],
                 ['Prison', 'Bolingbroke, jusqu\'à 60 min. Petits boulots pour réduire la peine, cantine payée en tickets, évasion possible la nuit, à plusieurs.']],
                [30 * mm, 150 * mm])]
    s += [tip('Témoin d\'un crime ? Raconte-le à la police : à RoadLine, les joueurs aussi sont des témoins, et leur description compte.')]

    # ---- 12. La ville ----
    s += chapter(12, 'Une ville qui vit sans toi', 'Ce qu\'on ne trouve nulle part ailleurs : la ville a une mémoire, une humeur et un emploi du temps.')
    s += [table([['Système', 'Ce que ça change pour toi'],
                 ['Quartiers', 'Chaque crime fait monter la tension d\'un quartier : passants qui fuient, trafic, police IA plus présente. '
                  'Un quartier propre et calme monte en standing ; sale et violent, il coule. Ramasser les déchets est payé par la mairie.'],
                 ['Black-out', 'Saboter un transformateur (avec un crochet, 20 s) plonge tout un quartier dans le noir 15 min : lumières, néons et caméras coupés. '
                  'N\'importe qui peut le réparer, payé 300 à 500 $ par la mairie.'],
                 ['Cicatrices', 'Mémorial là où quelqu\'un est tombé, vitrine brisée après un braquage (un ouvrier la répare : 250 à 450 $), '
                  'fresque du gang vainqueur.'],
                 ['Lieux de mémoire', 'Un grand casse, une cavale légendaire, un mariage : une plaque reste 30 jours. [E] : un passant raconte.'],
                 ['La mémoire des lieux', 'Chaque endroit accumule ce qui s\'y est passé (crimes, arrestations, mariages, courses, braquages, guerres). Les <b>passants en parlent</b> quand tu passes, Radio Los Santos le rappelle, et une plaque naît toute seule au 10e événement.'],
                 ['Les échos', 'La nuit, près d\'un lieu chargé, des <b>silhouettes translucides</b> rejouent le passé quelques secondes : deux danseurs là où il y a eu un mariage, des guetteurs là où il y a eu un braquage…'],
                 ['Rumeurs', 'Les barmans racontent ce qui s\'est passé (250 $ pour le détail). Paie un verre (50 $) pour lancer un bruit : '
                  'si 3 personnes répètent le même, il arrive (tempête, sac de billets caché, sale coup).'],
                 ['Faits divers', 'Quand la ville est calme, elle a ses propres criminels : cambriolage, corps retrouvé, délit de fuite, vandalisme. '
                  'Police, EMS et presse sont payés pour les traiter.'],
                 ['Ville de nuit', 'De 22 h à 5 h : noctambules, feu de camp à Vespucci, marchés de nuit, marché noir, ring.'],
                 ['Météo', 'Canicule, tempête, brouillard : prix, refus de vente, butins et visibilité changent.'],
                 ['Presse', 'Brèves Weazel automatiques, Direct pendant les grosses poursuites, Radio Los Santos en voiture, '
                  'et la <b>Gazette du dimanche</b> à 20 h (site, Discord, /gazette).'],
                 ['Le site', 'Carte en direct de la vraie Los Santos : tension des quartiers, rendez-vous, légendes, les 24 dernières heures rejouées, « En ce moment en ville », et une candidature en trois questions.']],
                [32 * mm, 148 * mm], font=8.3)]
    s += [Paragraph('Le calendrier', H3)]
    s += [table([['Quand', 'Rendez-vous', 'Bonus'],
                 ['Mercredi 21 h-23 h', 'Mercredi des métiers', '+25 % d\'XP'],
                 ['Vendredi 21 h-23 h 30', 'Vendredi des courses', '+15 % d\'XP'],
                 ['Samedi 21 h 30', 'Enchères de la fourrière (Davis)', '30 min'],
                 ['Samedi 22 h-minuit', 'Nuit des combats', '+10 % d\'XP, un tour de roue en plus'],
                 ['Dimanche 17 h-19 h', 'Dimanche road trip', '+15 % d\'XP, plus de rencontres de la route'],
                 ['Dimanche 20 h', 'Gazette de la semaine et tirage du loto', ''],
                 ['24 oct. - 1er nov.', 'Nuits d\'Halloween', '+25 % d\'XP, un tour de roue en plus, auto-stoppeur fantôme, 13 citrouilles cachées (6 666 $)'],
                 ['20 déc. - 2 janv.', 'Fêtes de fin d\'année', '+25 % d\'XP, un tour de roue en plus'],
                 ['21 juin - 22 sept.', 'Été à Los Santos', '+10 % d\'XP']],
                [35 * mm, 60 * mm, 85 * mm])]
    s += [Paragraph('Heures du jeu pour le jour et la nuit ; heures réelles (Paris) pour les rendez-vous. Rappel 30 min avant, en jeu et sur Discord.', SMALL)]

    # ---- Annexe : catalogue ----
    s += [PageBreak(), Paragraph('ANNEXE', KICK), Paragraph('Catalogue de la concession', H1),
          Paragraph('Tous les véhicules en vente, par catégorie, du moins cher au plus cher. Les <b>★ Imports RoadLine</b> (modèles exclusifs '
                    'ajoutés au serveur) sont présentés directement à la concession.', LEAD)]
    total = 0
    for shop in ('pdm', 'boats', 'air'):
        s += [Paragraph(SHOP_FR[shop], H2)]
        for cat in CAT_ORDER:
            lst = shops[shop].get(cat)
            if not lst:
                continue
            total += len(lst)
            rows = [['Modèle', 'Marque', 'Prix', 'Modèle', 'Marque', 'Prix']]
            half = (len(lst) + 1) // 2
            for i in range(half):
                a = lst[i]
                b = lst[i + half] if i + half < len(lst) else None
                rows.append([a['name'], a['brand'] or '—', money(a['price'])] + ([b['name'], b['brand'] or '—', money(b['price'])] if b else ['', '', '']))
            lo, hi = lst[0]['price'], lst[-1]['price']
            s += [CondPageBreak(40 * mm), Paragraph(f'{CAT_FR.get(cat, cat)} · {len(lst)} modèle' + ('s' if len(lst) > 1 else '') + (f' · de {money(lo)} à {money(hi)}' if lo != hi else f' · {money(lo)}'), H3),
                  table(rows, [33 * mm, 25 * mm, 32 * mm, 33 * mm, 25 * mm, 32 * mm], font=7.6)]
    s += [Spacer(1, 6), Paragraph(f'{total} véhicules au catalogue. Les véhicules de service (police, EMS, taxi…), militaires, armés et d\'arène ne sont pas en vente.', SMALL)]

    doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
                            title='RoadLine RP · Guide du joueur', author='RoadLine RP')
    doc.build(s, onFirstPage=cover, onLaterPages=footer)
    print(f'PDF généré : {OUT} ({total} véhicules au catalogue)')


if __name__ == '__main__':
    build()
