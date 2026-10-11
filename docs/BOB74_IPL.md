# Audit `bob74_ipl` — les intérieurs gratuits qu'on n'exploite pas encore

Fait le 11/10/2026 sur **bob74_ipl 2.7.1** (dernière version, 04/10/2026), code source lu intérieur par
intérieur. Objectif : savoir exactement ce qui est déjà chargé par la ressource, ce que RoadLine en utilise, et
ce qui dort. **Zéro téléchargement, zéro poids réseau en plus, zéro risque de marque** : ces intérieurs sont
dans le GTA V de chaque joueur, `bob74_ipl` ne fait que les allumer.

- Source : https://github.com/Bob74/bob74_ipl · licence **MIT** (aucun souci de redistribution)
- Déjà dans `server/cfg/resources.cfg` : `ensure bob74_ipl` (ligne 13)
- Wiki des réglages par intérieur : https://github.com/Bob74/bob74_ipl/wiki

---

## 1. Trois familles d'intérieurs — ça change tout

Comprendre la différence évite de perdre du temps :

| Famille | Où est l'intérieur | Ce qu'il faut pour y entrer |
|---|---|---|
| **A. Sous la carte** (DLC Online) | à des Z négatifs, hors de la ville (ex. `-38`, `-50`, `-100`) | une **porte-téléportation** dans `gs_interiors` (c'est exactement ce que fait la ressource aujourd'hui) |
| **B. En place** (mode histoire, DLC « en ville ») | à sa vraie adresse dans Los Santos | **rien à téléporter** : le joueur pousse la porte. Il faut juste l'IPL allumé (c'est le cas) et, parfois, `ox_doorlock` pour gérer la serrure |
| **C. Coquille** (*shell*) | un intérieur unique réutilisé | **un seul intérieur, plusieurs façades**, séparées par un `routing bucket` (un « monde » par locataire) |

**La famille C est déjà en production chez nous** : `gs_hideouts` prend l'appartement bas de gamme du jeu
(`261.46, -998.82, -99.0`) et donne à chaque locataire son propre monde (`Config.BucketBase = 5000`). Même
intérieur, 3 motels différents, 0 Mo de plus. C'est le modèle à dupliquer.

---

## 2. Ce que RoadLine utilise aujourd'hui

`gs_interiors/shared/config.lua` : **6 portes**, toutes dans la zone des business bikers et au casino.

| Porte | Intérieur bob74_ipl | Centre réel de l'intérieur |
|---|---|---|
| `casino` | `dlc_casino/casino` | `1089.73, 206.36, -48.99` |
| `lost_club` | `dlc_bikers/clubhouse1` | `1107.04, -3157.40, -37.52` |
| `lab_families` | `dlc_bikers/weed` (ferme de cannabis) | `1051.49, -3196.54, -39.15` |
| `lab_ballas` | `dlc_bikers/cocaine` (lockup) | `1093.60, -3196.60, -38.99` |
| `lab_vagos` | `dlc_bikers/meth` (labo de meth) | `1009.50, -3196.60, -38.99` |
| `lab_madrazo` | `dlc_bikers/counterfeit_cash` (faux billets) | `1121.90, -3195.34, -40.40` |

Ailleurs dans le serveur :
- `gs_hideouts` → appartement bas de gamme (famille C, routing buckets)
- `gs_casino` → l'intérieur du casino (roue, tables)
- `gs_business` → Bahama Mamas **en place** (`-1388.4, -607.2, 30.32`), famille B, aucune téléportation

**Verdict : on exploite 6 intérieurs sur ~90 disponibles.** Il reste beaucoup.

---

## 3. Inventaire complet (coordonnées lues dans le code source, donc exactes)

Ce sont les **centres d'intérieur** donnés par bob74_ipl. Pour une porte, le `inside` se cale à 2-5 m de là,
à l'endroit où le joueur doit apparaître (voir § 6 : ça se fait en jeu en 20 secondes).

### Famille A — sous la carte (une porte-téléportation à créer)

