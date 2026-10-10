# Optimiseur de textures (utilisé par IMPORTER-MODS.bat)

`GtaSoonTex.dll` (source : `GtaSoonTex.cs`) allège les `.ytd` des mods trop lourds pour FiveM (avertissements
« Oversized assets » dans la console) : retrait du plus grand niveau de mipmap des plus grosses textures (sans
recompression), ou réduction 2x des textures brutes sans mipmaps, jusqu'à ~40 Mo par fichier, jamais sous 512 px.
Le fichier produit est relu avant d'écraser l'original.

Dépendances livrées ici, chargées par le PowerShell de Windows (.NET Framework 4.7.2+, présent sur Windows 10/11) :
- `CodeWalker.Core.dll` : CodeWalker (dexyfex, https://github.com/dexyfex/CodeWalker, commit 485d56b), compilé en
  netstandard2.0 sans modification de fond (ambiguïté `Half` résolue vers SharpDX.Half). Mentions : NOTICE-CodeWalker.txt.
- `SharpDX.dll`, `SharpDX.Mathematics.dll` : SharpDX 4.2.0 (MIT), builds net45 du paquet NuGet.
