// gs_admin (serveur, Node) · V12.10 « Où sont mes mappings ? » : pour chaque map installée (ressource marquée
// `this_is_a_map` ou nommée gsa_*), l'emplacement est lu directement dans ses fichiers .ymap. Personne n'a besoin de
// connaître les coordonnées : F11 → Monde et lieux → Mappings installés liste chaque map avec son quartier, y téléporte
// le staff et peut les afficher sur sa carte. Détecte aussi les CONFLITS : deux maps qui remplacent le même fichier du jeu
// (.ymap, .ybn, .ytyp) → une seule des deux gagne, l'autre a des trous, des murs invisibles ou des textures qui clignotent.
// Lecture seule, à la demande (mise en cache tant que la liste des maps ne change pas). Aucune donnée envoyée aux joueurs.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const STREAM_CHECK = ['.ymap', '.ybn', '.ytyp'];   // fichiers dont le doublon casse une map (.ymf : nom commun, ignoré)
const MAX_FILE = 32 * 1024 * 1024;
const CLUSTER = 200.0;                              // deux lieux à moins de 200 m = le même endroit
const HEAVY = ['.ydr', '.ytd', '.ydd', '.yft'];      // modèles et textures : taille en mémoire lue dans l'en-tête
// Seuils du message « Oversized assets » de FiveM (mêmes que IMPORTER-MODS) : 48 Mo de mémoire graphique ou 64 Mo de mémoire
// système. V12.14 : la V12.11 signalait dès 16 Mo (ancienne limite), ce qui alertait à tort sur des modèles acceptés par le jeu.
const HEAVY_PHYS_MB = 48, HEAVY_VIRT_MB = 64;

/** Un .ymap est une ressource RSC7 : en-tête de 16 octets puis données compressées (deflate brut). */
function inflateRsc7(buf) {
  if (!buf || buf.length < 20 || buf.toString('latin1', 0, 4) !== 'RSC7') return null;
  try { return zlib.inflateRawSync(buf.subarray(16)); } catch (e) { return null; }
}

/** Taille en mémoire d'un bloc RSC7 (formule des « page flags » du format de ressource du jeu). */
function pagesSize(flags) {
  const s = (((flags >>> 27) & 1) << 0) + (((flags >>> 26) & 1) << 1) + (((flags >>> 25) & 1) << 2) + (((flags >>> 24) & 1) << 3)
    + (((flags >>> 17) & 0x7f) << 4) + (((flags >>> 11) & 0x3f) << 5) + (((flags >>> 7) & 0xf) << 6) + (((flags >>> 5) & 3) << 7)
    + (((flags >>> 4) & 1) << 8);
  return (0x200 * 2 ** (flags & 0xf)) * s;
}

/** Mémoire occupée une fois chargé (Mo) : la plus grande des deux parties (système / graphique). Le poids du fichier
 *  compressé ne suffit pas : un modèle de 15 Mo sur le disque peut en prendre 26 en mémoire. */
function memoryMB(head) {
  if (!head || head.length < 16 || head.toString('latin1', 0, 4) !== 'RSC7') return 0;
  return Math.max(pagesSize(head.readUInt32LE(8)), pagesSize(head.readUInt32LE(12))) / 1048576;
}

/** Mémoire système (virt) et graphique (phys), en Mo. */
function memorySplit(head) {
  if (!head || head.length < 16 || head.toString('latin1', 0, 4) !== 'RSC7') return { virt: 0, phys: 0 };
  return { virt: pagesSize(head.readUInt32LE(8)) / 1048576, phys: pagesSize(head.readUInt32LE(12)) / 1048576 };
}

/** Positions des objets posés par la map. Un CEntityDef = position (3 flottants), puis 16 octets plus loin une rotation
 *  (quaternion de norme 1), puis deux échelles proches de 1 : cette signature ne laisse passer que de vrais objets. */
