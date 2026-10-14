// Tests du lecteur de maps (gs_admin/server/maps.js) : décompression RSC7, repérage des objets posés, fichiers du jeu
// remplacés, lieux (priorité au bâtiment qui porte le nom de la map, regroupement à 200 m), conflits entre deux maps,
// retraits (V12.36 : par nom, par motif, par mods-retires.txt ; retrait F11 = suppression du disque ; listes lues par l'importeur).
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');
const M = require('../server/resources/[gtasoon]/gs_admin/server/maps.js');
let passed = 0, failed = 0;
const check = (name, cond) => { if (cond) passed++; else { failed++; console.error('ÉCHEC : ' + name); } };

/** Faux .ymap : objets posés (CEntityDef de 128 octets : position, rotation, échelles) entourés de bruit. */
function ymap(objects, noise = 64) {
  const body = Buffer.alloc(noise + objects.length * 128 + noise);
  for (let i = 0; i < noise; i += 4) body.writeFloatLE(Math.sin(i) * 3e6, i); // nombres qui ne ressemblent à rien
  objects.forEach(([x, y, z, model], i) => {
    const p = noise + i * 128;
    body.writeInt32LE(model ? M.joaat(model) : 0xdeadbeef | 0, p + 8); // CEntityDef.archetypeName (nom du modèle, hash)
    body.writeFloatLE(x, p + 32); body.writeFloatLE(y, p + 36); body.writeFloatLE(z, p + 40);
    body.writeFloatLE(0, p + 48); body.writeFloatLE(0, p + 52); body.writeFloatLE(0.7071, p + 56); body.writeFloatLE(0.7071, p + 60);
    body.writeFloatLE(1, p + 64); body.writeFloatLE(1, p + 68);
  });
  const head = Buffer.alloc(16); head.write('RSC7', 0, 'latin1'); head.writeUInt32LE(2, 4);
  return Buffer.concat([head, zlib.deflateRawSync(body)]);
}

// 1. Décompression et repérage
const one = M.inflateRsc7(ymap([[927.2, -1563.9, 34.2]]));
check('RSC7 décompressé', one && one.length > 0);
check('fichier qui n\'est pas un RSC7 : ignoré', M.inflateRsc7(Buffer.from('PK\u0003\u0004 pas une map')) === null);
check('RSC7 abîmé : ignoré sans planter', M.inflateRsc7(Buffer.concat([Buffer.from('RSC7'), Buffer.alloc(30, 7)])) === null);
const ents = M.entitiesOf(one);
check('un objet posé retrouvé à sa position', ents.length === 1 && Math.abs(ents[0][0] - 927.2) < 0.01 && Math.abs(ents[0][1] + 1563.9) < 0.01);
check('bruit seul : aucun objet', M.entitiesOf(M.inflateRsc7(ymap([], 512))).length === 0);
check('trois objets', M.entitiesOf(M.inflateRsc7(ymap([[1, 2000, 30], [10, 2010, 31], [20, 2020, 32]]))).length === 3);

// 2. Fichiers du jeu remplacés par une map (on ne s'en sert pas pour la situer)
for (const n of ['id1_occl_02.ymap', 'bkr_id1_rd_long_0.ymap', 'hei_hw1_rd_critical_1.ymap', 'cs1_occl_10.ymap', 'tm_workshop_lodlights.ymap'])
  check(`fichier du jeu : ${n}`, M.isVanillaName(n));
for (const n of ['TM_Workshop.ymap', 'int_vinewood_police_milo_.ymap', 'draft-pb-liquor_placement.ymap', 'garage.ymap', 'policestationupdated.ymap', 'bahamas_mamas_v1_0.ymap', 'long_beach_house.ymap'])
  check(`fichier propre à la map : ${n}`, !M.isVanillaName(n));

// 3. Lieux
const pd = { file: 'int_vinewood_police_milo_.ymap', entities: [[574.2, -10.6, 87.7]] };
const garage = { file: 'garage.ymap', entities: [[535.1, -32.8, 69.6], [537.3, -31.5, 69.6]] };
const road = { file: 'hei_hw1_rd_critical_1.ymap', entities: Array.from({ length: 50 }, (_, i) => [500 + i, 18, 77]) };
let pl = M.placesOf([garage, road, pd], 'gsa_zero_vinewoodfree');
check('bâtiment + garage voisin = un seul lieu', pl.length === 1);
check('position = le bâtiment qui porte le nom de la map (pas une moyenne entre deux étages)', pl[0].x === 574.2 && pl[0].z === 87.7);
check('les routes du jeu remplacées ne comptent pas', pl[0].objects === 3);
pl = M.placesOf([{ file: 'shop_a.ymap', entities: [[-161.5, 6325.4, 31]] }, { file: 'shop_b.ymap', entities: [[1135, -982, 46]] }], 'gsa_liquor_pack');
check('pack de deux magasins éloignés = deux lieux', pl.length === 2);
pl = M.placesOf([road, { file: 'id1_occl_02.ymap', entities: [] }], 'gsa_routes');
check('map qui ne fait que modifier le jeu : un lieu, le plus chargé', pl.length === 1 && pl[0].x > 500 && pl[0].x < 550);
check('map sans objet : aucun lieu', M.placesOf([{ file: 'x.ymap', entities: [] }], 'gsa_x').length === 0);
check('vrai nom affiché', M.labelOf('gsa_moreo_gym') === 'Salle de sport' && M.labelOf('gsa_pillbox_hospital_interior_master') === 'Hôpital Pillbox');
check('map inconnue : nom lisible sans version', M.labelOf('gsa_nouvelle_map_v1_0') === 'Nouvelle map');

