# Génère docs/pdf/ROADLINE_Backtest_complet.pdf : TOUT ce qui reste à tester en jeu (V5 → V12.11, sans ce que le backtest du 09/10 a couvert), rangé en sessions de
# jeu (dans l'ordre le plus efficace), avec qui il faut (Seul / 2 / 3+ / Staff) et la priorité (★★★ = bloquant à l'ouverture).
import sys
sys.path.insert(0, 'tools')
from pdf import H1, H2, P, SMALL, VERSION, footer, A4, mm, colors, SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

# (test, qui, priorité)
SESSIONS = [
    ('0 · Avant de commencer (5 min)', [
        ('METTRE-A-JOUR.bat : version V12.11 affichée, « Base de données sauvegardée », « Sauvegardes programmées » ; METTRE-A-JOUR-OVH puis GERER-OVH → 1 : « Version RoadLine : V12.11 »', 'Staff', 3),
        ('Fenêtre du serveur : aucune ligne ROUGE au démarrage ; F8 en jeu : aucune erreur rouge ; GERER-OVH → 3 : aucune erreur de script', 'Seul', 3),
        ('VIDER-CACHE-FIVEM.bat si tu vois encore un ancien menu (F11 doit afficher « RoadLine V12.11 ») ; bio du bot : X/48 ; site : « En ce moment en ville » 0/48', 'Seul', 2),
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
    ('1b · Corrigé le 11/10 — V12.4 à V12.6 (30 min) : à valider en priorité', [
        ('Bus d\'arrivée (nouveau perso) : posé SUR le trottoir devant la mairie, plus de chute sous la map, GPS tracé vers Max « le Guide », notification d\'accueil', 'Seul', 3),
        ('Déplacer un point (F11 → Monde et lieux → Déplacer / retirer un point, en mode staff) : une CAMÉRA → placer ici → quelques secondes après : « Vérifié : gs_cctv a redémarré avec la nouvelle position » ; le boîtier est sur le mur près de toi ; l\'ancien endroit n\'est plus interactif', 'Staff', 3),
        ('Même test avec un MAGASIN (filtre « Magasins ») et avec Max (filtre « Quêtes ») : déplacés, confirmés, ancien point inactif. Avec un compte fondateur ET un super-admin', 'Staff', 3),
        ('Cabine de la Voix : F11 → Déplacer un point → filtre « Quêtes » → colle-toi à une VRAIE cabine (ou un téléphone mural) → placer ici. [E] / Alt « Décrocher » sur la cabine elle-même, jamais dans le vide. F8 : aucun message « aucune cabine »', 'Staff', 3),
        ('Quête de la Voix jusqu\'à l\'étape « Rappelle la Voix depuis la cabine » : le téléphone se décroche à la cabine déplacée', 'Seul', 2),
        ('Ban F11 (super-admin) : Joueurs → Bannir (3 jours, motif) → double confirmation, déconnecté avec le motif, ligne dans #sanctions ; il se reconnecte → refusé avec motif + date de fin + lien Discord', '2', 3),
        ('F11 → Bannissements : il est dans la liste (fin, motif, staff), recherche par pseudo puis par licence ; cliquer → Débannir → il revient tout de suite', '2', 3),
        ('Un modo (niveau 2) ne voit ni « Bannir » ni « Bannissements » ; bannir un staff de rang égal ou supérieur est refusé', '2', 2),
        ('Discord, APRÈS METTRE-A-JOUR-OVH + redémarrage : console « Discord RoadLine détecté » ou GERER-OVH → diagnostic « gs_discord_guild réglé » ; /help = liste des commandes (plus le site) ; /ip = adresse + connect F8', 'Staff', 3),
        ('Discord : /annonce texte titre mention:@everyone → publiée dans #annonces ; avec en_jeu → aussi en ville ; un membre simple → « Réservé au staff » ; /ticket sujet → fil privé ouvert', 'Staff', 3),
        ('Anti-triche : pendant le backtest, set gs_honeypot "log" dans secrets.cfg ; console serveur sans erreur gs_security ; aucun joueur honnête signalé « PIÈGE » de toute la session', 'Staff', 2),
        ('IMPORTER-MODS avec une map protégée (escrow, .fxap) achetée sur la boutique officielle → installée (avertissement dans RAPPORT-MODS.txt) ; METTRE-A-JOUR-OVH → elle est bien sur le VPS', 'Staff', 2),
    ]),
    ('1c · Alertes et cohérence RP — V12.7 (20 min, à 2 : un policier en service + un civil)', [
        ('Le civil tire en ville (Legion Square) : le policier reçoit « Coups de feu détectés » avec le nom de rue et le GPS, même sans témoin ; un 2e tir dans les 10 s = pas de 2e alerte', '2', 3),
        ('Le policier en service tire : AUCUNE alerte ; un shérif en service : reçoit les alertes comme le LSPD, et ses tirs ne déclenchent rien', '2', 3),
        ('Chasse (forêt de Paleto, au nord) : avec le permis de chasse, tirer sur un cerf = aucune alerte ; sans permis = alerte « Coups de feu » ; dépecer sans permis = « Braconnage »', '2', 2),
        ('Voler une voiture garée (crochetage / fils) ou sortir un conducteur : UNE seule alerte « Vol de véhicule » dans l\'interface du central (plus d\'alerte Qbox en double)', '2', 3),
        ('Peindre une caméra (bombe) : alerte « Dégradation d\'une caméra de surveillance » ; saboter un transformateur : « Sabotage du réseau électrique » (plus « Racket »)', '2', 2),
        ('Braquer la caisse d\'un commerce (vêtements, coiffeur, bar avec doublure) : « Braquage de commerce » ; une vraie supérette 24/7 : « Braquage de supérette »', '2', 2),
        ('Civil : /911p refusé (« pas la permission ») ; l\'appli Urgences du téléphone fonctionne et arrive au policier', '2', 3),
        ('À terre avec un EMS en service : « [G] Demander de l\'aide » → l\'EMS reçoit l\'alerte + GPS ; sans EMS en service : « [G] Appeler les secours » (secouriste IA)', '2', 3),
    ]),
    ('1d · Apports de la session Windows — V12.8 / V12.9 (15 min)', [
        ('Seul en ville (aucun policier joueur en service) : braquer la caisse d\'un commerce (pistolet) → la police IA réagit au moins 6 fois sur 10 (étoiles + patrouilles) ; vendre de la drogue ou voler une voiture → le plus souvent rien', 'Seul', 3),
        ('/policeia 2 (admin) → 2 étoiles et des patrouilles sur toi ; un joueur simple : commande refusée', 'Staff', 2),
        ('Bus d\'arrivée (nouveau perso) : écran noir court, le bus part d\'une route chargée, jamais sous la map ; bloqué 6 s → dépose directe devant la mairie', 'Seul', 3),
        ('Discord : un compte de test rejoint le Discord → message de bienvenue dans le salon réglé (CONFIGURER-DISCORD) ; sans l\'option « Server Members » du portail Discord → console : bienvenue coupée, le bot reste connecté', 'Staff', 2),
        ('Site : météo et heure de la ville en direct, bouton son (coupé par défaut), fluide sur téléphone', 'Seul', 1),
    ]),
    ('1e · Mappings — V12.10 / V12.11 (25 min, en mode staff)', [
        ('Console du serveur au démarrage : « [gs_admin] Mappings : N installé(s), N situé(s), aucun conflit » ; s\'il y a un CONFLIT, me copier la ligne rouge', 'Staff', 3),
        ('F11 → Monde et lieux → Mappings installés : chaque map a un quartier ; clic → téléporté DEDANS (pas sur le toit) ; « Afficher leurs blips » → visibles sur ta carte, pas chez les autres', 'Staff', 3),
        ('Faire le tour : Pillbox, Fleeca, Pops Pills, Bahama Mamas, Willie\'s → nos points (soins, braquage, pharmacie, bar, supérette) dans la map et pas dans un mur ; sinon F11 → Déplacer un point', 'Staff', 3),
        ('Pillbox (nouvel intérieur) : prise de service EMS, direction, pharmacie, armurerie, vestiaire, garage, chirurgien, pharmacie publique → chaque [E] dans une pièce, pas dans un mur', 'Staff', 3),
        ('Fleeca Legion Square (habillage hp_fleeca, change les 6 agences) : banque, braquage du guichet, braquage du coffre et gros coup en duo : points accessibles, porte du coffre cohérente', '2', 3),
        ('Gym (Moreo) : murs, sol et miroirs s\'affichent bien, y compris chez un joueur avec un PC modeste (modèle de 26,5 Mo en mémoire, signalé en console)', '2', 2),
        ('mrpd_etendu installé : policier en service au sous-sol du commissariat → 3 portes (interrogatoire, briefing, réserve) ; un civil ne les voit pas', '2', 2),
        ('NETTOYER-MARQUES.bat : liste les mods de marque (dont mp_male_the_goat), supprime après « O », le reste (maps, vêtements sans marque) intact', 'Staff', 2),
    ]),
    ('2 · Jamais testé — nouveautés V11.4 à V12.3 (45 min)', [
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
         Paragraph(f'Tout ce qui reste à vérifier en jeu, de la V5 à la {VERSION}, sans ce que ton backtest du 09/10 a déjà couvert : {total} tests, dont {crit} bloquants (priorité maximale) à valider avant '
                   'l\'ouverture. Fais les sessions dans l\'ordre : chacune prépare la suivante. Colonne « Qui » : Seul, à 2, à 3 ou plus, Staff.', P),
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
