# Génère docs/pdf/ROADTRIP_Bilan_V7.pdf (tout ce qui existe, historique, état, ce qu'il reste, idées signature)
# et docs/pdf/ROADTRIP_Reste_a_tester.pdf (retours du beta test → statut V7 → à vérifier en jeu).
# Lancer depuis la racine : python3 tools/bilan.py
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from pdf import H1, H2, H3, P, SMALL, table, bullets, footer, VERSION, PINK, DARK  # noqa: E402
from reportlab.lib.pagesizes import A4  # noqa: E402
from reportlab.lib.units import mm  # noqa: E402
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepTogether  # noqa: E402


def doc(path, title):
    return SimpleDocTemplate(path, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm,
                             bottomMargin=16 * mm, title=title, author='ROADTRIP')


HISTORY = [
    ['Version', 'Ce qui est arrivé'],
    ['Phase 0 – 1', 'Structure du projet, sécurité serveur (gs_security), couche Qbox isolée (gs_bridge), multi-métiers (gs_jobs), tests automatiques'],
    ['V1', 'Config serveur complète, météo événementielle, recherche intelligente, économie dynamique, duo criminel, réseau social, '
           'écran de chargement, panel staff F10, téléphone, HUD néon, gangs et territoires, braquages, drogue, outils Windows (installer, lancer, réparer)'],
    ['V2', 'Menu staff F11, quêtes et XP, location, marqueurs unifiés, supérettes, secours et police IA, défis du jour, titres, points de métier déplaçables'],
    ['V3', 'Police et EMS complets, intérieurs du jeu, tenues de service, concession, casino, plantations, récolte, logement, Vibe 2, banque, '
           'base police, courses de rue, guerres de territoire, gros coups en duo, caméras, assurance, événements, loto, néons et plaques'],
    ['V4', 'Arrivée des joueurs, permis de conduire, justice, état civil, commerces de joueurs, presse Weazel, carnets de route, saisons et pass, '
           'réputation, contrats, bodycam, bourse de la ville, budget de performance'],
    ['V5', 'Touches sans doublon, staff à 5 rangs, radio, décor retirable, salaires et primes, braquage solo à la voix, marché noir, Cayo en duo, '
           'motels, blanchiment, contrats entre joueurs, munitions artisanales, importeur de mods, vols animés vers Cayo, soirée plage'],
    ['V6', 'Flotte des gangs, Weazel automatique, guides PDF, moins de PNJ, carte d\'identité corrigée, 3 signatures (Los Santos réactif, '
           'journal Weazel joué, road trip du mois), boutiques de vêtements, AFK 20 min, retouche de perso, lieux publics staff, marques réelles retirées'],
    ['V7', 'Retours du beta test : confort (touches, images, magasins, marqueurs discrets), staff F11 en 5 catégories, points déplaçables en jeu, '
           'récolte refaite, 3 bars, PNJ d\'ambiance, police IA réelle, braquage avec sacs, téléphone (Inconnu, Carnet, Weazel), 4 gangs + 2 organisations, '
           'tenues en objets, courses avec organisateur, personnalisation mécano, outil de mise en ligne'],
]

