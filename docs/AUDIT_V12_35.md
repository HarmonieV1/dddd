# Audit global RoadLine RP — 12/10/2026 (V12.35)

État de la base à 8 jours de l'ouverture (20/10, 21 h). Ce qui est vérifié automatiquement, ce qui ne l'est qu'en jeu,
ce qui peut encore faire bugger, et la liste de ce qu'il reste à faire.

## 1. Verdict en une phrase

**Le code est sain** : tous les tests passent, aucune faille évidente, aucun secret dans le dépôt. **Les risques qui
restent ne sont pas dans notre code** : ils viennent des maps payantes (licences, archives coupées, scripts jamais
testés en jeu), de deux sessions de travail qui peuvent diverger, et de réglages à basculer avant l'ouverture.

## 2. Ce qui a été vérifié (automatiquement, à chaque push)

| Contrôle | Résultat |
|---|---|
| Syntaxe de tout le Lua (67 ressources, ~38 000 lignes) | ✅ |
| ~2 900 tests de logique serveur (économie, police, prison, clés, tenues, maps…) | ✅ tous verts |
| Liens entre ressources (événements, exports, callbacks) | ✅ |
| Libellés d'objets en français, images d'objets | ✅ |
| Budget de performance : 138 threads client, 6 boucles par image justifiées, aucune boucle serveur < 250 ms | ✅ |
| Lecteur de maps (92 tests) et importeur de mods de bout en bout (9 tests) | ✅ |
| Marques réelles bloquées (même liste dans l'importeur et NETTOYER-MARQUES) | ✅ |
| Pièges connus : `and nil or`, apostrophes doublées, schtasks, DLL abîmées | ✅ |

Scans faits pour cet audit :
- **332 points d'entrée réseau** (39 événements + 298 callbacks serveur) : ceux qui donnent argent ou objets ont tous une
  protection visible (limite de fréquence, distance, métier, session, staff). Heuristique : à confirmer par l'audit
  détaillé prévu après l'ouverture.
- **SQL** : aucune requête construite par concaténation (pas d'injection possible par ce chemin).
- **Secrets** : aucun mot de passe, webhook ou chaîne MySQL en clair dans le dépôt ; `secrets.cfg` absent des zips.
- **Démarrage** : toutes les ressources `gs_*` sont lancées, après leurs dépendances (oxmysql, ox_lib, ox_inventory,
  illenium-appearance, qbx_vehiclekeys).

## 3. Ce qui peut encore faire bugger (par ordre de risque)

| # | Risque | Pourquoi | Que faire |
|---|---|---|---|
| 1 | **Maps payantes** invisibles ou sans activité | licence Cfx (achat avec un autre compte que la clé), archive coupée, script compagnon jamais testé en jeu, script qui refuse d'être renommé | après chaque import : RAPPORT-MODS.txt + console (« NON démarré », « DÉCOR SEUL », « CONFLIT ») + F11 → Contrôler les maps chez moi |
| 2 | **Deux sessions qui divergent** (web + poste Windows) | la V12.33 n'était que dans un zip ; une session qui repart d'un vieux zip efface le travail de l'autre | GitHub = seule référence. Chaque session commence par `git fetch` et finit par un push (ou un zip complet à réintégrer) |
| 3 | **Serveur encore en mode « dev » le jour J** | `dev.cfg` cache le serveur de la liste FiveM (`sv_master1 ""`) | sur le VPS, avant l'ouverture : `roadline public` (bascule sur prod.cfg) puis redémarrage |
| 4 | **Doublons de lieux** (casino, concession, Ammu-Nation, Benny's, prison) | la map payante est là, nos points et blips aussi sur le lieu du jeu | ta décision « nouveau / ancien » pour chacun, puis je recale |
| 5 | **Prison / jail** avec la nouvelle map | coordonnées de cellule et de sortie calées sur l'ancienne prison | test en jeu : se faire incarcérer, sortir ; `/coords` si décalé |
| 6 | Packs coupés au téléchargement | beach party, terrain de foot désactivés (fichier tronqué = crash joueur) | retélécharger depuis le portail Cfx, déposer dans mods-a-trier |
| 7 | `sv_entityLockdown "relaxed"` | moins strict qu'idéal contre certaines triches | volontaire : « strict » demande une migration (audit V12.4) → après l'ouverture |
| 8 | Charge du VPS | ~40 maps payantes + 67 ressources ; RAM à surveiller à 48 joueurs | txAdmin → performance ; `resmon` en jeu ; maps lourdes signalées en console (« au-delà de la limite FiveM ») |

## 4. Le site : héberger sur le VPS ?

**Mon avis : non, garde Netlify.** Le site ne pèse que 260 Ko : ce n'est ni sa taille ni l'hébergeur qui le rendent lourd.

- Netlify sert le site depuis des serveurs partout en Europe (CDN), gratuitement, avec HTTPS automatique.
- Sur le VPS, le site prendrait du processeur et de la bande passante **au serveur de jeu** ; il exposerait aussi
  l'adresse du VPS à plus de trafic (attaques), et il faudrait gérer nginx, un domaine et un certificat.

**La vraie cause, mesurée** dans un navigateur (défilement pendant 4 s) : les effets plein écran — aurore très floutée,
grain animé, pluie, brouillard, flous d'arrière-plan. Sans eux le site est **2 fois plus fluide** (9 → 19 images/s
sur une machine sans carte graphique ; l'écart est le même en proportion sur un PC modeste ou un téléphone).

**Corrigé (V12.35) : mode léger automatique.** Ces effets sont coupés d'office sur téléphone et sur petite machine
(≤ 4 cœurs ou ≤ 4 Go), ou si le site tourne à moins de 35 images/s quelques secondes après l'ouverture. Sur un bon PC,
rien ne change. Forcer : `…/index.html?lite` (léger) ou `?full` (tous les effets). Vérifié : 0 erreur JavaScript.
**À faire de ton côté : PUBLIER-SITE.bat** (glisser le dossier `docs\site` sur Netlify).

Autres points du site :
- 4 photos (`img/vespucci.jpg`, `course.jpg`, `vanilla.jpg`, `cayo.jpg`) et la police Pricedown (`fonts/`) sont prévues
  mais absentes : le site a un repli propre, mais ce sont 6 requêtes perdues à chaque visite. Dépose-les dans
  `docs\site\img` et `docs\site\fonts` quand tu les as.
- 5 polices Google : on peut descendre à 3 si on veut gagner encore un peu au premier chargement.
- Le bloc « en ville » lit `ville.json` sur le VPS toutes les 60 s : si le serveur est éteint, le site reste normal.

## 5. Les mods : où déposer, que sont tous ces dossiers ?

**Un seul dossier pour déposer : `C:\GTASOON\mods-a-trier`** — les archives (.zip / .rar / .7z) **telles quelles**, une
par pack, sans les décompresser. C'est là qu'on met les nouveaux mods ET les packs retéléchargés (à la place de l'ancien
fichier, même nom). Puis IMPORTER-MODS.bat (ou METTRE-A-JOUR, qui le lance).

Les autres dossiers sont fabriqués par l'importeur — **on n'y dépose rien** :

| Dossier | Contenu |
|---|---|
| `C:\GTASOON\mods-tri\` | le tri : `maps`, `vehicules`, `vetements`, `scripts-a-verifier`, `a-convertir`, `deja-convertis`, `rejetes` (+ `RAPPORT-MODS.txt`) |
| `C:\GTASOON\mods-tri\_extraction` | décompression temporaire (refaite à chaque import) |
| `C:\GTASOON\server-data\resources\[addons]\` | ce qui est **installé** : `gsa_<nom>` (maps, véhicules, vêtements) et, depuis la V12.31, les **scripts compagnons** des maps sous leur nom d'origine (sans `gsa_`) — d'où des dossiers d'un nouveau genre |
| `C:\GTASOON\server-data\cfg\addons.cfg` | la liste de ce qui démarre (`ensure …`) |
| `C:\GTASOON\mods-retires.txt` | les mods à ne jamais réinstaller |

Retirer une map : la mettre dans `RETIRED_MAPS` (gs_admin/server/maps.js — demande-le moi) : supprimée au démarrage
du serveur, jamais réimportée (V12.34).

## 6. Avant l'ouverture (check-list)

1. METTRE-A-JOUR (V12.35) puis METTRE-A-JOUR-OVH ; console sans ligne rouge.
2. F11 → Mappings installés → Contrôler les maps chez moi : tout « bâtiment chargé ».
3. Décisions « nouveau / ancien » (casino, concession, Ammu-Nation, Benny's, prison) → je recale.
4. Test prison, F4 police / EMS en service, garde-robe (U), clés, tenues.
5. PUBLIER-SITE.bat (mode léger du site).
6. Sauvegarde de la base (SAUVEGARDER-BDD ou celle du VPS) la veille.
7. Le jour J : `roadline public` sur le VPS, redémarrage, vérifier que le serveur apparaît dans la liste FiveM.

## 7. Après l'ouverture (déjà prévu)

entityLockdown strict, audit détaillé des 332 points d'entrée réseau, refonte des cabines téléphoniques, miniatures du
menu d'apparence, mises à jour ox_lib / ox_inventory / oxmysql (jamais pendant la semaine d'ouverture).
