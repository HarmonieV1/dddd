# Génère docs/pdf/ROADLINE_Backtest_complet.pdf : TOUT ce qui reste à tester en jeu (V5 → V10), rangé en sessions de
# jeu (dans l'ordre le plus efficace), avec qui il faut (Seul / 2 / 3+ / Staff) et la priorité (★★★ = bloquant à l'ouverture).
import sys
sys.path.insert(0, 'tools')
from pdf import H1, H2, P, SMALL, VERSION, footer, A4, mm, colors, SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

# (test, qui, priorité)
SESSIONS = [
    ('0 · Avant de commencer (5 min)', [
        ('METTRE-A-JOUR.bat : version V10 affichée, « Base de données sauvegardée », « Sauvegardes programmées »', 'Seul', 3),
        ('Fenêtre du serveur : aucune ligne ROUGE au démarrage ; F8 en jeu : aucune erreur rouge', 'Seul', 3),
        ('VIDER-CACHE-FIVEM.bat si tu vois encore un ancien menu (F11 doit afficher « RoadLine V10 »)', 'Seul', 2),
    ]),
    ('1 · Premier pas d\'un nouveau joueur (20 min) — le plus important pour la rétention', [
        ('Écran de chargement, règlement, création du perso (visages, teint, origines), pas de t-shirt blanc collé sous les vestes', 'Seul', 3),
        ('Apparition à la mairie, quête « Ton premier jour », aide des touches (I)', 'Seul', 3),
        ('Téléphone F1 → Que faire : « En ce moment » cohérent ; chaque bouton GPS pose le point ; chaque bouton action ouvre le bon menu', 'Seul', 3),
        ('Pôle emploi → prendre un métier libre (routier, bus…) → une mission → première paie', 'Seul', 3),
        ('Récolte (pêche ou ferme) → revente au marché ; prix qui bougent', 'Seul', 2),
        ('/mentor : un perso niveau 5+ parraine un nouveau (demande / accepter)', '2', 2),
    ]),
    ('2 · Téléphone (15 min)', [
        ('Ouvrir / fermer (F1, Échap), Messages, Contacts, Appel, Banque (virement), Factures, Emploi, Urgences', '2', 3),
        ('Appel manqué → notification sur l\'accueil + onglet Récents ; rappeler depuis Récents', '2', 2),
        ('Plans : enregistrer un lieu, GPS ; partager ma position → l\'autre a le bouton « Itinéraire »', '2', 2),
        ('Ville (quartiers, météo), Notes (créer, modifier, supprimer), Vibe (post, photo), Boulots, Weazel', 'Seul', 2),
        ('Réglages : fonds d\'écran, silencieux, filtre Vice, « Marcher téléphone ouvert » (écrire un SMS : le perso ne bouge pas)', 'Seul', 2),
        ('FPS : comparer téléphone fermé / ouvert (resmon : gs_phone presque à 0 ms fermé)', 'Seul', 2),
    ]),
    ('3 · Vie légale et commerces (30 min)', [
        ('Police : prise de service, F4 (menottes, fouille, amende, casier, plaque, radar, fourrière), garde à vue, /droits, K9', '2', 3),
        ('Police scientifique : douilles / sang / empreintes à la lampe, scellé, labo, fichier (F4 → Relever empreintes)', '2', 2),
        ('EMS : réanimer, soigner, respawn à l\'hôpital ; mécano : réparer, personnaliser la voiture d\'un client', '2', 3),
        ('Bars : préparer, vendre, prix du patron, libre-service ; « Laisser ma doublure » puis acheter auprès d\'elle', '2', 2),
        ('Supérette : acheter 5 jours différents → « habitué » (prénom + remise)', 'Seul', 1),
        ('Assurance auto, fourrière à 25 % ; auto-école + permis à points (/permis)', 'Seul', 2),
        ('/contrat : prêt face à face (copie papier, argent versé), salaire, location ; Mes contrats', '2', 2),
        ('Mairie : mariage / divorce ; tribunal (juge, avocat, verdict)', '3+', 1),
    ]),
    ('4 · Vie illégale (30 min)', [
        ('Braquer un passant, une supérette (viser le caissier, sacs à ramasser), une bijouterie, une banque, Cayo en duo', '2', 3),
        ('Témoins : description à la police (tenue, masque, voiture, plaque partielle) ; même tenue → reconnu ; changer → plus de lien', '2', 3),
        ('Supérette braquée SANS masque → revenir : le vendeur refuse ; avec masque : servi', 'Seul', 1),
        ('Police IA sans policier connecté (poursuite) ; recherche qui retombe ; /cavale à 5 étoiles, affiches, /livrer, /legendes', 'Seul', 2),
        ('Gangs (F9) : invitation, caisse, tags, territoire, guerre ; /racket à un bar (accepter / refuser, vitrine cassée)', '3+', 2),
        ('Marché noir (/contact), contrats discrets, drogues, blanchiment, fausse plaque, contrebande de nuit (garde-côtes)', '2', 2),
        ('Combats clandestins : trouver le ring la nuit (rumeurs), combat à 2 + un parieur ; arme sortie = disqualifié', '3+', 2),
        ('Fraude à l\'assurance : déclarer volée (assurée 24 h) puis la conduire → fraude, casier', 'Seul', 1),
        ('Prison : boulots, cantine, trafiquant, évasion à deux la nuit', '2', 1),
    ]),
    ('5 · Ville vivante (en roulant, 30 min)', [
        ('Rencontres de la route hors de la ville (auto-stoppeur, panne, accident…), collection (/rencontres)', 'Seul', 2),
        ('Radio Los Santos en voiture (sous-titres), /radiols pour couper', 'Seul', 1),
        ('Le quartier évolue : braquer plusieurs fois au sud → « en déclin », déchets à ramasser (payés) ; ventes au bar → « en essor »', 'Seul', 2),
        ('Faits divers PNJ : policier en service, ville calme (ou F11 → Fait divers) → GPS, scène, constatations payées', '2', 2),
        ('Cicatrices : bougies après une mort, vitrine brisée réparée par un autre perso, fresque après une guerre', '2', 1),
        ('Rumeurs (barmans) et l\'indic\' ; /histoire au volant ; appareil photo (photo = objet, mur, labo) ; cabines téléphoniques', 'Seul', 1),
        ('Tempête (/meteoevent storm), Halloween (/halloween on), rendez-vous fixes (/rdv, rappel 30 min avant)', 'Staff', 1),
        ('/recap (ce mois, mois dernier, biographie), /quartiers, casino, courses, road trip (/carnet), location, Cayo', 'Seul', 1),
    ]),
    ('6 · Staff et outils (20 min)', [
        ('F11 : mode staff, joueurs (aller à, amener, soigner, argent), vol libre / invisible SANS alerte anti-triche', 'Staff', 3),
        ('F11 → Anti-triche (alertes) ; F11 → Statistiques de rétention ; F10 panel complet (tickets /report, sanctions)', 'Staff', 2),
        ('F11 → Déplacer un point : recaler ring, doublures, faits divers, lieux estimés (voir la carte des points)', 'Staff', 3),
        ('SAUVEGARDER-BDD.bat, puis RESTAURER-BDD.bat → un seul joueur (sur un perso de test)', 'Staff', 3),
        ('CONFIGURER-DISCORD.bat → relance : bot en ligne, salon statut mis à jour, /statut et /rdv sur Discord', 'Staff', 2),
    ]),
    ('7 · Test de charge (à faire avant d\'ouvrir)', [
        ('6 à 10 joueurs pendant 1 h : FPS, ping, resmon (aucune ressource gs_ au-dessus de 0,5 ms en continu)', '3+', 3),
        ('Redémarrage programmé txAdmin : annonce Discord, statut « hors ligne » puis « en ligne »', 'Staff', 2),
        ('Après 24 h : sauvegardes présentes (C:\\GTASOON\\sauvegardes\\bdd), aucune erreur dans la console', 'Staff', 3),
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


def build():
    doc = SimpleDocTemplate('docs/pdf/ROADLINE_Backtest_complet.pdf', pagesize=A4, leftMargin=12 * mm, rightMargin=12 * mm, topMargin=12 * mm,
                            bottomMargin=16 * mm, title='RoadLine RP · Backtest complet', author='RoadLine RP')
    total = sum(len(r) for _, r in SESSIONS)
    crit = sum(1 for _, r in SESSIONS for t in r if t[2] == 3)
    s = [Paragraph('RoadLine RP · Backtest complet', H1),
         Paragraph(f'Tout ce qui reste à vérifier en jeu, de la V5 à la {VERSION} : {total} tests, dont {crit} bloquants (priorité maximale) à valider avant '
                   'l\'ouverture. Fais les sessions dans l\'ordre : chacune prépare la suivante. Colonne « Qui » : Seul, à 2, à 3 ou plus, Staff.', P),
         Paragraph('Pour chaque problème : capture d\'écran + F11 → Copier mes coordonnées + ce que tu as fait juste avant. Envoie-moi la liste, je corrige en une fois.', SMALL),
         Spacer(1, 4)]
    for title, rows in SESSIONS:
        data = [['', 'Test', 'Qui', 'Priorité']] + [['☐' if SYM != 'Helvetica' else '[ ]', Paragraph(t, P), q, STARS[p]] for t, q, p in rows]
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
