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
        ('METTRE-A-JOUR.bat : version V12.63 affichée, « Base de données sauvegardée » ; METTRE-A-JOUR-OVH puis GERER-OVH → 1 : « Version RoadLine : V12.63 »', 'Staff', 3),
        ('Console au démarrage (PC et VPS) : aucune ligne ROUGE ; en jaune seulement « Conflit tranché » (2 fichiers Patoche) ; F8 en jeu : aucune erreur rouge', 'Staff', 3),
        ('VIDER-CACHE-FIVEM.bat si un ancien menu apparaît (F11 doit afficher « RoadLine V12.63 »)', 'Staff', 2),
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
    ('4c · V12.50 → V12.58 — tatouages, voix, garde-robe, arrivée, duo, vie quotidienne (20 min)', [
        ('Tatoueur : menu en français (Tatouages, Torse), « Appliquer » un tatouage puis quitter SANS sauvegarder : le tatouage reste, payé une seule fois', 'Seul', 3),
        ('Voix (après METTRE-A-JOUR + REPARER-SON chez chaque joueur) : on s\'entend en « Normal » à quelques mètres, le son du jeu ne baisse plus quand quelqu\'un parle', '2', 3),
        ('Garde-robe (U) : clic sur un vêtement du sac = enfilé tout de suite, rien ne disparaît ; vêtement d\'un pack non chargé = message, il reste dans le sac', 'Seul', 2),
        ('Arme longue dans le dos à 2 joueurs : elle suit le dos, disparaît en main, aucune copie figée en l\'air (avant / après déconnexion de l\'autre)', '2', 3),
        ('Menu mécano (Alt) : caméra autour du véhicule (flèches ou Z/Q/S/D, molette, clic droit + souris), le perso ne bouge pas, vue normale à la fermeture', 'Seul', 2),
        ('Territoires (membre de gang) : pâtés de maisons alignés sur les rues au lieu de ronds ; /quartierforme <quartier> <angle> pour les ajuster', 'Staff', 2),
        ('Salles de jeu : 3 blips (Sandy, Del Perro, Paleto) ; jeu avec armes : ni police, ni étoiles, ni brève « quartier sous tension »', 'Seul', 3),
        ('Stand de jeux (jetée de Del Perro) : les stands sont là ; auto-tamponneuses : jeton achetable (après IMPORTER-MODS, rapport « objets du script ajoutés »)', 'Seul', 3),
        ('Prison : Pompes, Abdos, Haltères, Tractions dans la cour (peine −30 s, délai 90 s, sprint plus long)', 'Seul', 2),
        ('/son : fenêtre d\'aide son et micro (aussi dans Que faire ? → Aide) ; rappel « Vocal » ~45 s après la connexion (3 premières fois)', 'Seul', 2),
        ('Voix : console client F8 sans erreur pma-voice ; ² affiche « Chuchoter / Normal / Crier » (HUD) ; radio coupée à la mort', '2', 3),
        ('Spam de clics au poing : un coup toutes les 0,8 s au plus ; duo et missions de métier : plus de [E] qui reste après la fin', '2', 2),
        ('Connexion / réapparition : 30 s de protection (on te traverse, impossible de te frapper) ; aux points d\'apparition, personne ne peut frapper ni tirer', '2', 3),
        ('V12.57 · Poubelle (Alt sur une benne) : fouille 6 s, parfois un objet ; même benne vide ensuite ; distributeurs : boissons, snacks, café', 'Seul', 2),
        ('V12.57 · Lavabo / douche / fontaine (Alt) ou /laver dans la mer : sang et saleté effacés ; relevé par l\'EMS : on boite, un bandage ou des antidouleurs soignent', 'Seul', 2),
        ('V12.57 · Porter (Alt sur un joueur) : l\'autre accepte, X pour lâcher ; menotté ou à terre = sans accord ; Prendre en otage seulement arme de poing / couteau en main', '2', 3),
        ('V12.57 · Magasin de masques (plage de Vespucci, blip) : menu des masques seulement, payé en validant ; passagers PNJ (bus, taxi) qui racontent une rumeur', 'Seul', 2),
        ('V12.58 · Banc : assis puis ↑ ↓ (avant / arrière), PgUp / PgDn, ← → ; /meubleregle (staff) = gardé pour tous les bancs de ce modèle', 'Staff', 2),
        ('V12.58 · Arme longue rangée puis ressortie puis rangée : bien placée dans le dos sans /dosreglage ; caméra de rue : Alt dessus ou bombe de peinture utilisée dessous = peinte', 'Seul', 3),
        ('V12.57 · ENVOYER-PLACEMENTS.bat : portes / mapping / points posés sur le PC visibles sur le VPS après redémarrage ; /perfserveur pendant un test à plusieurs', 'Staff', 3),
    ]),
    ('4d · V12.59 — retours du backtest du 15/10 (20 min)', [
        ('Balle dans la tête : mort tout de suite, allongé SANS bouger (réanimable EMS) ; balle dans le corps : à terre qui bouge comme avant ; casque : arrête UNE balle, la 2e tue', '2', 3),
        ('Arme longue rangée : bien placée dans le dos au bout de 1 à 2 s, sans /dosreglage (même après l\'avoir ressortie)', 'Seul', 3),
        ('M : tomber au sol (rappuyer pour se relever) ; F5 → Raccourcis : emote sur 1 à 5, puis Pavé num. 1 à 5 la joue ; /vue ou W → Moi → Vue d\'ensemble : caméra autour du perso', 'Seul', 2),
        ('Fusillade : flaques de sang (une de plus par victime au même endroit) + douilles, plus de bougies ; braquage : barrières de police ; tout disparaît en 24 h ; textes des plaques lus de près seulement', '2', 3),
        ('F11 → Événements → Effets sur moi : super vitesse en voiture, voiture sauteuse (Espace), arc-en-ciel, caméra ivre ; « Chute lunaire » n\'est plus un événement général ; Persos GTA → Autre perso (nom du modèle)', 'Staff', 2),
        ('Bombe de peinture sous une caméra du décor (boîtier du jeu) : la caméra RoadLine du coin est peinte ; terminal LSPD : ← → change de caméra en direct', '2', 2),
        ('Sans policier en service : vol de voiture / rodéo → la police IA fonce vers toi sans devoir te voir ; braquage de banque / bijouterie → pas de police IA', 'Seul', 3),
        ('Discord : nouveau membre accueilli même après un redémarrage du bot ; #statut à jour chaque minute (sinon ligne jaune en console) ; profil : plus « Joue à Qbox »', 'Staff', 2),
        ('Courses sur mesure (F11) : nom avec accents, points à 15 m, enregistrer → visible chez l\'organisateur ; site : bandeau Weazel avec les articles écrits en jeu', 'Staff', 2),
    ]),
    ('4e · V12.60 — cimetière, cabines, Lives, diagnostic des mods (15 min)', [
        ('F11 → Joueurs → un joueur → Mort RP : tombe au cimetière (blip Cimetière), avis de décès dans Weazel ; Alt sur la tombe : épitaphe, fleurs 25 $ (fleurs + bougie visibles)', 'Staff', 3),
        ('Cabine téléphonique du décor (Alt) : appel anonyme → la police en service reçoit « Appel anonyme (cabine) » avec le message, zone floue ; Weazel : tuyau en direct ou /tuyaux', '2', 3),
        ('screenshot-basic installé : F11 → Lives (ou /lives) : WATCH ouvre l\'écran du joueur dans une fenêtre déplaçable ; 2 fenêtres en même temps ; ✕ pour jouer avec les fenêtres affichées', 'Staff', 2),
        ('DIAGNOSTIC-MODS.bat : rapport (vêtements en conflit, voitures en double, fichiers abîmés), O = corrections sûres ; F11 → Monde et lieux → Blips en double', 'Staff', 2),
    ]),
    ('4f · V12.61 — premier jour, cabines, samedi, rapport staff (15 min)', [
        ('Nouveau personnage : AUCUN téléphone dans le sac ; quête de Max : mairie → location → banque EN VOITURE → Pôle Emploi → téléphone acheté à la supérette (gardé) → Max', 'Seul', 3),
        ('Cabine : « Appeler un numéro » → l\'autre voit « Numéro masqué », on se parle, X raccroche ; policier grade 2+ : mettre la cabine sur écoute → l\'appel suivant arrive au central', '2', 3),
        ('Lives : screenshot-basic démarre tout seul (console sans erreur), F11 → Lives fonctionne sans rien installer', 'Staff', 3),
        ('Samedi 20 h : message LSPD en jeu + #annonces ; vol de voiture sans policier : une étoile de plus ; /rapportstaff (console) : rapport dans le salon staff', 'Staff', 2),
        ('Site : Nouveautés = V6 (teaser), V5, « V1 → V4 · Les fondations » ; Signatures : 39 systèmes (cimetière, cabines, rodéo du samedi…)', 'Staff', 1),
    ]),
    ('4g · V12.62 — Lives grille / replay, scène de crime, hélico, jetons (15 min)', [
        ('Lives : 3 fenêtres ouvertes → ▦ les range en grille ; « ⇢ TP » sur une fenêtre = téléporté à côté du joueur (journal staff)', 'Staff', 3),
        ('Un joueur fait « /report 12 il me fonce dessus » → dans /lives, le joueur 12 et l\'auteur ont « ticket #… » et ⏪ ; ⏪ rejoue ses 30 dernières secondes ; ticket fermé → plus de ⏪', '2', 3),
        ('Appareil photo sur du sang + douilles (là où quelqu\'un est tombé par balle) → « Scène de crime · … Au sol : … » ; verser au labo (police) → pièce « Scène de crime (photo) » dans les résultats, une seule fois', '2', 2),
        ('/policeia 3 (staff) : un hélico de police tourne au-dessus, projecteur la nuit ; Weazel en service prévenu ; site : « EN DIRECT · L\'hélico… » en tête du bandeau (60 s max)', 'Staff', 2),
        ('Guichet « Jetons de fête foraine » (salle de jeu Del Perro, à caler via F11) : acheter 10 jetons (50 $), revendre (4 $ pièce) ; caisse du casino : 10 jetons = 1 ticket à gratter', 'Seul', 2),
    ]),
    ('4h · V12.63 — appli staff externe, carte F10 (15 min)', [
        ('GERER-OVH → 20 → M : mot de passe collectif posé ; tablette : adresse /gs_admin/ → pseudo + mot de passe → tableau de bord (joueurs, staff, tickets, carte)', 'Staff', 3),
        ('Appli : fiche d\'un joueur → soigner, téléporter (lieu puis à côté d\'un joueur), geler / dégeler, isoler 5 min, avertir ; F10 → Journal : « Web · pseudo »', '2', 3),
        ('Appli : bannir 1 jour un compte de test → il est éjecté, onglet Sanctions → Débannir → il revient ; un super-admin ne peut pas être sanctionné depuis l\'appli', '2', 3),
        ('Appli → Lives : 2 écrans en même temps ; ticket « /report 12 … » → ⏪ Replay dans Tickets ; F10 → Carte : les joueurs bougent en direct', 'Staff', 2),
        ('Téléphone : appli en mode portrait (barre d\'onglets en bas), fiche plein écran, « Ajouter à l\'écran d\'accueil » ; 5 mauvais mots de passe → bloqué 15 min', 'Seul', 2),
        ('Lives SEUL : F11 → Lives → ta ligne « (toi : test) » → ton écran s\'affiche ; sinon la fenêtre dit pourquoi (copie la phrase) et GERER-OVH → 3 montre « [gs_lives] capture impossible »', 'Seul', 3),
        ('Site : diaporama « La ville » (9 photos, glisser), bande-annonce → TikTok, adresse « connect » affichée ; Gazette du site = édition en cours après une cavale (hélico)', 'Seul', 2),
    ]),
    ('4i · V12.63 — idées du soir (15 min)', [
        ('Mur des légendes (devant Mission Row) : E → liste ; texte « Dernière légende » au-dessus', 'Seul', 2),
        ('Cavale (/cavale à 5 ★) : affiche collée sur place ; un civil l\'arrache → 300 $ ; un policier → gratuit ; recollée 30 min après', '2', 2),
        ('Gangs : cadre A → Trêves → proposer ; cadre B → accepter ; déclarer la guerre → refusé ; A met B à terre → « TRÊVE ROMPUE », influence en baisse', '3+', 2),
        ('Figure du coin : missions / achats dans un quartier → message « t\'a adopté » ; remise à la supérette du quartier ; salut en revenant', 'Seul', 1),
        ('Braquage de caisse : « AVIS · BRAQUEUR RECHERCHÉ » au comptoir (si la caméra a filmé), E → 2 détails, jamais le nom', '2', 2),
        ('Cabine : appel anonyme police → l\'alerte porte un n° ; policier /faussealerte n° → amende si retrouvé, sinon « Introuvable »', '2', 2),
    ]),
    ('4j · V12.63 — idées et corrections du 16/10 au soir (15 min)', [
        ('Redémarrage du serveur : la console dit « ordre de démarrage déjà bon, aucune relance » (plus de gel de 11 s) ; sinon les maps en conflit sont relancées comme avant', 'Staff', 2),
        ('Se mettre sous la carte (noclip sous le sol) puis attendre 6 s (retour automatique) ou F11 → Joueurs → soi → « Coincé : ramener au dernier endroit sûr » : retour au dernier endroit au sol ; appli → Carte : anneau jaune sur l\'auteur d\'un ticket', '2', 2),
        ('DIAGNOSTIC-MODS.bat : « MÊME MAP EN DEUX VERSIONS » liste gsa_patoche_petshop_pack_1 (O = pause) ; Shadow Complex _1 démarre (lieu rempli, plus de lieu vide)', 'Staff', 3),
        ('Gang : bombe de peinture → « Un hommage », nom « Tony » → « R.I.P. Tony » au mur ; permanent coche → 1 000 $ pris dans la caisse ; un rival l\'efface → gang prévenu', '2', 2),
        ('/voisins dans un quartier → Rejoindre ; un ami tire en l\'air dans le quartier → notification « Voisins vigilants » sans position', '2', 2),
        ('Nuit, aucun policier en service, 3 verres, rouler hors de la ville : barrage du shérif (cônes) → s\'arrêter, E → « Alcootest positif » amende + points ; filer = refus d\'obtempérer', 'Seul', 2),
        ('Photomaton (à côté du guichet des jetons, à caler via F11) : 3 jetons → photo dans le sac ; un ami dans la cabine reçoit sa copie', '2', 1),
        ('F11 → Monde et lieux → Destination du vol de l\'île → North Yankton : un ami sur Cayo est ramené à l\'aéroport ; comptoir LSIA « Vol pour North Yankton » → ville enneigée, minimap du prologue, neige ; comptoir retour (à caler) → LSIA ; remettre « Alternance »', '2', 3),
        ('Site, « En ce moment en ville » : « ✈️ Vol du jour : … » suit la destination choisie dans F11 (1 min) ; jour North Yankton : annonce dans le bandeau Weazel', 'Seul', 1),
        ('Jour North Yankton : F11 → Événements → Soirée plage de Cayo → refusée ; se déconnecter à North Yankton, passer en Cayo, se reconnecter → repris à l\'aéroport', 'Staff', 2),
    ]),
    ('4k · V12.63 — retours du test du 16/10 au soir (15 min)', [
        ('Vol LSIA ↔ Cayo et retour de North Yankton : l\'avion vole droit, nez dans l\'axe du début à la fin (plus de glissade de côté vers le PNJ), descente douce, arrondi, toucher puis roulage dans le même axe', 'Seul', 3),
        ('Jour North Yankton : comptoir « Location · Ludendorff » → 4x4 / pick-up / berline enneigés, la voiture sort posée au sol (pas à travers la carte) ; jetée de Cayo absente ce jour-là', 'Seul', 3),
        ('Jour North Yankton : café de Ludendorff (café, sandwich, eau) ; avec des étoiles de recherche, rester là-bas → la recherche retombe plus vite ; serveuse, shérif et pilote sur place (positions à caler si besoin)', 'Seul', 2),
        ('Animalerie : Pôle Emploi → « Animalerie » → prendre le service ; les animaux (chat, lapin, chiens, poule) sont dans la boutique pour tout le monde', 'Seul', 3),
        ('Animalerie, staff : F11 → Monde et lieux → Déplacer un point → « Animalerie · Comptoir / Réserve / Gamelles / Cages / Toilettage » : placer chaque poste dans la boutique (les animaux suivent)', 'Staff', 3),
        ('Animalerie, en service : Réserve → carton porté → Gamelles (payé) ; Cages (balai) ; Toilettage ; refaire tout de suite = « reviens dans … s » ; client au comptoir après quelques minutes → Servir (payé + pourboire)', 'Seul', 2),
        ('North Yankton, Échap : noter ce que montre la carte du menu pause (coupée, vide, Los Santos…) et me l\'envoyer', 'Seul', 1),
    ]),
    ('5 · Obligatoire avant d\'ouvrir', [
        ('SAUVEGARDER-BDD.bat puis RESTAURER-BDD.bat sur un joueur ; redémarrage de 6 h : annonces 15 / 5 / 1 min', 'Staff', 3),
        ('Mode staff : vol libre / invisible SANS alerte anti-triche ; F10 tickets et sanctions ; carkill 2 fois → alerte', 'Staff', 3),
        ('Test de charge (docs/TEST_DE_CHARGE.md) : /perfserveur, 10 joueurs ou plus pendant 45 min : retard moyen < 5 ms, resmon (aucune ressource gs_ au-dessus de 0,5 ms en continu), aucune erreur F8', '3+', 3),
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
