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
garages ; prix réglés dans `importer-mods.ps1` ($Prices), sinon selon la catégorie. Packs > 300 Mo : pas installés
(on choisit 2-3 éléments). Vêtements « solo » (remplacement) : à convertir (durty cloth tool), pas automatique.

Contrôles : textures > 16 Mo (disparition de textures / crash), mod > 150 Mo, noms de spawn des véhicules.
À la fin : `RAPPORT-MODS.txt` s'ouvre → copie-colle-le moi : je branche les véhicules (concession, garages), les maps
(coords, blips, portes) et je relis les scripts.

## Marques réelles (Gucci, Versace, Lamborghini…)
Pour des tests entre amis, pas de souci. Avant d'ouvrir au public ou de vendre quoi que ce soit : pas de marques réelles
en boutique (voir docs/BOUTIQUE_LEGAL.md), privilégier des versions « lore GTA » (Pegassi, Grotti, Übermacht…).