// 4. Dossiers réels : lecture, conflits entre maps
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gsmaps-'));
const mk = (res, files) => { for (const [f, b] of Object.entries(files)) { const p = path.join(tmp, res, f); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, b); } return { name: res, dir: path.join(tmp, res) }; };
const a = mk('gsa_atelier', { 'stream/ymap/TM_Workshop.ymap': ymap([[927.2, -1563.9, 34.2]]), 'stream/ymap/id1_occl_02.ymap': ymap([]), 'stream/_manifest.ymf': 'x', 'fxmanifest.lua': "this_is_a_map 'yes'" });
const b = mk('gsa_autre', { 'stream/id1_occl_02.ymap': ymap([], 128), 'stream/garage_b.ymap': ymap([[1200, -1500, 34]]), 'stream/_manifest.ymf': 'x' });
const c = mk('gsa_vide', { 'LICENSE': 'GPL' });
const d = mk('gsa_casse', { 'stream/abime.ymap': Buffer.from('RSC7 pas compressé du tout') });
const r = M.scanAll([a, b, c, d]);
const by = Object.fromEntries(r.maps.map((m) => [m.name, m]));
check('map lue depuis son dossier', by.gsa_atelier.places.length === 1 && by.gsa_atelier.places[0].x === 927.2);
check('conflit : même fichier du jeu remplacé par deux maps', r.conflicts.length === 1 && r.conflicts[0].file === 'id1_occl_02.ymap'
  && r.conflicts[0].resources.includes('gsa_atelier') && r.conflicts[0].resources.includes('gsa_autre'));
check('_manifest.ymf (nom commun à toutes les maps) : pas un conflit', !r.conflicts.some((x) => x.file.endsWith('.ymf')));
check('ressource vide (aucun fichier de map) : pas dans la liste', by.gsa_vide === undefined);
check('fichier abîmé : compté illisible, rien ne plante', by.gsa_casse.unreadable === 1 && by.gsa_casse.places.length === 0);
check('liste brute des fichiers non envoyée au menu', r.maps.every((m) => m.streamed === undefined));
// V12.30 : modèles propres à la map (posés par ses .ymap ET livrés en .ydr/.yft) → contrôle « chez moi » côté client
check('hash du jeu (GetHashKey)', M.joaat('adder') === (0xB779A091 | 0) && M.joaat('ADDER') === M.joaat('adder'));
check('nom du modèle lu à côté de la position', M.entitiesOf(M.inflateRsc7(ymap([[927.2, -1563.9, 34.2, 'pg_shell']])))[0][3] === M.joaat('pg_shell'));
{
  const g = mk('gsa_patoche_plasmagame_pack', { 'stream/plasmagame.ymap': ymap([[300, 200, 100, 'pg_shell'], [301, 201, 100, 'pg_shell'], [302, 202, 100, 'prop_chair_01a']]),
    'stream/pg_shell.ydr': Buffer.from('RSC7'), 'stream/pg_bar.ydr': Buffer.from('RSC7') });
  const sg = M.scanResource(g.name, g.dir);
  check('modèles propres : seulement ceux de la map posés par ses .ymap, sans doublon', sg.models.length === 1 && sg.models[0] === M.joaat('pg_shell') && sg.ownModels === 2);
  check('objet du jeu de base (prop_chair_01a) : pas testé', !sg.models.includes(M.joaat('prop_chair_01a')));
}
check('activité sans script : décor seul', JSON.stringify(M.activityOf('gsa_patoche_plasmagame_pack', ['gs_admin', 'gsa_patoche_plasmagame_pack'])) === JSON.stringify({ what: 'laser game', script: null }));
check('activité avec son script', M.activityOf('gsa_patoche_plasmagame_pack', ['patoche_plasmagame_script']).script === 'patoche_plasmagame_script');
check('12/10 : villa moderne 01 retirée, villa bunker gardée (sans blip public)', M.RETIRED_MAPS.includes('gsa_sub_patoche_villa_01_pack')
  && !M.RETIRED_MAPS.includes('gsa_patoche_villa_bunker_pack') && M.PUBLIC.gsa_patoche_villa_bunker_pack === false);
check('map sans activité : rien', M.activityOf('gsa_patoche_casino_pack', []) === undefined);
check('maps triées par nom', r.maps.map((m) => m.label).join() === [...r.maps.map((m) => m.label)].sort((x, y) => x.localeCompare(y)).join());

// 5. Mémoire des modèles (en-tête RSC7) : le poids du fichier ne suffit pas
const rsc = (sysFlags, gfxFlags) => { const h = Buffer.alloc(16); h.write('RSC7', 0, 'latin1'); h.writeUInt32LE(165, 4); h.writeUInt32LE(sysFlags, 8); h.writeUInt32LE(gfxFlags, 12); return h; };
check('taille d\'une page : 0x200 << 0 × 1 page de rang 0', M.pagesSize((1 << 27) | 0) === 0x200);
check('taille : 2 pages de rang 4 de 0x2000 = 0x20000', M.pagesSize((2 << 17) | 4) === 0x2000 * 2 * 16);
const gym = rsc(0xa3020003, 0x52020188); // en-tête réel de moreo_gym_shell.ydr (26,5 Mo en mémoire graphique)
check('modèle lourd : ~26,5 Mo en mémoire', Math.abs(M.memoryMB(gym) - 26.5) < 0.3);
check('pas un RSC7 : 0', M.memoryMB(Buffer.from('PK\u0003\u0004xxxxxxxxxxxx')) === 0);
const huge = rsc(0, (32 << 17) | 8); // 64 Mo de mémoire graphique : au-delà de la limite FiveM (48 Mo)
check('64 Mo graphiques lus dans l\'en-tête', Math.abs(M.memorySplit(huge).phys - 64) < 0.01 && M.memorySplit(huge).virt === 0);
const e = mk('gsa_lourde', { 'stream/shell.ydr': Buffer.concat([huge, Buffer.alloc(64)]), 'stream/gym.ydr': Buffer.concat([gym, Buffer.alloc(64)]), 'stream/petit.ytd': Buffer.concat([rsc(0, (1 << 17) | 2), Buffer.alloc(64)]),
  'stream/lieu.ymap': ymap([[-451.5, -33.3, 48.9]]) });
