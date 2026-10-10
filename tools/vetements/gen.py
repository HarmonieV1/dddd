# Génère des collections de vêtements FiveM (ajouts, pas remplacements) à partir de vêtements « solo » mp_m / mp_f.
import os, re, glob, shutil, subprocess, sys
EX = '/tmp/claude-0/realimp/mods-tri/_extraction/'
OUT = '/tmp/claude-0/clothes_out/'
COMPS = ['head', 'berd', 'hair', 'uppr', 'lowr', 'hand', 'feet', 'teef', 'accs', 'task', 'decl', 'jbib']
# (ped, dlc, eCharacter, packs, ressource) : une collection par ressource (< 30 Mo chacune pour l'envoi)
JOBS = [
    ('mp_m_freemode_01', 'gsahomme', 'SCR_CHAR_MULTIPLAYER', ['mp_male_the_goat', 'brilliantovaja_cep_pervyjj_dollar', 'vine_cross_diamond_chain_mp_male'], 'vetements_homme'),
    ('mp_f_freemode_01', 'gsafemme', 'SCR_CHAR_MULTIPLAYER_F', ['basic', 'box_braids', 'dreads'], 'coiffures_femme_1'),
    ('mp_f_freemode_01', 'gsafemmeb', 'SCR_CHAR_MULTIPLAYER_F', ['edgar', 'leopard_print', 'locs'], 'coiffures_femme_2'),
]
report = []
for ped, dlc, echar, packs, resname in JOBS:
    full = f'{ped}_{dlc}'
    res = os.path.join(OUT, resname)
    shutil.rmtree(res, ignore_errors=True)
    os.makedirs(os.path.join(res, 'stream'))
    comps = {}  # comp index -> list of drawables [(pack, ydd, [ytd...])]
    for pack in packs:
        for ydd in sorted(glob.glob(EX + pack + '/**/*.ydd', recursive=True)):
            m = re.match(r'([a-z]+)_(\d{3})_[ur]\.ydd$', os.path.basename(ydd))
            if not m or m.group(1) not in COMPS: continue
            comp, num = m.group(1), m.group(2)
            texs = sorted(glob.glob(os.path.join(os.path.dirname(ydd), f'{comp}_diff_{num}_*.ytd')))
            if not texs: continue
            comps.setdefault(COMPS.index(comp), []).append((pack, ydd, texs))
    avail = ['255'] * 12
    items, infos = [], []
    for k, ci in enumerate(sorted(comps)):
        avail[ci] = str(k)
        comp = COMPS[ci]
        draws = []
        for di, (pack, ydd, texs) in enumerate(comps[ci]):
            shutil.copy(ydd, os.path.join(res, 'stream', f'{full}^{comp}_{di:03d}_u.ydd'))
            for ti, t in enumerate(texs[:26]):
                shutil.copy(t, os.path.join(res, 'stream', f'{full}^{comp}_diff_{di:03d}_{chr(97 + ti)}_uni.ytd'))
            tex = ''.join('      <Item>\n       <texId value="0" />\n       <distribution value="255" />\n      </Item>\n' for _ in texs[:26])
            draws.append(f'    <Item>\n     <propMask value="1" />\n     <numAlternatives value="0" />\n     <aTexData itemType="CPVTextureData">\n{tex}     </aTexData>\n     <clothData>\n      <ownsCloth value="false" />\n     </clothData>\n    </Item>\n')
            infos.append(f'  <Item>\n   <pedXml_audioID>none</pedXml_audioID>\n   <pedXml_audioID2>none</pedXml_audioID2>\n   <pedXml_expressionMods>0 0 0 0 0</pedXml_expressionMods>\n   <flags value="0" />\n   <inclusions>0</inclusions>\n   <exclusions>0</exclusions>\n   <pedXml_vfxComps>PV_COMP_HEAD</pedXml_vfxComps>\n   <pedXml_flags value="0" />\n   <pedXml_compIdx value="{ci}" />\n   <pedXml_drawblIdx value="{di}" />\n  </Item>\n')
            report.append(f'{ped} · {comp} n°{di} ← {pack} ({len(texs[:26])} textures)')
        ntex = sum(len(t[:26]) for _, _, t in comps[ci])
        items.append(f'  <Item>\n   <numAvailTex value="{ntex}" />\n   <aDrawblData3 itemType="CPVDrawblData">\n{"".join(draws)}   </aDrawblData3>\n  </Item>\n')
    xml = (f'<?xml version="1.0" encoding="UTF-8"?>\n<CPedVariationInfo name="{dlc}">\n <bHasTexVariations value="true" />\n <bHasDrawblVariations value="true" />\n'
           f' <bHasLowLODs value="false" />\n <bIsSuperLOD value="false" />\n <availComp>{" ".join(avail)}</availComp>\n'
           f' <aComponentData3 itemType="CPVComponentData">\n{"".join(items)} </aComponentData3>\n <aSelectionSets itemType="CPedSelectionSet" />\n'
           f' <compInfos itemType="CComponentInfo">\n{"".join(infos)} </compInfos>\n <propInfo>\n  <numAvailProps value="0" />\n'
           f'  <aPropMetaData itemType="CPedPropMetaData" />\n  <aAnchors itemType="CAnchorProps" />\n </propInfo>\n <dlcName>{dlc}</dlcName>\n</CPedVariationInfo>\n')
    xp = os.path.join(OUT, full + '.xml')
    open(xp, 'w').write(xml)
    r = subprocess.run(['/tmp/claude-0/dotnet/dotnet', '/tmp/claude-0/cwtool/cwtool.dll', 'xml2ymt', xp, os.path.join(res, 'stream', full + '.ymt')], capture_output=True, text=True)
    if r.returncode: sys.exit('ymt: ' + r.stderr)
    g = 'm' if '_m_' in ped else 'f'
    open(os.path.join(res, full + '.meta'), 'w').write(
        f'<?xml version="1.0" encoding="UTF-8"?>\n<ShopPedApparel>\n    <pedName>{ped}</pedName>\n    <dlcName>{dlc}</dlcName>\n    <fullDlcName>{full}</fullDlcName>\n'
        f'    <eCharacter>{echar}</eCharacter>\n    <creatureMetaData>mp_creaturemetadata_{g}_{dlc}</creatureMetaData>\n    <pedOutfits>\n    </pedOutfits>\n'
        f'    <pedComponents>\n    </pedComponents>\n    <pedProps>\n    </pedProps>\n</ShopPedApparel>\n')
    open(os.path.join(res, 'fxmanifest.lua'), 'w').write(
        f"-- Vêtements convertis (ajouts, ne remplacent rien) · RoadLine RP\nfx_version 'cerulean'\ngame 'gta5'\n\nfiles {{ '{full}.meta' }}\n"
        f"data_file 'SHOP_PED_APPAREL_META_FILE' '{full}.meta'\n")
print('\n'.join(report))