function entitiesOf(data) {
  const out = [];
  if (!data) return out;
  for (let p = 0; p + 40 <= data.length; p += 4) {
    const x = data.readFloatLE(p), y = data.readFloatLE(p + 4), z = data.readFloatLE(p + 8);
    if (!(x > -4500 && x < 4600 && y > -4500 && y < 8500 && z > -250 && z < 2000)) continue;
    if (Math.abs(x) < 1 && Math.abs(y) < 1) continue;
    const qx = data.readFloatLE(p + 16), qy = data.readFloatLE(p + 20), qz = data.readFloatLE(p + 24), qw = data.readFloatLE(p + 28);
    const nq = qx * qx + qy * qy + qz * qz + qw * qw;
    if (!(nq > 0.98 && nq < 1.02)) continue;
    const sxy = data.readFloatLE(p + 32), sz = data.readFloatLE(p + 36);
    if (!(sxy > 0.05 && sxy < 20 && sz > 0.05 && sz < 20)) continue;
    out.push([x, y, z]);
  }
  return out;
}

/** Fichier du jeu de base remplacé par la map (routes, occlusion, lumières : id1_occl_02, hei_hw1_rd_critical_1…) :
 *  il contient des centaines d'objets ailleurs que la map elle-même, on ne s'en sert pas pour la situer. */
function isVanillaName(file) {
  const base = path.basename(file).toLowerCase().replace(/\.[^.]+$/, '');
  if (/(^|_)(occl|lodlights|distantlights)(_|$)/.test(base)) return true;
  // Codes de zone de la carte du jeu : ap1, bh1, ch1-3, cs1-6, dt1, hw1, id1-2, kt1, po1, sc1, ss1, vb…
  return base.split(/[_\-]/).some((t) => /^(ap|bh|bt|ch|cs|dt|hw|id|kt|po|sc|ss|vb|cv)\d{1,2}$/.test(t));
}

const median = (a) => { const s = [...a].sort((u, v) => u - v); return s.length ? s[Math.floor(s.length / 2)] : 0; };

/** Lieux d'une map : centre de chaque groupe d'objets (une map peut couvrir plusieurs endroits, ex. un pack de magasins).
 *  `ymaps` = [{ file, entities }]. Les fichiers propres à la map passent avant les fichiers du jeu qu'elle remplace. */
function placesOf(ymaps, resource = '') {
  const res = resource.toLowerCase();
  // Fichier qui porte le nom de la map (int_vinewood_police pour zero_vinewoodfree, TM_Workshop pour tm_workshop_pack) :
  // c'est le bâtiment lui-même, prioritaire pour la téléportation sur un garage ou une annexe du même endroit
  const named = (file) => path.basename(file).toLowerCase().replace(/\.[^.]+$/, '').split(/[_\-\s.]+/)
    .some((tok) => tok.length >= 4 && res.includes(tok));
  const custom = ymaps.filter((y) => y.entities.length > 0 && !isVanillaName(y.file));
  const used = custom.length ? custom : ymaps.filter((y) => y.entities.length > 0);
  const centers = used.map((y) => ({
    x: median(y.entities.map((e) => e[0])), y: median(y.entities.map((e) => e[1])), z: median(y.entities.map((e) => e[2])),
    n: y.entities.length, w: custom.length ? 1 : y.entities.length, score: (named(y.file) ? 1e6 : 0) + y.entities.length,
  }));
  const groups = [];
  for (const c of centers) {
    const g = groups.find((k) => Math.hypot(k.x - c.x, k.y - c.y) < CLUSTER);
    if (g) {
      // Même endroit : on garde la position RÉELLE de la partie la plus fournie (une moyenne tomberait entre deux étages)
      if (c.score > g.score) { g.x = c.x; g.y = c.y; g.z = c.z; g.score = c.score; }
      g.w += c.w; g.n += c.n;
    } else groups.push({ ...c });
  }
  // Sans fichier propre (map qui ne fait que modifier le jeu) : seulement l'endroit le plus chargé
  const list = custom.length ? groups : groups.sort((a, b) => b.w - a.w).slice(0, 1);
  return list.map((g) => ({ x: Math.round(g.x * 10) / 10, y: Math.round(g.y * 10) / 10, z: Math.round(g.z * 10) / 10, objects: g.n }));
}