const f = mk('gsa_habillage', { 'stream/v_ilev_gb_vauldr.ydr': Buffer.concat([rsc(0, (1 << 17) | 2), Buffer.alloc(32)]), 'stream/v_int_10.ytyp': 'x' });
const r2 = Object.fromEntries(M.scanAll([e, f]).maps.map((m) => [m.name, m]));
check('modèle au-delà de 48 Mo graphiques signalé', r2.gsa_lourde.heavy.some((h) => h.file === 'shell.ydr' && h.mb === 64));
check('gym (26,5 Mo, sous la limite FiveM) : pas signalé', !r2.gsa_lourde.heavy.some((h) => h.file === 'gym.ydr'));
check('petite texture : pas signalée', !r2.gsa_lourde.heavy.some((h) => h.file === 'petit.ytd'));
check('habillage sans .ymap (Fleeca) : fichiers du jeu comptés, pas « vide »', r2.gsa_habillage.ymaps === 0 && r2.gsa_habillage.assets === 2);
const cloth = mk('gsa_bikini', { 'stream/mp_f_freemode_01_mp_f_bikini^jbib_000_u.ydd': 'x', 'stream/mp_f_freemode_01_mp_f_bikini^jbib_diff_000_a_uni.ytd': 'x', 'stream/mp_f_bikini.ymt': 'x' });
const veh = mk('gsa_voiture', { 'stream/maverick2.yft': 'x', 'stream/maverick2.ytd': 'x', 'data/vehicles.meta': 'x' });
const rc2 = M.scanAll([cloth, veh, a]);
check('vêtements et véhicules importés : pas dans la liste des maps', rc2.maps.length === 1 && rc2.maps[0].name === 'gsa_atelier');

// 6. Copies identiques : pas un conflit ; fusion : conflit résolu
const g1 = mk('gsa_copie_a', { 'stream/cs1_occl_10.ymap': ymap([], 64) });
const g2 = mk('gsa_copie_b', { 'stream/cs1_occl_10.ymap': ymap([], 64) });
check('deux copies identiques du même fichier : pas un conflit', M.scanAll([g1, g2]).conflicts.length === 0);
const h1 = mk('gsa_liquor', { 'stream/cs1_occl_10.ymap': ymap([], 64) });
const h2 = mk('gsa_willies', { 'stream/cs1_occl_10.ymap': ymap([], 96) });
let rc = M.scanAll([h1, h2]).conflicts;
check('versions différentes : conflit non résolu', rc.length === 1 && rc[0].resolved === null && rc[0].resources.length === 2);
const fx = mk('gsa_zz_fusion_occlusion', { 'stream/cs1_occl_10.ymap': ymap([], 32) });
rc = M.scanAll([h1, h2, fx]).conflicts;
check('ressource de fusion : conflit marqué résolu', rc.length === 1 && rc[0].resolved === 'gsa_zz_fusion_occlusion');
check('la fusion n\'est pas comptée comme une map en conflit', !rc[0].resources.includes('gsa_zz_fusion_occlusion'));

// 7. Fusion automatique des conflits d'occlusion (V12.13)
function occl(boxes) { // fichier d'occlusion fabriqué : CMapData + boîtes (format Meta du jeu), sans modèle
  const d = Buffer.alloc(0x1000);
  d.writeUInt32LE(0x50524430, 0x10); d.writeInt32LE(1, 0x1c); d.writeBigUInt64LE(BigInt(0x50000000 + 0x100), 0x30); d.writeInt16LE(2, 0x4c);
  [[0xd3593fa6, 512, 0x200], [0x3a282e1d, boxes.length * 16, 0x400]].forEach(([h, l, o], i) => {
    d.writeUInt32LE(h, 0x100 + i * 16); d.writeInt32LE(l, 0x104 + i * 16); d.writeBigUInt64LE(BigInt(0x50000000 + o), 0x108 + i * 16); });
  d.writeUInt32LE(boxes.length ? 2 : 0, 0x200 + 128); d.writeUInt16LE(boxes.length, 0x200 + 136); d.writeUInt16LE(boxes.length, 0x200 + 138);
  boxes.forEach((b, i) => { for (let j = 0; j < 8; j++) d.writeInt16LE(b * 10 + j, 0x400 + i * 16 + j * 2); });
  const h = Buffer.alloc(16); h.write('RSC7', 0, 'latin1'); h.writeUInt32LE(2, 4); h.writeUInt32LE(0x90000001, 8); h.writeUInt32LE(0x20000000, 12);
  return Buffer.concat([h, zlib.deflateRawSync(d)]);
}
const boxCount = (raw) => { const d = zlib.inflateRawSync(raw.subarray(16)); return d.readUInt16LE(0x200 + 136); };
const liq = mk('gsa_cfx_draft_pb_liquor_pack', { 'stream/vanilla/cs1_occl_10.ymap': occl([1, 2, 3, 4, 5, 6]) });   // a retiré 7, 8
const wil = mk('gsa_mlo_willies_supermarket', { 'stream/cs1_occl_10.ymap': occl([1, 2, 3, 4, 7, 8]) });           // a retiré 5, 6
const fusDir = path.join(tmp, 'gsa_zz_fusion_occlusion');
fs.mkdirSync(fusDir, { recursive: true });
const raw2 = (list) => list.map((r) => M.scanResource(r.name, r.dir));
let w = M.applyFusions(raw2([liq, wil]), fusDir);
const fused = fs.readFileSync(path.join(fusDir, 'stream', 'cs1_occl_10.ymap'));
check('conflit d\'occlusion : fusion écrite', w.length === 1 && w[0].how.startsWith('fusion'));
check('fusion = boîtes présentes dans les deux versions (1 à 4)', boxCount(fused) === 4);
check('fxmanifest de la fusion écrit', fs.readFileSync(path.join(fusDir, 'fxmanifest.lua'), 'utf8').includes("this_is_a_map 'yes'"));
check('2e démarrage : rien à réécrire', M.applyFusions(raw2([liq, wil]), fusDir).length === 0);
const fus = { name: 'gsa_zz_fusion_occlusion', dir: fusDir };
const after = M.scanAll([liq, wil, fus]);
check('conflit marqué résolu par la fusion', after.conflicts.length === 1 && after.conflicts[0].resolved === 'gsa_zz_fusion_occlusion');
check('la fusion n\'apparaît pas dans la liste des maps', !after.maps.some((m) => m.name === 'gsa_zz_fusion_occlusion'));
check('conflit déjà résolu : pas de nouvelle écriture', M.applyFusions(raw2([liq, wil, fus]), fusDir).length === 0);
// Version illisible : on garde la version préférée (magasin d'alcool)
const fusDir2 = path.join(tmp, 'fusion2');
const bad = mk('gsa_aaa_map_abimee', { 'stream/cs1_occl_10.ymap': Buffer.from('RSC7 abîmé') });
w = M.applyFusions(raw2([bad, liq]), fusDir2);
check('fusion impossible : version du magasin d\'alcool gardée', w.length === 1 && w[0].how.includes('gsa_cfx_draft_pb_liquor_pack')
  && fs.readFileSync(path.join(fusDir2, 'stream', 'cs1_occl_10.ymap')).equals(fs.readFileSync(path.join(liq.dir, 'stream/vanilla/cs1_occl_10.ymap'))));
