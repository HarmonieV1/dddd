# Génère docs/pdf/ROADLINE_Backtest_complet.pdf : TOUT ce qui reste à tester en jeu (V5 → V12.3, sans ce que le backtest du 09/10 a couvert), rangé en sessions de
# jeu (dans l'ordre le plus efficace), avec qui il faut (Seul / 2 / 3+ / Staff) et la priorité (★★★ = bloquant à l'ouverture).
import sys
sys.path.insert(0, 'tools')
from pdf import H1, H2, P, SMALL, VERSION, footer, A4, mm, colors, SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

# (test, qui, priorité)
SESSIONS = [
    ('0 · Avant de commencer (5 min)', [
        ('METTRE-A-JOUR.bat : version V12.3 affichée, « Base de données sauvegardée », « Sauvegardes programmées » ; METTRE-A-JOUR-OVH puis GERER-OVH → 1 : « Version RoadLine : V12.3 »', 'Staff', 3),
        ('Fenêtre du serveur : aucune ligne ROUGE au démarrage ; F8 en jeu : aucune erreur rouge ; GERER-OVH → 3 : aucune erreur de script', 'Seul', 3),
        ('VIDER-CACHE-FIVEM.bat si tu vois encore un ancien menu (F11 doit afficher « RoadLine V12.3 ») ; bio du bot : X/48 ; site : « En ce moment en ville » 0/48', 'Seul', 2),
    ]),
    ('1 · À re-vérifier après correction — ton retour du 09/10 (30 min)', [
        ('Nouveau joueur : un seul personnage ; fondateur, super-admins et VIP (F11 → Joueurs → VIP) : deux ; plus de choix du lieu ; déco / reco = même endroit', '2', 3),
        ('Nouveau perso : arrivée en bus à la mairie (Espace pour passer), une seule fois par personnage', 'Seul', 3),
        ('Téléphone : impossible menotté / mort / coma (se range seul) ; ouvert = caméra figée, aucun coup / tir / carte ; écrire un message : aucune touche de jeu (P, M, F…) ne passe', '2', 3),
        ('Prise de service par le téléphone (Emplois) ou /service, de n\'importe où avec un téléphone ; sans téléphone : au point de service', 'Seul', 3),
        ('Permis : plus de points ; police F4 → Contrôle d\'identité → Permis : retirer (motif au casier) → carte reprise, /permis refuse ; rendre → carte rendue', '2', 3),
        ('PPA : achat au comptoir Ammu-Nation → carte dans le sac ; police : délivrer / retirer → carte remise / reprise ; achat raté = plafond du jour non consommé', '2', 3),
        ('Inventaire et F11 : armes, munitions (ammo-9…), accessoires tous en français ; F11 → Items par catégorie avec image + recherche ; donner des munitions fonctionne', 'Staff', 3),
        ('F11 → Véhicules : catalogue par catégorie (marque, nom, prix) ; F11 → Mapping : catalogue par catégorie, placer puis retirer un objet', 'Staff', 2),
        ('Armes longues visibles dans le dos (2 max, pas les pistolets), vues par les autres joueurs', '2', 2),
        ('Nourriture : un sandwich frais se périme en 2 jours (barre dans l\'inventaire), chips / donut 7 jours, boissons jamais', 'Seul', 1),
        ('Legion Square la nuit : le food truck (camion taco) est bien derrière le vendeur du marché de nuit', 'Seul', 2),
        ('Caméras accrochées aux murs / poteaux, orientées vers la rue, aucune dans le vide (sinon F11 → Déplacer un point) ; PNJ acheteurs à la poissonnerie, scierie, marché, boucherie', 'Seul', 3),
        ('/porter (ou W → Moi → Porter un objet) : carton, caisse, pizza… puis « Poser » ; F11 → Déplacer / retirer un point : filtre par ressource, retirer puis réactiver', 'Staff', 2),
        ('Ambulance : réanimer, soigner, réapparition à l\'hôpital ; banque : virement, retrait, dépôt ; le log (GERER-OVH → 3) doit rester sans erreur', '2', 3),
    ]),
    ('2 · Jamais testé — nouveautés V11.4 → V12.3 (45 min)', [
        ('Discord : /ticket sujet → fil privé dans #tickets (joueur + rôle staff), /fermer ; /aide ; commande staff refusée sans rôle staff / admin, acceptée avec', 'Staff', 3),
        ('Discord : /joueurs, /geler, /degeler, /avertir, /message, /annonce, /expulser, /isoler id minutes motif, /liberer, /reanimer → effet en jeu, #sanctions, journal F11', 'Staff', 3),
        ('Appli staff (https://…/gs_admin/) : Isoler (minutes), Libérer, Réanimer, puis l\'onglet Tickets', 'Staff', 2),
        ('Site : « En ce moment en ville » (météo, heure, joueurs, quartier chaud, rendez-vous, rumeur) ; bandeau Weazel « LIVE » ; candidature en 3 questions → #candidatures ; 2e envoi en 10 min refusé', 'Seul', 3),
        ('Site : intro (Entrée pour passer), bandes noires sur Signatures, SMS pendant la visite, « recherché » en bas de page ; sur téléphone : lisible, fluide', 'Seul', 2),
        ('Mémoire des lieux : 3 événements au même endroit (crimes signalés, arrestations…) → un passant en parle ; Radio Los Santos le rappelle ; 10e → plaque automatique', '2', 3),
        ('Les échos : la nuit, près d\'un lieu à 5 événements, silhouettes translucides 40 s (mariage = danseurs, braquage = guetteurs…)', 'Seul', 2),
        ('Véhicule disparu : déclarer volée (assurée 24 h), non retrouvée 48 h → rumeur + tuyau → casse / garage louche / enchères, carnet intact, indemnité reprise sans pénalité', '2', 2),
        ('Faux papiers : marché noir → double-clic = présenter (les voisins voient le faux nom) ; F4 loin du commissariat = cru ; au commissariat = démasqué + casier', '2', 3),
        ('Témoin protégé : garde à vue → /droits → Dénoncer un gang : peine ÷ 2, gang prévenu « quelqu\'un a parlé », lieu sûr GPS 7 jours ; témoin tué → alerte police', '3+', 2),
        ('Guerre de l\'information : F9 → Opérations : brouiller les caméras (5 000 $) et pirater le scanner (8 000 $, les membres entendent le dispatch et le 911) ; police : Remonter la source (5 min)', '3+', 2),
        ('CONFIGURER-DISCORD → #tickets, #candidatures, #sanctions, #logs-staff ; GERER-OVH → 12 puis → 17 : message de test dans chaque salon', 'Staff', 3),
    ]),
    ('3 · Jamais testé — base, vie légale (30 min)', [
        ('/mentor : un perso niveau 5+ parraine un nouveau (demande / accepter) ; prime quand le filleul reste 7 jours', '2', 2),
        ('Téléphone : appel (sonnerie, décrocher), appel manqué → notification + Récents ; Plans (enregistrer, GPS, partager ma position → Itinéraire chez l\'autre)', '2', 2),
        ('Téléphone : Ville, Notes, Vibe (post, photo), Boulots, Weazel ; Réglages (fond, silencieux, filtre Vice) ; FPS fermé / ouvert (resmon gs_phone ≈ 0 ms fermé)', 'Seul', 2),
        ('Police F4 : menottes, fouille, amende, casier, plaque, radar, fourrière, garde à vue, /droits, K9 (drogue dans un coffre, puis sur une personne)', '2', 3),
        ('Police scientifique : douilles / sang / empreintes à la lampe, scellé, labo (3 min), fichier (F4 → Relever empreintes) ; gants, javel', '2', 2),
        ('Mécano : réparer, personnaliser la voiture d\'un client (Alt → Personnaliser → Valider) ; elle ressort du garage personnalisée', '2', 2),
        ('Bars : préparer, vendre, prix du patron, libre-service ; « Laisser ma doublure » puis acheter auprès d\'elle ; la braquer avec un autre perso', '2', 2),
        ('Supérette : acheter 5 jours différents → « habitué » ; braquer sans masque puis revenir : refusé ; coiffeur / tatoueur / chirurgien : PNJ + [E] → menu', 'Seul', 1),
        ('Assurance auto (24 h), fourrière à 25 % ; fraude : déclarer volée puis la conduire → casier ; auto-école (code + conduite)', 'Seul', 2),
        ('/contrat : prêt face à face (copie papier, argent versé), salaire, location ; Mes contrats ; marina (bateau d\'essai), motel', '2', 2),
        ('Mairie : mariage / divorce ; tribunal (juge, avocat, verdict, jury de 5 joueurs convoqués par téléphone) ; /recap, /rdv', '3+', 1),
        ('Métiers libres : dépôts bus / voirie / Post OP → garage → F6 → Mission → paie ; récolte (bois, mine, ferme, ferraille, pêche, chasse) → revente ; vestiaire', 'Seul', 2),
    ]),
    ('4 · Jamais testé — vie illégale (30 min)', [
        ('Braquer un passant, une supérette (viser le caissier, sacs à ramasser), une bijouterie, une banque, Cayo en duo', '2', 3),
        ('Témoins : description à la police (tenue, masque, voiture, plaque partielle) ; même tenue → reconnu ; changer → plus de lien', '2', 3),
        ('Police IA sans policier connecté (poursuite) ; recherche qui retombe ; /cavale à 5 étoiles, affiches, /livrer, /legendes, prime au policier', 'Seul', 2),
        ('Gangs (F9) : invitation, caisse, tags, territoire, guerre (fresque du gagnant) ; /racket à un bar (accepter / refuser, vitrine cassée)', '3+', 2),
        ('Marché noir (/contact), contrats discrets, drogues (plantations), blanchiment, fausse plaque, contrebande de nuit (docker → bateau → caisses → plage → argent sale)', '2', 2),
        ('Combats clandestins : trouver le ring la nuit (rumeurs), combat à 2 + un parieur ; arme sortie = disqualifié', '3+', 2),
        ('Prison : boulots (peine réduite), cantine, trafiquant, évasion à deux la nuit avec outils', '2', 1),
        ('Planques : visites répétées → signalement des voisins → /mandat → juge → perquisition, coffre ouvert', '3+', 2),
    ]),
    ('5 · Jamais testé — ville vivante, justice, presse (30 min)', [
        ('Rencontres de la route hors de la ville (auto-stoppeur, panne, accident…), collection (/rencontres), carnet de route', 'Seul', 2),
        ('Radio Los Santos en voiture (sous-titres, /radiols) ; rumeurs des barmans, l\'indic\' du pont de Davis ; /histoire au volant', 'Seul', 1),
        ('Le quartier évolue : braquages répétés au sud → « en déclin », déchets payés ; ventes au bar → « en essor » (/quartiers)', 'Seul', 2),
        ('Faits divers PNJ : policier en service, ville calme (ou F11 → Fait divers) → GPS, scène, constatations payées', '2', 2),
        ('Cicatrices : bougies après une mort, vitrine brisée réparée (payé), fresque après une guerre ; /plaque (staff), [E] Lire la plaque', '2', 1),
        ('Caméras : terminal du commissariat (passages, plaque) ; bombe de peinture = hors service ; transformateur (crochet) → black-out du quartier, réparation payée', '2', 2),
        ('Tribunal : verser photo + scellé analysé, le juge retient / écarte ; chantage à la photo (payer / refuser → brève Weazel)', '3+', 1),
        ('Enchères de la fourrière (samedi 21 h ou /encheres) : saisie, surenchère remboursée, lot livré ; direct Weazel (5 étoiles : bandeau, hélico, journaliste payé)', '3+', 2),
        ('Tempête (/meteoevent storm : routes fermées, dépannages payés), Halloween (/halloween on), /gazettepublier → Discord + site', 'Staff', 1),
        ('Casino (roue, tickets, loto), courses (Legion Square), road trip, location, Cayo (aller / retour), marché de nuit, noctambules', 'Seul', 1),
        ('Connexion : « Précédemment à Los Santos » avec les vrais faits, « Bon retour Prénom Nom · absent depuis N jours » ; Discord 23 h 30 : « La nuit à Los Santos »', 'Seul', 1),
    ]),
    ('6 · Staff, outils, charge — avant d\'ouvrir', [
        ('F11 : mode staff, joueurs (aller à, amener, soigner, argent), vol libre / invisible SANS alerte anti-triche ; Anti-triche, rétention ; F10 (tickets /report, sanctions)', 'Staff', 3),
        ('Alt : un appui ouvre le ciblage, un appui referme (aussi en voiture) ; foncer en voiture sur un piéton : aucun dégât, 2 fois → alerte « carkill »', '2', 2),
        ('SAUVEGARDER-BDD.bat (programmé toutes les 6 h) puis RESTAURER-BDD.bat → un seul joueur (perso de test) ; après 24 h : sauvegardes présentes', 'Staff', 3),
        ('Redémarrage 6 h : annonces 15 / 5 / 1 min, statut Discord hors ligne puis en ligne ; GERER-OVH → 5 sans alerte, → 6 ; couper autrement → alerte en 4 min', 'Staff', 2),
        ('Test de charge : 6 à 10 joueurs pendant 1 h : FPS, ping, resmon (aucune ressource gs_ au-dessus de 0,5 ms en continu), aucune erreur F8', '3+', 3),
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
         Paragraph(f'Tout ce qui reste à vérifier en jeu, de la V5 à la {VERSION}, sans ce que ton backtest du 09/10 a déjà couvert : {total} tests, dont {crit} bloquants (priorité maximale) à valider avant '
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
