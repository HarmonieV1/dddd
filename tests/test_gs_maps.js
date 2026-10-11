// Tests du lecteur de maps (gs_admin/server/maps.js) : décompression RSC7, repérage des objets posés, fichiers du jeu
// remplacés, lieux (priorité au bâtiment qui porte le nom de la map, regroupement à 200 m), conflits entre deux maps.
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
  objects.forEach(([x, y, z], i) => {
    const p = noise + i * 128;
    body.writeUInt32LE(0xdeadbeef, p); // nom du modèle (hash)
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
check('nom affiché', M.labelOf('gsa_moreo_gym') === 'Moreo gym');

// 4. Dossiers réels : lecture, conflits entre maps
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gsmaps-'));
const mk = (res, files) => { for (const [f, b] of Object.entries(files)) { const p = path.join(tmp, res, f); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, b); } return { name: res, dir: path.join(tmp, res) }; };
const a = mk('gsa_atelier', { 'stream/ymap/TM_Workshop.ymap': ymap([[927.2, -1563.9, 34.2]]), 'stream/ymap/id1_occl_02.ymap': ymap([]), 'stream/_manifest.ymf': 'x', 'fxmanifest.lua': "this_is_a_map 'yes'" });
const b = mk('gsa_autre', { 'stream/id1_occl_02.ymap': ymap([]), 'stream/garage_b.ymap': ymap([[1200, -1500, 34]]), 'stream/_manifest.ymf': 'x' });
const c = mk('gsa_vide', { 'LICENSE': 'GPL' });
const d = mk('gsa_casse', { 'stream/abime.ymap': Buffer.from('RSC7 pas compressé du tout') });
const r = M.scanAll([a, b, c, d]);
const by = Object.fromEntries(r.maps.map((m) => [m.name, m]));
check('map lue depuis son dossier', by.gsa_atelier.places.length === 1 && by.gsa_atelier.places[0].x === 927.2);
check('conflit : même fichier du jeu remplacé par deux maps', r.conflicts.length === 1 && r.conflicts[0].file === 'id1_occl_02.ymap'
  && r.conflicts[0].resources.includes('gsa_atelier') && r.conflicts[0].resources.includes('gsa_autre'));
check('_manifest.ymf (nom commun à toutes les maps) : pas un conflit', !r.conflicts.some((x) => x.file.endsWith('.ymf')));
check('map vide : signalée sans lieu', by.gsa_vide.places.length === 0 && by.gsa_vide.ymaps === 0);
check('fichier abîmé : compté illisible, rien ne plante', by.gsa_casse.unreadable === 1 && by.gsa_casse.places.length === 0);
check('liste brute des fichiers non envoyée au menu', r.maps.every((m) => m.streamed === undefined));
check('maps triées par nom', r.maps.map((m) => m.label).join() === [...r.maps.map((m) => m.label)].sort((x, y) => x.localeCompare(y)).join());
fs.rmSync(tmp, { recursive: true, force: true });

console.log(`lecteur de maps : ${passed} réussis, ${failed} échoués`);
if (failed) process.exit(1);
