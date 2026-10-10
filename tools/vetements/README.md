# Conversion de vêtements (solo MP -> addon FiveM)

Outil de dev (pas utilisé par le serveur). `Tool.cs` : petit CLI autour de CodeWalker.Core
(`ymt2xml` / `xml2ymt`). `gen.py` : regroupe des .ydd/.ytd freemode (mp_m / mp_f) en une
collection addon (ymt + ShopPedApparel .meta + fxmanifest `SHOP_PED_APPAREL_META_FILE`).

Les packs pour Franklin / Michael / Trevor (player_zero/one/two) ne sont pas convertibles :
modèles différents du ped freemode.