FEATURES = [
    ('Arrivée et confort', [
        'Écran de chargement néon / sunset, règlement à accepter, liste blanche optionnelle (candidature Discord).',
        'Création de perso en français (visage, teint, origines), retouche unique (/retoucheperso), apparition à la mairie, quête « Ton premier jour ».',
        'HUD néon (santé, faim, soif, voix, argent, métier, étoiles, météo, compteur), aide des touches (I), menu radial W « Moi ».',
        'Téléphone F1 : messages, contacts, appels, Vibe, banque, factures, emploi, boulots, urgences, Carnet, Weazel, Commandes, Inconnu, réglages.',
    ]),
    ('Progression', [
        'XP et niveaux, chaînes de quêtes homme / femme, personnages récurrents, paquets cachés, défis du jour, titres (F3).',
        'Saisons de 8 semaines avec pass (piste gratuite + cosmétique), réputation rue / légale / média qui change les prix et l\'accueil.',
        'Carnets de route (itinéraires panoramiques, spots photo, titres d\'explorateur) et road trip du mois (prime, bonus convoi, classement).',
    ]),
    ('Économie', [
        'Prix dynamiques (offre / demande / météo), bourse de la ville dans Vibe, tableau de bord éco du staff (/economie).',
        'Banque : distributeurs et guichets, plafonds, historique. Factures, caisses de société, salaires et primes réglables.',
        'Commerces : supérettes et Rob\'s Liquor, quincailleries, pharmacies, Ammu-Nation (permis), boutique cosmétique Tebex (zéro P2W).',
    ]),
    ('Métiers (F6)', [
        'LSPD (F4 : menottes, fouille, escorte, amendes, casier, radar, fourrière, objets de voirie, dossiers, bodycam), EMS (réanimer, soigner, secouriste IA).',
        'Mécano LS Customs : réparations, pneus, nettoyage, livraisons de pièces, personnalisation complète des véhicules des clients.',
        'Concession, agent immobilier (logements Qbox), auto-école (code + conduite), avocats, juge, mairie (mariage, divorce), psy, Weazel News (journal).',
        'Bars tenus par des joueurs : Tequi-la-la, Vanilla Unicorn, Bahama Mamas (préparation, caisse, prix du patron, barman PNJ sans employé).',
        'Métiers libres avec missions : routier, bus, taxi, livreur Post OP, éboueur (« Prendre le poste ici » au dépôt). Petits boulots au téléphone.',
    ]),
    ('Activités libres', [
        'Pêche, mine (pioche), bûcheron (hache), ferme, ferraille, chasse (permis) : nœuds qui s\'épuisent et repoussent, vestiaire, revente éloignée.',
        'Location de vélos, scooters, citadines, bateaux ; motels à la semaine (coffre, garde-robe) ; tenues en objets (plier / enfiler / échanger).',
        'Coiffeurs, tatoueurs, chirurgien, boutiques de vêtements avec vendeurs ; néons et plaque personnalisée ; assurance auto.',
    ]),
    ('Illégal', [
        'Braquage solo (passants, caisses, guichets) : peur à la voix, argent sale en sacs à ramasser, toujours signalé.',
        'Braquages de supérettes, bijouterie, Fleeca ; gros coup en duo (pirate + conducteur) ; Cayo Perico en duo.',
        'Drogues (plantations, labos, vente), marché noir (téléphone → Inconnu), contrats entre joueurs, blanchiment via les entreprises.',
        'Gangs (F9) : Families, Ballas, Vagos, Lost MC + Cartel Madrazo, Triades : caisse, territoires et guerres, tags, receleur, labo, munitions artisanales, flotte.',
        'Recherche intelligente : témoins, heure, météo, caméras, précision de la zone, chaleur ; police joueurs ou patrouilles IA réelles.',
    ]),
    ('Monde et loisirs', [
        'Los Santos réactif : la tension des quartiers monte avec les crimes (passants, trafic, témoins, police, brèves Weazel).',
        'Météo synchronisée et événements météo, golden hour allongée, densité de PNJ adaptée au nombre de joueurs.',
        'Cayo Perico (vol animé aller / retour, soirée plage), casino (roue, loto, tickets, PNJ), courses de rue avec organisateur et voitures prêtées.',
        'Vibe (réseau social) : posts, photos, stories, tendances, vérifiés, classements ; Weazel News automatique et journal écrit par les joueurs.',
        'Événements staff en un clic et bonus serveur (double XP, soirée chanceuse), événements saisonniers.',
    ]),
    ('Staff et outils', [
        'Panel F10 (tickets, fiches, sanctions publiques, isolement, journal) ; F11 en 5 catégories ; raccourcis Ctrl+Y / U / O ; persos GTA et animaux.',
        'Déplacer n\'importe quel point en jeu (sauvegardé), décor (/builder), lieux publics (boutiques, parkings), gangs et garages, journal de toutes les actions.',
        'Outils Windows en un double-clic : INSTALLER, METTRE-A-JOUR, IMPORTER-MODS (marques refusées), NETTOYER-MARQUES, REPARER-*, VIDER-CACHE, '
        'SAUVEGARDER-BDD, INVITER-AMIS, PREPARER-HEBERGEUR.',
        'Qualité : 49 ressources maison, ~1 900 vérifications automatiques à chaque envoi (GitHub), linters de config, de liaisons et de performance.',
    ]),
]