const idA = mk('gsa_x_id', { 'stream/hw1_rd_01.ymap': ymap([[1, 2000, 30]]) }), idB = mk('gsa_y_id', { 'stream/hw1_rd_01.ymap': ymap([[5, 2000, 30]]) });
check('conflit qui n\'est pas de l\'occlusion : pas fusionné automatiquement', M.applyFusions(raw2([idA, idB]), path.join(tmp, 'fusion3')).length === 0);

// 8. Retirer une map (V12.15) : ligne commentée dans addons.cfg, rien d'autre ; fusion devenue inutile supprimée
const cfgF = path.join(tmp, 'addons.cfg');
fs.writeFileSync(cfgF, '## Mods\r\nensure gsa_energy_redline_pack\r\nensure gsa_energy_redline_pack_b\r\n# ensure gsa_autre\r\nensure gsa_moreo_gym\r\n');
check('retrait : map trouvée', M.disableInCfg(cfgF, 'gsa_energy_redline_pack', 'retirée en jeu'));
const cfgT = fs.readFileSync(cfgF, 'utf8');
check('retrait : seule sa ligne est commentée', cfgT.includes('# ensure gsa_energy_redline_pack   # retirée en jeu\r\n') && cfgT.includes('\r\nensure gsa_energy_redline_pack_b\r\n')
  && cfgT.includes('\r\nensure gsa_moreo_gym\r\n') && cfgT.includes('# ensure gsa_autre'));
check('retrait : déjà retirée → rien', !M.disableInCfg(cfgF, 'gsa_energy_redline_pack', 'x'));
check('retrait : nom invalide refusé', !M.disableInCfg(cfgF, 'gs_admin', 'x') && !M.disableInCfg(cfgF, 'gsa_x\nensure y', 'x'));
check('fusion encore utile : gardée', M.pruneFusions(raw2([liq, wil]), fusDir).length === 0 && fs.existsSync(path.join(fusDir, 'stream', 'cs1_occl_10.ymap')));
check('une des deux maps retirée : fusion supprimée', M.pruneFusions(raw2([wil]), fusDir).join() === 'cs1_occl_10.ymap' && !fs.existsSync(path.join(fusDir, 'stream', 'cs1_occl_10.ymap')));

