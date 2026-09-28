# Checklist de lancement V1

Cocher dans l'ordre. Chaque ligne rouge en console = on s'arrête et on l'envoie à [DEV].

## A. Installation (Alpha)
- [ ] FiveM se lance (docs/FAQ_FIVEM.md, outil `scripts/windows/diagnostic-fivem.bat`)
- [ ] MariaDB installé (docs/INSTALL.md)
- [ ] txAdmin + recipe Qbox installés
- [ ] `scripts/windows/brancher-gtasoon.bat` exécuté, sortie sans rouge
- [ ] Étapes Qbox de docs/JOBS.md (jobs en double, maxJobsPerPlayer, item repairkit)
- [ ] Ton `license:` en group.admin dans `cfg/secrets.cfg`

## B. Premier démarrage (envoyer la console à [DEV])
- [ ] `[gs_jobs] prêt : 6 jobs chargés`
- [ ] Aucune ligne `[gs_bridge] ... a échoué` (sinon : un nom d'API Qbox à corriger)
- [ ] Liste des items absents (gs_economy / gs_jobs) notée → déclarer ou retirer
- [ ] Écran de chargement néon visible à la connexion

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
