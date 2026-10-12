# Importer des mods (véhicules, vêtements, maps / MLO, scripts)

## En 3 gestes
1. Sur ton Drive : clic droit sur le dossier **GTA** → **Télécharger** (Google fait un ou plusieurs .zip).
   Ou plus simple : installe **Google Drive pour ordinateur** ; le script trouve tout seul `G:\Mon Drive\GTA`.
2. Pose ces .zip tels quels dans `C:\GTASOON\mods-a-trier` (créé au premier lancement).
3. Double-clic sur **IMPORTER-MODS.bat**.

Le script décompresse tout (zip, rar, 7z, même imbriqués ; installe 7-Zip s'il manque), reconnaît chaque mod, le
contrôle et le range dans `C:\GTASOON\mods-tri\` :
- **vehicules / maps / vetements** prêts pour FiveM → installés dans `resources\[addons]\gsa_<nom>` + `cfg\addons.cfg`
  (jamais écrasé par METTRE-A-JOUR ; mets un `#` devant une ligne pour couper un mod) ;
- **a-convertir** : mods « solo » (dlc.rpf, vêtements qui remplacent ceux du jeu) ;
- **scripts-a-verifier** : scripts, jamais installés sans relecture ;
- **rejetes** : scripts ESX seuls, code obfusqué, packs graphiques (reshade, oiv), **marques réelles**.

## Réparer un pack abîmé (« Map ARRÊTÉE … fichier abîmé », « Invalid fixup », « Unexpected end of archive »)
1. portal.cfx.re → **Granted Assets** → retélécharger le pack (le zip complet, sans l'ouvrir).
2. Le mettre dans `C:\GTASOON\mods-a-trier` en **remplaçant** l'ancien (même nom, pas de « (1) »).
3. Double-clic **IMPORTER-MODS.bat** : le rapport doit dire « INSTALLÉ » et la console aucune ligne rouge « ARCHIVE INCOMPLÈTE ».
4. **METTRE-A-JOUR-OVH.bat**, puis redémarrer. Console ~20 s après : « Intégrité des maps : … aucun fichier abîmé ».

## Blips des maps sur la carte (V12.29)
Tous les joueurs voient un blip nommé par lieu (`PUBLIC` dans gs_admin/server/maps.js : nom, icône, couleur ; `false` = pas
de blip pour les lieux secrets : QG de gang, labo, garage clandestin, villa privée). Une map arrêtée perd son blip.
Une map d'activité sans son script (laser game, karting, auto-tamponneuses, foot, billard) a un blip « (bientôt) ».

## Bâtiment invisible, ou aucun point pour jouer (V12.30)
- **Pas de point pour jouer** : laser game, karting, auto-tamponneuses, foot, billard sont des **scripts** de l'auteur.
  La map seule = le décor. Console du serveur : « DÉCOR SEUL ». Depuis la V12.31, le script livré dans le même pack est
  installé avec sa map (voir « Scripts compagnons » ci-dessous).

## Scripts compagnons des maps payantes (V12.31)
Avant : la map s'installait, son script partait dans `scripts-a-verifier` → « les maps sont là mais les scripts ne
démarrent pas ». Maintenant, un script **chiffré (escrow)** dont le nom correspond à une map installée (même mot :
plasmagame, bumpercar, villa_bunker…) est installé avec elle :
- sous son **nom d'origine** (pas de préfixe `gsa_`) : ses exports et ses dépendances l'appellent par ce nom ;
- seulement si **toutes ses dépendances** sont sur le serveur (`qb-core` = qbx_core, `qb-target` / `qtarget` = ox_target,
  `mysql-async` = oxmysql) ou dans le même import (une librairie du vendeur est alors installée aussi) ;
- jamais s'il est ESX seul. Un script lisible (non chiffré) reste à relire avant installation.
Rapport : « INSTALLÉ (nom_du_script, avec gsa_map) » ou « il lui manque … sur le serveur ». Console du serveur :
« Script de map activé mais NON démarré » si la licence, une dépendance ou le renommage bloque.
- **Bâtiment invisible** sans erreur dans la console : en jeu, **F11 → Monde et lieux → Mappings installés → Contrôler les
  maps chez moi**. Pour chaque map : « bâtiment chargé », « aucun modèle reçu » (fichiers absents → réimporter ; ou cache →
  VIDER-CACHE-FIVEM), « reçus mais illisibles » (licence Cfx : pack acheté avec un autre compte que celui de la clé du
  serveur, ou fichier abîmé → retélécharger), « pack incomplet ». Le résultat est aussi écrit dans la console du serveur.

## Packs payants protégés (escrow Cfx, fichier `.fxap`) — V12.18
- Ils ne marchent **que** s'ils ont été achetés avec le compte Cfx.re (keymaster) **lié à la clé de licence du serveur**.
  Sinon la console du serveur affiche « You lack the required entitlement » et la map n'apparaît pas.
- Télécharge-les depuis le portail Cfx (Granted Assets) et **vérifie que le zip s'ouvre** : « Unexpected end of archive »
  dans la console d'IMPORTER-MODS = téléchargement coupé → à retélécharger.
- Map / véhicule / vêtement protégé : installé tel quel (rien n'est modifié, pas d'optimisation de textures), même avec
  un petit script chiffré dedans (portes, ascenseurs).
- Script payant seul, sans map correspondante : rangé dans **scripts-a-verifier**, pas installé (dis-moi si tu le veux).
  Script compagnon d'une map installée : installé avec elle (V12.31, voir plus haut).
- **Maps retirées / remises** : `RETIRED_MAPS` (maps.js) les supprime au démarrage et les note dans `mods-retires.txt` ;
  depuis la V12.34, IMPORTER-MODS lit aussi `RETIRED_MAPS` : jamais réinstallées, même supprimées à la main avant le redémarrage ;
  `$Restored` (importer-mods.ps1) les en sort pour qu'elles reviennent depuis leur archive. 12/10 : villa moderne 01
  retirée, **villa bunker remise**.
- **Archive incomplète** (« Unexpected end of archive » à la décompression) : depuis la V12.27, le pack n'est PAS installé et
  s'il l'était déjà, il est désactivé dans `cfg\addons.cfg`. Un fichier tronqué fait planter chaque joueur qui le charge
  (« Invalid fixup, address is neither virtual nor physical (in xxx.ydr) »). Retélécharger, puis relancer IMPORTER-MODS.
- Console du serveur après installation : « Failed to verify protected resource » = fichier `.fxap` manquant (zip mal
  extrait ou mal envoyé) → réimporter le zip d'origine.

Mods « solo » (dlc.rpf faits avec OpenIV) : ouverts automatiquement (archives non chiffrées), sans OpenIV.
Mods livrés avec un dossier « FiveM » : c'est cette version qui est installée.
Véhicules : ajoutés au catalogue Qbox (`qbx_core/shared/vehicles.lua`, bloc « GTA SOON ADDONS ») → concession et
garages ; prix et noms réglés dans `importer-mods.ps1` ($Prices, $Labels), sinon selon la catégorie. Le catalogue
est reconstruit depuis tous les mods actifs de `addons.cfg`. Véhicules de service (VC_EMERGENCY) : pas en concession,
mais dans le garage du métier (visibles seulement si le mod est installé).
Packs > 300 Mo : pas installés, sauf ceux de `$PackPick` réduits aux modèles choisis.
Kits de tuning > 16 Mo : retirés automatiquement avec leurs pièces liées, la voiture reste.
Vêtements « solo » : ceux pour le perso FiveM sont convertis par Claude (outil `tools/vetements/`, zips
ROADTRIP-*.zip) ; ceux pour Franklin / Michael / Trevor et les simples recolorations ne sont pas convertibles.
Lancé par METTRE-A-JOUR : l'import est sauté si rien n'a changé dans mods-a-trier (et si l'importeur n'a pas changé).

Textures trop lourdes (« Oversized assets ») : optimiseur tools/textures actif (GTASOON_TEXOPT=0 pour le couper) :
seulement les .ytd > 48 Mo, mipmaps retirés / réduction 2x, ~34 Mo max par .ytd, jamais sous 256-512 px.
Contrôles : textures > 16 Mo (disparition de textures / crash), mod > 150 Mo, noms de spawn des véhicules.
À la fin : `RAPPORT-MODS.txt` s'ouvre → copie-colle-le moi : je branche les véhicules (concession, garages), les maps
(coords, blips, portes) et je relis les scripts.

## Où sont mes maps ? (F11, V12.10)
Plus besoin de connaître les coordonnées : au démarrage, le serveur lit les fichiers `.ymap` de chaque map installée
(ressource `gsa_*` ou marquée `this_is_a_map`) et en déduit son emplacement. En jeu, en mode staff :
**F11 → Monde et lieux → Mappings installés** → chaque map avec son quartier → clic = téléportation dedans (au sol de
l'intérieur, pas sur le toit). « Afficher leurs blips sur ma carte » : blips visibles par toi seul pour faire le tour.
Console au démarrage : `[gs_admin] Mappings : N installé(s), N situé(s), aucun conflit`.
**Conflit** = deux maps qui remplacent le même fichier du jeu (`.ymap`, `.ybn`, `.ytyp`) : une seule des deux
s'affiche correctement (trous, murs invisibles, textures qui clignotent). Le menu et la console donnent le fichier et
les deux maps. Deux copies **identiques** du même fichier ne comptent pas (aucun effet).
**Conflit d'occlusion** (`*_occl_*.ymap`, le cas le plus courant : chaque MLO retire du jeu ce qui cacherait son intérieur) :
**réglé tout seul depuis la V12.13**. 15 s après le démarrage, `gs_admin` fusionne les versions (on garde ce qui est présent
dans toutes, donc les deux intérieurs s'affichent), écrit le résultat dans la ressource `gsa_zz_fusion_occlusion` et la
relance pour qu'elle passe après toutes les maps. Console : ligne verte « fusion », puis « Conflit résolu ». Fusion
impossible (fichier abîmé) : la version du magasin d'alcool de Paleto est gardée (choix du 12/10). Rien à envoyer.
Outil hors serveur, même algorithme : `tools/maps/fusion_occlusion.py`. Autre type de conflit :
en garder une (mettre un `#` devant l'autre dans `cfg\addons.cfg`).
Map sans lieu dans la liste : soit un **habillage** d'objets du jeu (ex. `hp_fleeca` retexture les 6 agences Fleeca, normal),
soit une map **vide** (aucun fichier de jeu, ex. `moto_free_shell`), à supprimer.
**Modèle trop lourd** : la mémoire réelle de chaque modèle / texture est lue dans son en-tête. Signalé (menu, console en jaune)
seulement au-delà de la limite de FiveM, la même que l'importeur : **48 Mo de mémoire graphique ou 64 Mo de mémoire système**
(V12.14 ; la V12.11 alertait à tort dès 16 Mo). Seuls les vrais fichiers de map comptent : vêtements et véhicules importés
n'apparaissent pas dans la liste. **Monde et lieux est réservé au super-admin et au fondateur.**
**Retirer une map** (V12.15) : F11 → Mappings installés → la map → « Retirer cette map » : arrêtée tout de suite, sa ligne de
`cfg\addons.cfg` passe en commentaire (plus chargée, IMPORTER-MODS respecte le #). Pour la remettre : enlever le #.
Une fusion d'occlusion devenue inutile (une des deux maps retirée) est supprimée au démarrage suivant.
**Supprimer définitivement** (V12.17) : F11 → Mappings installés → « Supprimer définitivement toutes les maps » (taper
SUPPRIMER) : dossiers `[addons]\gsa_*` des maps, leurs lignes de `addons.cfg`, leurs copies dans `mods-tri\maps` et leurs
archives dans `mods-a-trier` effacés ; noms ajoutés à `C:\GTASOON\mods-retires.txt`, que IMPORTER-MODS respecte (jamais
réinstallés, même depuis une archive groupée ; enlever une ligne pour le permettre). Vêtements et véhicules non touchés.

## Outils liés
- `VIDER-CACHE-FIVEM.bat` : après un changement de mods ou un crash « Streamer crashed » — ferme FiveM, vide cache,
  server-cache, server-cache-priv (garde cache\game) et le cache du serveur s'il est arrêté.
- Vêtements convertis (désactivés au départ dans cfg\addons.cfg) : en boutique, à la FIN des listes (numéros les plus
  hauts) — femme : Cheveux (6 coiffures).
- `NETTOYER-MARQUES.bat` : supprime de ton PC les mods de marques réelles déjà installés, leurs archives et leurs
  copies dans `mods-tri` (marque dans le nom du mod OU dans le nom d'un de ses fichiers, comme l'importeur).

## Marques réelles : refusées
Voitures, vêtements, boutiques et polices de marques ou d'organisations réelles sont **refusés** par l'importeur (liste
`$BrandBlock` dans `importer-mods.ps1`) : risque de retrait du serveur par Cfx.re / Rockstar et de demandes DMCA
(voir docs/BOUTIQUE_LEGAL.md, docs/VEHICULES_ADDON.md). Cherche des versions « lore GTA » (Pegassi, Grotti, Übermacht…).
