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
- **rejetes** : scripts chiffrés (escrow), ESX, code obfusqué, packs graphiques (reshade, oiv).

Mods « solo » (dlc.rpf faits avec OpenIV) : ouverts automatiquement (archives non chiffrées), sans OpenIV.
Mods livrés avec un dossier « FiveM » : c'est cette version qui est installée.
Véhicules : ajoutés au catalogue Qbox (`qbx_core/shared/vehicles.lua`, bloc « GTA SOON ADDONS ») → concession et
garages ; prix et noms réglés dans `importer-mods.ps1` ($Prices, $Labels), sinon selon la catégorie. Le catalogue
est reconstruit depuis tous les mods actifs de `addons.cfg`. Véhicules de service (VC_EMERGENCY) : pas en concession,
mais dans le garage du métier (ex. police : Charger 2023, Explorer, Tahoe, Charger banalisée, visibles seulement si le
mod est installé).
Packs > 300 Mo : pas installés, sauf ceux de `$PackPick` réduits aux modèles choisis (Dallas : 4 véhicules, 117 Mo).
Kits de tuning > 16 Mo (ex. Panamera) : retirés automatiquement avec leurs pièces liées (162 → 46 Mo), la voiture reste.
Vêtements « solo » : ceux pour le perso FiveM sont convertis par Claude (outil `tools/vetements/`, zips
ROADTRIP-*.zip) ; ceux pour Franklin / Michael / Trevor et les simples recolorations ne sont pas convertibles.
Lancé par METTRE-A-JOUR : l'import est sauté si rien n'a changé dans mods-a-trier (et si l'importeur n'a pas changé).

Textures trop lourdes (« Oversized assets ») : optimiseur tools/textures DÉSACTIVÉ par défaut depuis un crash « Streamer crashed » (réactivable avec GTASOON_TEXOPT=1 pour tests ;
mipmaps retirés / réduction 2x, ~40 Mo max par .ytd, jamais sous 256-512 px). Ex. : Charger 209 → 54 Mo, Fenomeno 175 → 44 Mo.
Contrôles : textures > 16 Mo (disparition de textures / crash), mod > 150 Mo, noms de spawn des véhicules.
À la fin : `RAPPORT-MODS.txt` s'ouvre → copie-colle-le moi : je branche les véhicules (concession, garages), les maps
(coords, blips, portes) et je relis les scripts.

## Marques réelles (Gucci, Versace, Lamborghini…)
Pour des tests entre amis, pas de souci. Avant d'ouvrir au public ou de vendre quoi que ce soit : pas de marques réelles
en boutique (voir docs/BOUTIQUE_LEGAL.md), privilégier des versions « lore GTA » (Pegassi, Grotti, Übermacht…).
