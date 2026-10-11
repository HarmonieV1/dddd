#!/usr/bin/env python3
"""Tests de tools/maps/fusion_occlusion.py sur un fichier d'occlusion fabriqué (format Meta du jeu : en-tête, table des
blocs, CMapData, boîtes d'occlusion, modèles d'occlusion et leurs sommets). Aucun fichier de map tiers dans le dépôt."""
import os
import struct
import sys
import tempfile
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'tools', 'maps'))
import fusion_occlusion as F  # noqa: E402

passed = failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print('ÉCHEC : ' + name)


def build(boxes, models):
    """boxes = [(cx, cy, cz, cos, l, w, h, sin)] ; models = [(bmin, bmax, sommets)] → fichier .ymap RSC7."""
    d = bytearray(0x2000)
    struct.pack_into('<I', d, 0x10, 0x50524430)
    struct.pack_into('<i', d, 0x1C, 1)                       # bloc racine = 1 (CMapData)
    struct.pack_into('<Q', d, 0x30, F.BASE + 0x100)          # table des blocs
    struct.pack_into('<h', d, 0x4C, 4)
    blocks = [(F.CMAPDATA, 512, 0x200), (0x3A282E1D, len(boxes) * 16, 0x400), (0xA36C4EAD, len(models) * 64, 0x800), (0x11, 0x400, 0xC00)]
    for i, (h, ln, off) in enumerate(blocks):
        struct.pack_into('<IiQ', d, 0x100 + i * 16, h, ln, F.BASE + off)
    struct.pack_into('<IIHHI', d, 0x200 + F.BOX_OFF, 2 if boxes else 0, 0, len(boxes), len(boxes), 0)
    struct.pack_into('<IIHHI', d, 0x200 + F.MODEL_OFF, 3 if models else 0, 0, len(models), len(models), 0)
    for i, b in enumerate(boxes):
        struct.pack_into('<8h', d, 0x400 + i * 16, *b)
    voff = 0
    for i, (bmin, bmax, verts) in enumerate(models):
        o = 0x800 + i * 64
        struct.pack_into('<3f', d, o, *bmin)
        struct.pack_into('<3f', d, o + 16, *bmax)
        struct.pack_into('<I', d, o + 32, len(verts))
        struct.pack_into('<I', d, o + 40, 4 | (voff << 12))  # bloc 4 (octets des sommets), décalage
        struct.pack_into('<HHI', d, o + 48, len(verts), 1, 0)
        d[0xC00 + voff:0xC00 + voff + len(verts)] = verts
        voff += len(verts)
    head = b'RSC7' + struct.pack('<3I', 2, 0x90000002, 0x20000000)
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    return head + c.compress(bytes(d)) + c.flush()


B = [(i * 10, i * 20, 30, 127, 40, 40, 10, 0) for i in range(10)]
MODELS = [((i, i, 0), (i + 5, i + 5, 9), bytes([0xA0 + i]) * 12) for i in range(4)]  # sommets reconnaissables
a = build(B, MODELS)
y = F.Ymap(a, 'a')
check('lecture : 10 boîtes, 4 modèles', len(y.boxes()) == 10 and len(y.models()) == 4)

# Map A retire les boîtes 0 et 1 et le modèle 0 ; map B retire la boîte 5 et le modèle 3
ma = build(B[2:], MODELS[1:])
mb = build(B[:5] + B[6:], MODELS[:3])
out, rep = F.merge([('A', ma), ('B', mb)])
r = F.Ymap(out, 'fusion')
check('fusion = boîtes présentes partout (7)', len(r.boxes()) == 7)
check('les retraits des DEUX maps sont appliqués', all(struct.pack('<8h', *B[i]) not in r.boxes() for i in (0, 1, 5)))
check('fusion = modèles présents partout (2)', len(r.models()) == 2)
keys = [k for _, k in r.models()]
check('modèles gardés : 1 et 2, avec leurs sommets', any(bytes([0xA1]) * 12 in k for k in keys) and any(bytes([0xA2]) * 12 in k for k in keys)
      and not any(bytes([0xA0]) * 12 in k or bytes([0xA3]) * 12 in k for k in keys))
check('en-tête RSC7 inchangé (taille en mémoire identique)', out[:16] == ma[:16])
check('taille décompressée inchangée', len(zlib.decompressobj(-15).decompress(out[16:])) == 0x2000)
out2, _ = F.merge([('B', mb), ('A', ma)])
check('ordre des fichiers sans effet sur le contenu', sorted(F.Ymap(out2, 'x').boxes()) == sorted(r.boxes()))
same, _ = F.merge([('A', ma), ('A bis', ma)])
check('fusion d\'un fichier avec lui-même : identique', zlib.decompressobj(-15).decompress(same[16:]) == zlib.decompressobj(-15).decompress(ma[16:]))
three, _ = F.merge([('A', ma), ('B', mb), ('C', build(B[:9], MODELS))])
check('trois maps : 6 boîtes', len(F.Ymap(three, 't').boxes()) == 6)
none, _ = F.merge([('A', build(B[:3], [])), ('B', build(B[5:], []))])
check('rien en commun : tableaux vides, fichier valide', len(F.Ymap(none, 'n').boxes()) == 0)

for bad, why in ((b'PK\x03\x04' + b'\0' * 40, 'pas un RSC7'), (b'RSC7' + b'\0' * 12 + zlib.compress(b'x' * 64)[2:-4], 'pas un Meta')):
    try:
        F.Ymap(bad, 'mauvais')
        check(f'refus : {why}', False)
    except (ValueError, zlib.error, struct.error):
        check(f'refus : {why}', True)

# Ligne de commande : ressource prête à importer
with tempfile.TemporaryDirectory() as tmp:
    pa, pb = os.path.join(tmp, 'a', 'cs1_occl_10.ymap'), os.path.join(tmp, 'b', 'cs1_occl_10.ymap')
    for p, raw in ((pa, ma), (pb, mb)):
        os.makedirs(os.path.dirname(p))
        open(p, 'wb').write(raw)
    code = F.main(['x', os.path.join(tmp, 'out'), pa, pb])
    res = os.path.join(tmp, 'out', 'zz_fusion_occlusion')
    check('ressource créée (fxmanifest + stream)', code == 0 and os.path.isfile(os.path.join(res, 'fxmanifest.lua'))
          and os.path.isfile(os.path.join(res, 'stream', 'cs1_occl_10.ymap')))
    check('fxmanifest : map', "this_is_a_map 'yes'" in open(os.path.join(res, 'fxmanifest.lua'), encoding='utf-8').read())
    open(os.path.join(tmp, 'b', 'autre.ymap'), 'wb').write(mb)
    check('noms différents refusés', F.main(['x', os.path.join(tmp, 'o2'), pa, os.path.join(tmp, 'b', 'autre.ymap')]) == 2)

print(f'fusion d\'occlusion : {passed} réussis, {failed} échoués')
sys.exit(1 if failed else 0)
