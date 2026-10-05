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
             ['F10 · panel', 'Tickets, fiches joueurs complètes, sanctions, journal de toutes les actions du staff.'],
             ['Appli staff (téléphone)', 'Joueurs, tickets, annonce, depuis ton téléphone (un code par membre, demandé au fondateur). '
              '5 mauvais codes = 15 min de blocage.'],
             ['Bot Discord', '/joueurs, /geler, /expulser… (rôle staff) quand tu n\'es pas en jeu.'],
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
    s += [Paragraph('Un point mal placé (transformateur, ring, vendeur, PNJ…) : F11 → Monde et lieux → <b>Déplacer un point</b>, puis préviens '
                    'le fondateur pour qu\'il reste au prochain envoi.', SMALL)]

    s += [Paragraph('6. La déontologie du staff', H2)]
    s += b(['<b>Le mode staff, c\'est pour modérer.</b> Jamais de pouvoir (vol, TP, argent, objets) pour ton personnage ou tes amis.',
            '<b>Neutralité</b> : en jeu, tu es un joueur comme les autres. Tes infos de staff (fiches, journal, positions) ne servent jamais à ton RP.',
            '<b>Confidentialité</b> : codes, captures du panel, discussions staff et identités restent entre nous. Ton code d\'appli est personnel.',
            '<b>Ton calme</b> : on explique, on ne se moque pas, on ne menace pas. Un joueur énervé reçoit une réponse courte et polie.',
            '<b>En cas de doute, on demande.</b> Un ticket qui attend 5 minutes vaut mieux qu\'une mauvaise sanction.'])
    s += [Paragraph('7. Quand ça casse', H2)]
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
