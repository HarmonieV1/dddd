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
