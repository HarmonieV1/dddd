# Stratégie V1 : ce qu'ont les gros serveurs, ce qu'on a, ce qu'on ajoute

Analyse [DEV] (à affiner avec Alpha, qui connaît la concurrence FR de l'intérieur).

## 1. L'essentiel attendu par les joueurs FR (hygiène de base)
| Brique | Chez nous | Action proposée |
|---|---|---|
| Création de perso + vêtements | illenium-appearance (V1_RESOURCES) | installer, magasins de vêtements |
| Téléphone | ❌ | **priorité 1** : téléphone open-source audité (ou payant type lb-phone, décision budget) ; Néon s'y intègre comme app |
| Logement / planques | ❌ | **priorité 2** : qbx_properties (Qbox) à auditer |
| Gangs / territoires | ❌ | **priorité 3** : étendre gs_jobs (les gangs = jobs « illégaux » avec caisse, grades, planque) + territoires liés à gs_wanted |
| Économie illégale (drogue, recel) | recel partiel (ferrailleur) | boucle drogue maison branchée sur gs_economy (prix) + gs_wanted (témoins) |
| Braquages | ❌ | supérettes → bijouterie → banque, branchés sur gs_wanted + gs_duo |
| Entreprises joueurs (resto, bar, concession) | jobs + caisses ✅ | ajouter des jobs « entreprise » + commerces qui s'approvisionnent via gs_economy |
| HUD | ❌ | **HUD néon maison** (vie, faim, argent, étoiles, météo) |
| Garages / concession / carburant | qbx_* + ox_fuel | installer (V1_RESOURCES) |
| Police/EMS gameplay (menottes, fouille, réa) | qbx_policejob / qbx_ambulancejob | installer, brancher le dispatch gs_wanted |
| Staff / modération | ✅ txAdmin + gs_admin | — |
| Anti-triche | ✅ validation serveur partout + durcissement cfg | évaluer un anticheat reconnu avant l'ouverture publique |

## 2. Là où on est déjà devant (à mettre en avant dans la com)
- **Recherche intelligente** (témoins / heure / météo) : la plupart des serveurs n'ont que des alertes « tir détecté » systématiques.
- **Économie vivante** (offre/demande + événements météo) : rare en FR.
- **Duo lié** façon GTA 6 : quasi inexistant.
- **Météo événementielle + golden hour** : identité visuelle forte.
- **Néon + miroir Discord** : la vie de la ville visible hors du jeu, gros levier communautaire.
- **Transparence des sanctions** : argument de confiance face aux serveurs à « main team ».
- **Qualité** : 360+ tests automatiques, CI, rate-limit partout. Les crashs et dupes sont la 1re cause d'abandon d'un serveur.

## 3. Idées signature (à valider par Alpha)
1. **Braquages dynamiques** : la réussite dépend de l'heure, de la météo, des témoins et du niveau de duo ; les flics reçoivent un dispatch plus ou moins précis.
2. **Territoires** : chaque quartier a une « chaleur » (crimes signalés) ; gangs = influence, police = patrouilles bonus.
3. **Journalistes Weazel-like maison** : job qui publie des « flash infos » officiels sur Néon (badge vérifié) et sur Discord.
4. **Courses de rue** : départs clandestins, paris en argent in-game, signalement aux flics selon les témoins.
5. **Influence Néon** : abonnés, posts tendance, badge « vérifié » ; sponsoring RP entre joueurs.
6. **Nuits de Vice** : événements du vendredi soir (golden hour prolongée, néons, clubs, DJ).
7. **Companion web** : fiche perso, fil Néon sur mobile, sanctions publiques, roadmap.

## 4. Ordre recommandé
Test en jeu V1 → **téléphone** → **HUD néon** → **gangs + territoires** → **braquages** → **drogue** → logement → companion web.
