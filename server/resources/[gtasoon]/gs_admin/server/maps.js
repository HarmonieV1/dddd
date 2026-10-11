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
const HEAVY_MB = 16;                                 // au-delà, FiveM prévient : textures ou modèles qui ne s'affichent pas

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
      const mb = memoryMB(head);
      if (mb > HEAVY_MB) heavy.push({ file: path.basename(f), mb: Math.round(mb * 10) / 10 });
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
  return { maps: maps.map(({ streamed, ...m }) => m), conflicts };
}

if (typeof module !== 'undefined' && module.exports) module.exports = { inflateRsc7, entitiesOf, memoryMB, pagesSize, isVanillaName, placesOf, scanResource, conflictsOf, scanAll, labelOf }; // tests Node seulement

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
  // Au démarrage : une ligne en console, et les conflits en clair (à corriger avant qu'un joueur tombe dans un trou)
  setTimeout(() => {
    const r = scan();
    const placed = r.maps.filter((m) => m.places.length).length;
    const open = r.conflicts.filter((c) => !c.resolved);
    console.log(`[gs_admin] Mappings : ${r.maps.length} installé(s), ${placed} situé(s) (F11 → Monde et lieux → Mappings installés)` +
      (open.length ? `, ^1${open.length} CONFLIT(S)^7` : ', aucun conflit') + (r.conflicts.length - open.length ? `, ${r.conflicts.length - open.length} résolu(s) par fusion` : ''));
    for (const m of r.maps) for (const h of m.heavy) console.log(`^3[gs_admin] Map ${m.name} : ${h.file} prend ${h.mb} Mo en mémoire (limite conseillée 16 Mo) : textures ou murs qui peuvent ne pas s'afficher chez certains joueurs^7`);
    for (const c of r.conflicts) {
      if (c.resolved) console.log(`^2[gs_admin] Conflit résolu : ${c.file} (${c.resources.join(' + ')}) fusionné par ${c.resolved}^7`);
      else console.log(`^1[gs_admin] Conflit de maps : ${c.file} est remplacé par ${c.resources.join(' ET ')} (une seule des deux s'affichera correctement)^7`);
    }
  }, 15000);
}
