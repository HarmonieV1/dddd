# Génère docs/pdf/ROADLINE_Backtest_complet.pdf : ce qui reste VRAIMENT à tester en jeu (doublons fusionnés, validé retiré), rangé en sessions de
# jeu (dans l'ordre le plus efficace), avec qui il faut (Seul / 2 / 3+ / Staff) et la priorité (★★★ = bloquant à l'ouverture).
import sys
sys.path.insert(0, 'tools')
from pdf import H1, H2, P, SMALL, VERSION, footer, A4, mm, colors, SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

# (test, qui, priorité)
SESSIONS = [
    # V12.45 (14/10) : fiche allégée. Tout ce qui datait d'avant la V12.37 et n'a pas fait l'objet d'un retour est considéré
    # validé (arrivée, téléphone, métiers, papiers, staff, Discord, site, alertes, vie légale / illégale…) et retiré.
    # Reste : ce qui a été corrigé ou ajouté depuis, jamais revu en jeu, et ce qui est obligatoire avant d'ouvrir.
    ('0 · Avant de commencer (5 min)', [
        ('METTRE-A-JOUR.bat : version V12.49 affichée, « Base de données sauvegardée » ; METTRE-A-JOUR-OVH puis GERER-OVH → 1 : « Version RoadLine : V12.49 »', 'Staff', 3),
        ('Console au démarrage (PC et VPS) : aucune ligne ROUGE ; en jaune seulement « Conflit tranché » (2 fichiers Patoche) ; F8 en jeu : aucune erreur rouge', 'Staff', 3),
        ('VIDER-CACHE-FIVEM.bat si un ancien menu apparaît (F11 doit afficher « RoadLine V12.49 »)', 'Staff', 2),
    ]),
    ('1 · Corrections du 13/10 à confirmer (V12.37 → V12.39, 20 min)', [
        ('Garage de métier : « Sortir » donne le véhicule à chaque fois, UNE notification ; prise de service au PNJ : une seule interaction', '2', 3),
        ('Éboueur : sac en main jusqu\'à la benne, tournée payée au retour au dépôt ; nouveau perso : bus déposé DEVANT la mairie (jamais sous la carte)', 'Seul', 3),
        ('Payer carte OU espèces partout dans le légal (motel, facture d\'un métier, marché de nuit) ; virement à un joueur déconnecté reçu à sa reconnexion', '2', 2),
        ('Points déplacés sur le PC → présents au même endroit sur le VPS après METTRE-A-JOUR-OVH', 'Staff', 2),
    ]),
    ('2 · V12.40 — concessions, Benny\'s, courses, portes, gangs (35 min)', [
        ('F11 → Concessions (map cardealer) : exposer 3 véhicules + « Départ des essais ICI » ; ils apparaissent figés, plaque EXPO ; staff : « Changer le modèle » de loin et au Alt, « Replacer ICI »', 'Staff', 3),
        ('Joueur : Alt → Prix, Essayer (2 min, /finessai), Acheter → véhicule SORTI au départ des essais, toi au volant, clé dans le sac, présent ensuite dans tes garages', '2', 3),
        ('Mécano en service + client : Alt → Personnaliser ; le CLIENT voit chaque changement en direct ; Valider → animations + facture au client ; Annuler → tout revient', '2', 3),
        ('F11 → Courses de rue sur mesure : 4 points, enregistrer 1 h → la course apparaît, disparaît après 1 h ; F11 → Portes verrouillées : /doorlock, porte de cellule fermée pour un civil, ouverte pour un policier', 'Staff', 2),
        ('Gangs : un civil ne voit AUCUNE zone ; un membre voit les zones tenues ; /territoire grove 2 → zone plus grande + PNJ du gang, hostiles à un rival', '2', 2),
        ('Tempête : véhicules et arbres au sol ; Cayo : carte refusée, espèces / argent sale OK ; Échap : « RoadLine RP » ; blips de maps : plus de ronds blancs, Benny\'s une seule fois', 'Seul', 2),
    ]),
    ('3 · V12.41 / V12.42 — tir à la tête, caméras, boutique, labo, mobilier (25 min)', [
        ('Tir à la tête au pistolet : à terre en un tir ; casque de moto : non ; poing / taser : non', '2', 3),
        ('Police au terminal de vidéosurveillance : caméra → Voir en direct (souris, molette, Retour) ; caméra peinte : refusée', '2', 2),
        ('Labo : douille prélevée (lampe torche) puis donnée à un collègue → il la voit au labo → Analyser → résultat ; idem après un restart gs_evidence', '2', 3),
        ('Mobilier (F11 → Mapping) : banc, chaise, lit d\'hôpital : S\'asseoir / S\'allonger bien placé (sinon PgUp/PgDn, ligne F8 à m\'envoyer), X pour se lever ; fauteuil roulant : rouler Z/S/Q/D, un 2e joueur le voit bouger', '2', 3),
        ('Arme dans le dos : courir, sauter, ragdoll, véhicule : reste fixe, ne se balance pas, ne tombe pas', '2', 3),
        ('/boutique : interface RoadLine (catégories, RoadCoins, Mes achats), Échap ferme ; console : gsstore_deliver TEST-RC roadcoins_500 <id fivem> → +500 affichés', 'Staff', 2),
    ]),
    ('4 · V12.43 / V12.45 — console, police, maps, import (10 min)', [
        ('Policier en service : monter / voler une voiture près du commissariat → plus de pop-up « prise de service / véhicule » en boucle', '2', 3),
        ('Garage de police : véhicules du pack LSPD selon le grade (Scout, moto, K9, Stalker…) ; concession : Severo et Hachura au catalogue', '2', 2),
        ('Stand de jeux, circuit, FastBox : démarrés (pas de « NON démarré » en console), blips Stand de jeux / Circuit ; FastBox : envoyer un colis à un autre point relais', '2', 2),
        ('Braquage masqué puis démasqué : la description des témoins dit « masqué » seulement dans le 1er cas', '2', 2),
    ]),
    ('4b · V12.45 / V12.46 — vêtements convertis, récolte (15 min)', [
        ('Coiffeur / garde-robe : nouvelles coupes homme (dreadlocks, buzzcut, pack TideFN : locks, boucles) et femme (tresses, cheveux longs) ; magasin : robes, sweat Lace Up, Knee Jeans ; rien du jeu n\'a disparu', '2', 3),
        ('Magasin femme : robes du pack « dresspack » dans le sous-haut (accs) avec un haut vide ; 4 hauts (jbib) ; vérifier que la peau ne dépasse pas', '2', 2),
        ('Récolte : champs d\'orge / houblon / maïs et tabac à Grapeseed (vrais plants), revente au marché ; pavot : pas de blip, latex vendu au receleur du port, alerte police possible', 'Seul', 2),
    ]),
    ('5 · Obligatoire avant d\'ouvrir', [
        ('SAUVEGARDER-BDD.bat puis RESTAURER-BDD.bat sur un joueur ; redémarrage de 6 h : annonces 15 / 5 / 1 min', 'Staff', 3),
        ('Mode staff : vol libre / invisible SANS alerte anti-triche ; F10 tickets et sanctions ; carkill 2 fois → alerte', 'Staff', 3),
        ('Test de charge : 6 à 10 joueurs pendant 1 h : FPS, ping, resmon (aucune ressource gs_ au-dessus de 0,5 ms en continu), aucune erreur F8', '3+', 3),
        ('Boutique : prix, packs et conformité PLA validés avant Config.Enabled = true (docs/BOUTIQUE.md)', 'Staff', 3),
    ]),
    ('6 · Jamais vu en jeu (si le temps le permet)', [
        ('Mémoire des lieux (passants, Radio Los Santos, plaque au 10e événement, « Les échos » la nuit)', '2', 1),
        ('Faux papiers (F4 loin du commissariat = cru, au commissariat = démasqué) ; témoin protégé (/droits)', '3+', 1),
        ('Guerre de l\'information : F9 → brouiller les caméras / pirater le scanner ; police : Remonter la source', '3+', 1),
        ('Véhicule déclaré volé, non retrouvé 48 h → rumeur, casse / enchères, indemnité', '2', 1),
    ]),
]

