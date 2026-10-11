#!/usr/bin/env python3
"""Fusionne plusieurs versions d'un même fichier d'OCCLUSION de GTA V (ex. cs1_occl_10.ymap) livré par deux maps.

Pourquoi : un fichier d'occlusion liste ce que le jeu a le droit de cacher (boîtes et modèles d'occlusion). Chaque MLO
retire les occluders qui feraient disparaître son intérieur. Si deux maps livrent le même fichier, une seule version est
chargée et l'autre intérieur clignote ou disparaît sous certains angles (F11 → Mappings installés → conflit).

Fusion : jeu d'origine S, map A = S − RA, map B = S − RB → ce qu'il faut = S − RA − RB = A ∩ B. On garde donc les
occluders présents dans TOUTES les versions. Le résultat est écrit à la place, sans changer la taille du fichier
décompressé (mêmes en-têtes RSC7), et rangé dans une ressource `zz_fusion_occlusion` qui démarre après les maps
(IMPORTER-MODS classe addons.cfg par ordre alphabétique : gsa_zz_… passe en dernier, donc l'emporte).

Usage :  python3 tools/maps/fusion_occlusion.py SORTIE_DOSSIER fichierA.ymap fichierB.ymap [fichierC.ymap …]
         → SORTIE_DOSSIER/zz_fusion_occlusion/{fxmanifest.lua, stream/<nom>.ymap} (à zipper puis IMPORTER-MODS)
"""
import os
import struct
import sys
import zlib
from collections import Counter

BASE = 0x50000000
CMAPDATA = 0xD3593FA6        # hash Meta de la structure CMapData
BOX_OFF, MODEL_OFF = 128, 144  # CMapData.boxOccluders, CMapData.occludeModels (Array_Structure : pointeur, compte)
BOX_SIZE, MODEL_SIZE = 16, 64  # BoxOccluder : 8 × int16 ; OccludeModel : bmin, bmax, dataSize, verts, … , flags


class Ymap:
    def __init__(self, raw: bytes, name: str = '?'):
        if raw[:4] != b'RSC7':
            raise ValueError(f'{name} : pas un fichier de jeu RSC7 (chiffré ou abîmé)')
        self.name, self.head = name, raw[:16]
        self.data = bytearray(zlib.decompressobj(-15).decompress(raw[16:]))
        d, f = self.data, struct.unpack_from
        if f('<I', d, 0x10)[0] != 0x50524430:
            raise ValueError(f'{name} : pas un fichier Meta (ymap)')
        blocks_ptr, = f('<Q', d, 0x30)
        count, = f('<h', d, 0x4C)
        self.blocks = []  # (hash, longueur, décalage dans data)
        for i in range(count):
            h, ln, ptr = f('<IiQ', d, blocks_ptr - BASE + i * 16)
            self.blocks.append((h, ln, ptr - BASE))
        root, = f('<i', d, 0x1C)
        h, _, off = self.blocks[root - 1]
        if h != CMAPDATA:
            raise ValueError(f'{name} : bloc racine inattendu ({h:#x})')
        self.cmap = off

    def _array(self, field):
        p, _, n, _, _ = struct.unpack_from('<IIHHI', self.data, self.cmap + field)
        if not p or not n:
            return None, 0
        _, _, off = self.blocks[(p & 0xFFF) - 1]
        return off + (p >> 12), n

    def _set_count(self, field, n):
        p, u0, _, _, u1 = struct.unpack_from('<IIHHI', self.data, self.cmap + field)
        struct.pack_into('<IIHHI', self.data, self.cmap + field, p if n else 0, u0, n, n, u1)

    def boxes(self):
        off, n = self._array(BOX_OFF)
        return [bytes(self.data[off + i * BOX_SIZE: off + (i + 1) * BOX_SIZE]) for i in range(n)] if off is not None else []

    def models(self):
        """[(struct de 64 o, clé de comparaison)] : la clé ignore le pointeur (adresse propre au fichier) et inclut les sommets."""
        off, n = self._array(MODEL_OFF)
        out = []
        for i in range(n if off is not None else 0):
            s = bytes(self.data[off + i * MODEL_SIZE: off + (i + 1) * MODEL_SIZE])
            size, = struct.unpack_from('<I', s, 32)
            vp, = struct.unpack_from('<I', s, 40)
            verts = b''
            if vp:
                _, _, boff = self.blocks[(vp & 0xFFF) - 1]
                start = boff + (vp >> 12)
                verts = bytes(self.data[start:start + size])
            out.append((s, s[:40] + s[48:] + verts))
        return out

    def keep(self, boxes, models):
        """Réécrit les tableaux sur place : éléments gardés en tête, compte mis à jour, reste à zéro."""
        for field, items, size in ((BOX_OFF, boxes, BOX_SIZE), (MODEL_OFF, models, MODEL_SIZE)):
            off, n = self._array(field)
            if off is None:
                continue
            blob = b''.join(items)
            self.data[off:off + n * size] = blob + b'\0' * (n * size - len(blob))
            self._set_count(field, len(items))

    def bytes(self) -> bytes:
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        return self.head + c.compress(bytes(self.data)) + c.flush()


def merge(files):
    """files = [(nom, octets)] → (octets fusionnés, rapport). La 1re version sert de base."""
    ys = [Ymap(raw, name) for name, raw in files]
    base = ys[0]
    common_boxes = Counter(base.boxes())
    for y in ys[1:]:
        common_boxes &= Counter(y.boxes())
    keys = Counter(k for _, k in base.models())
    for y in ys[1:]:
        keys &= Counter(k for _, k in y.models())
    boxes, budget = [], Counter(common_boxes)
    for b in base.boxes():
        if budget[b] > 0:
            boxes.append(b); budget[b] -= 1
    models, mbudget = [], Counter(keys)
    for s, k in base.models():
        if mbudget[k] > 0:
            models.append(s); mbudget[k] -= 1
    report = [f'{y.name} : {len(y.boxes())} boîtes, {len(y.models())} modèles' for y in ys]
    report.append(f'fusion : {len(boxes)} boîtes, {len(models)} modèles (présents dans toutes les versions)')
    base.keep(boxes, models)
    return base.bytes(), report


MANIFEST = """-- Fusion des fichiers d'occlusion livrés par plusieurs maps (tools/maps/fusion_occlusion.py).
-- Doit démarrer APRÈS ces maps : le nom gsa_zz_… passe en dernier dans cfg\\addons.cfg (ordre alphabétique).
fx_version 'cerulean'
game 'gta5'
author 'RoadLine'
this_is_a_map 'yes'
"""


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    out, files = argv[1], argv[2:]
    names = {os.path.basename(f).lower() for f in files}
    if len(names) != 1:
        print('Les fichiers doivent porter le même nom (ex. cs1_occl_10.ymap), un par map.')
        return 2
    merged, report = merge([(f, open(f, 'rb').read()) for f in files])
    Ymap(merged, 'contrôle')  # relecture : le fichier produit est valide
    res = os.path.join(out, 'zz_fusion_occlusion')
    os.makedirs(os.path.join(res, 'stream'), exist_ok=True)
    with open(os.path.join(res, 'fxmanifest.lua'), 'w', encoding='utf-8') as fh:
        fh.write(MANIFEST)
    with open(os.path.join(res, 'stream', names.pop()), 'wb') as fh:
        fh.write(merged)
    print('\n'.join(report))
    print(f'→ {res}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
