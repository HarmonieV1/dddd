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
- **rejetes** : scripts chiffrés (escrow), ESX, code obfusqué, packs graphiques (reshade, oiv), **marques réelles**.

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
envoie-moi ce fichier depuis le dossier de **chacune** des deux maps ; je les fusionne (`tools/maps/fusion_occlusion.py` :
on garde ce qui est présent dans toutes les versions) et je te renvoie `zz_fusion_occlusion.zip` à mettre dans
`mods-a-trier` puis IMPORTER-MODS. Son nom `gsa_zz_…` le fait démarrer après les maps (addons.cfg est trié par ordre
alphabétique) : c'est sa version qui compte, et F11 / la console affichent « conflit résolu » en vert. Autre type de conflit :
en garder une (mettre un `#` devant l'autre dans `cfg\addons.cfg`).
Map sans lieu dans la liste : soit un **habillage** d'objets du jeu (ex. `hp_fleeca` retexture les 6 agences Fleeca, normal),
soit une map **vide** (aucun fichier de jeu, ex. `moto_free_shell`), à supprimer.
**Modèle trop lourd** (V12.11) : la mémoire réelle de chaque modèle / texture est lue dans son en-tête. Au-delà de 16 Mo,
FiveM prévient que l'objet peut ne pas s'afficher (murs ou textures invisibles chez les PC modestes) : signalé dans le
menu et en console en jaune. Le poids du fichier ne suffit pas (le gym Moreo : 15,3 Mo sur le disque, 26,5 Mo en mémoire).

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
