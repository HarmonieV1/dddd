// GtaSoonTex : allège les dictionnaires de textures (.ytd) trop lourds pour FiveM.
// Principe : chaque texture contient déjà ses versions réduites (mipmaps). On retire le niveau le plus grand
// (4096 -> 2048, 2048 -> 1024...) des plus grosses textures jusqu'à passer sous le budget mémoire. Aucune
// recompression d'image : la qualité des niveaux gardés est intacte, et le résultat est garanti lisible par le jeu.
// Compilé en netstandard2.0 : chargé tel quel par le PowerShell de Windows (IMPORTER-MODS.bat), avec CodeWalker.Core.
using System;
using System.Collections.Generic;
using System.IO;
using CodeWalker.GameFiles;
using CodeWalker.Utils;

namespace GtaSoon
{
    public static class Tex
    {
        static bool IsRaw32(Texture t) => t.Format == TextureFormat.D3DFMT_A8R8G8B8 || t.Format == TextureFormat.D3DFMT_X8R8G8B8 || t.Format == TextureFormat.D3DFMT_A8B8G8R8;

        static bool Odd(Texture t) => t.Width % 2 != 0 || t.Height % 2 != 0 || t.Stride % 2 != 0;

        // Texture non compressée sans mipmaps (ou aux dimensions impaires : ses mipmaps sont alors abandonnés) (souvent des logos / flocages exportés à la va-vite) : réduite de moitié
        // en moyennant chaque carré de 2x2 pixels.
        static int Halve(Texture t)
        {
            int w = t.Width, h = t.Height, nw = w / 2, nh = h / 2;
            int srcPitch = t.Stride;
            var src = t.Data.FullData;
            var dst = new byte[nw * nh * 4];
            for (int y = 0; y < nh; y++)
                for (int x = 0; x < nw; x++)
                    for (int c = 0; c < 4; c++)
                    {
                        int a = (2 * y) * srcPitch + (2 * x) * 4 + c, b = a + srcPitch;
                        dst[(y * nw + x) * 4 + c] = (byte)((src[a] + src[a + 4] + src[b] + src[b + 4] + 2) / 4);
                    }
            int saved = src.Length - dst.Length;
            t.Data.FullData = dst;
            t.Levels = 1;
            t.Width = (ushort)nw; t.Height = (ushort)nh;
            t.Stride = (ushort)(nw * 4);
            return saved;
        }

        /// <summary>Allège un .ytd sur place. budget : octets de textures visés (ex. 40 Mo). minSize : taille
        /// minimale gardée (ex. 512). Retourne « avant|après » en octets, ou null si rien à faire / illisible.</summary>
        public static string Ytd(string path, long budget, int minSize)
        {
            var ytd = new YtdFile();
            ytd.Load(File.ReadAllBytes(path));
            var list = ytd.TextureDict?.Textures?.data_items;
            if (list == null || list.Length == 0) return null;
            var texs = new List<Texture>();
            long total = 0;
            foreach (var t in list)
            {
                if (t?.Data?.FullData == null) continue;
                total += t.Data.FullData.LongLength;
                texs.Add(t);
            }
            long before = total;
            while (total > budget)
            {
                Texture best = null;
                foreach (var t in texs)
                {
                    if (t.Depth > 1 || Math.Min(t.Width, t.Height) / 2 < minSize) continue;
                    if (t.Levels < 2 && !IsRaw32(t)) continue;
                    if (t.Levels >= 2 && Odd(t) && !IsRaw32(t)) continue;
                    if (best == null || t.Data.FullData.LongLength > best.Data.FullData.LongLength) best = t;
                }
                if (best == null) break;
                if (best.Levels < 2 || Odd(best)) { total -= Halve(best); continue; }
                // Taille du plus grand niveau, calculée comme le jeu la relit : Stride (octets par ligne de pixels, à la
                // façon GTA) x hauteur ; chaque niveau suivant fait 1/4.
                int top = best.Stride * best.Height;
                if (top <= 0 || top >= best.Data.FullData.Length) break;
                var rest = new byte[best.Data.FullData.Length - top];
                Buffer.BlockCopy(best.Data.FullData, top, rest, 0, rest.Length);
                best.Data.FullData = rest;
                best.Width = (ushort)(best.Width / 2);
                best.Height = (ushort)(best.Height / 2);
                best.Levels = (byte)(best.Levels - 1);
                best.Stride = (ushort)(best.Stride / 2);
                total -= top;
            }
            if (total == before) return null;
            foreach (var t in texs)
            {
                long expect = 0, len = (long)t.Stride * t.Height;
                for (int i = 0; i < t.Levels; i++) { expect += len; len /= 4; }
                if (expect != t.Data.FullData.LongLength) return null; // incohérence : on ne touche à rien
            }
            var data = ytd.Save();
            // Contrôle : le fichier produit doit se relire, sinon on ne touche pas à l'original.
            var check = new YtdFile();
            check.Load(data);
            if (check.TextureDict?.Textures?.data_items == null || check.TextureDict.Textures.data_items.Length != list.Length) return null;
            File.WriteAllBytes(path, data);
            return before + "|" + total;
        }
    }
}