| Intérieur | Fichier bob74 | Centre | État |
|---|---|---|---|
| Boîte de nuit (After Hours) | `dlc_afterhours/nightclubs` | `-1604.66, -3012.58, -78.00` | **libre** |
| Club-house biker n°2 | `dlc_bikers/clubhouse2` | `998.48, -3164.71, -38.91` | **libre** |
| Atelier de faux papiers | `dlc_bikers/document_forgery` | `1165.00, -3196.60, -39.01` | **libre** |
| Arcade (salle de jeux) | `dlc_casino/arcade` | `2732.00, -380.00, -50.00` | **libre** |
| Sous-sol de l'arcade (planification) | `dlc_casino/arcade_basement` | `2710.00, -360.78, -56.00` | **libre** |
| The Music Locker (club sous le casino) | `dlc_cayoperico/nightclub` | `1550.00, 250.00, -50.00` | **libre** |
| Sous-marin Kosatka | `dlc_cayoperico/submarine` | `1560.00, 400.00, -50.00` | **libre** |
| Casse / Salvage Yard | `dlc_chopshop/salvage` | `1077.28, -2274.88, -50.00` | **libre** |
| Garage du cartel | `dlc_chopshop/cartel_garage` | `1220.13, -2277.84, -50.00` | **libre** |
| Freakshop (atelier) | `dlc_drugwars/freakshop` | `570.97, -420.07, -70.00` | **libre** |
| Garage Eclipse Boulevard (10 places) | `dlc_drugwars/garage` | `519.25, -2618.79, -50.00` | **libre** |
| Labo d'acide | `dlc_drugwars/lab` | `483.43, -2625.07, -50.00` | **libre** |
| Bureau de caution / chasse aux primes | `dlc_bounties/office` | `565.89, -2688.76, -50.00` | **libre** |
| Studio d'enregistrement | `dlc_security/studio` | `-1010.22, -52.21, -100.00` | **libre** |
| Garage de l'agence (The Contract) | `dlc_security/garage` | `-1071.83, -77.96, -95.00` | **libre** |
| Vinewood Car Club | `dlc_mercenaries/club` | `1202.41, -3251.25, -50.00` | **libre** |
| Labo de Fort Zancudo | `dlc_mercenaries/lab` | `-1916.12, 3749.72, -100.00` | **libre** |
| Los Santos Car Meet | `dlc_tuner/meetup` | `-2000.00, 1113.21, -25.36` | **libre** |
| Station de lavage | `dlc_money/carwash` | `26.07, -1398.98, -75.00` | **libre** |
| Bureau (Money Fronts) | `dlc_money/office` | `-1160.49, -1538.93, -50.00` | **libre** |
| Hangar de contrebande (LSIA) | `dlc_smuggler/hangar` | `-1267.00, -3013.14, -49.50` | **libre** |
| Usine textile | `dlc_agents/factory` | `752.31, -997.24, -47.00` | **libre** |
| Bureau du hangar McKenzie | `dlc_agents/office` | `2149.71, 4787.76, -47.00` | **libre** |
| Installation Doomsday (immense) | `dlc_doomsday/facility` | `345.00, 4842.00, -60.00` | **libre** |
| Entrepôt de véhicules (haut) | `dlc_import/vehicle_warehouse` | `994.59, -3002.59, -39.65` | **libre** |
| Entrepôt de véhicules (bas) | `dlc_import/vehicle_warehouse` | `969.54, -3000.41, -48.65` | **libre** |
| Kortz — exposition | `dlc_kortz/exhibition` | `2603.17, 5903.76, -50.00` | **libre** |
| Kortz — sous-sol | `dlc_kortz/basement` | `2631.41, 5893.86, -62.00` | **libre** |
| Kortz — quai de chargement | `dlc_kortz/loadingbay` | `2693.67, 5877.49, -62.00` | **libre** |
| Kortz — atelier d'art | `dlc_kortz/mansion_workshop` | `2583.92, 5961.41, -50.00` | **libre** |
| Kortz — égouts | `dlc_kortz/sewers` | `2662.28, 5928.21, -67.00` | **libre** |
| Appartement haut de gamme (Online) | `gta_online/apartment_hi_1` | `-35.31, -580.42, 88.71` | **libre** |
| Appartement haut de gamme 2 | `gta_online/apartment_hi_2` | `-1477.14, -538.75, 55.53` | **libre** |
| Maison milieu de gamme | `gta_online/house_mid_1` | `347.27, -999.30, -99.20` | **libre** |
| Maison bas de gamme | `gta_online/house_low_1` | `261.46, -998.82, -99.00` | utilisée (`gs_hideouts`) |