STATE = [
    ['Domaine', 'État', 'Ce qu\'il reste'],
    ['Code et contenu', 'V7 complète, tests verts', 'Ton test en jeu de la V7, recalage des points estimés (outil Déplacer un point)'],
    ['Hébergement', 'Bloqué : offre sans base SQL', 'Base MySQL (support Sentrohost, offre avec base, ou VPS Linux + installateur), puis PREPARER-HEBERGEUR'],
    ['Beta test', 'Toi seul en local', 'Ouvrir aux beta-testeurs une fois hébergé (8 places en profil dev)'],
    ['Communauté', 'Discord fait', 'Quelques catégories / salons (règlement, candidatures, sanctions, annonces, tickets), webhooks à brancher'],
    ['Image', 'Logos et site en cours', 'Logo 96x96 du serveur, écran de chargement final, site (modèle fourni)'],
    ['Lancement public', 'À préparer', 'Profil prod (48 places), sauvegardes automatiques, staff recruté et formé, règlement final, Tebex (optionnel)'],
]

TO_OPEN = [
    '<b>Hébergeur avec base de données</b> : demander au support Sentrohost d\'ajouter une base MySQL / MariaDB, ou passer sur une offre qui en a une, '
    'ou louer un VPS Linux (on écrira l\'installateur Linux). Sans base, Qbox ne démarre pas.',
    '<b>Valider la V7 en jeu</b> avec la fiche « Reste à tester » ; me renvoyer les points encore mal placés et les erreurs F8.',
    '<b>Clé de licence</b> Cfx (keymaster) pour l\'hébergeur, sv_hostname / projet / tags, logo 96x96 (load_server_icon).',
    '<b>Discord</b> : webhooks (staff, sanctions publiques, annonces, social) dans secrets.cfg ; rôles staff = rangs en jeu ; salon candidatures si liste blanche.',
    '<b>Staff</b> : nommer 2-3 modos, leur donner le rang en jeu (F11 → Joueurs → Rang), leur faire lire docs/ADMIN.md.',
    '<b>Sauvegardes</b> automatiques de la base chez l\'hébergeur (tâche planifiée ou sauvegarde du panel).',
    '<b>Test de charge</b> à 6-8 joueurs (FPS, resmon, ping) avant de monter en places ; puis profil prod.',
    '<b>Règlement final</b> (RP, sanctions, boutique zéro P2W) publié sur le Discord et le site.',
]

