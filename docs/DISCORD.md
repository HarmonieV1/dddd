# Discord de Roadtrip : structure conseillée

Un modèle Discord ne contient que des salons, rôles et permissions. Le plus fiable : créer la structure ci-dessous une
fois, puis **Paramètres du serveur → Modèle de serveur → Générer un lien** pour la dupliquer. (Des modèles communautaires
existent aussi, par ex. xenon.bot/templates/for/fivem : vérifie les permissions avant d'en importer un.)

## Rôles (du plus haut au plus bas)
Fondateur · Super-admin · Admin · Modérateur · Helper · Bot · Whitelisté · Candidat · Visiteur
(les mêmes rangs qu'en jeu ; les rangs en jeu se donnent dans le menu staff F11, pas via Discord)

## Catégories et salons
- **📢 ACCUEIL** : `règlement` (lecture seule, même texte que /regles), `annonces`, `mises-à-jour`, `statut-serveur`
- **📝 CANDIDATURES** : `comment-candidater`, `candidatures` (formulaire → staff), `résultats`
- **💬 COMMUNAUTÉ** : `général`, `médias`, `clips`, `idées`, `vibe-miroir` ← webhook `gs_webhook_social`
- **⚖️ TRANSPARENCE** : `sanctions` ← webhook `gs_webhook_sanctions` (public, staff anonyme)
- **🛟 SUPPORT** : `aide`, `signaler-un-bug`, `tickets` (bot de tickets au choix), `remboursements`
- **🎭 RP HORS JEU** : `entreprises` (recrutements), `gangs` (sur candidature), `événements`
- **🔒 STAFF** (Helper+) : `staff-général`, `logs-staff` ← `gs_staff_webhook`, `logs-jobs` ← `gs_webhook_jobs`,
  `logs-boutique` ← `gs_webhook_boutique`, `vocal-staff`
- **🔊 VOCAL** : `Salle d'attente support`, `Détente`, `Événements`

Webhooks : clic droit sur le salon → Modifier → Intégrations → Webhooks → copier l'adresse dans `cfg/secrets.cfg`.
