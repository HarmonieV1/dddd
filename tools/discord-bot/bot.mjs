// RoadLine RP · bot Discord (Node.js 22+, aucune dépendance à installer).
// Présence en direct « 12/48 citoyens à Los Santos », commandes /statut /rejoindre /site.
// Le jeton est lu dans config.json (à côté de ce fichier, créé par CONFIGURER-DISCORD.bat) et n'est jamais affiché.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(readFileSync(join(here, 'config.json'), 'utf8'));
if (!cfg.token || cfg.token.includes('COLLE_ICI')) { console.error('Jeton manquant : lance CONFIGURER-DISCORD.bat.'); process.exit(1); }
const API = 'https://discord.com/api/v10';
const COLOR = 0xb048ff;
const log = (...a) => console.log(new Date().toLocaleTimeString('fr-FR'), ...a);

// --- FiveM ---------------------------------------------------------------------------------------------------
export async function fivemStatus(base = cfg.fivem) {
  try {
    const ctl = AbortSignal.timeout(4000);
    const [dyn, players] = await Promise.all([
      fetch(`${base}/dynamic.json`, { signal: ctl }).then(r => r.json()),
      fetch(`${base}/players.json`, { signal: ctl }).then(r => r.json()),
    ]);
    return { online: true, players: Array.isArray(players) ? players.length : Number(dyn.clients) || 0, max: Number(dyn.sv_maxclients) || 48 };
  } catch { return { online: false, players: 0, max: 0 }; }
}

export function statusEmbed(s, c = cfg) {
  return s.online
    ? { title: `🟢 ${c.name} · en ligne`, color: COLOR, description: `**${s.players} / ${s.max}** citoyens à Los Santos`,
        fields: [{ name: 'Rejoindre', value: `\`connect ${c.connect}\``, inline: false }], timestamp: new Date().toISOString() }
    : { title: `🔴 ${c.name} · hors ligne`, color: 0xd0122f, description: 'La ville redémarre, retour dans quelques minutes.', timestamp: new Date().toISOString() };
}

// --- REST ----------------------------------------------------------------------------------------------------
async function rest(method, path, body) {
  const r = await fetch(API + path, { method, headers: { Authorization: `Bot ${cfg.token}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined });
  if (r.status === 429) { const j = await r.json(); await new Promise(res => setTimeout(res, (j.retry_after || 1) * 1000)); return rest(method, path, body); }
  if (!r.ok && r.status !== 204) log('Discord a refusé', method, path, r.status);
  return r.status === 204 ? null : r.json().catch(() => null);
}

const COMMANDS = [
  { name: 'statut', description: 'État du serveur RoadLine (joueurs en ville)' },
  { name: 'rejoindre', description: 'Comment rejoindre RoadLine RP' },
  { name: 'site', description: 'Le site de RoadLine RP' },
];

async function answer(i) {
  let data;
  if (i.data.name === 'statut') data = { embeds: [statusEmbed(await fivemStatus())] };
  else if (i.data.name === 'rejoindre') data = { embeds: [{ title: 'Rejoindre RoadLine RP', color: COLOR,
    description: `1. Lance FiveM\n2. Touche **F8**\n3. Tape \`connect ${cfg.connect}\`\n\nFree Access · zéro pay-to-win · Discord : ${cfg.discord}` }] };
  else data = { content: cfg.site };
  await rest('POST', `/interactions/${i.id}/${i.token}/callback`, { type: 4, data: { ...data, allowed_mentions: { parse: [] } } });
}

// --- Gateway -------------------------------------------------------------------------------------------------
let ws, beat, seq = null, appId = null, lastPresence = '';

function send(op, d) { if (ws && ws.readyState === 1) ws.send(JSON.stringify({ op, d })); }

async function presence(force) {
  const s = await fivemStatus();
  const text = s.online ? `${s.players}/${s.max} citoyens à Los Santos` : 'la ville redémarre…';
  if (!force && text === lastPresence) return;
  lastPresence = text;
  send(3, { since: null, activities: [{ name: text, type: 3 }], status: s.online ? 'online' : 'idle', afk: false });
}

function connect() {
  ws = new WebSocket('wss://gateway.discord.gg/?v=10&encoding=json');
  ws.onmessage = async (ev) => {
    const p = JSON.parse(ev.data);
    if (p.s) seq = p.s;
    if (p.op === 10) {
      clearInterval(beat);
      beat = setInterval(() => send(1, seq), p.d.heartbeat_interval);
      send(2, { token: cfg.token, intents: 0, properties: { os: 'windows', browser: 'roadline', device: 'roadline' } });
    } else if (p.op === 7 || p.op === 9) {
      ws.close();
    } else if (p.op === 0 && p.t === 'READY') {
      appId = p.d.application.id;
      log(`Connecté en tant que ${p.d.user.username}.`);
      await rest('PUT', `/applications/${appId}/commands`, COMMANDS);
      presence(true);
    } else if (p.op === 0 && p.t === 'INTERACTION_CREATE' && p.d.type === 2) {
      answer(p.d).catch(e => log('Erreur commande', e.message));
    }
  };
  ws.onclose = (ev) => {
    clearInterval(beat);
    if (ev.code === 4004) { console.error('Jeton refusé par Discord : relance CONFIGURER-DISCORD.bat.'); process.exit(1); }
    log('Connexion perdue, reconnexion dans 5 s…');
    setTimeout(connect, 5000);
  };
  ws.onerror = () => {};
}

if (process.argv[2] !== '--test') {
  connect();
  setInterval(() => presence(false), 60000);
}