// 9. Suppression définitive des maps (V12.16)
check('nom d\'archive comme IMPORTER-MODS', M.cleanName('a1b2c3-TM_Workshop.pack.zip') === 'tm_workshop_pack' && M.cleanName('Moreo Gym (v2).rar') === 'moreo_gym_v2');
const R9 = path.join(tmp, 'GTASOON'), SD = path.join(R9, 'server-data'), AD = path.join(SD, 'resources', '[addons]');
const put = (p, c) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, c); };
put(path.join(AD, 'gsa_tm_workshop_pack', 'stream', 'TM_Workshop.ymap'), ymap([[927.2, -1563.9, 34.2]]));
put(path.join(AD, 'gsa_hp_fleeca_main', 'stream', 'v_int_10.ytyp'), 'x');
put(path.join(AD, 'gsa_raduzhnoe_bikini', 'stream', 'mp_f_freemode_01^jbib_000_u.ydd'), 'x');
put(path.join(SD, 'cfg', 'addons.cfg'), '## Mods\r\nensure gsa_tm_workshop_pack\r\n# ensure gsa_hp_fleeca_main   # retirée\r\nensure gsa_raduzhnoe_bikini\r\n');
put(path.join(R9, 'mods-tri', 'maps', 'tm_workshop_pack', 'fxmanifest.lua'), 'x');
put(path.join(R9, 'mods-a-trier', 'a1b2c3-TM_Workshop.pack.zip'), 'zip');
put(path.join(R9, 'mods-a-trier', 'pack_drive_complet.zip'), 'zip');
put(path.join(R9, 'mods-retires.txt'), '# en-tête\r\nancienne_map\r\n');
const del = M.deleteMapsOnDisk(SD, R9);
check('les 2 maps supprimées (dont l\'habillage Fleeca)', del.maps.length === 2 && !fs.existsSync(path.join(AD, 'gsa_tm_workshop_pack')) && !fs.existsSync(path.join(AD, 'gsa_hp_fleeca_main')));
check('vêtements intacts', fs.existsSync(path.join(AD, 'gsa_raduzhnoe_bikini')));
const cfg9 = fs.readFileSync(path.join(SD, 'cfg', 'addons.cfg'), 'utf8');
check('addons.cfg : lignes des maps retirées, vêtements gardés, CRLF gardés', !cfg9.includes('tm_workshop') && !cfg9.includes('fleeca') && cfg9.includes('ensure gsa_raduzhnoe_bikini') && cfg9.includes('\r\n'));
check('copie de mods-tri et archive de la map effacées', !fs.existsSync(path.join(R9, 'mods-tri', 'maps', 'tm_workshop_pack')) && !fs.existsSync(path.join(R9, 'mods-a-trier', 'a1b2c3-TM_Workshop.pack.zip')));
check('archive groupée gardée (protégée par mods-retires.txt)', fs.existsSync(path.join(R9, 'mods-a-trier', 'pack_drive_complet.zip')));
const ret = fs.readFileSync(path.join(R9, 'mods-retires.txt'), 'utf8');
check('mods-retires.txt : anciens + nouveaux noms', ret.includes('ancienne_map') && ret.includes('tm_workshop_pack') && ret.includes('hp_fleeca_main'));
check('2e passage : rien à supprimer', M.deleteMapsOnDisk(SD, R9).maps.length === 0);
// V12.18 : suppression ciblée (RETIRED_MAPS) : seulement les maps nommées, archives gardées
{
  const R2 = path.join(tmp, 'G2'), S2 = path.join(R2, 'server-data'), A2 = path.join(S2, 'resources', '[addons]');
  put(path.join(A2, 'gsa_moreo_gym', 'stream', 'gym.ymap'), ymap([[0, 0, 0]]));
  put(path.join(A2, 'gsa_patoche_ammu', 'stream', 'ammu.ymap'), ymap([[1, 1, 1]]));
  put(path.join(S2, 'cfg', 'addons.cfg'), 'ensure gsa_moreo_gym\r\nensure gsa_patoche_ammu\r\n');
  put(path.join(R2, 'mods-a-trier', 'moreo_gym.rar'), 'rar');
  const d2 = M.deleteMapsOnDisk(S2, R2, { only: ['gsa_moreo_gym'], keepArchives: true });
  check('retrait ciblé : la map nommée seulement', d2.maps.join() === 'gsa_moreo_gym' && fs.existsSync(path.join(A2, 'gsa_patoche_ammu')) && !fs.existsSync(path.join(A2, 'gsa_moreo_gym')));
  check('retrait ciblé : archive gardée, nom dans mods-retires.txt', fs.existsSync(path.join(R2, 'mods-a-trier', 'moreo_gym.rar')) && fs.readFileSync(path.join(R2, 'mods-retires.txt'), 'utf8').includes('moreo_gym'));
  check('liste des maps retirées : 14 noms gsa_ (V12.33 : plasma retirés)', M.RETIRED_MAPS.length === 14 && M.RETIRED_MAPS.every((n) => /^gsa_[a-z0-9_]+$/.test(n))
    && ['gsa_patoche_plasmagame_pack', 'gsa_patoche_plasmakart_pack', 'gsa_patoche_plasmatron_pack'].every((n) => M.RETIRED_MAPS.includes(n)));
}
check('lignes ensure actives seulement', JSON.stringify(M.activeEnsures('## titre\r\nensure gsa_a\r\n# ensure gsa_b\r\n  ensure gsa_c  # note\r\n')) === '["gsa_a","gsa_c"]');
// V12.27 : fichier tronqué (téléchargement coupé) détecté, fichier entier ou chiffré jamais signalé
const pendingTrunc = (async () => {
  const good = Buffer.concat([Buffer.from('RSC7'), Buffer.alloc(12), zlib.deflateRawSync(Buffer.alloc(200000, 7))]);
  const cut = good.subarray(0, Math.floor(good.length / 2));
  const junk = Buffer.concat([Buffer.from('RSC7'), Buffer.alloc(12), Buffer.from([0xff, 0xff, 0xff, 0xff, 0x13, 0x37, 0x42, 0x99])]);
  check('fichier entier : sain', (await M.rscTruncated(good)) === false);
  check('fichier coupé en deux : abîmé', (await M.rscTruncated(cut)) === true);
  check('contenu illisible (chiffré, autre format) : jamais déclaré abîmé', (await M.rscTruncated(junk)) === false);
  check('pas un RSC7 : ignoré', (await M.rscTruncated(Buffer.from('hello world, not a resource'))) === false);
  const td = fs.mkdtempSync(path.join(os.tmpdir(), 'trunc-'));
  fs.mkdirSync(path.join(td, 'stream'));
  fs.writeFileSync(path.join(td, 'stream', 'ok.ydr'), good);
  fs.writeFileSync(path.join(td, 'stream', 'patoche_beach_guard.ydr'), cut);
  fs.writeFileSync(path.join(td, 'stream', 'notes.txt'), cut);
  const bad = await M.truncatedFiles(td);
  check('dossier : seul le fichier coupé est listé', bad.length === 1 && bad[0].endsWith('patoche_beach_guard.ydr'));
  fs.rmSync(td, { recursive: true, force: true });
})();
// V12.29 : blips publics des mappings
check('nom propre d\'un pack payant', M.labelOf('gsa_sub_patoche_benny_bw_pack') === 'Benny\'s' && M.labelOf('gsa_patoche_new_bowling_pack') === 'New bowling');
const pb = M.publicBlips([
  { name: 'gsa_patoche_casino_pack', label: 'Casino', places: [{ x: 1, y: 2, z: 3 }] },
  { name: 'gsa_patoche_gang_2_pack', label: 'Gang 2', places: [{ x: 4, y: 5, z: 6 }] },
  { name: 'gsa_patoche_inconnu_pack', label: 'Inconnu', places: [{ x: 7, y: 8, z: 9 }] },
  { name: 'gsa_sans_lieu', label: 'Sans lieu', places: [] },
]);
check('blips : casino avec son icône, QG de gang caché, map inconnue SANS blip (V12.40 : plus de rond blanc), sans lieu ignorée',
  pb.length === 1 && pb[0].label === 'Casino' && pb[0].sprite === 679);