### Famille B — en place (le joueur pousse la porte, rien à téléporter)

| Intérieur | Fichier bob74 | Où | État |
|---|---|---|---|
| Hôpital Pillbox | `gtav/pillbox_hospital` | `307.17, -590.81, 43.28` | **libre** |
| Bahama Mamas | `gtav/bahama` | `-1388.00, -618.42, 30.82` | utilisé (`gs_business`) |
| Villa de Vinewood | `dlc_mansions/mansion1` (+ sous-sol) | `543.85, 712.75, 201.00` | **libre** |
| Villa de Richman | `dlc_mansions/mansion2` (+ sous-sol) | `-1630.43, 470.85, 128.00` | **libre** |
| Domaine Tongva | `dlc_mansions/mansion3` (+ sous-sol) | `-2601.71, 1874.83, 166.00` | **libre** |
| Musée Kortz Center | `dlc_kortz/museum` | `-2242.16, 270.78, 173.50` | **libre** |
| Toit du studio (concerts) | `dlc_security/musicrooftop` | `-854.19, -225.73, 60.00` | **libre** |
| Poste de sauveteurs (Vespucci) | `dlc_chopshop/lifeguard` | `-1488.15, -1021.17, 5.00` | **libre** |
| 3655 Wild Oats Drive | `gta_online/house_hi_1` | `-169.29, 486.49, 137.44` | **libre** |
| 2044 North Conker Avenue | `gta_online/house_hi_2` | `340.94, 437.18, 149.39` | **libre** |
| 2045 North Conker Avenue | `gta_online/house_hi_3` | `373.02, 416.11, 145.70` | **libre** |
| 2862 Hillcrest Avenue | `gta_online/house_hi_4` | `-676.13, 588.61, 145.17` | **libre** |
| 2868 Hillcrest Avenue | `gta_online/house_hi_5` | `-763.11, 615.91, 144.14` | **libre** |
| 2874 Hillcrest Avenue | `gta_online/house_hi_6` | `-857.80, 682.56, 152.65` | **libre** |
| 2677 Whispymound Drive | `gta_online/house_hi_7` | `120.50, 549.95, 184.10` | **libre** |
| 2133 Mad Wayne Thunder | `gta_online/house_hi_8` | `-1288.00, 440.75, 97.69` | **libre** |
| Bureau Arcadius Business Centre | `dlc_finance/office1` | `-141.20, -620.91, 168.82` | **libre** |
| Bureau Maze Bank Building | `dlc_finance/office2` | `-75.85, -826.99, 243.39` | **libre** |
| Bureau Lom Bank | `dlc_finance/office3` | `-1579.76, -565.07, 108.52` | **libre** |
| Bureau Maze Bank West | `dlc_finance/office4` | `-1392.67, -480.47, 72.04` | **libre** |
| Penthouse du casino | `dlc_casino/penthouse` | `976.64, 70.30, 115.16` | **libre** |
| Appartements Executive 1-3 | `dlc_executive/apartment1-3` | `-787.78, 334.92, 215.84` et voisins | **libre** |
| Appartements High Life 1-6 | `dlc_high_life/apartment1-6` | 6 adresses (voir code) | **libre** |
| Yacht de Del Perro | `dlc_heists/yacht` | `-2043.97, -1031.58, 11.98` | **libre** |
| Yacht de Paleto | `dlc_gunrunning/yacht` | `-1363.72, 6734.11, 2.45` | **libre** |
| Piste d'atterrissage (Agents) | `dlc_agents/airstrip` | `-2106.98, 1468.31, 282.00` | **libre** |
| Maisons du mode histoire | `gtav/michael`, `franklin`, `floyd`, `trevors_trailer`, `franklin_aunt` | à leur adresse | **libre** |
| Vanilla Unicorn (coulisses) | `gtav/stripclub` | en place | **libre** |
| Showroom Premium Deluxe | `gtav/simeon` | en place | **libre** |
| Usine de Lester | `gtav/lester_factory` | en place | **libre** |
| Porte-avions, cargos, OVNI, North Yankton, tapis rouge, graffitis, portes de Zancudo | divers | divers | décor, sans RP direct |

### Les 4 bureaux d'agence (The Contract) et les 5 garages tuner

Cas particulier : ce sont **des IPL multiples** pour un même type de lieu, à des adresses différentes.