IDEAS = [
    ('La ville se souvient (témoins à mémoire)', 'Les PNJ témoins décrivent vraiment le suspect : tenue, couleur de voiture, plaque partielle. '
     'Changer de tenue (tenues en objets !) ou repeindre sa voiture chez le mécano brouille la piste. La police IA et les joueurs policiers reçoivent '
     'ces descriptions. Le RP criminel devient une vraie partie d\'échecs, et c\'est relié à 3 systèmes qu\'on a déjà.'),
    ('Chaîne d\'approvisionnement réelle', 'Les rayons des supérettes, bars et pharmacies se remplissent grâce aux livraisons des joueurs '
     '(fermiers, pêcheurs, routiers). Si personne ne livre : ruptures, prix qui montent, brèves Weazel « pénurie de tomates ». '
     'Chaque métier libre devient utile à toute la ville.'),
    ('Élections municipales', 'Tous les mois, les joueurs votent pour un maire (campagne, débats sur Weazel). Le maire fixe 2-3 « lois » '
     'réglables (taxe sur l\'alcool, prime aux métiers de service, horaires des bars, limite de vitesse en ville) qui changent vraiment le jeu.'),
    ('Rencontres de la route (road movie)', 'Pendant un road trip ou un trajet hors de la ville : rencontres aléatoires scénarisées (auto-stoppeur, '
     'panne d\'un PNJ, contrôle routier, animal sur la route, vendeur ambulant, tempête). C\'est le cœur de l\'identité ROADTRIP.'),
    ('Ambition de personnage', 'À la création, chaque perso choisit une ambition (ouvrir un commerce, devenir chef de gang, entrer au LSPD, '
     'faire le tour de l\'île…). Un carnet de vie suit les étapes, le staff voit les ambitions pour scénariser, récompenses cosmétiques à la clé.'),
    ('Enquêtes avec preuves physiques', 'Douilles, traces de sang, empreintes sur une caisse, traces de pneus : la police les ramasse, '
     'un labo (EMS / police) les analyse en temps réel et les relie à un suspect. Les criminels prudents nettoient (gants, nettoyage).'),
    ('Radio Roadtrip', 'Une vraie station de radio dans toutes les voitures, animée par des joueurs DJ (voix pma-voice), avec flashs Weazel '
     'automatiques (trafic, braquages, météo). Une ville qui parle d\'elle-même.'),
    ('Agenda vivant de la ville', 'Les événements naissent de l\'état du serveur : grève des éboueurs si personne ne ramasse, festival quand '
     'l\'économie va bien, couvre-feu si la tension explose, marché du dimanche. Le staff n\'a plus à tout animer à la main.'),
    ('Héritage et dynasties', 'Testament chez l\'avocat, biens et réputation transmis à un autre perso (enfant, associé), mort RP '
     'acceptée et valorisée. Des familles et des empires qui durent dans le temps.'),
    ('Mode réalisateur Weazel', 'Les journalistes filment (caméra, cadrage, interviews de rue) et publient des reportages illustrés '
     'dans Vibe ; classement des meilleurs reportages, prime de la rédaction. Les joueurs racontent eux-mêmes l\'histoire du serveur.'),
]


def bilan():
    d = doc('docs/pdf/ROADTRIP_Bilan_V7.pdf', 'ROADTRIP · Bilan complet V7')
    s = [Paragraph('ROADTRIP · Bilan complet', H1),
         Paragraph(f'De la création de la base à la {VERSION} : tout ce qui existe en jeu, où on en est, ce qu\'il reste pour ouvrir, '
                   'et 10 idées signature pour la suite. Serveur FiveM RP français, Free Access, zéro pay-to-win (Qbox, ox_lib, ox_inventory, pma-voice).', P),
         Paragraph('1. Historique', H2), table(HISTORY, [24 * mm, 156 * mm])]
    s += [PageBreak(), Paragraph('2. Tout ce qu\'il y a en jeu', H2)]
    for title, items in FEATURES:
        s += [KeepTogether([Paragraph(title, H3)] + bullets(items))]
    s += [PageBreak(), Paragraph('3. Où on en est', H2), table(STATE, [32 * mm, 45 * mm, 103 * mm]),
          Paragraph('4. Ce qu\'il reste pour ouvrir le serveur', H2)] + bullets(TO_OPEN)
    s += [PageBreak(), Paragraph('5. Dix idées signature pour la suite', H2),
          Paragraph('Dans l\'esprit de « Los Santos réactif » : des systèmes qui se branchent sur ce qui existe déjà et que peu de serveurs proposent.', P)]
    for i, (t, txt) in enumerate(IDEAS, 1):
        s += [KeepTogether([Paragraph(f'{i}. {t}', H3), Paragraph(txt, P)])]
    s += [Spacer(1, 6), Paragraph('Reportés : écrans TV / piano avec vidéo, photos des parents à la création, itinéraire de l\'auto-école. '
                                  'Refusé : map de Liberty City (risque Rockstar), marques réelles.', SMALL)]
    d.build(s, onFirstPage=footer, onLaterPages=footer)


