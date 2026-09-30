# Features signature (Phase 2)

Toutes : validées côté serveur, rate-limitées, loggées, testées (`./tests/run.sh`), 0 boucle client au repos.
Réglages dans `shared/config.lua` de chaque ressource ([CONFIG]).

## gs_wanted — recherche intelligente
Un crime n'existe pour la police **que s'il est signalé**.
- **Chance de signalement** = base du crime + 12 %/témoin (PNJ vivants et joueurs dans 40 m),
  × heure (nuit ×0,6), × météo (brouillard ×0,6, orage ×0,7), × blackout ×0,6, × silencieux ×0,3,
  × notoriété (un visage connu se fait reconnaître). Un policier en service à 60 m = signalement certain.
- **Précision** : zone floue de ±250 m (aucun témoin, nuit) à ±20 m (foule, plein jour), plaque partielle
  (`GSO****`), délai d'appel de 40 s à 5 s.
- **Chaleur** (0-100) : étoiles néon affichées au suspect seulement quand il est signalé ; redescend si on se fait oublier.
- **Police** : alerte + zone sur la carte (90 s), `/dispatch` = 20 derniers signalements avec GPS.
- **Détection** : tirs et car-jacking (client, revérifiés serveur : arme réellement en main, rate-limit),
  explosions (serveur, invisible au client), + `exports.gs_wanted:ReportCrime(src, 'robbery', coords)` pour les futurs scripts.
- Stand de tir = zone sûre. Staff : `/effacerrecherche <id>`.

## gs_economy — économie dynamique
- Chaque achat fait monter le prix (demande), chaque revente le fait baisser (offre) ; retour progressif à l'équilibre.
- Bornes min/max par produit, prix affichés avec tendance ▲ / ▼.
- **Événements** : canicule → eau +60 %, tempête → kits de réparation +50 %…
- **Anti-arbitrage** : revente toujours strictement sous le prix d'achat (testé sur toutes les pressions).
- Supérettes, quincaillerie, ferrailleurs (ferraille, cuivre). Items absents d'ox_inventory désactivés au démarrage.
- API : `GetBuyPrice`, `GetSellPrice`, `RecordBuy`, `RecordSell` pour brancher d'autres commerces. Staff : `/marche`.

## gs_duo — duo criminel lié
- Duo formé avec consentement, persistant, un seul par personnage, 1 h de délai après une rupture.
- **Partenaire visible sur la carte** partout (position envoyée par le serveur, seulement au partenaire).
- **Contrats à deux** (F7 / `/duo`) : récupérer puis livrer une marchandise ; les **deux** doivent être sur chaque
  étape, anti-TP, le vol est signalé via gs_wanted (témoins, heure, météo).
- **Lien** : XP (contrats + temps passé ensemble) → 5 niveaux (Complices → Légendes) : paie +30 %,
  chaleur transmise au complice proche 50 % → 15 %.
- Nom de duo personnalisable (nettoyé).

## gs_social — Vibe, réseau social in-game (app du téléphone F1, ou `/vibe`)
- Pseudo @unique et définitif par personnage, fil en temps réel, likes, mentions (@pseudo → notification).
- Anti-abus : cooldown 30 s par post, 280 caractères, balises retirées, liens et invitations Discord remplacés par `[lien]`.
- Modération : suppression par l'auteur ou le staff (ACE `gs.social.moderate`), bouton « Signaler » → webhook staff.
- **Miroir Discord** : chaque post copié sur un salon public (`gs_webhook_social`) → la vie de la ville visible hors du jeu.
- Confidentialité : les clients ne reçoivent jamais d'identifiant de personnage, seulement le pseudo.
- Interface React + Vite (71 Ko gzip), DA néon ; notifications coupables (🔔).
- Dev de l'UI sans le jeu : `cd gs_social/web && npm install && npm run dev` (données de démo). Après modif : `npm run build` et commiter `web/dist`.

## gs_loadscreen — écran de chargement
Soleil couchant rétro, titre néon, astuces tournantes (FR), touches utiles, vraie progression du chargement. 100 % local, aucune ressource externe.

