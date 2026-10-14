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

// V12.18 · Écritures disque. Les FXServer récents bloquent fs.write* / fs.rm* en JavaScript (« Use --allow-fs-write ») :
// on essaie Node, et sinon on passe par server/fsw.lua (Lua n'est pas concerné). Les tests Node utilisent fs directement.
const denied = (e) => e && (e.code === 'ERR_ACCESS_DENIED' || /allow-fs-write|restricted/i.test(String(e.message)));
let luaFs = null;
// V12.24 : FXServer n'autorise une ressource à écrire que dans SON dossier → la ressource de fusion écrit elle-même
// (gsa_zz_fusion_occlusion/server.lua, événement gsa_fusion:save). null = tests Node (écriture directe).
let fusionSave = null; // { write(path, base64), remove(path) } branché au démarrage dans FiveM
function writeFile(p, data) {
  const buf = Buffer.isBuffer(data) ? data : Buffer.from(String(data), 'utf8');
  try { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, buf); return; } catch (e) { if (!luaFs || !denied(e)) throw e; }
  if (!luaFs.write(p, buf.toString('base64'))) throw new Error(`écriture refusée : ${p}`);
}
function removeFile(p) {
  try { fs.unlinkSync(p); return; } catch (e) { if (!luaFs || !denied(e)) throw e; }
  if (!fs.existsSync(p)) return;
  luaFs.remove(p);
  if (fs.existsSync(p)) throw new Error(`suppression refusée : ${p}`);
}
function removeTree(p) {
  try { fs.rmSync(p, { recursive: true, force: true }); return; } catch (e) { if (!luaFs || !denied(e)) throw e; }
  let st; try { st = fs.statSync(p); } catch (e) { return; }
  if (st.isDirectory()) for (const f of fs.readdirSync(p)) removeTree(path.join(p, f));
  luaFs.remove(p);
  if (fs.existsSync(p)) throw new Error(`suppression refusée : ${p}`);
}

/** Un .ymap est une ressource RSC7 : en-tête de 16 octets puis données compressées (deflate brut). */
function inflateRsc7(buf) {
  if (!buf || buf.length < 20 || buf.toString('latin1', 0, 4) !== 'RSC7') return null;
  try { return zlib.inflateRawSync(buf.subarray(16)); } catch (e) { return null; }
}

/** V12.27 · Fichier du jeu TRONQUÉ (téléchargement coupé) ? Un tel fichier fait planter chaque joueur qui le charge
 *  (« Invalid fixup, address is neither virtual nor physical (in xxx.ydr) »). Seul signe retenu, sans faux positif : le
 *  flux compressé s'arrête avant sa fin (erreur zlib « unexpected end of file »). Un fichier chiffré ou d'un autre format
 *  n'est jamais déclaré abîmé. Asynchrone (décompression hors du fil du serveur). Renvoie true / false. */
const STREAM_EXT = /\.(ydr|ydd|yft|ytd|ybn|ymap|ytyp)$/i;
function rscTruncated(buf) {
  return new Promise((resolve) => {
    if (!buf || buf.length < 20 || buf.toString('latin1', 0, 4) !== 'RSC7') return resolve(false);
    zlib.inflateRaw(buf.subarray(16), (err) => resolve(!!err && (err.code === 'Z_BUF_ERROR' || /unexpected end/i.test(String(err.message)))));
  });
}

/** Fichiers tronqués d'un dossier de ressource (liste de chemins relatifs). Un fichier à la fois (mémoire). */
async function truncatedFiles(dir) {
  const bad = [];
  for (const f of walk(dir).filter((x) => STREAM_EXT.test(x))) {
    let buf;
    try { buf = await fs.promises.readFile(f); } catch (e) { continue; }
    if (await rscTruncated(buf)) bad.push(path.relative(dir, f));
  }
  return bad;
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
    out.push([x, y, z, p >= 24 ? data.readInt32LE(p - 24) : 0]); // CEntityDef : archetypeName 24 octets avant la position
  }
  return out;
}

