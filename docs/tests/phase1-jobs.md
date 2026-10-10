# [TEST] Plan de test — gs_jobs (serveur de dev)

Pré-requis : 3 comptes (Patron, Employé, Civil), `Config.Debug = true`, console + resmon ouverts.

## Cas normaux
- [ ] `/gsjob add <id> police 4` → Patron ; F6 → passer LSPD ; service au point
- [ ] Recruter Employé (grade Cadet) → popup d'offre → accepter → visible dans Employés
- [ ] Promouvoir, rétrograder, licencier ; notification côté Employé
- [ ] Dépôt / retrait caisse ; montant correct en BDD (`gs_societies`)
- [ ] Garage : sortir, ranger ; plaque `LSPD####` ; clés données
- [ ] Coffre Armurerie : refusé grade 0, ok grade 1
- [ ] Amende sur Civil → `/factures` → payer ; 10 % à l'émetteur
- [ ] Pôle Emploi : rejoindre Livreur → véhicule → mission 3 étapes → paie
- [ ] Mécano : réparer une voiture abîmée (kit consommé), nettoyer
- [ ] Paie après 15 min en service (réduire `PayrollMinutes` à 1 pour tester)

## Cas limites
- [ ] 3 contrats puis rejoindre un 4e → refus
- [ ] Offre non répondue 60 s → expirée
- [ ] Déco en service avec véhicule sorti → véhicule supprimé, pas d'erreur console
- [ ] Restart `gs_jobs` à chaud avec joueurs connectés → contrats rechargés
- [ ] Caisse mécano vide → pas de paie + message

## Cas abusifs (triche / dupe)
- [ ] Executor : `TriggerServerEvent('gs_jobs:server:switch', 'police')` sans contrat → refus
- [ ] Spam d'events → rate-limit + log staff
- [ ] Mission : téléport vers l'étape → mission annulée + log
- [ ] Réparation : appeler `finish` sans attendre → refus, kit non consommé
- [ ] Double-clic payer facture → payée une seule fois
- [ ] Retrait caisse montant négatif / décimal → refus
- [ ] `/setjob` natif sans contrat → retiré au prochain login

## Perf
- [ ] resmon `gs_jobs` < 0,5 ms au repos (client et serveur) ; 0 erreur console

Verdict : ✅ GO / ⚠️ GO avec réserves / ❌ NO GO + repro
