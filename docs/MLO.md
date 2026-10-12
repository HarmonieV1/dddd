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
| **Script compagnon** chiffré (escrow `.fxap`) livré avec une map du même vendeur (laser game, villa bunker…) | ✅ depuis la V12.31 : installé avec sa map, sous son **nom d'origine**, si toutes ses dépendances sont sur le serveur et s'il n'est pas ESX seul |
| **Script** chiffré seul (aucune map installée ne lui correspond) | ⏸ rangé dans `scripts-a-verifier`, installé seulement sur demande |
| **Script** obfusqué hors escrow (lignes illisibles) | ❌ refusé : on ne peut ni le relire, ni savoir ce qu'il envoie |

`IMPORTER-MODS.bat` applique ces règles : une map escrow est installée avec un avertissement dans le rapport (V12.5) ;
son script compagnon aussi (V12.31). Avant, le script restait dans `scripts-a-verifier` : la map était là, mais le jeu
(laser game, auto-tamponneuses…) ne démarrait jamais.

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
  L'importeur refuse un script ESX seul.
- **Un script compagnon dont une dépendance manque** (ex. `pma-voice`, une librairie du vendeur pas téléchargée) :
  pas installé, le rapport dit « il lui manque … ». Télécharger la dépendance chez le vendeur, la poser dans
  `mods-a-trier`, relancer IMPORTER-MODS.

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

### Maps payantes installées (12/10/2026, V12.34)

Une quarantaine de packs escrow (achat Cfx.re lié à la clé du serveur), surtout Patoche, vérifiés à chaque démarrage
(intégrité des fichiers, conflits d'occlusion fusionnés dans `gsa_zz_fusion_occlusion`). Blips publics : `PUBLIC` dans
`gs_admin/server/maps.js`.

| Lieu | Ressource | Remarque |
|---|---|---|
| Prison de Bolingbroke | `gsa_sub_patoche_prison_pack` | gardée à la place de Digital Den (même occlusion) ; coords de cellule à confirmer en jeu |
| Benny's noir et blanc | `gsa_sub_patoche_benny_bw_pack` | gardé à la place du Benny's original |
| Villa bunker | `gsa_patoche_villa_bunker_pack` | **V12.31 : gardée**, la villa moderne 01 est retirée (même villa) |
| Karting | `gsa_patoche_plasmakart_pack` (+ DLC) | **retiré le 12/10** (V12.33, demande du fondateur) |
| Laser game | `gsa_patoche_plasmagame_pack` (+ DLC) | **retiré le 12/10** (V12.33, demande du fondateur) |
| Auto-tamponneuses Del Perro / Pacific | `gsa_patoche_bumpercar_*` | activité = script compagnon |
| Casino, concession, Ammu-Nation ×2, tabac, tacos, animalerie, billard, entrepôt, box de stockage | `gsa_patoche_*` | casino / concession / Ammu-Nation : doublons avec nos points sur les lieux du jeu, choix « nouveau / ancien » en attente |
| QG gang 2, garage clandestin, labo weed, panneaux | `gsa_patoche_*` | sans blip (lieux secrets) |

Retirées (`RETIRED_MAPS` dans `gs_admin/server/maps.js` = **liste unique**) : supermarché Willie's, magasin d'alcool
de Paleto, Moreo Gym, casse, Benny's original, villa moderne 01, Digital Den, Shadow Complex, laser game (+ DLC), karting
(+ DLC), plasmatron. Le serveur les supprime au démarrage (archives gardées dans mods-a-trier) et, depuis la V12.34,
IMPORTER-MODS ne les réinstalle jamais (même supprimées à la main avant un redémarrage) et enlève leurs lignes de
addons.cfg. Pour en retirer une autre : l'ajouter à `RETIRED_MAPS` ; pour en remettre une : `$Restored` dans
importer-mods.ps1.
Désactivées tant que l'archive n'est pas retéléchargée (téléchargement coupé, V12.27) : beach party, terrain de foot
(soccer, soccer_cloth).

### Lieux du jeu de base (audit du 11/10/2026)

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

La sélection de MLO à consulter (20 gratuits, 10 payants) est dans `docs/SELECTION_MAPPINGS.md`.

## 7. Une map ne marche pas : diagnostic (V12.27 → V12.34)

| Symptôme | Où regarder | Cause / remède |
|---|---|---|
| Crash « Invalid fixup … (in xxx.ydr) » | console : « Map ARRÊTÉE … fichier abîmé » | archive coupée : retélécharger, IMPORTER-MODS |
| Bâtiment absent, chargement sans fin | console : « Map activée mais NON démarrée » | licence Cfx (« entitlement ») ou `.fxap` manquant |
| Bâtiment invisible, console muette | **F11 → Mappings installés → Contrôler les maps chez moi** | « aucun modèle reçu » (cache : VIDER-CACHE-FIVEM), « illisibles » (licence / fichier abîmé), « pack incomplet » |
| Map visible mais aucun point pour jouer | console : « DÉCOR SEUL » ; F11 : « Activité : … décor seul » | script compagnon absent : il doit être dans le zip du pack ; sinon le télécharger chez le vendeur |
| Script installé mais pas lancé | console : « Script de map activé mais NON démarré » | licence, dépendance manquante, ou script qui refuse d'être renommé (remonter dans la console) |
| Deux maps au même endroit | console : « CONFLIT » | fusion automatique ; sinon en garder une (`RETIRED_MAPS`) |
| Map supprimée qui revient après METTRE-A-JOUR | `RAPPORT-MODS.txt` | corrigé en V12.34 : elle doit être dans `RETIRED_MAPS` (ou `mods-retires.txt`) |

## 8. Après le téléchargement

1. Tout dans `C:\GTASOON\mods-a-trier` (zips tels quels, même imbriqués).
2. **IMPORTER-MODS.bat** → contrôle, installation dans `resources\[addons]\gsa_<nom>`, ligne dans `cfg\addons.cfg`.
3. Envoie-moi **`RAPPORT-MODS.txt`** : je branche les entrées, les blips, les PNJ et les points dans les `gs_*`, et je
   règle les conflits (deux maps au même endroit, IPL du jeu à couper).
4. **METTRE-A-JOUR-OVH.bat** envoie les nouveaux mods au VPS. Depuis la V12.5, un mod tout juste importé est bien
   envoyé : avant, il gardait la date de son archive et pouvait être oublié.