- `dlc_security/office1-4` → 4 bureaux d'agence de détective privé, chacun dans un vrai immeuble
  (IPL `sf_fixeroffice_bh1_05`, `sf_fixeroffice_hw1_08`, etc.)
- `dlc_tuner/garage` → 5 ateliers tuner en une seule ressource
  (IPL `tr_tuner_shop_burton`, `..._mesa`, `..._mission`, `..._rancho`, `..._strawberry`)
- `dlc_import/garage1-4` → 4 garages de PDG, sous les 4 immeubles de bureaux
- `dlc_finance/office1-4` → les 4 bureaux de PDG eux-mêmes

**Les 5 ateliers tuner sont le meilleur exemple de coquille** : un intérieur, cinq quartiers (Burton, La Mesa,
Mission Row, Rancho, Strawberry). Un seul fichier, cinq ateliers de mécano jouables.

---

## 4. Les 12 portes que je recommande, par valeur RP

Classées par ce que ça apporte au serveur **divisé par** le travail que ça demande. Chacune se branche sur une
ressource qui existe déjà — pas de nouveau système à écrire.

| # | Lieu | Se branche sur | Pourquoi ça vaut le coup |
|---|---|---|---|
| 1 | **Atelier de faux papiers** | `gs_market` / `gs_civil` | « Le marché des faux papiers » existe déjà dans les features mais n'a pas de lieu. Là, il en a un, caché, avec accès gang. |
| 2 | **Bureau de caution / primes** | `gs_wanted` (primes) | Les primes existent déjà. Un vrai bureau de chasseur de primes, c'est le métier qui se tient debout tout seul. |
| 3 | **Los Santos Car Meet** | `gs_races` + `gs_tuning` | Le lieu de rassemblement auto. Sur un serveur RP, c'est le point de rendez-vous naturel du soir. Énorme pour la vie sociale. |
| 4 | **Casse / Salvage Yard** | `gs_auction` (fourrière) + `gs_tuning` | Une vraie casse pour démonter les véhicules volés, et un décor pour les enchères de la fourrière. |
| 5 | **Studio d'enregistrement** | `gs_lsradio` (Radio Los Santos) | Radio Los Santos existe déjà. Un studio où on enregistre pour de vrai, c'est une signature que personne n'a. |
| 6 | **Garage de l'agence** | `gs_dossier` / `gs_evidence` | Le bureau du détective privé. Le RP enquête privée (hors police) n'a aujourd'hui aucun lieu. |
| 7 | **Boîte de nuit** | `gs_business` + `gs_events` | Un intérieur, **10 façades possibles** dans la ville (coquille). Piste de danse, DJ, VIP, bureau, entrepôt au sous-sol. Le meilleur rapport qualité/poids du lot. |
| 8 | **Labo d'acide** | `gs_drugs` | Une drogue de plus, dans un labo mobile (il est dans un camion dans le jeu de base). |
| 9 | **Garage Eclipse Boulevard** | `gs_tuning` / `gs_hideouts` haut de gamme | 10 places de parking + atelier. Le garage de luxe que les joueurs riches veulent. |
| 10 | **Hangar de contrebande (LSIA)** | `gs_smuggling` | `gs_smuggling` existe et n'a pas de base. Le hangar, c'est son QG évident. |
| 11 | **Station de lavage** | `gs_business` (blanchiment) | Le blanchiment par commerce légal existe déjà. Un car-wash, c'est le cliché parfait — et c'est gratuit. |
| 12 | **Maison milieu de gamme** | `gs_hideouts` | Un **palier au-dessus** des motels, avec le système de routing bucket déjà écrit. Quasi rien à coder : 1 ligne de config. |

Et en réserve, sans porte à créer (famille B, le joueur entre physiquement) :
- **Les 8 maisons de Vinewood** (Wild Oats, North Conker ×2, Hillcrest ×3, Whispymound, Mad Wayne Thunder) →
  logement haut de gamme à leur vraie adresse. C'est ce que les serveurs vendent le plus cher.
- **Les 3 villas** (Vinewood, Richman, Tongva) + leurs sous-sols → QG de gang de haut niveau, ou la maison du
  joueur le plus riche du serveur.
- **Les 4 bureaux de PDG** (Arcadius, Maze Bank, Lom Bank, Maze Bank West) → siège d'entreprise pour `gs_business`.
- **Le musée Kortz Center** → cible de braquage d'œuvre d'art pour `gs_heists`, et lieu visitable le reste du temps.