/** Tous les fichiers d'un dossier (récursif, sans node_modules). */
function walk(dir, out = []) {
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const d of entries) {
    const p = path.join(dir, d.name);
    if (d.isDirectory()) { if (d.name !== 'node_modules' && !d.name.startsWith('.')) walk(p, out); } else if (d.isFile()) out.push(p);
  }
  return out;
}

/** Lit une ressource map : ses lieux et les fichiers du jeu qu'elle remplace. */
function scanResource(name, dir) {
  const files = walk(dir);
  const ymaps = [], streamed = [], heavy = [];
  let unreadable = 0, assets = 0;
  for (const f of files) {
    const ext = path.extname(f).toLowerCase();
    if (STREAM_CHECK.includes(ext)) streamed.push({ file: path.basename(f).toLowerCase(), path: f });
    if (HEAVY.includes(ext) || STREAM_CHECK.includes(ext)) assets++;
    if (HEAVY.includes(ext)) {
      let head = null;
      try { const fd = fs.openSync(f, 'r'); head = Buffer.alloc(16); fs.readSync(fd, head, 0, 16, 0); fs.closeSync(fd); } catch (e) { head = null; }
      const m = memorySplit(head);
      if (m.phys > HEAVY_PHYS_MB || m.virt > HEAVY_VIRT_MB) heavy.push({ file: path.basename(f), mb: Math.round(Math.max(m.phys, m.virt) * 10) / 10 });
    }
    if (ext !== '.ymap') continue;
    let buf = null;
    try { if (fs.statSync(f).size <= MAX_FILE) buf = fs.readFileSync(f); } catch (e) { buf = null; }
    const data = inflateRsc7(buf);
    if (!data) { unreadable++; continue; }
    ymaps.push({ file: path.basename(f), entities: entitiesOf(data) });
  }
  heavy.sort((a, b) => b.mb - a.mb);
  return { name, label: labelOf(name), places: placesOf(ymaps, name), ymaps: ymaps.length, unreadable, assets, heavy, streamed };
}