## gs_heists — braquages
- **Sites** : 4 supérettes (1 policier requis), bijouterie Vangelico (6 vitrines, 3 policiers), Fleeca Legion Square (3 coffres, 4 policiers).
- **Conditions** : arme en main, nombre de policiers en service, cooldown par site, pas de braquage par un policier en service.
- **Signalement** : alarme silencieuse (chance par site, 100 % bijouterie/banque) = police prévenue à coup sûr et précisément ;
  sinon ce sont les témoins / l'heure / la météo (gs_wanted) qui décident.
- **Butin** calculé serveur, en argent sale (`black_money`) : × nuit (22h-5h), × événement météo, × lien de duo (partenaire à < 25 m),
  × quartier tenu par ton gang (+ influence gagnée). Durée d'action vérifiée serveur (impossible de sauter la barre).
- Staff : `/braquages` (état, cooldowns).

## gs_drugs — drogue (cannabis, cocaïne, extensible)
- **Boucle** : récolte au champ (Grapeseed) → préparation (Sandy Shores, 3 feuilles → 1 sachet) → vente aux passants (ox_target « Proposer quelque chose »).
- **Vente** : 1 fois par PNJ (state bag serveur), prix calculé serveur :
  × nuit, × quartier (ton gang +20 %, rival −15 %), × **saturation** (−4 % par vente récente dans le quartier, plancher 55 %, se remet en 1 h).
- **Risque** : refus 25 % (+15 % sous la pluie), refus systématique si un policier est à < 60 m ; un refus comme une vente peut être signalé (gs_wanted).
- Gangs : chaque vente donne de l'influence dans le quartier.
- **Items à déclarer** dans `ox_inventory/data/items.lua` (sinon la drogue est désactivée proprement au démarrage) :
  ```lua
  ['weed_leaf'] = { label = 'Feuille de cannabis', weight = 50, stack = true },
  ['weed_bag']  = { label = 'Sachet de cannabis', weight = 20, stack = true },
  -- ['black_money'] existe déjà dans ox_inventory (argent sale)
  ```

## gs_quests — progression et quêtes de départ (V2, F3 / `/progression` depuis la V5)
- **XP et niveaux** (1 → 50) : quêtes, missions de métier, braquages, ventes de drogue. Chaque niveau rapporte un bonus en banque.
  Les annonces plein écran (« NIVEAU 4 », « MISSION RÉUSSIE ») sont faites façon anciens GTA.
- **Personnages récurrents** repérables au **losange vert** au-dessus de la tête (façon Sims) : Max le Guide (mairie),
  Big Sal (chaîne **homme**), Mama Rosa (chaîne **femme**), Lenny, Kiki Starlight, DJ Nova, le Contact du port,
  et **la Voix** (cabine téléphonique, dès le niveau 3).
- Types d'étapes : aller à, conduire (chrono), livrer, ramasser, parler. Tout est vérifié par le serveur ; le véhicule
  et les items prêtés sont repris à la fin, à l'abandon ou à la déconnexion.
- **20 paquets cachés** sur la carte : +50 XP chacun, et 2 500 XP + 5 000 $ quand on les a tous.
- Autres ressources : `exports.gs_quests:Reward(src, 'job_mission' | 'drug_sale' | 'heist')` ou `AddXP(src, n, raison)`.

### Défis du jour, série de connexions, titres, badges (V2.1)
- **3 défis par jour** tirés au sort par personnage (mission de métier, quête, paquet caché, location, 3 achats,
  revente, 30 min en ville, ventes discrètes, butin) : 150 XP chacun, et +300 XP + 500 $ quand les 3 sont faits.
- **Série de connexions** : 50 XP × jours d'affilée (7 max), 1 000 $ et le badge « Fidèle » tous les 7 jours.
- **Titres** selon le niveau (Nouveau venu → Mythe), affichés sur **Néon** à côté du pseudo et dans la fiche du **panel staff**.
- **Badges** : Premier contrat, Ami de la famille, Le cercle de Rosa, Au bout du fil, Collectionneur, Fidèle, Assidu.

