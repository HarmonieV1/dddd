# Boutique (gs_store + Tebex)

## ⚠️ À lire AVANT d'ouvrir les ventes (décision Alpha)
Les règles Cfx.re ont changé en 2026. Des analyses publiques signalent que le Creator PLA de janvier 2026
définit des « Virtual Items » (véhicules, skins…) et semble en restreindre la vente, et un PLA daté du
**10 septembre 2026** existe ([PLA officiel](https://static.cfx.re/platform-license-agreement-10-sept-2026.pdf),
[analyse Prism News](https://www.prismnews.com/news/cfxre-creator-pla-update-threatens-fivem-and-redm-monetization-models),
[guide FiveM Coach 2026](https://fivemcoach.com/blog/fivem-monetization-rules)).
[DEV] n'a pas pu lire le texte officiel depuis son environnement. **Alpha doit le lire (ou le faire lire)
et confirmer ce qui est vendable avant de passer `Config.Enabled = true`.** C'est pour ça que la boutique
est livrée désactivée : les achats sont enregistrés, rien n'est réclamable.

## Règles maison (prompt maître, non négociables)
| ✅ Autorisé | ❌ Interdit |
|---|---|
| Tenues, skins, véhicules **créés pour nous** ou **sous licence** | Marques réelles, véhicules « débadgés » d'autres jeux, personnages connus (IP tierce) |
| Véhicules aux **performances identiques** à un équivalent achetable en jeu | Véhicule plus rapide/résistant qu'en jeu (pay-to-win) |
| Confort : slot de perso, plaque perso, emplacement de garage | Argent in-game, armes, items de gameplay, loot box |
| Tebex uniquement | Tout autre moyen de paiement |

Chaque contenu vendu : fichier source et licence gardés (preuve), relu par [DEV] (audit sécurité, docs/SECURITY.md).

## Fonctionnement
1. Le joueur achète sur Tebex (connecté avec son compte **Cfx.re**).
2. Tebex exécute une commande **console** sur le serveur : `gsstore_deliver <transaction> <package> <id Cfx.re>`.
3. La commande est enregistrée une seule fois (`gs_store_orders`, transaction unique : pas de double livraison).
4. En jeu : `/boutique` → « À récupérer » → le joueur choisit **le personnage** qui reçoit le pack (définitif).
5. Skins et tenues : applicables depuis `/boutique` ; véhicule : ajouté au garage du personnage.
6. Remboursement / chargeback : Tebex exécute `gsstore_revoke <transaction>` → skins/tenues retirés ;
   un véhicule déjà livré est signalé au staff (webhook `gs_webhook_boutique`) pour retrait manuel.

Sécurité : les commandes `gsstore_*` sont **refusées en jeu, même pour un admin** (console / Tebex uniquement),
et toute tentative est loggée.

## Installation Tebex ([CONFIG])
1. Créer la boutique sur tebex.io (type FiveM), relier le serveur : clé secrète dans `cfg/secrets.cfg` :
   `set sv_tebexSecret "..."` (voir docs.fivem.net → *Setting up a Tebex store*).
2. Pour chaque package Tebex, commande à l'achat :
   `gsstore_deliver {transaction} pack_neon_rider {id}` — la clé (`pack_neon_rider`) = une entrée de `Config.Packages`.
   **[À VÉRIFIER dans le panel Tebex]** le nom exact des variables (`{transaction}`, et celle qui donne
   l'identifiant Cfx.re de l'acheteur) ; ne PAS cocher « nécessite que le joueur soit en ligne » (la réclamation se fait en jeu).
3. Commande au remboursement / chargeback : `gsstore_revoke {transaction}`.
4. Déclarer packages, skins et tenues dans `gs_store/shared/config.lua` (les exemples actuels sont des placeholders vanilla).
5. Tester avec un achat à 0 € / mode test Tebex sur le serveur de dev.

## Impact / risques / rollback
- Tables : `gs_store_orders`, `gs_store_unlocks`, `gs_store_prefs`.
- Risques : conformité PLA (ci-dessus) ; noms d'API `[API]` (qbx_vehicles, illenium-appearance) à confirmer.
- Rollback : `Config.Enabled = false` (les commandes continuent d'être enregistrées), ou retirer `ensure gs_store`.