---

## 5. Blocs prêts à coller dans `gs_interiors/shared/config.lua`

Les `inside` ci-dessous sont **exacts** (lus dans la source de bob74_ipl). Les `outside` sont marqués
`⚠ À RELEVER` : je ne peux pas les inventer sans risquer de poser un marqueur dans un mur. Le § 6 explique
comment les relever en jeu en 20 secondes par porte — et comment les corriger sans toucher au code.

```lua
-- ⚠ Chaque `outside` est à relever en jeu (F11 → Copier mes coordonnées), devant la façade indiquée.
-- Les `inside` sont les centres d'intérieur donnés par bob74_ipl : à affiner de 2-5 m pour tomber
-- sur le pas de porte intérieur plutôt qu'au milieu de la pièce.

-- 1 · Faux papiers (accès gang). Façade : un local discret, idéalement dans le quartier du gang.
{ id = 'faux_papiers', label = 'Atelier de faux papiers', access = { gang = 'madrazo' },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(1165.0, -3196.6, -39.01, 180.0) },

-- 2 · Bureau de caution / chasse aux primes (métier). Façade : près du commissariat de Mission Row.
{ id = 'primes', label = 'Bureau de caution', access = { job = 'bail' }, blip = { sprite = 110, color = 5 },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(565.89, -2688.76, -50.0, 0.0) },

-- 3 · Los Santos Car Meet (public). Façade : l'entrepôt de Cypress Flats (rideau métallique).
{ id = 'carmeet', label = 'Los Santos Car Meet', access = { public = true }, blip = { sprite = 226, color = 46 },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(-2000.0, 1113.21, -25.36, 0.0) },

-- 4 · Casse (métier mécano / fourrière). Façade : le portail de la casse.
{ id = 'casse', label = 'Casse', access = { job = 'mecano' },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(1077.28, -2274.88, -50.0, 0.0) },

-- 5 · Studio d'enregistrement (public ou métier radio). Façade : l'immeuble du studio, Del Perro.
{ id = 'studio', label = 'Studio d\'enregistrement', access = { public = true }, blip = { sprite = 136, color = 27 },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(-1010.22, -52.21, -100.0, 0.0) },

-- 6 · Agence de détective privé (métier). Façade : l'entrée de l'agence.
{ id = 'agence', label = 'Agence', access = { job = 'detective' },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(-1071.83, -77.96, -95.0, 0.0) },

-- 7 · Boîte de nuit (public la nuit). UN intérieur, 10 façades possibles : voir le § « coquille » ci-dessous.
{ id = 'club', label = 'Boîte de nuit', access = { public = true }, blip = { sprite = 614, color = 27 },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(-1604.66, -3012.58, -78.0, 0.0) },

-- 8 · Labo d'acide (accès gang). Façade : un hangar ou un camion garé.
{ id = 'lab_acide', label = 'Labo d\'acide', access = { gang = 'lostmc' }, lab = 'acid',
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(483.43, -2625.07, -50.0, 0.0) },

-- 9 · Garage Eclipse Boulevard (10 places + atelier). Façade : la rampe du parking.
{ id = 'garage_eclipse', label = 'Garage Eclipse', access = { public = true },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(519.25, -2618.79, -50.0, 0.0) },

-- 10 · Hangar de contrebande (métier / gang). Façade : les hangars de l'aéroport.
{ id = 'hangar', label = 'Hangar', access = { gang = 'lostmc' },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(-1267.0, -3013.14, -49.5, 0.0) },

-- 11 · Station de lavage (blanchiment, public). Façade : le car-wash.
{ id = 'carwash', label = 'Station de lavage', access = { public = true },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(26.07, -1398.98, -75.0, 0.0) },

-- 12 · Club-house biker n°2 (second gang). Façade : un local de gang.
{ id = 'club_house_2', label = 'Club-house', access = { gang = 'ballas' },
  outside = vec4(0.0, 0.0, 0.0, 0.0),   -- ⚠ À RELEVER
  inside  = vec4(998.48, -3164.71, -38.91, 0.0) },
```

Pour le n°12 de la liste des recommandations (maison milieu de gamme), ce n'est **pas** une porte `gs_interiors` :
c'est une ligne dans `gs_hideouts/shared/config.lua`, car le système de routing bucket est déjà là.

