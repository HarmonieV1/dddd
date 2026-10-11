# MLO, coquilles et mapping — ce qu'on installe, ce qu'on refuse, comment

Comment on ajoute des bâtiments entrables à RoadLine sans alourdir le téléchargement des joueurs, sans risquer
un retrait par Cfx.re et sans payer ce qu'on peut avoir gratuitement.

Documents liés : `docs/BOB74_IPL.md` (l'audit des intérieurs gratuits déjà chargés),
`docs/IMPORTER_MODS.md` (le fonctionnement de `IMPORTER-MODS.bat`),
`docs/BOUTIQUE_LEGAL.md` et `docs/VEHICULES_ADDON.md` (la règle « pas de marques réelles »).

---

## 1. L'ordre dans lequel il faut chercher

Toujours dans cet ordre. On ne descend d'un cran que si le cran du dessus ne peut pas faire le travail.

| Rang | Solution | Poids joueur | Prix | Quand |
|---|---|---|---|---|
| **1** | **`bob74_ipl`** — un intérieur du jeu déjà chargé | **0 Mo** | 0 € | presque toujours : ~85 intérieurs libres, voir `docs/BOB74_IPL.md` |
| **2** | **Coquille** (*shell*) — un intérieur réutilisé derrière N façades | **0 Mo** (si l'intérieur vient du jeu) | 0 € | logements, ateliers, clubs, commerces : tout ce qui se répète |
| **3** | **MLO gratuit** sous licence claire | 10-60 Mo | 0 € | un lieu précis qui n'existe pas dans le jeu |
| **4** | **MLO payant** | 30-120 Mo | 25-45 € | **seulement** si le RP le justifie vraiment : commissariat, hôpital, tribunal, ring |

Le rang 2 est celui qu'on sous-exploite. `gs_hideouts` le fait déjà : un appartement du jeu, un
`routing bucket` par locataire (`Config.BucketBase = 5000`), trois motels différents à l'écran, **0 Mo** de
téléchargement. La même mécanique vaut pour les ateliers, les clubs, les bureaux.

**Règle de décision** : si le joueur passe moins de 5 minutes par semaine dans un lieu, il ne mérite pas un MLO
payant. Il mérite une coquille, ou rien.

---

## 2. Les 5 contrôles avant d'installer quoi que ce soit

Un MLO qui rate un seul de ces contrôles ne rentre pas. `IMPORTER-MODS.bat` en automatise une partie, mais le
contrôle de licence et de marque se fait à l'œil avant le téléchargement.

### Contrôle 1 — Poids

| Mesure | Seuil | Pourquoi |
|---|---|---|
| Taille du mod | **≤ 60 Mo** idéalement, 150 Mo refusé par l'importeur | chaque Mo est téléchargé par **chaque** joueur à sa première connexion |
| Une texture `.ytd` | **≤ 16 Mo** | au-delà : textures qui disparaissent, « Streamer crashed » |
| Total des maps | **≤ 500 Mo** pour tout le serveur | au-delà, les premières connexions deviennent décourageantes |

`IMPORTER-MODS.bat` refuse au-delà de 150 Mo, signale les `.ytd` > 16 Mo, et passe les `.ytd` > 48 Mo dans
l'optimiseur de textures (`tools/textures`, retrait des mipmaps, jamais sous 256-512 px).

### Contrôle 2 — Licence

| Signe | Verdict |
|---|---|
| Licence explicite (MIT, CC, ou « free to use on your server ») | ✅ |
| Acheté sur la boutique **officielle du créateur** (Tebex du créateur, Cfx.re asset store), facture au nom du serveur | ✅ |
| « Open source » annoncé mais sans fichier de licence | ⚠️ demander au créateur, sinon refuser |
| Pas de licence, pas d'auteur identifiable | ❌ |
| Trouvé sur un site de fuites (voir § 5) | ❌ **jamais**, même « pour tester » |

### Contrôle 3 — Marques réelles

Refus automatique par l'importeur (liste `$BrandBlock` dans `importer-mods.ps1`). Un MLO « Starbucks », un
commissariat « LAPD » avec les vrais écussons, une boutique « Gucci » : **retrait du serveur possible par
Cfx.re / Rockstar et demandes DMCA**. On cherche les équivalents fictifs du jeu (Bean Machine, LSPD, Ponsonbys).

Attention : les marques **fictives** de GTA (Maze Bank, Bahama Mamas, Vanilla Unicorn, Pegassi, Grotti) sont
sans problème — ce sont des créations Rockstar présentes dans le jeu.

### Contrôle 4 — Chiffrement (escrow)

Deux cas très différents, à ne pas confondre :

| Cas | Verdict |
|---|---|
| **Map** protégée par l'**escrow officiel Cfx** (fichier `.fxap`), achetée sur la boutique **officielle** du créateur | ✅ normal : Gabz, UncleJust et la plupart des créateurs payants protègent leurs maps ainsi. **Condition** : l'acheter avec le compte Cfx.re lié à la clé de licence du serveur, sinon elle ne se charge pas |
| **Script** chiffré (Lua illisible, escrow ou obfusqué) | ❌ on ne peut ni le relire, ni le corriger, ni savoir ce qu'il envoie |

`IMPORTER-MODS.bat` applique cette règle depuis la V12.5 : une map escrow est installée avec un avertissement dans
le rapport, un script chiffré part dans `rejetes`. (Avant, toute map escrow était refusée à tort.)

### Contrôle 5 — Performance, en jeu

Après installation, dans le lieu, `resmon` ouvert :

| Mesure | Seuil |
|---|---|
| CPU de la ressource, à l'intérieur | **< 0,10 ms** (une map ne calcule rien, elle est streamée) |
| FPS à l'intérieur vs dehors | perte **< 15 %** |
| Console | **0 erreur**, 0 « failed to load » |
| Collisions | pas de mur traversable, pas de sol manquant |

Un MLO qui coûte des FPS est un MLO mal fait : il y en a toujours un autre. Et il faut vider le cache
(`VIDER-CACHE-FIVEM.bat`) avant de conclure qu'un MLO est cassé.

---

## 3. Installer un MLO — la procédure

1. Poser le `.zip` (ou `.rar`, `.7z`) **tel quel** dans `C:\GTASOON\mods-a-trier`.
2. Double-clic sur **`IMPORTER-MODS.bat`**.
3. Le script décompresse (même imbriqué), reconnaît une map, applique les contrôles 1, 3, 4, et l'installe
   dans `resources\[addons]\gsa_<nom>` + une ligne dans `cfg\addons.cfg`.
4. `RAPPORT-MODS.txt` s'ouvre à la fin. **Copie-le-moi** : je branche les coordonnées, les blips, les portes
   et les points d'interaction dans les ressources `gs_*`.
5. `VIDER-CACHE-FIVEM.bat`, puis test en jeu avec `resmon` (contrôle 5).

Pour couper un mod sans le supprimer : mettre un `#` devant sa ligne dans `cfg\addons.cfg`.
`METTRE-A-JOUR.bat` n'écrase jamais `[addons]` ni `addons.cfg`.

### Ce qui ne s'installe pas tout seul

- **Un MLO qui remplace un bâtiment existant** a parfois besoin qu'on désactive l'IPL d'origine
  (`EnableIpl(..., false)`). À me signaler : ça se fait en 2 lignes dans une petite ressource.
- **Un MLO avec des PNJ, des portes à serrure ou des coffres** : les PNJ et les points viennent de nos
  ressources (`gs_markers`, `gs_places`, `ox_doorlock`), jamais du pack.
- **Un MLO « pour ESX »** : les fichiers de map sont réutilisables, les scripts livrés avec ne le sont pas.
  L'importeur met les scripts dans `scripts-a-verifier`.

---

## 4. Où chercher — sources acceptables

| Source | Type | Remarque |
|---|---|---|
| **`bob74_ipl`** (GitHub, MIT) | gratuit | déjà installé. **Commence toujours par là** : voir `docs/BOB74_IPL.md` |
| **forum.cfx.re**, catégorie *Releases → Maps* | gratuit | la source de référence. Licence annoncée par l'auteur dans le fil, auteur joignable |
| **GitHub**, avec un fichier `LICENSE` | gratuit | parfait pour les coquilles et les petits intérieurs |
| **Cfx.re asset store** (store officiel dans le portail Cfx) | payant | facturé proprement, licence serveur claire |
| **Tebex du créateur** (sa boutique officielle, lien depuis son fil forum ou son site) | payant | la seule façon correcte d'acheter. Vérifie que le lien vient **du créateur**, pas d'un tiers |

**Avant d'acheter**, trois questions : (1) est-ce que `bob74_ipl` a déjà un intérieur qui fait le travail ?
(2) est-ce que ce lieu sert au moins une heure par semaine à plusieurs joueurs ? (3) le poids annoncé tient-il
sous 60 Mo ? Trois « oui » (ou un « non » à la première) et c'est un achat raisonnable.

Les prix et la disponibilité bougent tout le temps : je ne les recopie pas ici pour ne pas te donner un chiffre
faux. Demande-moi au moment de l'achat, je vérifie la boutique officielle du créateur.

---

## 5. Sites à ne jamais utiliser

Les sites de **fuites** (« leaks ») et les **revendeurs non autorisés** redistribuent le travail de créateurs
sans licence, souvent avec du code ajouté. Les utiliser expose à :

- le **retrait du serveur de la liste Cfx.re** (perte totale de visibilité, c'est la sanction la plus courante) ;
- une **réclamation DMCA** du créateur, qui a votre nom de serveur dans ses logs ;
- du **code ajouté** dans le pack (backdoor), impossible à repérer si c'est chiffré.

Signes qu'un site est un revendeur non autorisé :

- il vend le travail de **plusieurs** créateurs connus, bien moins cher que leurs boutiques officielles
  (typiquement 10-15 $ ce qui coûte 30-45 € chez l'auteur) ;
- il propose des packs « tout-en-un » de dizaines de MLO ;
- aucun moyen de contacter un auteur, pas de licence, paiement par moyens détournés ;
- les mots « leak », « free download » associés à des ressources normalement payantes.

**Règle simple** : si le prix ou la gratuité semble trop beau pour le travail fourni, c'est volé. Le créateur
a presque toujours un fil sur forum.cfx.re avec le lien de **sa** boutique. C'est celui-là qu'on suit.

---

## 6. Ce que RoadLine a déjà, et ce qui manque vraiment

Fait au 11/10/2026.

| Lieu | État |
|---|---|
| Commissariat de Mission Row | intérieur du jeu, utilisé (`gs_police`) |
| Hôpital Pillbox | intérieur du jeu (`307.17, -590.81, 43.28`), chargé par `bob74_ipl`, **libre** |
| Casino Diamond | porte `gs_interiors`, utilisé (`gs_casino`) |
| Club-house Lost MC + 4 labos de gang | portes `gs_interiors`, utilisés |
| Bahama Mamas, Vanilla Unicorn, Tequi-la-la | en place, utilisés (`gs_business`) |
| Motels (3) | coquille + routing bucket, utilisés (`gs_hideouts`) |
| Tribunal | **manque** — candidat n°1 à un MLO payant si le RP justice décolle (`gs_justice` existe) |
| Ring de combat | **manque** — `gs_fightclub` existe ; voir le Freakshop ou le Vinewood Car Club en coquille d'abord |
| Garage mécano jouable | **manque** — 5 ateliers tuner gratuits disponibles en coquille (voir `docs/BOB74_IPL.md` § 3) |
| Logement haut de gamme | **manque** — 8 maisons de Vinewood + 3 villas gratuites, en place, rien à télécharger |

Conclusion de l'audit : **avant d'acheter le moindre MLO, il reste ~85 intérieurs gratuits à brancher.** Les
seuls achats que je recommanderais à terme sont le **tribunal** et éventuellement un **commissariat plus grand** —
et seulement une fois que le serveur tourne et que le RP correspondant existe vraiment.

---

## 7. Sélection V12.5 — 20 gratuits + 10 payants, choisis pour RoadLine

Recherche du 11/10/2026, **uniquement sur le forum officiel Cfx.re, GitHub et les boutiques officielles des
créateurs** (aucun revendeur ni site de fuites). Chaque lieu est relié à un système RoadLine qui existe déjà : on ne
télécharge pas un décor, on donne un lieu à du RP qui n'en a pas.

**Avant de télécharger, sur chaque page** : vérifie que la release est toujours en ligne, la date de dernière mise à
jour, le build minimum demandé, et (pour les « gratuits via Tebex ») que le panier est bien à 0 €. Certains fils ont
2 à 5 ans : ils peuvent ne plus se charger proprement sur un build récent.

**Budget poids** : l'ensemble dépasserait largement les 500 Mo conseillés (§ 2). Installe d'abord les ★, teste en jeu
(`resmon`), puis ajoute. Les doublons (deux laveries, deux salles de combat) sont là pour te laisser **choisir** un des
deux, pas pour installer les deux.

### Gratuits (20)

| # | Lieu | Branché sur | Pourquoi | Lien |
|---|---|---|---|---|
| 1 ★ | **Fight Club** (souterrain, 3 pièces) | `gs_fightclub` | les combats clandestins existent sans vrai lieu | [forum](https://forum.cfx.re/t/free-mlo-fight-club/5402796) — gratuit via Tebex |
| 2 | **Fight club souterrain de Sandy Shores** (1 pièce, sans dépendance) | `gs_fightclub` (nord) | variante légère, au nord, pour le road trip | [forum](https://forum.cfx.re/t/mlo-sandy-shores-underground-fight-club/5371265) |
| 3 ★ | **QG de gangs : Grove, Ballas, Vagos** (pack) | `gs_gangs` | trois QG d'un coup, cohérents avec nos gangs | [forum](https://forum.cfx.re/t/free-mlo-three-gang-war-mlo-bundle-grove-ballas-vagos-i-zerodazed/5369478) |
| 4 ★ | **Armurier clandestin** (Secret Weapondealer) | `gs_blackmarket` | le marché noir a enfin une arrière-boutique | [forum](https://forum.cfx.re/t/free-mlo-secret-weapondealer/5177991) |
| 5 | **Prêteur sur gages, Eclipse Boulevard** (salle, bureau, coffre au sous-sol) | recel / `gs_market` | revendre le butin à quelqu'un, pas à un menu | [forum](https://forum.cfx.re/t/40-free-pawn-shop-los-santos-mlo/5366787) — titre ambigu (« 40% »), vérifier la gratuité |
| 6 | **Prêteur sur gages de Sandy Shores** | recel (nord) | même rôle, côté Blaine County | [forum](https://forum.cfx.re/t/free-mlo-sandy-pawnshop/5296578) |
| 7 ★ | **Laverie ONE Laundromat** (près de Grove) | blanchiment (`gs_business`) | le cliché parfait du blanchiment, au cœur des gangs | [forum](https://forum.cfx.re/t/map-free-one-laundromat-free-mlo/5391980) |
| 8 | **Bureau de poste PostOps** (19,9 Mo) | `gs_gigs` (livreur) | un vrai dépôt pour les tournées de livraison | [forum](https://forum.cfx.re/t/free-mlo-postops/5348302) |
| 9 ★ | **Magasin d'alcool de Paleto Bay** | `gs_roadbook`, braquage de supérette | une étape de road trip, et une cible au bout du monde | [forum](https://forum.cfx.re/t/free-mlo-paleto-bay-liquor-store/5412728) |
| 10 ★ | **Atelier FIX IT** (ancien MLO payant, offert) | mécano (`gs_tuning`) | atelier jouable ; complète les 5 ateliers tuner bob74 | [forum](https://forum.cfx.re/t/free-mlo-fix-it-workshop/5423357) |
| 11 ★ | **Deer Diner** (Vinewood : bar, coin arcade, cuisine) | « Les habitués », `gs_business` | le diner où la ville se croise ; « sans copyright » selon l'auteur | [forum](https://forum.cfx.re/t/free-deer-diner-mlo-20-off/5307081) |
| 12 | **Old Pub** (occlusion audio, musique intérieure) | « Les habitués », Radio Los Santos | un bar d'habitués avec une vraie ambiance sonore | [forum](https://forum.cfx.re/t/free-mlo-old-pub/5219659) |
| 13 | **Salons de tatouage** (07/2025) | tatoueur | remplace le salon du jeu, plus jouable | [forum](https://forum.cfx.re/t/free-mlo-tattoo-parlors/5337863) |
| 14 | **Barbier retexturé** (08/2025, sans support) | coiffeur (menu barbier V10.2) | rafraîchit un lieu déjà utilisé, sans changer les points | [forum](https://forum.cfx.re/t/mlo-free-release-barbershop-retextured-and-a-few-more/5347664) |
| 15 | **Commissariat de Davis** | `gs_police` (sud) | un second poste au sud, là où ça chauffe | [forum](https://forum.cfx.re/t/mlo-free-davis-policestation/5178725) |
| 16 | **Commissariat LSPD de Vinewood** | `gs_police` (nord de la ville) | poste de quartier pour Vinewood / Rockford | [forum](https://forum.cfx.re/t/free-mlo-lspd-vinewood-police-station/5161866) |
| 17 | **Labo de meth dans le motel de Sandy Shores** | `gs_drugs` | atypique : un labo caché derrière une porte de motel | [forum](https://forum.cfx.re/t/free-methlab-in-sandy-shores-motel-mlo/4967109) |
| 18 ★ | **Entrepôt (coquille, 3 emplacements)** | `gs_hideouts`, `gs_business` | une coquille, 3 entrées : exactement le modèle à suivre | [forum](https://forum.cfx.re/t/warehouse-free-mlo-shell/5377851) |
| 19 | **Salle de sport de Los Santos** | activité sociale, `gs_fightclub` (entraînement) | un lieu de vie de jour, quand les combats sont la nuit | [forum](https://forum.cfx.re/t/free-mlo-los-santos-gym/5312943) |
| 20 | **Lucky Plucker** (usine de volaille) | job ouvrier (`gs_gigs`), décor de braquage | atypique et très « lore GTA » | [forum](https://forum.cfx.re/t/free-mlo-lucky-plucker/5151950) |

En réserve : [Laverie de Jerry](https://forum.cfx.re/t/map-free-laundromat/5295643) (alternative au n°7, sur
GitHub), [Atelier mécanique 3DMarket, 5 Mo](https://forum.cfx.re/t/free-mlo-mechanical-workshop/5261324) (alternative
légère au n°10), [Starlite Motel, 23 chambres](https://forum.cfx.re/t/release-mlo-starlite-motel-23-rooms/1126937)
(ancien), [shérif moderne de Paleto, YMAP](https://forum.cfx.re/t/free-ymap-modern-paleto-bay-sheriffs-station/4816478)
(ancien, extérieur seulement).

### Payants (10)

Prix relevés sur la page officielle quand elle était lisible ; sinon « voir la page ». Toujours acheter sur la
**boutique du créateur** (lien depuis son fil Cfx), avec le compte Cfx.re lié à la clé du serveur (§ 2, contrôle 4).

| # | Lieu | Créateur | Prix | Branché sur | Pourquoi | Lien |
|---|---|---|---|---|---|---|
| 1 ★ | **Mairie + tribunal** (Townhall) | Gabz | 45 € | `gs_justice`, jurés | **le** manque n°1 de l'audit : la justice joue sans tribunal | [boutique Gabz](https://fivem.gabzv.com/category/standalones) |
| 2 ★ | **Hôpital Pillbox** | Gabz | 30 € | EMS | l'hôpital du jeu est vide ; c'est le lieu le plus fréquenté du RP | [boutique Gabz](https://fivem.gabzv.com/category/standalones) |
| 3 | **Bean Machine** (Legion Square) | Gabz | 30 € | « Les habitués », commerce joueur | le café central, juste à côté du spawn | [boutique Gabz](https://fivem.gabzv.com/category/standalones) |
| 4 | **Prison** | UncleJust | 149 $ | prison vivante (V8) | cher, mais la prison vivante est une signature ; à n'acheter que si elle est jouée | [boutique](https://unclejust.tebex.io/package/4808803) |
| 5 | **Tribunal** (alternative au n°1) | UncleJust | voir la page (deux annonces, 5 $ et 69 $ : vérifier laquelle est la bonne) | `gs_justice` | si tu préfères un tribunal seul plutôt que la mairie entière | [boutique](https://unclejust.tebex.io/package/4808758) |
| 6 ★ | **Ciné en plein air** (Sandy Shores : 21 voitures, grand écran, snack, VIP) | — | voir la page | `gs_events`, `gs_roadbook` | atypique : soirées ciné, rendez-vous du week-end, étape de road trip | [forum](https://forum.cfx.re/t/paid-mlo-drive-in-cinema/5330466) |
| 7 ★ | **Inferno Boxing Club & Black Market** | — | voir la page | `gs_fightclub` + `gs_blackmarket` | deux de nos systèmes illégaux dans un seul bâtiment | [forum](https://forum.cfx.re/t/inferno-boxing-club-black-market-fivem-mlo/5271383) |
| 8 | **Bureau du shérif + hôpital de Sandy Shores** (60 pièces) | — | voir la page | `gs_police`, EMS (nord) | Blaine County jouable sans redescendre à Los Santos | [forum](https://forum.cfx.re/t/mlo-sheriff-station-hospital-sandy-shores/5365466) |
| 9 ★ | **Pack de 150+ coquilles** (2025) | K4MB1 | voir la page | `gs_hideouts` (paliers de logement) | **le** rapport qualité/poids : 150 intérieurs pour les logements. Attention : ce sont des props `.ydr` placés par script, pas des MLO → petite adaptation de `gs_hideouts` (je m'en charge) | [forum](https://forum.cfx.re/t/paid-150-all-shells-pack-k4mb1-maps-2025/5347513) |
| 10 | **Salle d'arcade** (Eight-Bit) | — | voir la page | `gs_business`, salle de jeux | atypique : lieu de détente, couverture idéale | [forum](https://forum.cfx.re/t/arcade-salon-fivem-mlo-eight-bit-arcade/5384906) |

En réserve : [Fight Club « Illegal Underground »](https://forum.cfx.re/t/fight-club-illegal-underground/5334503)
(25 $), [bureau de chantier en préfabriqué](https://forum.cfx.re/t/paid-mlo-trailer-office-mlo/4856922)
(se pose n'importe où), [siège Gouvernement / DOJ](https://forum.cfx.re/t/paid-government-doj-hq-mlo/5329164)
(alternative au tribunal).

**Écarté volontairement** :
- un studio radio « RadioHead Studios » : le nom reprend celui d'un **groupe réel**, donc risque de marque. Le
  studio d'enregistrement gratuit de `bob74_ipl` fait le même travail ;
- tout ce que les recherches renvoyaient vers **fivemx.com** : revendeur non autorisé (§ 5), même quand la page
  s'appelle « free ».

### Ma recommandation si tu ne prends que 5 lieux

1. **Mairie + tribunal** (Gabz, 45 €) — la justice est le système le plus abouti de RoadLine et le seul sans lieu.
2. **Fight Club** (gratuit) — `gs_fightclub` prend vie immédiatement.
3. **QG de gangs Grove / Ballas / Vagos** (gratuit) — trois QG d'un coup.
4. **Laverie** (gratuit) — le blanchiment devient visible et attaquable.
5. **Pack de coquilles K4MB1** — le logement devient un vrai marché, pour un poids minime.

## 8. Après le téléchargement

1. Tout dans `C:\GTASOON\mods-a-trier` (zips tels quels, même imbriqués).
2. **IMPORTER-MODS.bat** → contrôle, installation dans `resources\[addons]\gsa_<nom>`, ligne dans `cfg\addons.cfg`.
3. Envoie-moi **`RAPPORT-MODS.txt`** : je branche les entrées, les blips, les PNJ et les points dans les `gs_*`, et je
   règle les conflits (deux maps au même endroit, IPL du jeu à couper).
4. **METTRE-A-JOUR-OVH.bat** envoie les nouveaux mods au VPS. Depuis la V12.5, un mod tout juste importé est bien
   envoyé : avant, il gardait la date de son archive et pouvait être oublié.
