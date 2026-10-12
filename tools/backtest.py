# Génère docs/pdf/ROADLINE_Backtest_complet.pdf : ce qui reste VRAIMENT à tester en jeu (doublons fusionnés, validé retiré), rangé en sessions de
# jeu (dans l'ordre le plus efficace), avec qui il faut (Seul / 2 / 3+ / Staff) et la priorité (★★★ = bloquant à l'ouverture).
import sys
sys.path.insert(0, 'tools')
from pdf import H1, H2, P, SMALL, VERSION, footer, A4, mm, colors, SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

# (test, qui, priorité)
SESSIONS = [
    ('0 · Avant de commencer (5 min)', [
        ('METTRE-A-JOUR.bat : version V12.17 affichée, « Base de données sauvegardée », « Sauvegardes programmées » ; METTRE-A-JOUR-OVH puis GERER-OVH → 1 : « Version RoadLine : V12.17 »', 'Staff', 3),
        ('Fenêtre du serveur : aucune ligne ROUGE au démarrage (sauf un conflit de maps déjà connu) ; F8 en jeu : aucune erreur rouge ; GERER-OVH → 3 : aucune erreur de script', 'Seul', 3),
        ('VIDER-CACHE-FIVEM.bat si tu vois un ancien menu (F11 doit afficher « RoadLine V12.17 ») ; pendant le backtest : set gs_honeypot "log" dans secrets.cfg (piège = simple signalement)', 'Staff', 2),
    ]),
    ('1 · Arrivée et personnage (15 min) — corrigé après tes retours', [
        ('Nouveau joueur : un seul personnage ; fondateur, super-admins et VIP (F11 → Joueurs → VIP) : deux ; plus de choix du lieu ; déco / reco = même endroit', '2', 3),
        ('Arrivée en bus (nouveau perso, une seule fois, Espace pour passer) : écran noir court, bus jamais sous la carte, dépose SUR le trottoir de la mairie (bus bloqué 6 s → dépose directe), GPS tracé vers Max + notification', 'Seul', 3),
        ('/retoucheperso une fois après la création ; armes longues visibles dans le dos (2 max, pas les pistolets), vues par les autres', '2', 2),
    ]),
    ('2 · Téléphone, métiers, papiers (20 min) — corrigé après tes retours', [
        ('Téléphone : impossible menotté / mort / coma (se range seul) ; ouvert = caméra figée, aucun coup / tir / carte ; en écrivant : aucune touche de jeu (P, M, F…) ne passe', '2', 3),
        ('Prise de service par le téléphone (Emplois) ou /service, de n\'importe où avec un téléphone ; sans téléphone : au point de service', 'Seul', 3),
        ('Permis : plus de points ; police F4 → Contrôle d\'identité → Permis : retirer (motif au casier) → carte reprise, /permis refuse ; rendre → carte rendue', '2', 3),
        ('PPA : achat au comptoir Ammu-Nation → carte dans le sac ; police : délivrer / retirer → carte remise / reprise ; achat raté = plafond du jour non consommé', '2', 3),
        ('Mort (sans EMS) : maintenir [E] 2 s → réapparition à l\'hôpital ; si rien ne se passe, 6 s plus tard : « Soigné à l\'hôpital de … » (devant Pillbox, Sandy ou Paleto, 500 $)', 'Seul', 3),
        ('Ambulance : réanimer, soigner, réapparition à l\'hôpital ; banque : virement, retrait, dépôt ; GERER-OVH → 3 sans erreur', '2', 3),
        ('Nourriture : sandwich frais périmé en 2 jours (barre dans l\'inventaire), chips / donut 7 jours, boissons jamais ; food truck de Legion Square (nuit) derrière le vendeur', 'Seul', 1),
    ]),
    ('3 · Staff en jeu (20 min) — corrigé après tes retours', [
        ('/optin (admin) : « service admin » basculé ; ensuite /tp, /addkeys… de Qbox acceptés (avant : « not opted in »)', 'Staff', 2),
        ('F11 : items par catégorie avec image + recherche (armes, munitions ammo-9…, accessoires en français), donner des munitions ; véhicules : catalogue par catégorie', 'Staff', 3),
        ('Déplacer un point (F11 → Monde et lieux) avec un compte fondateur ET un super-admin : une CAMÉRA, un MAGASIN, Max → « Vérifié : … a redémarré avec la nouvelle position », ancien point inactif', 'Staff', 3),
        ('Cabine de la Voix : la placer contre une VRAIE cabine ou un téléphone mural → [E] / Alt sur la cabine elle-même ; quête de la Voix jusqu\'à « Rappelle depuis la cabine » : ça décroche', 'Staff', 2),
        ('Caméras accrochées aux murs / poteaux, orientées vers la rue ; PNJ acheteurs (poissonnerie, scierie, marché, boucherie) ; /porter puis « Poser » ; retirer puis réactiver un point', 'Staff', 2),
        ('Ban (super-admin) : F11 → Joueurs → Bannir 3 jours → double confirmation, #sanctions ; reconnexion refusée avec motif + date + Discord ; F11 → Bannissements : recherche, Débannir → il revient', '2', 3),
        ('Un modo (niveau 2) ne voit ni Bannir ni Bannissements ; bannir un staff de rang égal ou supérieur : refusé ; aucun joueur honnête signalé « PIÈGE » de toute la session', '2', 2),
    ]),
    ('4 · Discord et site (20 min)', [
        ('Après METTRE-A-JOUR-OVH : console « Discord RoadLine détecté » ou diagnostic « gs_discord_guild réglé » ; /aide et /help = liste des commandes ; /ip = adresse + connect F8', 'Staff', 3),
        ('/ticket sujet → fil privé dans #tickets (joueur + rôle staff), /fermer ; commande staff refusée sans rôle staff / admin, acceptée avec', 'Staff', 3),
        ('/annonce texte titre mention:@everyone → publiée dans #annonces ; avec en_jeu → aussi en ville ; /joueurs, /geler, /avertir, /message, /expulser, /isoler, /liberer, /reanimer → effet en jeu, #sanctions, journal F11', 'Staff', 3),
        ('Bienvenue : un compte de test rejoint le Discord → message dans le salon réglé ; sans « Server Members Intent » → console : bienvenue coupée, le bot reste connecté', 'Staff', 2),
        ('CONFIGURER-DISCORD → #tickets, #candidatures, #sanctions, #logs-staff ; GERER-OVH → 12 puis → 17 : message de test dans chaque salon ; appli staff : Isoler, Libérer, Réanimer, Tickets', 'Staff', 3),
        ('Site : « En ce moment en ville » (météo, heure, joueurs, quartier chaud, rendez-vous, rumeur) ; candidature en 3 questions → #candidatures (2e envoi en 10 min refusé) ; bouton son ; sur téléphone : bouton menu visible, pas de défilement de côté', 'Seul', 3),
    ]),
    ('5 · Alertes et police (25 min, à 2 : un policier en service + un civil)', [
        ('Le civil tire en ville : « Coups de feu détectés » + rue + GPS même sans témoin ; 2e tir dans les 10 s = pas de 2e alerte ; le policier ou un shérif en service tire : AUCUNE alerte ; le shérif reçoit tout', '2', 3),
        ('Chasse (Paleto) : avec permis, tirer un cerf = aucune alerte ; sans permis = « Coups de feu » ; dépecer sans permis = « Braconnage »', '2', 2),
        ('Vol de voiture (crochetage, fils, conducteur sorti) : UNE seule alerte « Vol de véhicule » ; caméra peinte : « Dégradation… » ; transformateur : « Sabotage… » ; caisse d\'un commerce : « Braquage de commerce »', '2', 3),
        ('Civil : /911p refusé ; appli Urgences → arrive au policier ; à terre avec EMS en service : [G] → alerte + GPS ; sans EMS : [G] → secouriste IA', '2', 3),
        ('Seul en ville (aucun policier joueur) : braquer une caisse → la police IA réagit au moins 6 fois sur 10, poursuite, recherche qui retombe ; vente de drogue / vol de voiture : le plus souvent rien ; /policeia 2 (admin) ; joueur simple refusé', 'Seul', 3),
        ('Police F4 : menottes, fouille, amende, casier, plaque, radar, fourrière, garde à vue, /droits, K9 ; scientifique : douilles / sang / empreintes, scellé, labo, fichier', '2', 3),
    ]),
    ('6 · Mappings (10 min, en mode staff) — toutes retirées le 12/10', [
        ('F11 → Monde et lieux → Mappings installés → « Supprimer définitivement toutes les maps » (taper SUPPRIMER), sur le PC PUIS sur le VPS : dossiers gsa_ des maps effacés de resources\\[addons], vêtements gardés ; redémarrage : liste vide ; IMPORTER-MODS ne les réinstalle pas', 'Staff', 3),
        ('Hôpital Pillbox, Fleeca, Pop\'s Pills, Bahama Mamas : nos points (soins, braquage, pharmacie, bar) accessibles sans les maps', 'Staff', 3),
        ('NETTOYER-MARQUES.bat : liste les mods de marque (dont mp_male_the_goat), supprime après « O », le reste intact', 'Staff', 2),
        ('Pack acheté (plus tard) : IMPORTER-MODS puis F11 → Mappings installés : chaque map a un quartier, aucune ligne rouge (conflit) ni jaune (poids) en console', 'Staff', 2),
    ]),
    ('7 · Nouveautés jamais testées — la ville se souvient (30 min)', [
        ('Mémoire des lieux : 3 événements au même endroit → un passant en parle, Radio Los Santos le rappelle ; 10e → plaque ; la nuit près d\'un lieu à 5 événements : « Les échos » (silhouettes 40 s)', '2', 3),
        ('Véhicule disparu : déclarer volée (assurée 24 h), non retrouvée 48 h → rumeur + tuyau → casse / garage louche / enchères, carnet intact, indemnité reprise', '2', 2),
        ('Faux papiers : double-clic = présenter ; F4 loin du commissariat = cru ; au commissariat = démasqué + casier ; témoin protégé : /droits → dénoncer un gang (peine ÷ 2, lieu sûr 7 jours)', '3+', 3),
        ('Guerre de l\'information : F9 → Opérations : brouiller les caméras (5 000 $), pirater le scanner (8 000 $) ; police : Remonter la source (5 min)', '3+', 2),
    ]),
    ('8 · Vie légale (30 min)', [
        ('/mentor ; téléphone : appel, appel manqué, Plans (GPS, partager ma position), Ville, Notes, Vibe, Boulots, Weazel, Réglages ; resmon gs_phone ≈ 0 ms fermé', '2', 2),
        ('Mécano : réparer, personnaliser la voiture d\'un client (Alt → Personnaliser → Valider) ; bars : préparer, vendre, prix, libre-service, doublure (et la braquer)', '2', 2),
        ('Supérette : habitué après 5 jours ; braqueur sans masque refusé ; coiffeur / tatoueur / chirurgien ; assurance, fourrière à 25 %, fraude détectée ; auto-école', 'Seul', 2),
        ('/contrat (prêt, salaire, location) ; marina, motel ; mairie (mariage) ; tribunal avec jury de 5 joueurs ; /recap, /rdv', '3+', 1),
        ('Métiers libres (bus, voirie, Post OP → F6 → Mission → paie) ; récolte (bois, mine, ferme, ferraille, pêche, chasse) → revente ; vestiaire', 'Seul', 2),
    ]),
    ('9 · Vie illégale (30 min)', [
        ('Braquer un passant, une supérette (sacs à ramasser), une bijouterie, Cayo en duo ; témoins : description (tenue, masque, voiture, plaque partielle) ; même tenue → reconnu', '2', 3),
        ('/cavale à 5 étoiles, affiches, /livrer, /legendes, prime au policier ; gangs (F9) : caisse, tags, territoire, guerre (fresque), /racket d\'un bar', '3+', 2),
        ('Marché noir (/contact), contrats, drogues, blanchiment, fausse plaque, contrebande de nuit ; combats clandestins (ring, parieur) ; prison (boulots, évasion à deux)', '2', 2),
        ('Planques : visites répétées → voisins → /mandat → juge → perquisition', '3+', 2),
    ]),
    ('10 · Ville vivante, presse (25 min)', [
        ('Rencontres de la route, carnet de route ; Radio Los Santos, rumeurs des barmans, indic\' ; /histoire au volant ; /quartiers (déclin / essor) ; faits divers PNJ', 'Seul', 2),
        ('Cicatrices (bougies, vitrine réparée, fresque) ; caméras du commissariat ; black-out (transformateur) puis réparation payée', '2', 2),
        ('Tribunal : photo + scellé versés, chantage ; enchères de la fourrière ; direct Weazel (5 étoiles) ; tempête, Halloween, /gazettepublier', '3+', 1),
        ('Casino, courses, road trip, location, Cayo aller / retour, marché de nuit ; connexion : « Précédemment à Los Santos », « Bon retour Prénom » ; Discord 23 h 30 : « La nuit à Los Santos »', 'Seul', 1),
    ]),
    ('11 · Outils et charge — avant d\'ouvrir', [
        ('Mode staff : vol libre / invisible SANS alerte anti-triche ; F10 (tickets /report, sanctions) ; Alt ouvre / ferme le ciblage ; carkill 2 fois → alerte', 'Staff', 3),
        ('SAUVEGARDER-BDD.bat (toutes les 6 h) puis RESTAURER-BDD.bat → un seul joueur ; redémarrage 6 h : annonces 15 / 5 / 1 min, statut Discord ; coupure → alerte en 4 min', 'Staff', 3),
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