```lua
-- gs_hideouts : palier au-dessus des motels (même mécanique, intérieur plus grand)
-- Intérieur : maison milieu de gamme du jeu, centre 347.27, -999.30, -99.20
-- À ajouter dans Config.Sites avec son propre interior / stash / wardrobe (3 coords à relever dedans).
```

### La coquille, en pratique : 1 boîte de nuit → 10 façades

L'intérieur `ba_int_placement_ba_interior_0_dlc_int_01_ba_milo_` est **unique** : les 10 boîtes de nuit de
GTA Online partagent le même. Donc :

- **une** entrée `Config.Doors` par façade (10 entrées), toutes avec le **même** `inside` ;
- un `routing bucket` par club si tu veux qu'ils soient indépendants (comme `gs_hideouts`), ou aucun si tu
  veux un seul club commun où tout le monde se croise (plus vivant, et plus simple).

Mon avis : **un seul club pour commencer**, commun à tous, dans un quartier central. Dix clubs vides valent
moins qu'un club plein. On en ouvre un deuxième quand le premier est trop petit.

---

## 6. Relever les coordonnées de façade (20 secondes par porte)

1. En jeu, mode staff, `F11` → **Copier mes coordonnées** : le `vec4` complet (position + orientation) part
   dans le presse-papiers. Place-toi devant la porte, **tourné vers elle**, et copie.
2. Colle-le dans `outside`.

**Et surtout** : `gs_interiors` inclut déjà `@gs_bridge/shared/points.lua`. Donc **chaque `outside` et chaque
`inside` est déjà déplaçable en jeu** par le staff (`F11` → **Déplacer un point**), sans toucher au code et
sans redémarrer le serveur à la main. Concrètement : on peut poser les 12 portes avec des coordonnées
approximatives, puis les caler toutes en une seule session de jeu.

C'est pour ça que je n'ai pas inventé les `outside` : ce n'est pas le travail difficile. Le travail difficile
(savoir quels intérieurs existent, où ils sont exactement, et lesquels valent le coup) est fait ci-dessus.

---

## 7. Pièges à connaître

- **Ne jamais déplacer un intérieur.** Les intérieurs de la famille A sont sous la carte à des coordonnées
  fixes : si tu bouges le point `inside` de plus de quelques mètres, tu sors de l'intérieur et tu tombes dans
  le vide. Le `outside`, lui, se déplace librement.
- **`dlc_import/garage4` chevauche `dlc_finance/office4`** (le code de bob74_ipl le signale lui-même). Si tu
  utilises les deux, vérifie en jeu.
- **Un intérieur partagé est partagé.** Sans routing bucket, deux gangs qui auraient le même intérieur se
  verraient. C'est déjà le cas chez nous : chaque labo a son propre intérieur, c'est volontaire.
- **La famille B n'a pas besoin de nous.** Pour une villa ou une maison de Vinewood, le joueur pousse la
  porte. S'il faut une serrure (clé, propriétaire), c'est `ox_doorlock`, pas `gs_interiors`.
- **`sv_entityLockdown`** : ces portes ne créent aucune entité, donc aucun impact — même en `strict`
  (voir le bloc de commentaires dans `server/cfg/prod.cfg`).
- **Aucune marque réelle** dans tout ce qui précède : ce sont des lieux du jeu de base (Vanilla Unicorn,
  Maze Bank, Bahama Mamas sont des marques **fictives** de Rockstar). Zéro risque Cfx.re.

---

## 8. Ce que ça coûte

| Poste | Coût |
|---|---|
| Téléchargement joueur | **0 Mo** (déjà dans son GTA V) |
| Poids serveur | **0 Mo** (`bob74_ipl` est déjà installé) |
| Performance | une porte = un marqueur `gs_markers` + un blip. Négligeable, et les marqueurs non autorisés ne sont même pas créés côté client. |
| Licence | MIT, aucune contrainte |
| Risque Cfx.re / DMCA | **aucun** |
| Travail | ~15 min par porte (relevé façade + test aller-retour), plus le branchement RP de la ressource concernée |

À comparer avec un MLO payant : 25-45 € l'unité, 30-120 Mo de téléchargement par joueur, et une licence à
vérifier. Voir `docs/MLO.md`.