# Retours du beta test → ce qui a été fait en V7 → à vérifier
RETEST = [
    ('Démarrage et touches', [
        ('Carte d\'identité donnée au départ', 'Retirée : mairie / Pôle Emploi', 'Créer un perso : pas de carte'),
        ('F3 ne marche pas, F5 ouvre 2 menus', 'Nouveau nom de commande (touche F3 pour tous)', 'F3 ouvre / ferme ; F5 = emotes seules'),
        ('Progression qui reste ouverte', 'Même touche = fermer', 'F3 deux fois'),
        ('Double-clic : coup de poing dans le vide', 'Attaque bloquée 0,7 s', 'Boire / manger depuis l\'inventaire'),
        ('Menu rapide (W) pauvre', 'W → Moi : tenue, chapeau, lunettes, masque, animations…', 'Tester chaque entrée'),
        ('Objets sans image', '47 images ajoutées', 'Inventaire : tomate, pioche, hache, pochons, alcools, tenue'),
        ('Jerrican bugué', 'Vrai jerrican d\'essence', 'L\'acheter et l\'utiliser'),
        ('Magasin qui se ferme après un achat', 'Menu qui reste ouvert', '3 achats d\'affilée'),
        ('Perso chauve en reprenant sa tenue civile', 'Vêtements remis sans changer de modèle', 'Tenue de service puis civile'),
        ('Père / mère sans photo', 'Noms : Visage de base, Ressemblance, Teint, Origines', 'Nouveau perso'),
        ('Flèches trop visibles', 'Petit cercle discret, visible à 15 m', 'Regarder plusieurs points'),
        ('Commandes / pour tout le monde', 'Joueurs : seulement les utiles', 'Taper / avec un compte joueur'),
    ]),
    ('Vie légale', [
        ('Coiffeurs / tatoueurs / chirurgien inopérants', 'Vendeur PNJ + [E] à chaque boutique', 'Un coiffeur, un tatoueur, le chirurgien (Pillbox)'),
        ('Ammu-Nation ne marche pas, port d\'arme', 'Permis au comptoir (5 000 $)', 'Demander le permis puis acheter un pistolet'),
        ('Pharmacies inaccessibles', 'Pops Pills et hall de Pillbox', 'Acheter des antidouleurs'),
        ('Caviste = supérette', 'Rob\'s Liquor en supérettes', 'Logo et articles'),
        ('Ferraille à côté de la revente, 2 ferrailleurs, fonderie inaccessible', 'Un seul ferrailleur (Cypress Flats), casses ailleurs', 'Récolter à Rogers / Sandy, vendre à Cypress Flats'),
        ('Pêche dans l\'eau', 'Point retiré, points sur les pontons', 'Pêcher sur chaque ponton'),
        ('Bûcheron : « axe », un seul arbre, pas de tenue', 'Hache, 12 arbres qui repoussent, vestiaire', 'Couper plusieurs arbres'),
        ('Mine « pickaxe »', 'Pioche en main, rochers qui s\'épuisent', 'Miner à Davis Quartz'),
        ('Ferme : où revendre ?', 'Marché de Grapeseed (logo visible de loin)', 'Revendre tomates / pommes de terre'),
        ('Permis de chasse dans une maison fermée', 'Comptoir Ammu-Nation de Paleto', 'Acheter le permis et le fusil'),
        ('Boucherie mais pas de métier', 'Viande et cuir = chasse', 'Chasser puis vendre à Paleto'),
        ('Dépôts voirie / bus / Post OP introuvables', '« Prendre le poste ici » au dépôt', 'Les 3 dépôts + F6 → Mission'),
        ('Direction LS Customs dans le mur', 'Point déplacé', 'Patron mécano : direction'),
        ('Marina : essai qui finit dans l\'eau', 'Retour sur le ponton', 'Essayer un bateau'),
        ('Motel Pink Cage introuvable', 'Logo motel', 'Louer une chambre'),
        ('Fourrière : mauvais nom et logo', '« Fourrière », logo fourrière', 'Carte'),
        ('Double logo police', 'Logos Qbox masqués', 'Carte'),
        ('Horny\'s non mappé, libre-service bugué', 'Horny\'s retiré ; barman PNJ sans employé', 'Commander au Tequi-la-la sans employé'),
        ('Bars : trop de métiers', 'Tequi-la-la, Vanilla Unicorn, Bahama Mamas', 'Les 3 bars (comptoir, préparation, réserve)'),
        ('Personnaliser les véhicules (garagiste)', 'Personnalisation complète par le mécano', 'Mécano : Alt sur la voiture d\'un ami → Valider'),
        ('Vêtements en objets', 'Plier / enfiler / échanger', 'W → Moi → Vêtements'),
        ('Dynasty 8 inaccessible', 'Non corrigé (pas d\'intérieur) : service partout', 'Déplacer ses points (F11 → Points de métier)'),
    ]),
    ('Vie illégale', [
        ('Braquage de supérette avec E', 'Démarre seul en visant le caissier', 'Braquer une caisse'),
        ('Argent donné directement', 'Sacs plastique au sol à ramasser', 'Ramasser les sacs'),
        ('Police IA présente sans l\'être, voitures vides', 'Patrouilles créées par le serveur (2 agents, poursuite)', 'Commettre un crime sans policier connecté'),
        ('/contact pas sûr', 'Téléphone → Inconnu → Appeler le contact', 'Dans un gang, la nuit'),
        ('Contrats à mettre dans le téléphone', 'Téléphone → Inconnu → Contrats', 'Publier / accepter'),
        ('100 gangs, planque Ballas buggée', '4 gangs + 2 organisations ; garage visible', 'F9, planque et garage de chaque gang'),
    ]),
    ('Monde, secours, staff', [
        ('Cayo : pas de retour', 'Comptoir retour (pilote, logo)', 'Aller-retour'),
        ('Roue du casino qui dépasse', 'Roue recollée au socle', 'Regarder la roue'),
        ('Pas de PNJ (casino, scène)', 'Barman, caisse, croupiers, danseuses, groupe, DJ', 'Casino, Vanilla, Tequi-la-la, Bahama'),
        ('Pop-ups Weazel pas travaillés', 'Bandeau rouge Weazel', 'Article, flash, brève'),
        ('Respawn EMS / relais IA', 'IA seulement sans EMS ou envoyée par un EMS (F4)', 'À terre avec / sans EMS'),
        ('[E] de réanimation lent', 'Maintenir 2 s au lieu de ~5', 'Mourir, maintenir E'),
        ('Courses : points dans des supérettes', 'Organisateur, voiture prêtée, grille, points sur la route', 'Un chrono solo et une course à 2'),
        ('TP / GPS staff dans le ciel', 'Attente du sol avant d\'arriver', 'TP au marqueur plusieurs fois'),
        ('Give d\'argent', 'Super-admin et fondateur (F10 corrigé, F11 ajouté)', 'Donner de l\'argent'),
        ('Section peds', 'F11 → Moi → Persos GTA', 'Se transformer puis reprendre son perso'),
        ('Événements en double', 'Une seule catégorie Événements', 'F11'),
    ]),
]


