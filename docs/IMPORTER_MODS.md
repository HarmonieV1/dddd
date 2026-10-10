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

## Outils liés
- `VIDER-CACHE-FIVEM.bat` : après un changement de mods ou un crash « Streamer crashed » — ferme FiveM, vide cache,
  server-cache, server-cache-priv (garde cache\game) et le cache du serveur s'il est arrêté.
- Vêtements convertis (désactivés au départ dans cfg\addons.cfg) : en boutique, à la FIN des listes (numéros les plus
  hauts) — femme : Cheveux (6 coiffures).
- `NETTOYER-MARQUES.bat` : supprime de ton PC les mods de marques réelles déjà installés (et leurs archives).

## Marques réelles : refusées
Voitures, vêtements, boutiques et polices de marques ou d'organisations réelles sont **refusés** par l'importeur (liste
`$BrandBlock` dans `importer-mods.ps1`) : risque de retrait du serveur par Cfx.re / Rockstar et de demandes DMCA
(voir docs/BOUTIQUE_LEGAL.md, docs/VEHICULES_ADDON.md). Cherche des versions « lore GTA » (Pegassi, Grotti, Übermacht…).