## gs_services — secours IA (V2.1)
Aucun EMS joueur en service → à terre, **[G] Appeler les secours** : un secouriste PNJ arrive, fait un massage
cardiaque et te relève (300 $, banque puis liquide ; gratuit si tu n'as rien). Dès qu'un EMS joueur prend son
service, le secours IA s'efface. Réglages Qbox posés par METTRE-A-JOUR : à terre 90 s, réapparition après 70 s,
hôpital 500 $, inventaire conservé.

## gs_wanted — police IA (V2.1)
Moins de `Config.NpcPolice.minCops` policiers joueurs en service → un crime signalé déclenche la police du jeu
(1 à 4 étoiles selon la gravité). La ville n'est jamais sans police ; les vrais policiers reprennent la main dès qu'ils sont en service.

## gs_economy — commerces (V2.1)
12 supérettes, 6 cavistes, 2 quincailleries aux vrais comptoirs du jeu (blip + cercle au sol) : boissons, snacks,
alcool (effet d'ivresse), cigarettes (briquet requis), téléphone, bandages, jerricans… Les magasins ox_inventory
par défaut (vides) sont retirés par METTRE-A-JOUR.

## gs_rental — location de véhicules (V2)
- 5 comptoirs (mairie, Legion Square, Del Perro, Sandy Shores, Paleto) signalés par un blip et un cercle au sol.
- BMX 15 $, vélo 20 $, scooter 45 $, mini citadine 90 $, petite décapotable 140 $ : 30 à 60 min, une location à la fois.
  Le véhicule est rendu à n'importe quel comptoir et récupéré à l'échéance (avec un délai de grâce si le joueur est encore dedans).

## gs_markers — marqueurs unifiés (V2)
Un seul fil pour tous les cercles au sol et icônes (location, quêtes, entrées, commerces, métiers) : 0 coût loin des points.
`exports.gs_markers:Add(id, { coords, style = 'rental' | 'quest' | 'entry' | 'shop' | 'job' | 'objective', label })`.

## gs_drugs (V2) — vente directe et mode deal
- Viser un passant (ox_target) → **Proposer quelque chose**. Si tu as plusieurs produits, tu choisis lequel.
  L'échange est animé (main à main).
- **`/deal`** : reste à un coin de rue, des passants viennent à toi toutes les 20 à 40 s. Le mode se coupe si tu montes en véhicule.

## gs_police — interventions (V3, F4, en service)
- **Police** : menotter (menottes requises), escorter, mettre / sortir du véhicule, fouiller (menotté, à terre ou mains en l'air),
  casier judiciaire (lecture / ajout), prison RP (grade ≥ 1, 1-60 min, persistante, évasion ramenée), fourrière,
  cônes / barrières / **herse** (crève les pneus), **radar de vitesse** (`/radar`, en véhicule).
- **EMS** : réanimer (trousse), soigner (bandage), porter le patient, le mettre dans l'ambulance.

## gs_details — petits détails (V3)
Radial véhicule (**Z** en véhicule : moteur, portes, places, vitres, ceinture), `/me` `/do` (texte au-dessus de la tête,
visible à 20 m), **mains en l'air** (X), **ceinture** (B, éjection en cas de choc sans ceinture), kits utilisables par tous :
réparation de fortune (moteur 75 %), réparation avancée (complète), nettoyage.

## gs_gangs — gangs vivants (V3)
- **Tags** : bombe de peinture (quincaillerie), 15 tags max par gang, 25 m entre deux tags, +influence de quartier ;
  n'importe qui peut effacer un tag ([G]), le gang est prévenu.
- **Garage du gang** au QG : véhicules aux couleurs du gang, un par membre.
- **Receleur** (grade ≥ 1, la nuit, lieu qui change toutes les heures) : vente en gros (10 à 50 pochons), prix ×1,35, argent sale.
- **Labos** (gs_interiors) : intérieurs cachés du jeu derrière une porte réservée au gang ; préparation ×2.

## V3.2 — finitions (casino, plantations, récolte, logement, Vibe)
- **gs_casino** : porte publique du **Casino Diamond** (gs_interiors, blip), **roue de la fortune** au casino (1 tour gratuit / jour / perso :
  argent, XP, tickets, kits ; tirage serveur, comptée avant paiement), **tickets à gratter** (supérettes 100 $, +1 offert quand les 3 défis
  du jour sont faits ; 10 / jour max, gain moyen ≈ 70 $ : pas une machine à cash).
- **Plantations de cannabis (gs_drugs)** : graine (vendeur louche près de Grapeseed, ou trouvée au champ / sur les plants) + pot (quincaillerie)
  → on plante **dehors, où on veut**. 3 stades visibles de tous, arrosage (bouteille d'eau), engrais (×1,5), meurt sans eau.
  Mûr : **n'importe qui peut récolter** (vol signalé à la police) ; le propriétaire arrache, la **police saisit** (+150 $).
  Ensuite : transformation (Sandy ou labo de gang ×2) et vente, comme avant. 6 plants max / perso, survivent au redémarrage.
- **Labos / club-house** : le marqueur n'apparaît plus qu'aux membres autorisés (fini la « ferme de cannabis » au milieu de Grove).
- **gs_harvest** (libre, sans embauche) : **pêche** (pontons), **mine** (carrière), **bûcheron** (Paleto), **ferme** (Grapeseed),
  **chasse** (animaux créés par le serveur, dépeçage au couteau). Outils en quincaillerie, casse 3 %, acheteurs dédiés, défi du jour « récolte ».
- **Nouveaux métiers gs_jobs** : **routier** (entrepôts, au km), **chauffeur de bus** (5 arrêts), **agent immobilier Dynasty 8** (whitelist).
- **Logement : qbx_properties** (recipe Qbox, audité) : choix d'un **appartement de départ** au 1er perso, **achat / location** de biens créés
  par les agents immobiliers (`/createproperty` : prix, loyer, intérieur, garage), coffre, garde-robe, déco.
- **Vendeurs PNJ** : armurier derrière chaque comptoir Ammu-Nation, vendeur aux boutiques de vêtements / coiffeur / tatoueur (illenium, ox_target).
- **Vibe** (ex-Néon) : le réseau social est une **app du téléphone** (F1), en temps réel. `/vibe` garde la version grand écran.
- **Correctifs** : retour humain après un animal (menu staff), F5 n'ouvre plus la progression (ancienne commande supprimée).

## V3.4 — Roadtrip, permis, Cayo Perico, densité
- **Nom** : ROADTRIP, sous-titre « new generation » (écran de chargement, liste des serveurs).
- **Permis** : port d'arme obligatoire pour les armes de poing d'Ammu-Nation (déjà en place) ; **permis de chasse** (750 $ au pavillon
  de chasse de Paleto) obligatoire pour le fusil ; dépecer sans permis = **braconnage** signalé. La police (grade ≥ 2) délivre / retire
  les deux permis depuis le contrôle d'identité (F4).
- **Cayo Perico** (gs_world) : l'île du jeu se charge seulement à moins de 2,2 km (zéro coût en ville). Vols réguliers LSIA ↔ île (350 $).
- **Moins de PNJ** : piétons 60 %, circulation 65 %, voitures garées 75 % (réglable dans gs_world/shared/config.lua).

## V3.5 — Vibe 2, petits boulots, filtre Vice
- **Vibe 2** : profils publics (clic sur un pseudo), **abonnements** (notif à la personne suivie), badge **vérifié** posé par la
  modération (ACE gs.social.moderate), badge **influenceur** dès 25 abonnés, onglet **Top semaine** (posts, créateurs les plus aimés
  sur 7 jours, plus suivis ; cache 60 s). Aucun citizenid n'est envoyé aux clients.
- **App Boulots** (gs_gigs) : 3 offres tirées par le serveur, renouvelées toutes les 5 min. **Livraison express** (légal, liquide)
  ou **Passeur** (illégal, argent sale, 35 % de chance d'être signalé au chargement). GPS vers A puis B, [E] sur place, temps de trajet
  crédible exigé, 15 min max, 1 min entre deux boulots.
- **Filtre Vice** : réglage du téléphone, couleurs saturées + léger vignettage (mémorisé par joueur).

## V3.6 — banque et base de données police
- **gs_bank** : distributeurs (ox_target sur les props du jeu, partout) et guichets Fleeca / Pacific / Blaine (marqueur [E], blip).
  Menu : solde, retrait, dépôt, historique. Plafonds : distributeur 5 000 $ / opération et 15 000 $ / jour, guichet 100 000 $ / 250 000 $.
  Virements entre joueurs : app Banque du téléphone.
- **Dossiers LSPD** (F4 → Dossiers) : recherche d'un citoyen par nom (même hors ligne), casier, **mandats** (grade ≥ 1 pour délivrer,
  ≥ 2 pour clore, 5 actifs max par agent), **rapports** (tous les agents lisent, l'auteur ou un gradé ≥ 3 supprime).
  Le contrôle d'identité affiche « mandat actif ». Amendes : facture (gs_jobs), déjà en place.

## V3.7 — courses de rue classées, guerres de territoire
- **gs_races** : 3 circuits (points à caler en jeu). **Chrono solo** ou **course à mise** (500 $ liquide, 45 s pour rejoindre, ≥ 2 pilotes ;
  cagnotte − 10 %, répartie 70/30 à 2, 60/30/10 à 3+). Le serveur chronomètre et valide chaque point (ordre, position, vitesse crédible,
  au volant). Mise remboursée si moins de 2 pilotes ou pilote hors ligne. Une course à plusieurs peut être signalée à la police.
  **Classement par circuit** dans Vibe → Top semaine → « Courses de rue ».
- **Guerres de territoire** (gs_gangs, menu F9 → Guerres) : un cadre déclare la guerre au gang qui tient un quartier (5 000 $ de la caisse,
  2 membres en ligne min., 1 en face). Préavis 10 min (police prévenue), puis 20 min : chaque adversaire mis à terre dans le quartier
  rapporte 3 points (détection serveur : coup d'arme + état « à terre »). Écart ≥ 3 : l'attaquant prend le quartier, sinon le défenseur le garde.
  Repos : 6 h pour l'attaquant, 1 h pour le défenseur.

## V3.8 — gros coups en duo, police plus maligne, assurance auto
- **Gros coup en duo** (gs_heists, Fleeca Legion : marqueur au site, partenaire de duo F7 obligatoire, 4 policiers min.) :
  **Pirate** (pirate le terminal 20 s : coupe l'alarme, 15 % d'échec bruyant, aveugle les caméras 10 min) → **Conducteur** (vide 2 coffres, 15 s chacun)
  → **Fuite** (conducteur au volant à 900 m du site, pirate à moins de 80 m, 4 min). Butin 9–14 k$ en argent sale, 50/50. Échec si l'un est à terre / parti.
- **Police IA plus maligne** : **caméras de surveillance** (10 points de la ville) : crime filmé = signalement quasi certain, zone précise, plaque
  lisible, caméra nommée dans le dispatch. Après avoir semé les policiers du jeu, ils **fouillent la dernière zone connue** 2 min :
  y rester ou y retourner relance la recherche (cercle jaune sur la carte).
- **Assurance auto** (gs_insurance, Mors Mutual) : 4 % du prix du véhicule pour 7 jours (28 max d'avance) ; un véhicule assuré ne paie que
  **25 %** de la fourrière (patch de qbx_garages posé par METTRE-A-JOUR).

## V3.9 — événements, loto, personnalisation
- **gs_events** : événements saisonniers du calendrier (été +10 % XP, Halloween et fêtes +25 % XP et +1 tour de roue, anniversaire du serveur +50 %)
  et événements staff `/gsevent start double_xp|lucky <minutes>` (ACE gs.events.manage), `/gsevent stop|status`. Annonce à la connexion.
- **Loto hebdomadaire** (gs_casino, caisse du casino) : 100 $ le ticket (10 max / semaine), tirage le dimanche à 20 h (heure du serveur,
  rattrapé si le serveur était éteint), 3 gagnants distincts (60 / 25 / 15 % de la cagnotte = report + 80 % des ventes), report sous 3 tickets.
  Gains en banque, ou à la prochaine connexion si le gagnant est hors ligne.
- **Personnalisation** (gs_tuning, LS Customs) : **néons** (9 couleurs, 800 $, écrits dans les modifications du véhicule : persistent) et
  **plaque personnalisée** (2 500 $, 2–8 caractères A-Z 0-9 / espaces, préfixes réservés et mots interdits refusés, unique).
  Uniquement sur ses propres véhicules, au volant, dans un salon. Cosmétique : aucun effet sur les performances.

## V4 — ouverture, vie de la ville, signatures Roadtrip
**Arrivée des joueurs** : règlement à accepter à la 1re connexion (versionné, relu après chaque changement, `/regles`),
liste blanche (`gs_whitelist "true"`, `/whitelist add <id | license>` par les modos, lien Discord aux refusés),
quête guidée **« Ton premier jour »** (mairie, banque, Pôle Emploi, auto-école, location) proposée automatiquement.

**Services publics et métiers** :
- **Auto-école** (gs_driving) : un nouveau personnage n'a plus le permis. Code (QCM tiré et corrigé par le serveur, 8/10),
  puis examen de conduite (parcours, 80 km/h, dégâts relevés sur le véhicule par le serveur, 3 fautes max). Métier **moniteur**
  (`/moniteur`). Les anciens personnages qui ont déjà un véhicule gardent leur permis.
- **Justice** (gs_justice, `/tribunal`) : juge (ouvre une affaire, prévenu présent, avocat), verdicts appliqués (amende facturée,
  prison, casier, mandats clos), avocat qui consulte le casier **avec l'accord** de son client.
- **Presse** : journalistes Weazel News, badge presse sur Vibe, **flash info** envoyé à toute la ville.
- **Mairie** (gs_civil) : mariage (accord + frais, célébré par un agent de la mairie en service), divorce, conjoint au contrôle.
- **Commerces tenus par des joueurs** (gs_business) : bar Le Néon, Horny's Burgers. Préparation à partir de la réserve
  (ingrédients du jeu : alcools, viande de chasse, légumes de la ferme), caisse client, prix fixés par le patron,
  libre-service +20 % sans employé, comptabilité.
- **Santé** : pharmacies (antidouleurs), psychologue (métier) ; blessures par zone / saignements : qbx_medical.
- Nouveaux métiers gs_jobs : moniteur, avocat, juge, Weazel News, bar, restaurant, mairie, psychologue.

**Staff** : `/economie` (argent créé / détruit par source, masse monétaire, inflation 7 j, indice des prix, top fortunes,
rapport quotidien Discord et alerte si création anormale) ; budget de performance vérifié à chaque test (docs/PERFORMANCE.md).
Traductions françaises manquantes des scripts Qbox ajoutées par METTRE-A-JOUR (server/locales-fr).

**Signatures** :
1. **Carnets de route** (`/carnet`) : 3 itinéraires panoramiques, anecdotes, spots photo, bonus duo, titres, classement.
2. **Saisons** (`/saison`) : 8 semaines, pass gratuit + premium **cosmétique** (paquet Tebex `season_pass`), classement, palmarès.
3. **Vibe influence la ville** : #rassemblement (point de rendez-vous + XP), #promo (commerces −15 %), #course (courses sans mise).
4. **Photos et stories** : appareil photo du téléphone, stories 24 h, bonus heure dorée (docs/PHOTOS.md).
5. **Réputation** (`/reputation`) : rue / légale / média → remise fidélité, meilleurs prix « discrets », vendeurs qui te saluent.
6. **Contrats dynamiques** : l'app Boulots suit la météo, la nuit, les événements et les quartiers sous tension.
7. **Bodycam et preuves vidéo** : capture jointe aux rapports police, crimes filmés par les caméras consultables.
8. **Bourse de la ville** : onglet de Vibe avec les indices (prix, carburant, métaux, immobilier, richesse) et leur évolution.

## V5 — touches sans doublon, staff à 5 rangs, radio, métiers plus profonds
- **Départ en ville** : plus d'appartement gratuit à la création (réglage qbx_core `startingApartment = false` posé par
  METTRE-A-JOUR). Le nouveau perso apparaît devant la mairie, guidé vers Max (« Ton premier jour »). Les logements
  s'achètent / se louent auprès de l'agent immobilier.
- **Touches** : progression F2 → **F3** (F2 = inventaire), mains en l'air X → **H** (à pied), radio **Verr. Maj**,
  emotes scully sans doublon (X annuler, J pointer, ragdoll coupé). **I** ou `/touches` : aide de toutes les touches.
- **Inventaire** : **double-clic** sur un objet = l'utiliser (en plus d'Alt + clic).
- **Staff** : helper, modo, admin, **super-admin**, fondateur. Seul le fondateur promeut / rétrograde (en jeu, immédiat,
  enregistré). Argent et items : super-admin minimum, motif obligatoire. Raccourcis en mode staff : Ctrl+Y TP marqueur,
  Ctrl+U vol libre, Ctrl+O noms. Section **Fun** : course rapide, super saut, endurance, nage rapide, gravité lunaire,
  visions nocturne et thermique.
- **Décor** (super-admin et fondateur, `/builder`) : placer des objets (poubelles, bancs, lampadaires…) et **retirer
  ceux de la map d'origine** pour tout le monde, réversible.
- **gs_radio** : Z → Radio ou `/radio` : canal de son métier, canal privé de son gang, fréquence libre. On règle une fois,
  on parle en maintenant Verr. Maj. Canaux réservés vérifiés par pma-voice côté serveur. Fréquence reprise à la connexion.
- **Métiers** : salaires réglables par la direction (entreprises privées, 0,5× à 2× la base), **primes** depuis la
  caisse, mécano : pneus, remettre sur ses roues, réparation capot ouvert (animations plus naturelles), « Établi et
  outillage » au lieu d'« Armurerie » (EMS : « Matériel médical »), **double des clés** des véhicules de service.
- **Marqueurs** : plus de cercle violet sur les points de métier (chevron blanc discret), cercles restants plus fins.

## V5.1 — économie illégale, solo annexe, Cayo Perico
- **gs_stickup — braquage solo de PNJ** (annexe ; les gros coups restent en duo / groupe) : vise un passant, un caissier
  ou un guichetier Fleeca avec une arme → [E]. La **peur** monte avec l'arme pointée et **la voix** : chuchoter < parler
  < **crier** (portée ², touche N pour parler). Arme baissée : il s'enfuit. Toujours signalé (gs_wanted) : police
  joueurs, sinon **police IA**. Anti-farm : cooldowns (joueur, caisse), 6 par heure, 5 000 $ par jour. Caisse / guichet
  = argent sale.
- **gs_blackmarket — marché noir** : `/contact` (gang, ou réputation de rue ≥ 15) → planque qui change toutes les 2 h,
  la nuit. Munitions de tous calibres, armes non déclarées (1 par jour, armes lourdes réservées aux gangs), silencieux,
  crochets, gilets. Stock du jour, **prix qui montent avec la rareté**, -10 % sur son territoire, argent sale (ou liquide
  +40 %), signalement possible.
- **Munitions cohérentes** : Ammu-Nation = pistolet, pistolet compact, fusil à pompe, munitions 9 mm / .45 / cartouches,
  **permis obligatoire** pour armes et munitions, **120 munitions et 1 arme à feu par jour**. L'ancien « Black Market »
  absurde d'ox_inventory (1 000 $ la balle) est retiré.
- **Cayo Perico** : accès libre (vol gratuit à LSIA, ou bateau / avion) ; le braquage de l'île a été retiré (V5.2).
- **Clés** : voitures PNJ moins souvent verrouillées (garées 50 %, en circulation 35 %), fouille (H) 65 %.
- **Métiers** : animations de mission (carton porté, sac poubelle, bloc-notes routier), petit geste de fin de service,
  **mécano : livraison de pièces** (tâche payée), **carnet de commandes** : `/depanneur` et `/taxi` pour les joueurs,
  `/commandes` pour les employés en service (prendre → GPS, clôturer → facture).
- **Radio** : canal 11 « Urgences » (police, EMS, mécanos en service), « Qui est sur le canal ? ».
- **Staff — événements en un clic** (F11, admin) : course à super vitesse, chute lunaire, concours de super saut,
  soirée boxe (armes rangées dans la zone), course de rue (inscription gratuite). Annonce + GPS à tous.
- **gs_hideouts — planques de départ** : chambres de motel (Pink Cage, Sandy, Paleto) louées à la semaine (1 à 4),
  coffre perso, garde-robe, monde séparé par locataire. Pour un vrai logement : l'agent immobilier.

## V5.2 — économie de l'ombre, blanchiment, import de mods
- **Blanchiment** (menu Direction des entreprises privées : garage, concession, bar, restaurant, agence…) : argent sale
  → caisse de l'entreprise, -30 %, 30 min de traitement. Plafond = 1,5 × le **chiffre d'affaires légal du jour**
  (factures payées, ventes) : une entreprise qui ne travaille pas ne blanchit pas. **Contrôle fiscal** possible (plus
  risqué quand on blanchit beaucoup par rapport au chiffre) → signalement police.
- **Contrats entre joueurs** (`/contrats`, gang ou réputation de rue) : vol, braquage, livraison, vente, élimination
  (scène RP obligatoire). Récompense en argent sale **bloquée** à la publication, versée à la validation, commission 5 %.
- **Munitions artisanales** : nouvelle activité **Ferrailleur** (casses de La Mesa, Sandy, Rogers) → ferraille + cuivre
  → atelier de la planque du gang (F9) : 9 mm, .45, cartouches, 5,56 (grade 2). 600 munitions par gang et par jour.
  Échelle des prix : artisanal (récolte) < Ammu-Nation (permis, plafond) < marché noir (rare, cher).
- **Motels** un peu plus chers (450 / 300 / 320 $ la semaine) : pousse vers l'agent immobilier.
- **IMPORTER-MODS.bat** : tri et installation automatiques des mods téléchargés (docs/IMPORTER_MODS.md).

## V5.4 — Cayo vivant, vols animés, import de mods automatique
- **Vol LSIA ↔ Cayo** : petit film (avion au-dessus de l'océan, [Espace] = transfert rapide), gratuit.
- **Soirée DJ plage de Cayo** (F11 → Événements en un clic) : sono, lumières, danseurs, musique de l'île, 1 h.
- **Location de bateaux** : marina de LS et jetée de Cayo (jet-ski, semi-rigide, hors-bord).
- **Staff** : « Noms et ID » jusqu'à 150 m avec PV et indicateur « parle » (rouge), activé automatiquement en spectate.
- **IMPORTER-MODS** : ouvre les dlc.rpf (mods solo), préfère les dossiers FiveM, détecte les packs chiffrés, ajoute
  les véhicules au catalogue Qbox (concession) avec prix.

## V6 — flotte des gangs, Weazel automatique, import chaîné, guides PDF
- **Flotte du gang** (F9, chef) : jusqu'à 4 modèles choisis dans une liste (lowriders, muscle, motos, utilitaires) +
  **1 véhicule personnalisé** (modèle + 2 couleurs), au garage du gang.
- **Weazel News automatique** : brèves dans Vibe (@WeazelNews) pour les braquages, gros coups, courses, loto et
  événements staff ; jamais de nom de suspect ; anti-spam.
- **METTRE-A-JOUR** lance aussi l'import des mods posés dans `C:\GTASOON\mods-a-trier`.
- **IMPORTER-MODS** : un mod avec un fichier > 16 Mo n'est plus installé (à optimiser d'abord).
- Derniers cercles violets / roses (missions de métier, duo) remplacés par un cercle bleu discret.
- **PDF** (`docs/pdf`, régénérés par `tools/points.lua` + `tools/pdf.py`) : guide complet, fiche de tests, carte des
  points (419 points + maps importées).

## Liens entre features
`gs_weather` → visibilité de `gs_wanted` + prix de `gs_economy` ;
`gs_duo` → crimes vers `gs_wanted`, chaleur partagée ; `gs_jobs` → police en service pour le dispatch.
`gs_heists` / `gs_drugs` → `gs_wanted` (signalements), `gs_weather` (nuit, météo), `gs_duo` (bonus), `gs_gangs` (territoires, influence).

## Impact / risques / rollback
- Tables : `gs_economy`, `gs_duos` (créées au démarrage). gs_wanted : mémoire uniquement.
- Risques : coords et noms d'items à caler en jeu ; équilibrage des prix/chances à ajuster après la bêta.
- Rollback : retirer l'`ensure` concerné (gs_duo dépend de gs_wanted : les retirer dans l'ordre inverse).