STARS = {3: '★★★', 2: '★★', 1: '★'}
# Police avec ☐ et ★ (Helvetica ne les a pas) ; à défaut, du texte simple
SYM = 'Helvetica'
try:
    import os
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 'C:/Windows/Fonts/seguisym.ttf'):
        if os.path.exists(f):
            pdfmetrics.registerFont(TTFont('Sym', f))
            SYM = 'Sym'
            break
except Exception:
    pass
if SYM == 'Helvetica':
    STARS = {3: '***', 2: '**', 1: '*'}
# V12.5 : texte des tests dans la même police que les symboles. Helvetica n'a pas la flèche « → », omniprésente dans la
# recette (« F11 → Joueurs → Bannir ») : elle sortait en carré noir ou disparaissait.
from reportlab.lib.styles import ParagraphStyle
TP = ParagraphStyle('tp', parent=P, fontName=SYM) if SYM != 'Helvetica' else P
if SYM == 'Helvetica':
    SESSIONS = [(ti, [(x.replace('→', '>'), q, pr) for x, q, pr in r]) for ti, r in SESSIONS]


def build():
    doc = SimpleDocTemplate('docs/pdf/ROADLINE_Backtest_complet.pdf', pagesize=A4, leftMargin=12 * mm, rightMargin=12 * mm, topMargin=12 * mm,
                            bottomMargin=16 * mm, title='RoadLine RP · Backtest complet', author='RoadLine RP')
    total = sum(len(r) for _, r in SESSIONS)
    crit = sum(1 for _, r in SESSIONS for t in r if t[2] == 3)
    s = [Paragraph('RoadLine RP · Backtest complet', H1),
         Paragraph(f'Ce qui reste VRAIMENT à vérifier en jeu ({VERSION}) : {total} tests, dont {crit} bloquants à valider avant l\'ouverture. '
                   'Retiré : ce que ton backtest du 09/10 a validé, l\'import des mods et la console des maps (validés le 12/10), et les doublons '
                   '(bus, Discord, déplacement des points, police IA, site, Fleeca : un seul test chacun). Sessions 1 à 3 : corrigé après tes retours, à confirmer. '
                   'Colonne « Qui » : Seul, à 2, à 3 ou plus, Staff.', P),
         Paragraph('Coche la case de ce qui marche et renvoie-moi la fiche (ou la liste des numéros validés) : je retire ce qui est validé à chaque version.', SMALL),
         Paragraph('Pour chaque problème : capture d\'écran + F11 → Copier mes coordonnées + ce que tu as fait juste avant. Envoie-moi la liste, je corrige en une fois.', SMALL),
         Spacer(1, 4)]
    for title, rows in SESSIONS:
        data = [['', 'Test', 'Qui', 'Priorité']] + [['☐' if SYM != 'Helvetica' else '[ ]', Paragraph(t, TP), q, STARS[p]] for t, q, p in rows]
        tbl = Table(data, colWidths=[8 * mm, 140 * mm, 16 * mm, 20 * mm], repeatRows=1)
        tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2a1440')), ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTSIZE', (0, 0), (-1, -1), 9), ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#d9cfe8')),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f6f1fc')]),
            ('ALIGN', (2, 1), (3, -1), 'CENTER'), ('FONTNAME', (0, 1), (0, -1), SYM), ('FONTNAME', (3, 1), (3, -1), SYM), ('FONTSIZE', (0, 1), (0, -1), 12), ('TEXTCOLOR', (3, 1), (3, -1), colors.HexColor('#c0187a')),
        ]))
        s += [KeepTogether([Paragraph(title, H2), tbl])]
    doc.build(s, onFirstPage=footer, onLaterPages=footer)
    return total, crit


if __name__ == '__main__':
    t, c = build()
    print(f'PDF généré : docs/pdf/ROADLINE_Backtest_complet.pdf ({t} tests, {c} bloquants)')
