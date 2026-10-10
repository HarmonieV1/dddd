# Véhicules « addon » (voitures moddées)

## ⚠️ À lire avant d'ajouter des voitures de vraies marques

Lamborghini, Audi, Mercedes, BMW… sont des **marques déposées**, et la plupart des modèles 3D qui circulent
sont des **rips** de jeux comme Forza ou Assetto Corsa, donc sans licence.

- **Cfx (FiveM)** interdit de **vendre** ou de monétiser du contenu de marques tierces ou sans licence :
  pas de voiture de vraie marque dans la boutique Tebex, ni en avantage payant.
  L'enjeu, c'est la suspension de la clé serveur.
- Pour les **ayants droit**, un serveur public avec des modèles rippés s'expose à une demande de retrait (DMCA).
- Règle GTA SOON (prompt maître) : **aucune IP tierce**.

**Ce qui reste possible :**
1. Les véhicules **du jeu** qui s'en inspirent, prêts tout de suite et sans risque :
   Pegassi **Toros** (SUV « Urus »), Obey **10F** (« R8 »), Obey **Tailgater S** (« A4/S4 »),
   Benefactor **Schlagen GT** (« AMG GT »), Übermacht **Cypher** (« M2 »),
   Pfister **Comet S2** (« 911 »), Enus **Paragon R** (« Continental »).
2. Des modèles **originaux**, ou **sous licence explicite de leur auteur** (création gratuite avec autorisation
   écrite, ou achat chez un créateur qui fournit une licence FiveM), **sans logo ni nom de marque réelle**.
3. Le « flex » réel passe par le **style** (couleurs, néons, jantes, plaques perso), pas par le logo.

## Ajouter un véhicule autorisé (5 min)

1. Récupère le pack du créateur. Tu y trouves des `.yft` / `.ytd` (le modèle) et des `.meta` (réglages).
2. Mets les `.yft` et `.ytd` dans `resources/[addons]/gs_cars/stream/`.
3. Crée un dossier `resources/[addons]/gs_cars/data/<nom_du_modele>/` et mets-y ses `.meta`.
4. Dans `cfg/resources.cfg`, décommente la ligne `ensure gs_cars` si ce n'est pas déjà fait.
5. Pour qu'il apparaisse en concession et dans les garages Qbox, ajoute-le à `qbx_core/shared/vehicles.lua`
   (modèle, nom, prix, catégorie) en suivant l'exemple des autres lignes.
6. Redémarre, puis teste en jeu : menu staff **F11 → Faire apparaître un véhicule →** `<nom_du_modele>`.

`METTRE-A-JOUR.bat` ne touche **jamais** à `[addons]` : tes véhicules ne sont pas écrasés par une mise à jour.

## Poids et performance

Chaque voiture addon est téléchargée par tous les joueurs. Vise **moins de 16 Mo par véhicule**
(textures en 2K maximum), et pas plus d'une trentaine de voitures au lancement : sinon, les premiers
chargements seront très longs.