const pb3 = M.publicBlips([{ name: 'gsa_patoche_new_bar_pack', label: 'New bar', places: [{ x: 1, y: 2, z: 3 }] },
  { name: 'gsa_mlo_garage_luxe', label: 'Garage luxe', places: [{ x: 1, y: 2, z: 3 }] },
  { name: 'gsa_modern_villa_02', label: 'Villa', places: [{ x: 1, y: 2, z: 3 }] }]);
check('V12.40 icône devinée d\'après le nom (bar, garage), villa privée sans blip', pb3.length === 2 && pb3[0].sprite === 93 && pb3[1].sprite === 446);
check('V12.40 aucune icône par défaut (rond blanc)', [...pb, ...pb3].every((b) => b.sprite !== 1));
const pb2 = M.publicBlips([
  { name: 'gsa_patoche_plasmagame_pack', label: 'Plasmagame', places: [{ x: 1, y: 2, z: 3 }], activity: { what: 'laser game', script: null } },
  { name: 'gsa_patoche_plasmakart_pack', label: 'Plasmakart', places: [{ x: 1, y: 2, z: 3 }], activity: { what: 'karting', script: 'patoche_plasmakart' } },
]);
check('blip d\'une activité sans son script : « (bientôt) »', pb2[0].label === 'Laser game (bientôt)' && pb2[1].label === 'Karting');
// V12.18 : FXServer récent = écriture interdite au JavaScript (« Use --allow-fs-write ») → repli par Lua (server/fsw.lua)
{
  const orig = { w: fs.writeFileSync, u: fs.unlinkSync, r: fs.rmSync };
  const deny = () => { const e = new Error('Access to this API has been restricted. Use --allow-fs-write to manage permissions.'); e.code = 'ERR_ACCESS_DENIED'; throw e; };
  const calls = [];
  M._setLuaFs({ write: (p, b64) => { calls.push('w'); orig.w(p, Buffer.from(b64, 'base64')); return true; },
    remove: (p) => { calls.push('r'); try { orig.r(p, { recursive: false }); } catch (e) { try { fs.rmdirSync(p); } catch (e2) { /* rien */ } } return true; } });
  const cfgD = path.join(tmp, 'deny', 'addons.cfg');
  put(cfgD, 'ensure gsa_a\r\nensure gsa_b\r\n');
  put(path.join(tmp, 'deny', 'fus', 'stream', 'old_occl_01.ymap'), Buffer.from([0, 1, 2, 255]));
  fs.writeFileSync = deny; fs.unlinkSync = deny; fs.rmSync = deny;
  let ok1, threw = null;
  try { ok1 = M.disableInCfg(cfgD, 'gsa_a', 'test'); M.pruneFusions([], path.join(tmp, 'deny', 'fus')); } catch (e) { threw = e; }
  Object.assign(fs, { writeFileSync: orig.w, unlinkSync: orig.u, rmSync: orig.r });
  M._setLuaFs(null);
  check('écriture refusée à Node : passe par Lua', !threw && ok1 && fs.readFileSync(cfgD, 'utf8').startsWith('# ensure gsa_a') && calls.includes('w'));
  check('suppression refusée à Node : passe par Lua', !fs.existsSync(path.join(tmp, 'deny', 'fus', 'stream', 'old_occl_01.ymap')) && calls.includes('r'));
}
const rd = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch (e) { return ''; } }; // lecture sans plantage (une régression doit donner « ÉCHEC », pas une exception)
// 10. V12.36 · Retraits par MOTIF (plasmagame_dlc2 et le pack Redline restaient : absents de la liste exacte), retrait F11 =
//     suppression du disque + mods-retires.txt + ligne enlevée de addons.cfg, scripts compagnons, synchronisation avec l'importeur
check('motifs : les 5 décidés, en minuscules', JSON.stringify(M.RETIRED_PATTERNS) === JSON.stringify(['plasmagame', 'plasmakart', 'plasmatron', 'villa_01', 'redline']));
check('plasmagame_dlc2 (absent de la liste exacte) : retiré par motif', JSON.stringify(M.retiredReason('gsa_patoche_plasmagame_dlc2_pack')) === JSON.stringify({ by: 'motif', pattern: 'plasmagame' }));
check('pack Redline : retiré par motif « redline », libellé console', (M.retiredReason('gsa_energy_redline_pack') || {}).pattern === 'redline' && M.retiredLabel(M.retiredReason('gsa_energy_redline_pack')) === 'motif « redline »');
check('majuscules dans le nom : motif quand même', (M.retiredReason('gsa_Energy_REDLINE_pack') || {}).by === 'motif');
check('nom exact de RETIRED_MAPS : par nom', (M.retiredReason('gsa_mlo_willies_supermarket') || {}).by === 'nom' && M.retiredLabel({ by: 'nom' }) === 'décision du 12/10');
check('villa 01 retirée (nom et motif), villa bunker gardée', M.retiredReason('gsa_sub_patoche_villa_01_pack') !== null && M.retiredReason('gsa_patoche_villa_01_v2') !== null && M.retiredReason('gsa_patoche_villa_bunker_pack') === null);
check('casino, prison, Benny\'s noir et blanc, ressources gs_ : gardés', ['gsa_patoche_casino_pack', 'gsa_sub_patoche_prison_pack', 'gsa_sub_patoche_benny_bw_pack', 'gs_admin', 'ox_lib'].every((n) => M.retiredReason(n) === null));
check('script compagnon du laser game : par motif', (M.retiredReason('patoche_plasmagame_script') || {}).pattern === 'plasmagame');
check('mods-retires.txt : retiré par liste (V12.36 : plus aucune map remise d office, RESTORED_MAPS vide)', (M.retiredReason('gsa_ancienne', ['gsa_ancienne']) || {}).by === 'liste' && M.retiredLabel({ by: 'liste' }) === 'mods-retires.txt'
  && (M.retiredReason('gsa_patoche_villa_bunker_pack', ['gsa_patoche_villa_bunker_pack']) || {}).by === 'liste' && M.RESTORED_MAPS.length === 0 && M.retiredLabel(null) === '');
{ // Démarrage : par motif et par liste, scripts compagnons, addons.cfg nettoyé, archives gardées
  const R3 = path.join(tmp, 'G3'), S3 = path.join(R3, 'server-data'), A3 = path.join(S3, 'resources', '[addons]');
  put(path.join(A3, 'gsa_patoche_plasmagame_dlc2_pack', 'stream', 'dlc2.ymap'), ymap([[10, 10, 10]]));
  put(path.join(A3, 'gsa_energy_redline_pack', 'stream', 'redline.ymap'), ymap([[20, 20, 20]]));
  put(path.join(A3, 'gsa_patoche_casino_pack', 'stream', 'casino.ymap'), ymap([[30, 30, 30]]));
  put(path.join(A3, 'patoche_plasmagame_script', 'fxmanifest.lua'), 'x');
  put(path.join(A3, 'patoche_lib', 'fxmanifest.lua'), 'x');
  put(path.join(A3, 'gsa_old_listed', 'stream', 'old.ymap'), ymap([[40, 40, 40]]));
  put(path.join(S3, 'cfg', 'addons.cfg'), '## Mods importés par IMPORTER-MODS.bat\r\nensure gsa_patoche_plasmagame_dlc2_pack\r\n## gsa_energy_redline_pack : désactivé par sécurité (test)\r\n# ensure gsa_energy_redline_pack\r\nensure gsa_patoche_casino_pack\r\nensure patoche_plasmagame_script\r\nensure patoche_lib\r\nensure gsa_old_listed\r\n');
  put(path.join(R3, 'mods-a-trier', 'patoche_plasmagame_dlc2_pack.zip'), 'zip');
  put(path.join(R3, 'mods-retires.txt'), '# en-tête\r\nold_listed\r\n');
  const listed = M.readRetiredList(R3);
  check('mods-retires.txt lu avec le préfixe gsa_ (absent : liste vide)', JSON.stringify(listed) === '["gsa_old_listed"]' && M.readRetiredList(path.join(tmp, 'nulle_part')).length === 0);
  const why = (n) => M.retiredReason(n, listed);
  const d3 = M.deleteMapsOnDisk(S3, R3, { filter: why, keepArchives: true });
  check('démarrage : maps par motif et par liste supprimées, casino gardé', d3.maps.sort().join() === 'gsa_energy_redline_pack,gsa_old_listed,gsa_patoche_plasmagame_dlc2_pack'
    && !fs.existsSync(path.join(A3, 'gsa_energy_redline_pack')) && !fs.existsSync(path.join(A3, 'gsa_patoche_plasmagame_dlc2_pack')) && fs.existsSync(path.join(A3, 'gsa_patoche_casino_pack')));
  const c3 = M.deleteCompanionsOnDisk(S3, (n) => { const r = why(n); return r && r.by === 'motif' ? r : null; });
  check('script compagnon du laser game supprimé, librairie du vendeur gardée', c3.scripts.join() === 'patoche_plasmagame_script' && !fs.existsSync(path.join(A3, 'patoche_plasmagame_script')) && fs.existsSync(path.join(A3, 'patoche_lib')));
  const cfg3 = rd(path.join(S3, 'cfg', 'addons.cfg'));
  check('addons.cfg : lignes (actives, commentées, notes) des retraits enlevées, le reste gardé', !cfg3.includes('plasmagame') && !cfg3.includes('redline') && !cfg3.includes('old_listed')
    && cfg3.includes('ensure gsa_patoche_casino_pack\r\n') && cfg3.includes('ensure patoche_lib\r\n') && cfg3.startsWith('## Mods importés par IMPORTER-MODS.bat\r\n'));
  const ret3 = rd(path.join(R3, 'mods-retires.txt'));
  check('archive gardée (pack payant), noms courts dans mods-retires.txt', fs.existsSync(path.join(R3, 'mods-a-trier', 'patoche_plasmagame_dlc2_pack.zip'))
    && ['patoche_plasmagame_dlc2_pack', 'energy_redline_pack', 'old_listed'].every((s) => ret3.includes(s)));
  check('2e démarrage : plus rien à retirer', M.deleteMapsOnDisk(S3, R3, { filter: why, keepArchives: true }).maps.length === 0 && M.deleteCompanionsOnDisk(S3, why).scripts.length === 0);
  check('pas de [addons] : rien, sans planter', M.deleteCompanionsOnDisk(path.join(tmp, 'nulle_part'), why).scripts.length === 0);
}
{ // Retrait F11 d'une map (retireMap) : suppression disque, mods-retires.txt, ligne enlevée, archive gardée, cas limites
  const R4 = path.join(tmp, 'G4'), S4 = path.join(R4, 'server-data'), A4 = path.join(S4, 'resources', '[addons]');
  put(path.join(A4, 'gsa_patoche_tacos_pack', 'stream', 'tacos.ymap'), ymap([[50, 50, 50]]));
  put(path.join(A4, 'gsa_patoche_tabac_pack', 'stream', 'tabac.ymap'), ymap([[60, 60, 60]]));
  put(path.join(S4, 'cfg', 'addons.cfg'), 'ensure gsa_patoche_tacos_pack\r\nensure gsa_patoche_tabac_pack\r\n');
  put(path.join(R4, 'mods-a-trier', 'patoche_tacos_pack.zip'), 'zip');
  const f11 = M.retireMap(S4, R4, 'gsa_patoche_tacos_pack', 'Fondateur');
  check('retrait F11 : dossier supprimé, le voisin gardé', f11.ok && f11.deleted && !fs.existsSync(path.join(A4, 'gsa_patoche_tacos_pack')) && fs.existsSync(path.join(A4, 'gsa_patoche_tabac_pack')));
  check('retrait F11 : ligne enlevée de addons.cfg (pas seulement commentée), voisin gardé', rd(path.join(S4, 'cfg', 'addons.cfg')) === 'ensure gsa_patoche_tabac_pack\r\n');
  check('retrait F11 : noté dans mods-retires.txt, archive gardée', rd(path.join(R4, 'mods-retires.txt')).includes('patoche_tacos_pack') && fs.existsSync(path.join(R4, 'mods-a-trier', 'patoche_tacos_pack.zip')));
  check('retrait F11 : message clair', f11.msg.includes('dossier supprimé') && f11.msg.includes('mods-retires.txt') && f11.msg.includes('addons.cfg'));
  check('retrait F11 : nom invalide refusé', !M.retireMap(S4, R4, 'gs_admin', 'x').ok && !M.retireMap(S4, R4, 'gsa_x; rm', 'x').ok);
  fs.appendFileSync(path.join(S4, 'cfg', 'addons.cfg'), 'ensure gsa_ailleurs\r\n');
  const f11b = M.retireMap(S4, R4, 'gsa_ailleurs', 'Fondateur');
  check('retrait F11 d\'une map hors [addons] : ligne commentée, message le dit', f11b.ok && !f11b.deleted && rd(path.join(S4, 'cfg', 'addons.cfg')).includes('# ensure gsa_ailleurs') && f11b.msg.includes('introuvable'));
  // Dossier verrouillé (suppression refusée partout) : noté quand même dans mods-retires.txt, message « au prochain démarrage »
  const orig = { w: fs.writeFileSync, u: fs.unlinkSync, r: fs.rmSync };
  const deny = () => { const e = new Error('Access to this API has been restricted. Use --allow-fs-write to manage permissions.'); e.code = 'ERR_ACCESS_DENIED'; throw e; };
  M._setLuaFs({ write: (p, b64) => { orig.w(p, Buffer.from(b64, 'base64')); return true; }, remove: () => true }); // Lua « réussit » sans rien effacer = verrou
  fs.unlinkSync = deny; fs.rmSync = deny;
  let f11c = null, threw = null;
  try { f11c = M.retireMap(S4, R4, 'gsa_patoche_tabac_pack', 'Fondateur'); } catch (e) { threw = e; }
  Object.assign(fs, { writeFileSync: orig.w, unlinkSync: orig.u, rmSync: orig.r });
  M._setLuaFs(null);
  check('retrait F11, dossier verrouillé : rien ne plante, noté dans mods-retires.txt, ligne enlevée, message « prochain démarrage »', !threw && f11c && f11c.ok && !f11c.deleted
    && f11c.msg.includes('prochain démarrage') && rd(path.join(R4, 'mods-retires.txt')).includes('patoche_tabac_pack') && !rd(path.join(S4, 'cfg', 'addons.cfg')).includes('tabac'));
  check('dossier verrouillé : supprimé au démarrage suivant grâce à mods-retires.txt', (M.retiredReason('gsa_patoche_tabac_pack', M.readRetiredList(R4)) || {}).by === 'liste'
    && M.deleteMapsOnDisk(S4, R4, { filter: (n) => M.retiredReason(n, M.readRetiredList(R4)), keepArchives: true }).maps.join() === 'gsa_patoche_tabac_pack');
}
{ // L'importeur (importer-mods.ps1) lit RETIRED_MAPS et RETIRED_PATTERNS dans maps.js par regex : les deux côtés doivent voir les mêmes listes
  const src = fs.readFileSync(path.join(__dirname, '..', 'server', 'resources', '[gtasoon]', 'gs_admin', 'server', 'maps.js'), 'utf8');
  const grab = (re, item) => { const b = (src.match(re) || [])[1] || ''; return [...b.matchAll(item)].map((m) => m[1]); };
  check('importeur : RETIRED_PATTERNS lus par regex = la liste', JSON.stringify(grab(/const RETIRED_PATTERNS = \[([\s\S]*?)\];/, /'([a-z0-9_]+)'/g)) === JSON.stringify(M.RETIRED_PATTERNS));
  check('importeur : RETIRED_MAPS lus par regex = la liste (noms courts)', JSON.stringify(grab(/const RETIRED_MAPS = \[([\s\S]*?)\];/, /'gsa_([a-z0-9_]+)'/g)) === JSON.stringify(M.RETIRED_MAPS.map((n) => n.replace(/^gsa_/, ''))));
  const ps1 = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'windows', 'importer-mods.ps1'), 'utf8');
  check('importeur : lit bien les deux blocs et applique Test-Retired', ps1.includes('const RETIRED_PATTERNS = \\[(.*?)\\];') && ps1.includes('const RETIRED_MAPS = \\[(.*?)\\];') && (ps1.match(/Test-Retired/g) || []).length >= 4);
}
fs.rmSync(tmp, { recursive: true, force: true });

pendingTrunc.then(() => {
  console.log(`lecteur de maps : ${passed} réussis, ${failed} échoués`);
  if (failed) process.exit(1);
});