def reste():
    d = doc('docs/pdf/ROADTRIP_Reste_a_tester.pdf', 'ROADTRIP · Reste à tester')
    s = [Paragraph('ROADTRIP · Reste à tester', H1),
         Paragraph(f'Chaque retour de ton beta test, ce qui a été fait en {VERSION}, et comment le vérifier. Coche ce qui est bon ; '
                   'pour le reste : capture + coordonnées (F11 → Monde et lieux → Copier mes coordonnées), ou déplace le point en jeu.', P)]
    for title, rows in RETEST:
        data = [['OK', 'Ton retour', f'Fait en {VERSION}', 'À vérifier en jeu']] + [['[  ]', a, b, c] for a, b, c in rows]
        s += [Paragraph(title, H2), table(data, [9 * mm, 58 * mm, 60 * mm, 53 * mm], font=8)]
    s += [Paragraph('Points estimés à confirmer en jeu', H2)] + bullets([
        'Bahama Mamas (intérieur du mod) : comptoir, préparation, réserve, DJ.',
        'Vanilla Unicorn : service, direction, réserve, comptoir, danseuses.',
        'Planque et garage des Triades ; ranch Madrazo ; poissonnerie de Del Perro ; forêt du bûcheron ; organisateur de courses ; PNJ du casino.',
    ])
    d.build(s, onFirstPage=footer, onLaterPages=footer)


if __name__ == '__main__':
    bilan()
    reste()
    print('PDF générés : docs/pdf/ROADTRIP_Bilan_V7.pdf, docs/pdf/ROADTRIP_Reste_a_tester.pdf')
