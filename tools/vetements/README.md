# Conversion de vêtements (solo MP -> addon FiveM)

Outil de dev (pas utilisé par le serveur). `Tool.cs` : petit CLI autour de CodeWalker.Core
(`ymt2xml` / `xml2ymt`). `gen.py` : regroupe des .ydd/.ytd freemode (mp_m / mp_f) en une
collection addon (ymt + ShopPedApparel .meta + fxmanifest `SHOP_PED_APPAREL_META_FILE`).

Les packs pour Franklin / Michael / Trevor (player_zero/one/two) ne sont pas convertibles :
modèles différents du ped freemode.

## Collections déjà livrées (noms `dlc` à ne JAMAIS réutiliser : deux collections au même nom s'écrasent)
| Ressource | dlc | Ped | Contenu | Date |
|---|---|---|---|---|
| vetements_homme | gsahomme | mp_m | the goat, chaîne dollar, chaîne vine cross | 11/10 |
| coiffures_femme_1 | gsafemme | mp_f | basic, box braids, dreads | 11/10 |
| coiffures_femme_2 | gsafemmeb | mp_f | edgar, leopard print, locs | 11/10 |
| coiffures_homme_2 | gsahommec | mp_m | dreadlocks (Suthyland), Buzzcut Fade ×2, coupe « hair » | 14/10 |
| coiffures_femme_3 | gsafemmec | mp_f | Long Hyun, tresse grzybeek, long braids jazlyn13, long hair, Erika, Alycia, tresse Natt | 14/10 |
| tenues_femme_1 | gsafemmed | mp_f | robe Grace (23 coloris), robe à découpes (18, 1 texture coupée retirée), sweat Lace Up (haut + bas) | 14/10 |
| tenues_femme_2 | gsafemmee | mp_f | robe d'été Dollie Moko (26 coloris), Knee Jeans | 14/10 |

Prochaines : `gsahommed`, `gsafemmef`, puis `g`, `h`… Une archive coupée (texture tronquée) est refusée : la redemander.
Les .rar : `unar` (le 7z du conteneur n'a pas le codec RAR).

Refusés le 14/10 : sac BOOMODS (logo d'une vraie marque de luxe), Afro for Lamar (ped de l'histoire `ig_lamardavis`),
dreadlocks Trycky (archive coupée : à renvoyer). Lace Up Sweats était refusé à tort par l'importeur (« perso solo ») :
c'est un set MP Female (fichiers jbib / accs), converti. Ses pièces « (TORSO & LOWR TO USE) » (uppr_032_r, lowr_003_r) sans
texture ne sont pas reprises : porter le haut / bas du jeu correspondant si la peau dépasse.
