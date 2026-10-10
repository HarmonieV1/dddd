# Checklist de lancement V1

Cocher dans l'ordre. Chaque ligne rouge en console = on s'arrête et on l'envoie à [DEV].

## A. Installation (Alpha) — outils à la racine du dossier GTA SOON
- [x] FiveM se lance (docs/FAQ_FIVEM.md, outil `scripts/windows/diagnostic-fivem.bat`)
- [x] MariaDB installé + `REPARER-MARIADB.bat`
- [x] `INSTALLER.bat` (Qbox officiel + GTA SOON) → `C:\GTASOON\server-data`
- [x] Licence : `CHANGER-LICENCE.bat` (lit la clé copiée, répare un double collage)
- [ ] `DEVENIR-ADMIN.bat` après une première connexion (écrit ton `license:` en group.god)
- [ ] Mises à jour suivantes : `METTRE-A-JOUR.bat` (sauvegarde auto dans `C:\GTASOON\sauvegardes`)

## B. Premier démarrage (envoyer la console à [DEV])
- [x] `Server license key authentication succeeded`
- [x] `[gs_jobs] prêt : 6 jobs chargés`, les 16 `gs_*` démarrés
- [x] Corrigé : `;` dans les cfg (« No such command les »), `onesync`, `hardcap`, `sv_endpointPrivacy`, item `scrapmetal`
- [ ] Aucune ligne `[gs_bridge] ... a échoué` à la première connexion (sinon : un nom d'API Qbox à corriger)
- [ ] Écran de chargement néon visible à la connexion
- [x] Corrigé : `qbx_idcard` non démarré → création de perso bloquée (écran noir, chargement infini)
- [x] Corrigé : écran noir après création (qbx_core attend un choix d'appartement absent) → gs_bridge bascule sur le spawn centre-ville + création d'apparence
- [x] Build du jeu 3570 (véhicules récents connus de qbx_core)
- [ ] Connu, sans effet : `Table 'properties' does not exist` (logement Qbox = V2)

## C. Tests en jeu ([TEST], plans détaillés dans docs/tests/)
- [ ] Jobs : docs/tests/phase1-jobs.md
- [ ] Météo, recherche, économie, duo : docs/tests/phase2-signature.md
- [ ] Néon : pseudo, post, like, mention, suppression, miroir Discord
- [ ] `resmon 1` : chaque `gs_*` < 0,5 ms au repos, 0 erreur console (client F8 + serveur)
- [ ] Test à 2 joueurs minimum (duo, embauche, facture, dispatch)

## D. Avant ouverture publique
- [ ] Coords calées en jeu (points de service, garages, commerces, étapes de mission)
- [ ] Équilibrage : salaires, prix, chances de signalement
- [ ] Profil prod (`cfg/prod.cfg`) + durcissement validé en dev
- [ ] Webhooks Discord remplis (staff, jobs, annonces, social, boutique)
- [ ] Backups automatiques (`scripts/backup_db.sh` / backups txAdmin) + test de restauration
- [ ] Boutique : PLA Cfx 2026 lu et validé (docs/BOUTIQUE.md) avant `Config.Enabled = true`
- [ ] Merge `feature/phase1-bridge` → `main` (validation Alpha)

## V2 — à tester en jeu (Alpha)
- [ ] F11 : mode staff ON, vol libre, invisible, invincible, animal puis forme humaine, spectate, TP marqueur, noms/ID
- [ ] F11 : me mettre police grade 2, puis un gang ; items (fondateur) : donner / retirer / poser au sol
- [ ] Nouveau perso homme → Max (mairie) → Big Sal ; nouveau perso femme → Mama Rosa (chaînes différentes)
- [ ] Livraison chronométrée (Big Sal) ; Nuit Néon refusée le jour, OK après 20 h
- [ ] F5 : barre d'XP, abandon de quête ; un paquet caché ; annonce NIVEAU SUPÉRIEUR
- [ ] Location : louer une citadine, la rendre, laisser expirer
- [ ] Drogue : vente avec choix du produit + échange animé ; `/deal` (un client vient)
- [ ] Caler les coords (F11 → Copier mes coordonnées) : personnages, comptoirs, paquets, labo coke

## V2.1 — à tester en jeu
- [ ] HUD sans cadre (texte néon seul)
- [ ] Supérette : acheter téléphone, bière (effet), cigarettes + briquet ; caviste ; quincaillerie
- [ ] À terre sans EMS : [G] secours IA, paiement ; réapparition possible après 70 s, hôpital 500 $, inventaire gardé
- [ ] Crime sans policier en service : étoiles GTA, puis « la police a perdu ta trace »
- [ ] Choix du lieu d'apparition (persos existants) : Mairie, Legion, Pôle Emploi, Del Perro, Motels, Sandy, Paleto
- [ ] F5 : titre, série, 3 défis du jour, badges ; Néon : titre à côté du pseudo ; F10 : progression dans la fiche

## V2.2 — à tester en jeu
- [ ] Police / EMS / mécano en service : cercles violets (service, armurerie, coffre, direction, garage) ; armurerie = équipement gratuit selon le grade
- [ ] F11 → Points de métier : déplacer l'armurerie / le coffre LSPD dans une partie ouverte du commissariat
- [ ] Gangs par défaut (Families, Ballas, Vagos, Marabunta, Lost MC) : F11 → Me mettre dans un gang ; blip QG + planque
- [ ] Transformation animal (nouveaux animaux) → « Reprendre forme humaine » : on retrouve exactement son perso
- [ ] Max le Guide : « Parler à Max » visible même de loin (zone fixe), PNJ posé au sol

## V2.3 — à tester en jeu
- [ ] [E] près de Max, d'un comptoir de location, d'une supérette, d'un point de métier, d'une planque : le menu s'ouvre
- [ ] (ox_target : appui sur ALT gauche, choisir à la souris, rappuyer sur ALT pour fermer)
- [ ] Vendeur PNJ derrière chaque comptoir (sinon noter les coords avec F11 → Copier mes coordonnées)
- [ ] F11 cliquable à la souris : chaque ligne fait bien ce qu'elle dit (TP marqueur ≠ soin)
- [ ] Menus ox_lib noir-violet néon, accents roses (ligne verte « menus ox_lib en noir néon » dans METTRE-A-JOUR)

## V3 — à tester en jeu
- [ ] F4 police : menotter, escorter, véhicule, fouiller, casier, prison, fourrière, cônes / herse, /radar
- [ ] F4 EMS : réanimer (trousse), soigner (bandage), porter, ambulance
- [ ] Z en véhicule (portes, moteur, places, vitres), B ceinture, X mains en l'air, /me /do
- [ ] Kits : réparation (moteur), avancé (complet), nettoyage — utilisables sans métier
- [ ] Gang : bombe de peinture → tag ; [G] effacer ; garage du gang ; receleur la nuit ; porte du labo → préparation ×2
- [ ] F10 : tiroir compact à droite ; F11 inchangé
- [ ] Inventaire : vraies icônes (cigarettes, drogues, snacks, colis)
