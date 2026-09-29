# Photos Vibe, stories et bodycam

Tout est prêt dans le code ; il reste deux choses à faire de ton côté, sinon le bouton 📷 reste simplement masqué.

## 1. Installer screenshot-basic
Ressource officielle Cfx.re qui capture l'écran du joueur. Télécharge-la depuis son dépôt officiel (citizenfx/screenshot-basic),
place-la dans `resources/[standalone]/screenshot-basic`, puis retire le `#` devant `ensure screenshot-basic` dans
`cfg/resources.cfg` (METTRE-A-JOUR remettra la ligne : garde ton `ensure` dans un cfg privé si besoin).

## 2. Choisir un hébergeur d'images
Un service qui accepte un envoi `multipart/form-data` et répond en JSON avec l'adresse de l'image (par exemple Fivemanage,
ou ton propre petit serveur). Dans `cfg/secrets.cfg` :
```
set gs_photo_upload_url "https://…/upload"      # adresse d'envoi
set gs_photo_auth "CLE_API"                     # si l'hébergeur demande une clé (en-tête Authorization)
set gs_photo_field "file"                       # nom du champ fichier
set gs_photo_url_field "url"                    # champ JSON de la réponse contenant l'adresse
set gs_photo_allowed_host "https://…/"          # début des adresses acceptées (le reste est refusé)
```
Pourquoi c'est sûr : le joueur envoie sa capture **au serveur**, et c'est le serveur qui l'envoie à l'hébergeur : la clé
ne quitte jamais le serveur. Les adresses d'images affichées sont limitées à ton hébergeur (pas de traçage d'IP par un
site tiers). Taille max 1,5 Mo, une photo toutes les 20 s par joueur.

## Ce que ça débloque
- Vibe : bouton 📷 → photo dans un post, ou **story 24 h** (bandeau en haut du fil).
- **Heure dorée** (18 h – 20 h, heure du jeu) : une photo par jour rapporte de l'XP.
- Police : **capture bodycam** jointe à un rapport (F4 → Dossiers → Rapports → Nouveau rapport).