/** Hash Jenkins du jeu (GetHashKey), en entier signé comme côté Lua. */
function joaat(str) {
  let h = 0;
  for (const c of Buffer.from(String(str).toLowerCase(), 'utf8')) {
    h = (h + c) >>> 0; h = (h + (h << 10)) >>> 0; h = (h ^ (h >>> 6)) >>> 0;
  }
  h = (h + (h << 3)) >>> 0; h = (h ^ (h >>> 11)) >>> 0; h = (h + (h << 15)) >>> 0;
  return h | 0;
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
  const ymaps = [], streamed = [], heavy = [], own = new Set();
  let unreadable = 0, assets = 0;
  for (const f of files) {
    const ext = path.extname(f).toLowerCase();
    if (STREAM_CHECK.includes(ext)) streamed.push({ file: path.basename(f).toLowerCase(), path: f });
    if (HEAVY.includes(ext) || STREAM_CHECK.includes(ext)) assets++;
    if (ext === '.ydr' || ext === '.yft') own.add(joaat(path.basename(f, path.extname(f))));
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
  // V12.30 · Modèles PROPRES à la map posés par ses .ymap (nom d'objet = nom d'un de ses .ydr / .yft) : le client vérifie
  // qu'il les a bien et qu'il arrive à les charger (F11 → Mappings installés → Contrôler). Sans eux : bâtiment invisible.
  const models = [];
  for (const y of ymaps) for (const e of y.entities) if (own.has(e[3]) && !models.includes(e[3]) && models.length < 200) models.push(e[3]);
  return { name, label: labelOf(name), places: placesOf(ymaps, name), ymaps: ymaps.length, unreadable, assets, heavy, streamed, models, ownModels: own.size };
}

// V12.15 : vrais noms des maps installées (menu F11 et blips), au lieu du nom de fichier du mod
const LABELS = {
  gsa_sub_patoche_benny_bw_pack: "Benny's",
  gsa_9a13b85d2a84bbb31aad0d6f69e178d3b502ba3d: 'Props de récolte (orge, houblon, maïs, tabac, pavot)', // V12.45 : gs_harvest // V12.40 : plus de blip public (celui du métier mécano suffit), le nom reste
  gsa_apteka_pops_pills_v_dauntaune: "Pharmacie Pop's Pills",
  gsa_bahamas_mamas_v1_0: 'Bahama Mamas',
  gsa_biznes_ofis: "Bureau d'entreprise",
  gsa_cfx_draft_pb_liquor_pack: "Magasin d'alcool de Paleto Bay",
  gsa_energy_redline_pack: 'Pack Redline',
  gsa_hp_fleeca_main: 'Banques Fleeca (rénovées)',
  gsa_mlo_willies_supermarket: "Supermarché Willie's",
  gsa_moreo_gym: 'Salle de sport',
  gsa_nelegalnyjj_avtoservis_i_avtorazborka: 'Garage clandestin et casse',
  gsa_pillbox_hospital_interior_master: 'Hôpital Pillbox',
  gsa_tm_workshop_pack: 'Atelier mécanique de La Mesa',
  gsa_zabroshennaja_derevnja_v1_0: 'Village abandonné',
  gsa_zero_vinewoodfree: 'Commissariat de Vinewood',
  gsa_mrpd_etendu: 'Commissariat de Mission Row (sous-sol)',
};

function labelOf(name) {
  if (LABELS[name]) return LABELS[name];
  if (PUBLIC[name] && PUBLIC[name].label) return PUBLIC[name].label;
  const s = name.replace(/^gsa_/, '').replace(/_v\d+(_\d+)?$/, '').replace(/(^|_)(sub|patoche|pack|mlo|cfx|draft)(?=_|$)/g, '_')
    .replace(/[_\-]+/g, ' ').trim() || name.replace(/^gsa_/, '');
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// V12.29 · Blips PUBLICS des mappings (tous les joueurs) : nom et icône. false = pas de blip (lieu secret ou partout sur la
// carte : QG de gang, labo, garage clandestin, villa privée, panneaux). Map inconnue ici : blip avec son nom nettoyé.
const PUBLIC = {
  gsa_es_billboard_map_pack: false,
  gsa_patoche_ammu: { label: 'Ammu-Nation', sprite: 110, color: 1 },
  gsa_patoche_ammu2: { label: 'Ammu-Nation', sprite: 110, color: 1 },
  gsa_patoche_gamestand_pack: { label: 'Stand de jeux', sprite: 38, color: 27 }, // V12.44 (+ patoche_gamestand_script)
  gsa_9a13b85d2a84bbb31aad0d6f69e178d3b502ba3d: false, // V12.45 : props de récolte (BzZz), pas un lieu
  gsa_patoche_fastbox_pack: false, // V12.44 : points relais FastBox (colis) : le script pose ses propres blips (config Patoche)
  gsa_sub_patoche_track_pack: { label: 'Circuit', sprite: 38, color: 46 }, // V12.44 (+ patoche_track_script)
  gsa_patoche_beach_party_pack: { label: 'Beach party', sprite: 93, color: 27 },
  gsa_patoche_billiard_pack: { label: 'Salle de billard', sprite: 93, color: 5 },
  gsa_patoche_bumpercar_del_perro: { label: 'Auto-tamponneuses', sprite: 38, color: 27 },
  gsa_patoche_bumpercar_pacific: { label: 'Auto-tamponneuses', sprite: 38, color: 27 },
  gsa_patoche_cardealer_pack: { label: 'Concession automobile', sprite: 225, color: 3 },
  gsa_patoche_casino_pack: { label: 'Casino', sprite: 679, color: 5 },
  gsa_patoche_gang_2_pack: false,
  gsa_patoche_hideout_mechanic_pack: false,
  gsa_patoche_petshop_pack: { label: 'Animalerie', sprite: 52, color: 2 },
  gsa_patoche_plasmagame_pack: { label: 'Laser game', sprite: 38, color: 7 },
  gsa_patoche_plasmagame_dlc_pack: false, // extension du laser game (même endroit)
  gsa_patoche_plasmakart_pack: { label: 'Karting', sprite: 38, color: 46 },
  gsa_patoche_plasmakart_dlc_pack: false,
  gsa_patoche_soccer_pack: { label: 'Terrain de foot', sprite: 38, color: 2 },
  gsa_patoche_stock_pack: { label: 'Entrepôt', sprite: 357, color: 0 },
  gsa_patoche_tabac_pack: { label: 'Bureau de tabac', sprite: 52, color: 0 },
  gsa_patoche_tacos_pack: { label: 'Tacos', sprite: 93, color: 17 },
  gsa_sub_patoche_benny_bw_pack: false, // V12.40 : le blip « Benny's » est celui du métier mécano (gs_jobs), pas de doublon
  gsa_sub_patoche_prison_pack: { label: 'Prison de Bolingbroke', sprite: 188, color: 1 },
  gsa_sub_patoche_storage_pack: { label: 'Box de stockage', sprite: 357, color: 0 },
  gsa_patoche_villa_bunker_pack: false, // villa privée (V12.31 : gardée à la place de la villa 01)
  gsa_sub_patoche_weed_pack: false,
  gsa_mrpd_etendu: false, // sous-sol du commissariat : le commissariat a déjà son blip
};

// V12.40 · Map absente de PUBLIC : icône devinée d'après son nom (plus jamais le rond blanc par défaut). Aucun mot reconnu
// (villa, décor, maison…) = pas de blip public (la map reste dans F11 → Mappings installés pour le staff).
const GUESS = [
  [/(^|_)(villa|house|mansion|appart|apartment|maison|home)(_|$)/, false],
  [/(benny|mechanic|meca|garage|custom|tuning|lsc|repair)/, { sprite: 446, color: 47 }],
  [/(cardealer|dealer|concession|showroom|pdm)/, { sprite: 225, color: 3 }],
  [/(police|lspd|mrpd|sheriff|(^|_)pd(_|$))/, { sprite: 60, color: 29 }],
  [/(prison|jail|bolingbroke)/, { sprite: 188, color: 1 }],
  [/(hospital|medical|clinic|pillbox|(^|_)ems(_|$))/, { sprite: 61, color: 1 }],
  [/(casino)/, { sprite: 679, color: 5 }],
  [/(ammu|gunshop|weapon)/, { sprite: 110, color: 1 }],
  [/(bank|fleeca)/, { sprite: 108, color: 2 }],
  [/(barber|hair|coiff)/, { sprite: 71, color: 0 }],
  [/(tattoo|tatoo)/, { sprite: 75, color: 0 }],
  [/(cloth|binco|suburban|ponsonby|boutique)/, { sprite: 73, color: 0 }],
  [/(gym|fitness|muscle)/, { sprite: 311, color: 7 }],
  [/(gas|fuel|ltd|station_service)/, { sprite: 361, color: 1 }],
  [/(bar|pub|club|nightclub|tequila|bahama|unicorn|lounge)/, { sprite: 93, color: 27 }],
  [/(burger|pizza|tacos|food|restaurant|diner|cafe|coffee|bean)/, { sprite: 93, color: 17 }],
  [/(shop|store|market|liquor|247|superette|supermarket)/, { sprite: 52, color: 2 }],
  [/(stock|storage|warehouse|entrepot|depot)/, { sprite: 357, color: 0 }],
  [/(bowling|arcade|cinema|kart|soccer|golf|beach|park|bumpercar|laser)/, { sprite: 38, color: 27 }],
];
function guessBlip(name) {
  const n = String(name).toLowerCase().replace(/^gsa_/, '');
  for (const [re, cfg] of GUESS) if (re.test(n)) return cfg;
  return false;
}

/** Blips publics : un par map située, sauf celles marquées false (ou sans icône devinable). */
function publicBlips(maps) {
  const out = [];
  for (const m of maps) {
    const cfg = PUBLIC[m.name] !== undefined ? PUBLIC[m.name] : guessBlip(m.name);
    if (cfg === false || !m.places || !m.places.length) continue;
    const p = m.places[0];
    const soon = m.activity && !m.activity.script ? ' (bientôt)' : ''; // activité sans son script : pas encore jouable
    out.push({ label: String((cfg && cfg.label) || m.label).slice(0, 40 - soon.length) + soon, sprite: (cfg && cfg.sprite) || 1, color: (cfg && cfg.color) || 0, x: p.x, y: p.y, z: p.z });
  }
  return out;
}

// V12.30 · Maps d'ACTIVITÉ : le bâtiment seul n'a aucun point d'interaction. Le jeu (laser game, karting…) est un SCRIPT
// vendu à part par l'auteur (rangé dans mods-tri\scripts-a-verifier par IMPORTER-MODS, jamais installé sans relecture).
// Clé = mot cherché dans le nom des ressources démarrées (patoche_plasmagame_script…) ; sans script : décor seul.
const ACTIVITY = {
  gsa_patoche_plasmagame_pack: { what: 'laser game', token: 'plasmagame' },
  gsa_patoche_plasmakart_pack: { what: 'karting', token: 'plasmakart' },
  gsa_patoche_bumpercar_del_perro: { what: 'auto-tamponneuses', token: 'bumpercar' },
  gsa_patoche_bumpercar_pacific: { what: 'auto-tamponneuses', token: 'bumpercar' },
  gsa_patoche_soccer_pack: { what: 'football', token: 'soccer' },
  gsa_patoche_billiard_pack: { what: 'billard', token: 'billiard' },
  gsa_patoche_gamestand_pack: { what: 'stand de jeux', token: 'gamestand' }, // V12.44
  gsa_sub_patoche_track_pack: { what: 'circuit', token: 'patoche_track' },  // V12.44
};

/** Script d'activité démarré pour une map (`started` = noms des ressources démarrées), ou null. */
function activityOf(name, started) {
  const a = ACTIVITY[name];
  if (!a) return undefined;
  const script = started.find((r) => !/^gsa_/.test(r) && r.toLowerCase().includes(a.token)) || null;
  return { what: a.what, script };
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
// V12.43 · Conflits qui ne sont PAS de l'occlusion (herbe, décor) entre packs protégés : impossibles à fusionner. On tranche :
// la ressource choisie est relancée après les autres au démarrage → sa version du fichier est celle que les joueurs reçoivent.
// L'autre map perd seulement ce fichier-là (un peu d'herbe ou de décor autour d'elle). Inverser = changer le nom ici.
const KEEP_ON_CONFLICT = {
  'cs4_03_grass_0.ymap': 'gsa_sub_patoche_storage_pack',  // stand de jeux ↔ entrepôt : l'entrepôt garde son herbe
  'hei_sm_22_strm_2.ymap': 'gsa_patoche_billiard_pack',   // stand de jeux ↔ billard : le billard garde son décor
};
/** Conflits tranchés par priorité : { file → ressource gardée } pour ceux dont la ressource choisie est bien en cause. */
function keptOf(conflicts) {
  const out = {};
  for (const c of conflicts) {
    const k = KEEP_ON_CONFLICT[c.file];
    if (!c.resolved && k && c.resources.includes(k)) out[c.file] = k;
  }
  return out;
}

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

/** Fusions devenues inutiles (une des deux maps retirée) : leur fichier masquerait la version de la map restante. */
function pruneFusions(maps, fusionDir) {
  const wanted = new Set(conflictsOf(maps).filter((c) => /_occl_/.test(c.file)).map((c) => c.file));
  const removed = [];
  let files = [];
  try { files = fs.readdirSync(path.join(fusionDir, 'stream')); } catch (e) { files = []; }
  for (const f of files) {
    if (wanted.has(f.toLowerCase())) continue;
    try { removeFile(path.join(fusionDir, 'stream', f)); removed.push(f); } catch (e) { /* verrouillé : au prochain démarrage */ }
  }
  return removed;
}

/** Retire une map : sa ligne de cfg/addons.cfg passe en commentaire (réversible : enlever le #). Renvoie true si trouvée.
 *  Ne touche à aucune autre ligne. */
function disableInCfg(cfgFile, name, note) {
  if (!/^gsa_[a-z0-9_]+$/.test(name)) return false;
  let text;
  try { text = fs.readFileSync(cfgFile, 'utf8'); } catch (e) { return false; }
  const re = new RegExp('^[ \\t]*ensure[ \\t]+' + name + '([ \\t][^\\r\\n]*)?(?=\\r?$)', 'm');
  if (!re.test(text)) return false;
  writeFile(cfgFile, text.replace(re, `# ensure ${name}   # ${note}`));
  return true;
}

/** Nom donné par IMPORTER-MODS à une archive (même règle que Clean-Name dans importer-mods.ps1). */
function cleanName(file) {
  let n = path.basename(file).replace(/\.[^.]+$/, '');
  n = n.replace(/^[0-9a-f]{6}-/, '').replace(/_\d{9,}_\d+$/, '');
  n = n.replace(/[^A-Za-z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
  if (n.length > 40) n = n.slice(0, 40).replace(/_+$/, '');
  return n || 'mod';
}

/** Ressources activées (lignes « ensure x » non commentées) d'un fichier cfg. */
function activeEnsures(text) {
  return String(text).split(/\r?\n/).map((l) => l.match(/^\s*ensure\s+(\S+)/)).filter(Boolean).map((x) => x[1]);
}

/** Lignes « ensure x » (actives ou commentées) et notes « ## x : … » de ces ressources retirées de cfg/addons.cfg, le reste
 *  intact (fins de ligne gardées). Rien si le fichier n'existe pas (VPS sans mods). V12.36 : factorisé (maps et scripts). */
function removeCfgLines(cfgFile, names) {
  if (!names.length) return;
  try {
    const text = fs.readFileSync(cfgFile, 'utf8');
    const eol = text.includes('\r\n') ? '\r\n' : '\n';
    const kept = text.split(/\r?\n/).filter((line) => {
      const m = line.match(/^\s*#?\s*ensure\s+(\S+)/) || line.match(/^\s*##\s*(\S+)\s*:/);
      return !(m && names.includes(m[1]));
    });
    writeFile(cfgFile, kept.join(eol));
  } catch (e) { /* pas de addons.cfg (VPS sans mods) */ }
}

/** V12.16 · Supprime DÉFINITIVEMENT toutes les maps du disque (demande du 12/10 : « retire-les totalement de ma base »).
 *  serverData = dossier server-data ; root = dossier parent (C:\GTASOON sur le PC). Seules les vraies maps de
 *  resources/[addons] (gsa_* avec .ymap / .ytyp / .ybn) : vêtements et véhicules intacts. Pour chacune : dossier effacé,
 *  ligne retirée de cfg/addons.cfg, copie de mods-tri/maps et archive de mods-a-trier effacées, nom ajouté à
 *  mods-retires.txt (IMPORTER-MODS ne la réinstallera jamais, même depuis une archive groupée).
 *  opts.only = noms exacts ; opts.filter(name) = prédicat (V12.36 : retrait par motif) ; opts.keepArchives = archives gardées. */
function deleteMapsOnDisk(serverData, root, opts = {}) {
  const addons = path.join(serverData, 'resources', '[addons]');
  const done = { maps: [], errors: [] };
  let dirs = [];
  try {
    dirs = fs.readdirSync(addons, { withFileTypes: true }).filter((d) => d.isDirectory() && /^gsa_[a-z0-9_]+$/.test(d.name)
      && (!opts.only || opts.only.includes(d.name)) && (!opts.filter || opts.filter(d.name)));
  } catch (e) { return done; }
  const maps = dirs.map((d) => scanResource(d.name, path.join(addons, d.name))).filter((m) => m.ymaps > 0 || m.streamed.length > 0);
  if (!maps.length) return done;
  const names = maps.map((m) => m.name);
  for (const m of maps) {
    try { removeTree(path.join(addons, m.name)); done.maps.push(m.name); } catch (e) { done.errors.push(`${m.name} : ${e.message}`); }
  }
  // cfg/addons.cfg : lignes de ces maps retirées (actives ou déjà commentées)
  removeCfgLines(path.join(serverData, 'cfg', 'addons.cfg'), names);
  const shorts = names.map((n) => n.replace(/^gsa_/, ''));
  for (const s of shorts) { try { removeTree(path.join(root, 'mods-tri', 'maps', s)); } catch (e) { /* rien */ } }
  if (!opts.keepArchives) try {
    for (const f of fs.readdirSync(path.join(root, 'mods-a-trier'))) {
      if (shorts.includes(cleanName(f))) { try { removeTree(path.join(root, 'mods-a-trier', f)); } catch (e) { /* rien */ } }
    }
  } catch (e) { /* pas de mods-a-trier (VPS) */ }
  try {
    const list = path.join(root, 'mods-retires.txt');
    let old = [];
    try { old = fs.readFileSync(list, 'utf8').split(/\r?\n/).map((x) => x.trim()).filter(Boolean); } catch (e) { old = []; }
    const all = [...new Set([...old, ...shorts])];
    writeFile(list, '# Mods retirés par le staff (F11) : IMPORTER-MODS ne les réinstalle jamais. Enlever une ligne pour le permettre.\r\n'
      + all.filter((x) => !x.startsWith('#')).join('\r\n') + '\r\n');
  } catch (e) { done.errors.push(`mods-retires.txt : ${e.message}`); }
  return done;
}

/** V12.18 · Maps retirées sur décision du 12/10 (doublons entre packs et anciennes maps gratuites). Supprimées au démarrage
 *  du PC comme du VPS (dossier, ligne de addons.cfg, copie mods-tri), notées dans mods-retires.txt (jamais réimportées) ;
 *  les archives de mods-a-trier sont gardées (packs payants : retéléchargeables, mais autant ne rien perdre). */
const RETIRED_MAPS = [
  'gsa_mlo_willies_supermarket', 'gsa_cfx_draft_pb_liquor_pack', 'gsa_moreo_gym', 'gsa_nelegalnyjj_avtoservis_i_avtorazborka',
  'gsa_sub_patoche_benny_original_pack', // gardé : Benny's noir et blanc
  'gsa_sub_patoche_villa_01_pack',       // V12.31 : gardé la villa bunker (même villa) ; remise par IMPORTER-MODS
  'gsa_sub_patoche_digitalden',          // gardé : prison (même occlusion du centre-ville)
  'gsa_patoche_shadow_complex_pack',
  // V12.33 (12/10) : plus de laser game, de karting ni de plasmatron (activités dont RoadLine n'a pas les scripts, décor seul)
  'gsa_patoche_plasmagame_pack', 'gsa_patoche_plasmagame_dlc_pack', 'gsa_patoche_plasmakart_pack', 'gsa_patoche_plasmakart_dlc_pack',
  'gsa_patoche_plasmatron_pack', 'gsa_patoche_plasmatron', // archive coupée le 12/10 : jamais réinstallée, quel que soit son nom
];

// V12.36 · Retraits par MOTIF (sous-chaînes, minuscules) : « plasmagamedlc2 encore présent, redline à supprimer » — ces noms
// n'étaient pas dans la liste exacte, donc jamais supprimés au démarrage et réinstallés par IMPORTER-MODS depuis mods-a-trier.
// Toute ressource de resources/[addons] dont le nom contient un motif est arrêtée, supprimée, notée dans mods-retires.txt,
// et son script compagnon (patoche_plasmagame_script…) avec elle. Lu aussi par importer-mods.ps1 (regex sur ce bloc : une
// chaîne par motif, sur une seule ligne, sans guillemet dans les commentaires).
const RETIRED_PATTERNS = ['plasmagame', 'plasmakart', 'plasmatron', 'villa_01', 'redline'];
// Maps remises en service après un retrait (= $Restored de importer-mods.ps1) : jamais supprimées à cause de mods-retires.txt
const RESTORED_MAPS = []; // V12.36 : migration V12.31 (villa bunker remise) terminée le 12/10 ; miroir de $Restored dans importer-mods.ps1

/** V12.36 · Pourquoi une ressource est retirée : { by: 'nom' } (RETIRED_MAPS), { by: 'motif', pattern } (RETIRED_PATTERNS),
 *  { by: 'liste' } (`listed` = noms de mods-retires.txt, sauf RESTORED_MAPS), ou null. */
function retiredReason(name, listed = []) {
  const n = String(name || '');
  if (RETIRED_MAPS.includes(n)) return { by: 'nom' };
  const low = n.toLowerCase();
  const pattern = RETIRED_PATTERNS.find((p) => low.includes(p));
  if (pattern) return { by: 'motif', pattern };
  if (listed.includes(low) && !RESTORED_MAPS.includes(low)) return { by: 'liste' };
  return null;
}

/** Texte de la raison pour la console : « motif « redline » », « mods-retires.txt », « décision du 12/10 ». */
function retiredLabel(r) {
  if (!r) return '';
  if (r.by === 'motif') return `motif « ${r.pattern} »`;
  if (r.by === 'liste') return 'mods-retires.txt';
  return 'décision du 12/10';
}

/** Noms de ressources (gsa_ + nom court) inscrits dans root/mods-retires.txt ; [] si absent. */
function readRetiredList(root) {
  try {
    return fs.readFileSync(path.join(root, 'mods-retires.txt'), 'utf8').split(/\r?\n/).map((x) => x.trim().toLowerCase())
      .filter((x) => x && !x.startsWith('#')).map((x) => (x.startsWith('gsa_') ? x : 'gsa_' + x));
  } catch (e) { return []; }
}

/** V12.36 · Scripts compagnons (ressources de resources/[addons] SANS préfixe gsa_ : patoche_plasmagame_script…) retirés
 *  par motif (`why(name)` vrai) : dossier supprimé, ligne enlevée de cfg/addons.cfg. Jamais rien hors de [addons]. */
function deleteCompanionsOnDisk(serverData, why) {
  const addons = path.join(serverData, 'resources', '[addons]');
  const done = { scripts: [], errors: [] };
  let dirs = [];
  try { dirs = fs.readdirSync(addons, { withFileTypes: true }).filter((d) => d.isDirectory() && /^[a-z0-9_\-]+$/i.test(d.name) && !/^gsa_/i.test(d.name) && why(d.name)); } catch (e) { return done; }
  if (!dirs.length) return done;
  for (const d of dirs) {
    try { removeTree(path.join(addons, d.name)); done.scripts.push(d.name); } catch (e) { done.errors.push(`${d.name} : ${e.message}`); }
  }
  removeCfgLines(path.join(serverData, 'cfg', 'addons.cfg'), dirs.map((d) => d.name));
  return done;
}

/** V12.36 · Retrait d'UNE map depuis F11 (« on arrête juste la ressource, on ne la supprime pas vraiment ») : dossier supprimé,
 *  nom dans mods-retires.txt (jamais réimportée), ligne enlevée de cfg/addons.cfg ; archive gardée dans mods-a-trier. L'appelant
 *  a arrêté la ressource avant. Renvoie { ok, msg, deleted }. Dossier verrouillé : noté quand même, supprimé au démarrage suivant
 *  (le démarrage lit mods-retires.txt). Dossier introuvable dans [addons] : au moins la ligne de cfg passe en commentaire. */
function retireMap(serverData, root, name, who) {
  if (!/^gsa_[a-z0-9_]+$/.test(name)) return { ok: false, deleted: false, msg: 'Map inconnue.' };
  let done = { maps: [], errors: [] };
  try { done = deleteMapsOnDisk(serverData, root, { only: [name], keepArchives: true }); } catch (e) { done.errors.push(`${name} : ${e.message}`); }
  if (done.maps.length) return { ok: true, deleted: true, msg: 'Map retirée : arrêtée, dossier supprimé, notée dans mods-retires.txt (jamais réimportée), ligne enlevée de cfg/addons.cfg. Archive gardée dans mods-a-trier.' };
  if (done.errors.length) return { ok: true, deleted: false, msg: `Map arrêtée et notée dans mods-retires.txt, dossier pas encore supprimé (${done.errors[0]}) : il le sera au prochain démarrage.` };
  const day = new Date().toISOString().slice(0, 10);
  const inCfg = disableInCfg(path.join(serverData, 'cfg', 'addons.cfg'), name, `retirée en jeu (F11) par ${String(who || 'staff').replace(/[^\w .-]/g, '')} le ${day}`);
  return { ok: true, deleted: false, msg: inCfg ? 'Map arrêtée et désactivée dans cfg/addons.cfg (dossier introuvable dans resources/[addons] : rien à supprimer).'
    : 'Map arrêtée. Dossier introuvable dans resources/[addons] et ligne absente de cfg/addons.cfg : rien d\'autre à faire.' };
}

const FUSION_MANIFEST = "-- Fusion automatique des fichiers d'occlusion en conflit entre maps (gs_admin/server/maps.js).\n" +
  "-- Lancée APRÈS les maps (dev.cfg / prod.cfg), donc prioritaire. Contenu régénéré à chaque démarrage si besoin.\n" +
  "fx_version 'cerulean'\ngame 'gta5'\nauthor 'RoadLine'\nlua54 'yes'\nthis_is_a_map 'yes'\n" +
  "server_script 'server.lua' -- écrit les fusions dans son propre dossier (seul endroit où FXServer l'autorise)\n";

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
    if (fusionSave) fusionSave(c.file, out); else writeFile(dest, out);
    written.push({ file: c.file, resources: c.resources, how });
  }
  if (written.length) {
    const mf = path.join(fusionDir, 'fxmanifest.lua');
    try { if (fs.readFileSync(mf, 'utf8') !== FUSION_MANIFEST) throw new Error('différent'); } catch (e) { writeFile(mf, FUSION_MANIFEST); }
  }
  return written;
}

if (typeof module !== 'undefined' && module.exports) module.exports = { keptOf, KEEP_ON_CONFLICT, cleanName, deleteMapsOnDisk, pruneFusions, disableInCfg, inflateRsc7, entitiesOf, memoryMB, memorySplit, pagesSize, isVanillaName, placesOf, scanResource, conflictsOf, scanAll, labelOf, mergeOcclusion, applyFusions, RETIRED_MAPS, RETIRED_PATTERNS, RESTORED_MAPS, retiredReason, retiredLabel, readRetiredList, deleteCompanionsOnDisk, retireMap, removeCfgLines, activeEnsures, publicBlips, PUBLIC, joaat, ACTIVITY, activityOf, rscTruncated, truncatedFiles, _setLuaFs: (f) => { luaFs = f; } }; // tests Node seulement

if (typeof GetCurrentResourceName === 'function') {
  const self = GetCurrentResourceName();
  const viaLua = (ev, ...args) => {
    let r, why;
    emit(ev, ...args, (ok, err) => { r = ok; why = err; });
    if (r === undefined) throw new Error(`${ev} sans réponse (erreur au chargement de server/fsw.lua ? voir la console au démarrage)`);
    if (!r && why) throw new Error(`${ev} : ${why}`);
    return r;
  };
  luaFs = { write: (p, b64) => viaLua('gs_admin:fsWrite', p, b64), remove: (p) => viaLua('gs_admin:fsRemove', p) };
  fusionSave = (file, buf) => {
    if (GetResourceState('gsa_zz_fusion_occlusion') !== 'started') StartResource('gsa_zz_fusion_occlusion');
    viaLua('gsa_fusion:save', file, buf.toString('base64'));
  };
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
      const started = [];
      for (let i = 0; i < GetNumResources(); i++) { const n = GetResourceByFindIndex(i); if (n && GetResourceState(n) === 'started') started.push(n); }
      for (const m of cache.maps) m.activity = activityOf(m.name, started);
      cacheKey = key;
    }
    return cache;
  };
  exports('MapScan', scan);
  // V12.15 · Retirer une map depuis F11 (super-admin / fondateur, vérifié côté Lua). V12.36 : vraiment supprimée (avant : seulement
  // arrêtée + ligne commentée, le dossier restait et IMPORTER-MODS le réinstallait) : arrêt, dossier effacé, nom dans
  // mods-retires.txt, ligne enlevée de cfg/addons.cfg, comme RETIRED_MAPS au démarrage ; archive gardée dans mods-a-trier.
  exports('DisableMap', (name, who) => {
    const known = scan().maps.some((m) => m.name === name);
    if (!known || !/^gsa_[a-z0-9_]+$/.test(name)) return { ok: false, msg: 'Map inconnue.' };
    const serverData = path.resolve(GetResourcePath(name), '..', '..', '..');
    StopResource(name);
    const r = retireMap(serverData, path.resolve(serverData, '..'), name, who);
    cache = null;
    console.log(`${r.deleted ? '^2' : '^3'}[gs_admin] Map retirée en jeu (F11, ${String(who || 'staff').replace(/[^\w .-]/g, '')}) : ${name} — ${r.msg}^7`);
    broadcastBlips(); // V12.36 : son blip public disparaît chez tous les joueurs tout de suite
    return { ok: r.ok, msg: r.msg };
  });
  // V12.16 · Supprimer définitivement toutes les maps du disque (dossiers, lignes de addons.cfg, copies, archives)
  exports('DeleteAllMaps', () => {
    const serverData = path.resolve(GetResourcePath(GetCurrentResourceName()), '..', '..', '..');
    const addons = path.join(serverData, 'resources', '[addons]');
    try { for (const d of fs.readdirSync(addons)) if (/^gsa_/.test(d) && GetResourceState(d) === 'started') {
      const m = scanResource(d, path.join(addons, d)); if (m.ymaps > 0 || m.streamed.length > 0) StopResource(d); } } catch (e) { /* rien */ }
    const done = deleteMapsOnDisk(serverData, path.resolve(serverData, '..'));
    cache = null;
    return { ok: done.maps.length > 0, msg: done.maps.length
      ? `${done.maps.length} map(s) supprimée(s) définitivement${done.errors.length ? ` (${done.errors.length} erreur(s) : ${done.errors[0]})` : ''}. Redémarre le serveur.`
      : 'Aucune map trouvée dans resources/[addons].' };
  });
  // V12.16 · Retirer TOUTES les maps d'un coup (les vêtements et véhicules importés ne sont pas des maps : non touchés)
  exports('DisableAllMaps', (who) => {
    const names = scan().maps.map((m) => m.name).filter((n) => /^gsa_[a-z0-9_]+$/.test(n));
    const day = new Date().toISOString().slice(0, 10);
    let inCfg = 0;
    for (const name of names) {
      const cfgFile = path.resolve(GetResourcePath(name), '..', '..', '..', 'cfg', 'addons.cfg');
      if (disableInCfg(cfgFile, name, `toutes les maps retirées en jeu (F11) par ${String(who || 'staff').replace(/[^\w .-]/g, '')} le ${day}`)) inCfg++;
      StopResource(name);
    }
    cache = null;
    return { ok: names.length > 0, msg: names.length ? `${names.length} map(s) retirée(s) (${inCfg} désactivée(s) dans cfg/addons.cfg).` : 'Aucune map installée.' };
  });
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
    try { for (const f of pruneFusions(list.map((r) => scanResource(r.name, r.dir)), dir)) console.log(`^2[gs_admin] Fusion ${f} retirée : plus de conflit^7`); } catch (e) { /* rien */ }
    let has = false;
    try { has = fs.readdirSync(path.join(dir, 'stream')).length > 0; } catch (e) { has = false; }
    if (has) { StopResource(FUSION_RES); StartResource(FUSION_RES); cache = null; }
  };
  const notStartedMaps = () => {
    const cfgFile = path.resolve(GetResourcePath(self), '..', '..', '..', 'cfg', 'addons.cfg');
    let text = '';
    try { text = fs.readFileSync(cfgFile, 'utf8'); } catch (e) { return []; }
    const listed = readRetiredList(path.resolve(GetResourcePath(self), '..', '..', '..', '..'));
    return activeEnsures(text).filter((n) => /^gsa_/.test(n) && !retiredReason(n, listed)) // V12.36 : retraits par nom, motif ou liste
      .map((name) => ({ name, state: GetResourceState(name) })).filter((x) => x.state !== 'started')
      .filter((x) => { const d = GetResourcePath(x.name); if (!d) return x.state === 'missing'; try { const s = scanResource(x.name, d); return s.ymaps > 0 || s.streamed.length > 0; } catch (e) { return true; } });
  };
  // V12.31 · Scripts compagnons des maps (installés sous leur nom d'origine par IMPORTER-MODS) activés mais pas démarrés
  const notStartedScripts = () => {
    const cfgFile = path.resolve(GetResourcePath(self), '..', '..', '..', 'cfg', 'addons.cfg');
    let text = '';
    try { text = fs.readFileSync(cfgFile, 'utf8'); } catch (e) { return []; }
    return activeEnsures(text).filter((n) => !/^gsa_/.test(n)).map((name) => ({ name, state: GetResourceState(name) })).filter((x) => x.state !== 'started');
  };
  // V12.18 · Maps retirées par décision : arrêtées puis supprimées, avant la fusion (qui ne les voit plus). V12.36 : par NOM
  // (RETIRED_MAPS), par MOTIF (RETIRED_PATTERNS : plasmagame_dlc2, redline… restaient, absents de la liste exacte) et par
  // mods-retires.txt (retrait F11 dont le dossier était verrouillé, VPS après METTRE-A-JOUR-OVH) ; leurs scripts compagnons
  // (sans préfixe gsa_) retirés par motif aussi. Seulement dans resources/[addons] : rien d'autre n'est touché.
  const inAddons = (n) => { const d = GetResourcePath(n); return !!d && path.basename(path.dirname(d)) === '[addons]'; };
  setTimeout(() => {
    const serverData = path.resolve(GetResourcePath(self), '..', '..', '..');
    const root = path.resolve(serverData, '..');
    const listed = readRetiredList(root);
    const why = (n) => retiredReason(n, listed);
    for (let i = 0; i < GetNumResources(); i++) {
      const n = GetResourceByFindIndex(i);
      if (n && why(n) && GetResourceState(n) === 'started' && inAddons(n)) StopResource(n);
    }
    let done = { maps: [], errors: [] }, comp = { scripts: [], errors: [] };
    try { done = deleteMapsOnDisk(serverData, root, { filter: why, keepArchives: true }); } catch (e) { done.errors.push(e.message); }
    try { comp = deleteCompanionsOnDisk(serverData, (n) => { const r = why(n); return r && r.by === 'motif' ? r : null; }); } catch (e) { comp.errors.push(e.message); }
    if (done.maps.length || comp.scripts.length) cache = null;
    for (const n of done.maps) console.log(`^2[gs_admin] Map retirée (${retiredLabel(why(n))}) : ${n} supprimée^7`);
    for (const n of comp.scripts) console.log(`^2[gs_admin] Script compagnon retiré (${retiredLabel(why(n))}) : ${n} supprimé^7`);
    for (const e of [...done.errors, ...comp.errors]) console.log(`^1[gs_admin] Retrait de map impossible : ${e}^7`);
  }, 8000);
  // V12.29 · Blips publics : envoyés à chaque joueur qui les demande (client/mapblips.lua), et à tous quand la liste change
  const lastAsk = new Map();
  onNet('gs_admin:mapBlips:get', () => {
    const src = global.source;
    const now = Date.now();
    if (now - (lastAsk.get(src) || 0) < 10000) return;
    lastAsk.set(src, now);
    emitNet('gs_admin:mapBlips', src, publicBlips(scan().maps));
  });
  on('playerDropped', () => lastAsk.delete(global.source));
  const broadcastBlips = () => emitNet('gs_admin:mapBlips', -1, publicBlips(scan().maps));

  // V12.27 · Contrôle d'intégrité de toutes les maps démarrées (en arrière-plan) : un fichier tronqué = la map est ARRÊTÉE
  // tout de suite (sinon chaque joueur qui passe à côté plante). Rien n'est écrit sur le disque : au prochain démarrage,
  // elle est revérifiée ; si l'archive a été retéléchargée et réimportée, elle repart toute seule.
  setTimeout(async () => {
    let checked = 0;
    const stopped = [];
    for (const r of mapResources()) {
      if (/^gsa_zz_fusion/.test(r.name)) continue;
      let bad = [];
      try { bad = await truncatedFiles(r.dir); } catch (e) { continue; }
      checked++;
      if (bad.length && GetResourceState(r.name) === 'started') {
        StopResource(r.name);
        stopped.push(r.name);
        console.log(`^1[gs_admin] Map ARRÊTÉE : ${r.name} — fichier abîmé (téléchargement incomplet) : ${bad.slice(0, 3).join(', ')}${bad.length > 3 ? ` (+${bad.length - 3})` : ''}. Elle ferait planter les joueurs. Retélécharge le pack, remplace l'archive dans C:\\GTASOON\\mods-a-trier, relance IMPORTER-MODS puis METTRE-A-JOUR-OVH.^7`);
      }
    }
    cache = null;
    broadcastBlips();
    console.log(`[gs_admin] Intégrité des maps : ${checked} vérifiée(s), ${stopped.length ? `^1${stopped.length} arrêtée(s) (fichiers abîmés)^7` : '^2aucun fichier abîmé^7'}`);
  }, 20000);
  // Au démarrage : fusion, puis une ligne en console et les conflits en clair (à corriger avant qu'un joueur tombe dans un trou)
  setTimeout(() => {
    fuse();
    const r = scan();
    const placed = r.maps.filter((m) => m.places.length).length;
    const open = r.conflicts.filter((c) => !c.resolved);
    console.log(`[gs_admin] Mappings : ${r.maps.length} installé(s), ${placed} situé(s) (F11 → Monde et lieux → Mappings installés)` +
      (open.length - Object.keys(keptOf(r.conflicts)).length > 0 ? `, ^1${open.length - Object.keys(keptOf(r.conflicts)).length} CONFLIT(S)^7` : ', aucun conflit non tranché') + (r.conflicts.length - open.length ? `, ${r.conflicts.length - open.length} résolu(s) par fusion` : ''));
    // V12.25 · Maps activées dans cfg/addons.cfg mais NON démarrées : en jeu = bâtiment absent ou chargement sans fin.
    // Cause habituelle d'une map payante : licence (achetée avec un autre compte Cfx que celui de la clé du serveur) ou
    // fichier .fxap manquant ; la vraie raison est écrite plus haut dans la console (« entitlement », « protected »…).
    for (const n of notStartedMaps()) console.log(`^1[gs_admin] Map activée mais NON démarrée : ${n.name} (état : ${n.state}). En jeu : bâtiment absent ou chargement sans fin. Cherche « ${n.name} » plus haut dans la console (licence Cfx « entitlement », fichier « protected resource » manquant)^7`);
    for (const n of notStartedScripts()) console.log(`^1[gs_admin] Script de map activé mais NON démarré : ${n.name} (état : ${n.state}). Cherche « ${n.name} » plus haut dans la console : licence Cfx (« entitlement »), dépendance manquante (« dependency »), ou script qui refuse d'être renommé^7`);
    for (const m of r.maps) if (m.activity && !m.activity.script) console.log(`^3[gs_admin] Map ${m.name} : DÉCOR SEUL. L'activité (${m.activity.what}) est un script vendu à part (aucune ressource « *${ACTIVITY[m.name].token}* » démarrée) : pas de point pour jouer. Il est dans C:\\GTASOON\\mods-tri\\scripts-a-verifier : à relire avant de l'installer. Blip affiché « (bientôt) »^7`);
    for (const m of r.maps) for (const h of m.heavy) console.log(`^3[gs_admin] Map ${m.name} : ${h.file} prend ${h.mb} Mo en mémoire (au-delà de la limite FiveM : 48 Mo graphique / 64 Mo système) : textures ou murs qui peuvent ne pas s'afficher^7`);
    const kept = keptOf(r.conflicts);
    const relaunch = [...new Set(Object.values(kept))].filter((n) => GetResourceState(n) === 'started');
    for (const n of relaunch) { StopResource(n); StartResource(n); } // relancée en dernier : sa version gagne
    for (const c of r.conflicts) {
      if (c.resolved) console.log(`^2[gs_admin] Conflit résolu : ${c.file} (${c.resources.join(' + ')}) fusionné par ${c.resolved}^7`);
      else if (kept[c.file]) console.log(`^3[gs_admin] Conflit tranché : ${c.file} → version de ${kept[c.file]} (relancée en dernier ; ${c.resources.filter((x) => x !== kept[c.file]).join(', ')} perd ce fichier : un peu d'herbe ou de décor)^7`);
      else console.log(`^1[gs_admin] Conflit de maps : ${c.file} est remplacé par ${c.resources.join(' ET ')} (une seule des deux s'affichera correctement)^7`);
    }
  }, 15000);
}