function labelOf(name) {
  const s = name.replace(/^gsa_/, '').replace(/[_\-]+/g, ' ').trim();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const FUSION = /^gsa_zz_fusion/; // ressource de fusion (tools/maps/fusion_occlusion.py), démarrée après les maps

function digest(file) {
  try { return crypto.createHash('sha1').update(fs.readFileSync(file)).digest('hex'); } catch (e) { return file; }
}

/** Fichiers remplacés par au moins deux maps AVEC un contenu différent (deux copies identiques ne gênent pas).
 *  `resolved` : une ressource de fusion livre aussi ce fichier et passe après les autres → c'est sa version qui compte. */
function conflictsOf(maps) {
  const by = new Map();
  for (const m of maps) {
    const seen = new Set();
    for (const s of m.streamed) {
      const f = typeof s === 'string' ? s : s.file;
      if (seen.has(f)) continue;
      seen.add(f);
      if (!by.has(f)) by.set(f, []);
      by.get(f).push({ name: m.name, path: typeof s === 'string' ? null : s.path });
    }
  }
  const out = [];
  for (const [file, list] of by.entries()) {
    if (list.length < 2) continue;
    const others = list.filter((x) => !FUSION.test(x.name));
    const sums = new Set(others.map((x) => (x.path ? digest(x.path) : x.name)));
    if (others.length < 2 || sums.size < 2) continue;
    const fix = list.find((x) => FUSION.test(x.name));
    out.push({ file, resources: others.map((x) => x.name), resolved: fix ? fix.name : null });
  }
  return out.sort((a, b) => a.file.localeCompare(b.file));
}

/** `list` = [{ name, dir }] → résultat envoyé au menu F11 (sans la liste brute des fichiers). */
function scanAll(list) {
  const maps = list.map((r) => scanResource(r.name, r.dir));
  const conflicts = conflictsOf(maps);
  maps.sort((a, b) => a.label.localeCompare(b.label));
  // La ressource de fusion n'est pas une map à visiter : elle sert seulement à résoudre les conflits
  // V12.14 : seulement les vraies maps. Les vêtements et véhicules importés (gsa_*) n'ont ni .ymap ni .ytyp ni .ybn.
  const isMap = (m) => !/^gsa_zz_fusion/.test(m.name) && (m.ymaps > 0 || m.streamed.length > 0);
  return { maps: maps.filter(isMap).map(({ streamed, ...m }) => m), conflicts };
}

// ---- V12.13 · Fusion automatique des conflits d'OCCLUSION (même algorithme que tools/maps/fusion_occlusion.py) ----------
// Un fichier *_occl_*.ymap liste ce que le jeu peut cacher derrière les murs. Chaque MLO en retire ce qui ferait disparaître son
// intérieur ; si deux maps livrent le même fichier, une seule version compte. Fusion = occluders présents dans TOUTES les
// versions (jeu − retraits de A − retraits de B). Écrite dans la ressource gsa_zz_fusion_occlusion, lancée après les maps.
const META_BASE = 0x50000000, CMAPDATA = 0xd3593fa6, BOX_OFF = 128, MODEL_OFF = 144, BOX_SIZE = 16, MODEL_SIZE = 64;
const PREFER = ['gsa_cfx_draft_pb_liquor_pack']; // si une fusion échoue : version gardée en priorité (choix du 12/10)

function readMeta(raw) {
  const data = inflateRsc7(raw);
  if (!data || data.length < 0x50 || data.readUInt32LE(0x10) !== 0x50524430) return null;
  const blocksPtr = Number(data.readBigUInt64LE(0x30)) - META_BASE, count = data.readInt16LE(0x4c);
  const blocks = [];
  for (let i = 0; i < count; i++) {
    const o = blocksPtr + i * 16;
    if (o < 0 || o + 16 > data.length) return null;
    blocks.push({ hash: data.readUInt32LE(o), len: data.readInt32LE(o + 4), off: Number(data.readBigUInt64LE(o + 8)) - META_BASE });
  }
  const root = data.readInt32LE(0x1c);
  if (!blocks[root - 1] || blocks[root - 1].hash !== CMAPDATA) return null;
  const cmap = blocks[root - 1].off;
  const arr = (field) => {
    const p = data.readUInt32LE(cmap + field), n = data.readUInt16LE(cmap + field + 8);
    if (!p || !n || !blocks[(p & 0xfff) - 1]) return { off: null, n: 0 };
    return { off: blocks[(p & 0xfff) - 1].off + (p >>> 12), n };
  };
  const boxes = () => { const a = arr(BOX_OFF); const o = []; for (let i = 0; i < a.n; i++) o.push(data.subarray(a.off + i * BOX_SIZE, a.off + (i + 1) * BOX_SIZE)); return o; };
  const models = () => {
    const a = arr(MODEL_OFF); const o = [];
    for (let i = 0; i < a.n; i++) {
      const s = data.subarray(a.off + i * MODEL_SIZE, a.off + (i + 1) * MODEL_SIZE);
      const size = s.readUInt32LE(32), vp = s.readUInt32LE(40);
      let verts = Buffer.alloc(0);
      if (vp && blocks[(vp & 0xfff) - 1]) { const st = blocks[(vp & 0xfff) - 1].off + (vp >>> 12); verts = data.subarray(st, st + size); }
      o.push({ s, key: Buffer.concat([s.subarray(0, 40), s.subarray(48), verts]).toString('hex') });
    }
    return o;
  };
  const keep = (bx, md) => {
    for (const [field, items, size] of [[BOX_OFF, bx, BOX_SIZE], [MODEL_OFF, md, MODEL_SIZE]]) {
      const a = arr(field);
      if (a.off === null) continue;
      const blob = Buffer.concat([...items.map((x) => Buffer.from(x)), Buffer.alloc(a.n * size - items.length * size)]);
      blob.copy(data, a.off);
      const p = data.readUInt32LE(cmap + field);
      data.writeUInt32LE(items.length ? p : 0, cmap + field);
      data.writeUInt16LE(items.length, cmap + field + 8); data.writeUInt16LE(items.length, cmap + field + 10);
    }
  };
  return { head: raw.subarray(0, 16), data, boxes, models, keep };
}

/** Fusionne plusieurs versions d'un fichier d'occlusion (Buffers) ; null si l'une n'est pas lisible. La 1re sert de base. */
function mergeOcclusion(raws) {
  const ys = raws.map(readMeta);
  if (ys.length < 2 || ys.some((y) => !y)) return null;
  const count = (list) => list.reduce((m, k) => m.set(k, (m.get(k) || 0) + 1), new Map());
  const inter = (a, b) => { const r = new Map(); for (const [k, v] of a) if (b.has(k)) r.set(k, Math.min(v, b.get(k))); return r; };
  let cb = count(ys[0].boxes().map((b) => b.toString('hex')));
  let cm = count(ys[0].models().map((m) => m.key));
  for (const y of ys.slice(1)) { cb = inter(cb, count(y.boxes().map((b) => b.toString('hex')))); cm = inter(cm, count(y.models().map((m) => m.key))); }
  const boxes = [], models = [];
  for (const b of ys[0].boxes()) { const k = b.toString('hex'); if (cb.get(k) > 0) { boxes.push(Buffer.from(b)); cb.set(k, cb.get(k) - 1); } }
  for (const m of ys[0].models()) { if (cm.get(m.key) > 0) { models.push(Buffer.from(m.s)); cm.set(m.key, cm.get(m.key) - 1); } }
  ys[0].keep(boxes, models);
  return { bytes: Buffer.concat([ys[0].head, zlib.deflateRawSync(ys[0].data, { level: 9 })]), boxes: boxes.length, models: models.length };
}

const FUSION_MANIFEST = "-- Fusion automatique des fichiers d'occlusion en conflit entre maps (gs_admin/server/maps.js).\n" +
  "-- Lancée APRÈS les maps (dev.cfg / prod.cfg), donc prioritaire. Contenu régénéré à chaque démarrage si besoin.\n" +
  "fx_version 'cerulean'\ngame 'gta5'\nauthor 'RoadLine'\nlua54 'yes'\nthis_is_a_map 'yes'\n";

/** Écrit les fusions des conflits d'occlusion non résolus dans `fusionDir`. `maps` = résultat de scanResource (avec streamed).
 *  Renvoie la liste des fichiers écrits ou modifiés (vide = rien à faire). Si une fusion échoue : version préférée (PREFER). */
function applyFusions(maps, fusionDir) {
  const written = [];
  for (const c of conflictsOf(maps)) {
    if (c.resolved || !/_occl_/.test(c.file)) continue;
    const owners = maps.filter((m) => c.resources.includes(m.name));
    const paths = owners.map((m) => (m.streamed.find((s) => s.file === c.file) || {}).path).filter(Boolean);
    let raws = [];
    try { raws = paths.map((p) => fs.readFileSync(p)); } catch (e) { continue; }
    const merged = mergeOcclusion(raws);
    let out = merged && merged.bytes;
    let how = merged ? `fusion (${merged.boxes} boîtes, ${merged.models} modèles)` : '';
    if (!out) {
      const pick = owners.find((m) => PREFER.includes(m.name)) || owners.slice().sort((a, b) => a.name.localeCompare(b.name))[0];
      out = fs.readFileSync(pick.streamed.find((s) => s.file === c.file).path);
      how = `version de ${pick.name} gardée (fusion impossible)`;
    }
    const dest = path.join(fusionDir, 'stream', c.file);
    let same = false;
    try { same = fs.readFileSync(dest).equals(out); } catch (e) { same = false; }
    if (same) continue;
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, out);
    written.push({ file: c.file, resources: c.resources, how });
  }
  if (written.length) {
    const mf = path.join(fusionDir, 'fxmanifest.lua');
    try { if (fs.readFileSync(mf, 'utf8') !== FUSION_MANIFEST) throw new Error('différent'); } catch (e) { fs.writeFileSync(mf, FUSION_MANIFEST); }
  }
  return written;
}

if (typeof module !== 'undefined' && module.exports) module.exports = { inflateRsc7, entitiesOf, memoryMB, memorySplit, pagesSize, isVanillaName, placesOf, scanResource, conflictsOf, scanAll, labelOf, mergeOcclusion, applyFusions }; // tests Node seulement

if (typeof GetCurrentResourceName === 'function') {
  const mapResources = () => {
    const out = [];
    for (let i = 0; i < GetNumResources(); i++) {
      const name = GetResourceByFindIndex(i);
      if (!name || GetResourceState(name) !== 'started') continue;
      const isMap = String(GetResourceMetadata(name, 'this_is_a_map', 0) || '').toLowerCase() === 'yes' || name.startsWith('gsa_');
      const dir = GetResourcePath(name);
      if (isMap && dir) out.push({ name, dir });
    }
    return out;
  };
  let cache = null, cacheKey = '';
  const scan = () => {
    const list = mapResources();
    const key = list.map((r) => r.name).sort().join(',');
    if (!cache || key !== cacheKey) {
      try { cache = scanAll(list); } catch (e) { cache = { maps: [], conflicts: [], error: String(e && e.message || e) }; }
      cacheKey = key;
    }
    return cache;
  };
  exports('MapScan', scan);
  // V12.13 : conflits d'occlusion fusionnés tout seuls dans gsa_zz_fusion_occlusion, puis relance de cette ressource pour
  // qu'elle passe APRÈS toutes les maps (la dernière lancée l'emporte). Aucun fichier à envoyer, rien à faire à la main.
  const FUSION_RES = 'gsa_zz_fusion_occlusion';
  const fuse = () => {
    const dir = GetResourcePath(FUSION_RES);
    if (!dir) { console.log(`^3[gs_admin] Ressource ${FUSION_RES} absente : conflits d'occlusion non fusionnés (METTRE-A-JOUR)^7`); return; }
    const list = mapResources().filter((r) => r.name !== FUSION_RES);
    let written = [];
    try { written = applyFusions(list.map((r) => scanResource(r.name, r.dir)), dir); } catch (e) { console.log(`^1[gs_admin] Fusion des maps impossible : ${e.message}^7`); }
    for (const w of written) console.log(`^2[gs_admin] ${w.file} (${w.resources.join(' + ')}) : ${w.how}^7`);
    let has = false;
    try { has = fs.readdirSync(path.join(dir, 'stream')).length > 0; } catch (e) { has = false; }
    if (has) { StopResource(FUSION_RES); StartResource(FUSION_RES); cache = null; }
  };
  // Au démarrage : fusion, puis une ligne en console et les conflits en clair (à corriger avant qu'un joueur tombe dans un trou)
  setTimeout(() => {
    fuse();
    const r = scan();
    const placed = r.maps.filter((m) => m.places.length).length;
    const open = r.conflicts.filter((c) => !c.resolved);
    console.log(`[gs_admin] Mappings : ${r.maps.length} installé(s), ${placed} situé(s) (F11 → Monde et lieux → Mappings installés)` +
      (open.length ? `, ^1${open.length} CONFLIT(S)^7` : ', aucun conflit') + (r.conflicts.length - open.length ? `, ${r.conflicts.length - open.length} résolu(s) par fusion` : ''));
    for (const m of r.maps) for (const h of m.heavy) console.log(`^3[gs_admin] Map ${m.name} : ${h.file} prend ${h.mb} Mo en mémoire (au-delà de la limite FiveM : 48 Mo graphique / 64 Mo système) : textures ou murs qui peuvent ne pas s'afficher^7`);
    for (const c of r.conflicts) {
      if (c.resolved) console.log(`^2[gs_admin] Conflit résolu : ${c.file} (${c.resources.join(' + ')}) fusionné par ${c.resolved}^7`);
      else console.log(`^1[gs_admin] Conflit de maps : ${c.file} est remplacé par ${c.resources.join(' ET ')} (une seule des deux s'affichera correctement)^7`);
    }
  }, 15000);
}
