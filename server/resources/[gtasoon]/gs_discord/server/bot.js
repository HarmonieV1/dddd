// gs_discord (serveur, JS) · V9.1 « Bot RoadLine » intégré au serveur FiveM : rien à installer, il démarre avec le serveur
// (en local comme chez l'hébergeur) dès que `set gs_discord_bot_token` est rempli (CONFIGURER-DISCORD.bat).
// Présence « 12/48 citoyens à Los Santos », commandes /statut /rejoindre /site /rdv. Le jeton ne sort jamais du serveur.
// Client WebSocket minimal écrit ici (compatible avec toutes les versions de Node de FXServer, aucune dépendance).
'use strict';
const https = require('https');
const crypto = require('crypto');

// --- Trames WebSocket (RFC 6455) ------------------------------------------------------------------------------
function encodeFrame(text, opcode = 1) {
  const payload = Buffer.from(text, 'utf8');
  const mask = crypto.randomBytes(4);
  let header;
  if (payload.length < 126) { header = Buffer.alloc(2); header[1] = 0x80 | payload.length; }
  else if (payload.length < 65536) { header = Buffer.alloc(4); header[1] = 0x80 | 126; header.writeUInt16BE(payload.length, 2); }
  else { header = Buffer.alloc(10); header[1] = 0x80 | 127; header.writeUInt32BE(0, 2); header.writeUInt32BE(payload.length, 6); }
  header[0] = 0x80 | opcode;
  const body = Buffer.alloc(payload.length);
  for (let i = 0; i < payload.length; i++) body[i] = payload[i] ^ mask[i % 4];
  return Buffer.concat([header, mask, body]);
}

/** Découpe un tampon en trames complètes ; retourne { frames: [{ fin, opcode, payload }], rest } */
function decodeFrames(buf) {
  const frames = [];
  let off = 0;
  while (buf.length - off >= 2) {
    const b0 = buf[off], b1 = buf[off + 1];
    let len = b1 & 0x7f, p = off + 2;
    if (len === 126) { if (buf.length - p < 2) break; len = buf.readUInt16BE(p); p += 2; }
    else if (len === 127) { if (buf.length - p < 8) break; len = buf.readUInt32BE(p) * 4294967296 + buf.readUInt32BE(p + 4); p += 8; }
    let mask = null;
    if (b1 & 0x80) { if (buf.length - p < 4) break; mask = buf.slice(p, p + 4); p += 4; }
    if (buf.length - p < len) break;
    let payload = buf.slice(p, p + len);
    if (mask) { payload = Buffer.from(payload); for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4]; }
    frames.push({ fin: (b0 & 0x80) !== 0, opcode: b0 & 0x0f, payload });
    off = p + len;
  }
  return { frames, rest: buf.slice(off) };
}

// --- Connexion WebSocket TLS ------------------------------------------------------------------------------------
function wsConnect(url, handlers) {
  const u = new URL(url);
  const key = crypto.randomBytes(16).toString('base64');
  const lib = u.protocol === 'ws:' ? require('http') : https; // ws: seulement pour les tests locaux
  const req = lib.request({ host: u.hostname, port: u.port || (u.protocol === 'ws:' ? 80 : 443), path: u.pathname + u.search, method: 'GET',
    headers: { Connection: 'Upgrade', Upgrade: 'websocket', 'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13' } });
  let socket = null, buffer = Buffer.alloc(0), parts = [], closed = false;
  const close = (code) => { if (closed) return; closed = true; try { socket && socket.destroy(); } catch (e) { /* déjà fermé */ } handlers.close(code); };
  req.on('upgrade', (res, sock, head) => {
    socket = sock;
    buffer = head && head.length ? Buffer.from(head) : Buffer.alloc(0);
    const onData = (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      const { frames, rest } = decodeFrames(buffer);
      buffer = rest;
      for (const f of frames) {
        if (f.opcode === 8) return close(f.payload.length >= 2 ? f.payload.readUInt16BE(0) : 1000);
        if (f.opcode === 9) { sock.write(encodeFrame(f.payload.toString('utf8'), 10)); continue; }
        if (f.opcode === 1 || f.opcode === 0) {
          parts.push(f.payload);
          if (f.fin) { const text = Buffer.concat(parts).toString('utf8'); parts = []; handlers.message(text); }
        }
      }
    };
    sock.on('data', onData);
    sock.on('close', () => close(1006));
    sock.on('error', () => close(1006));
    if (buffer.length) { const b = buffer; buffer = Buffer.alloc(0); onData(b); }
  });
  req.on('response', () => close(1002)); // pas de passage en WebSocket
  req.on('error', () => close(1006));
  req.end();
  return { send: (text) => { if (socket && !closed) socket.write(encodeFrame(text)); }, close: () => close(1000) };
}

function rest(token, method, path, body) {
  return new Promise((resolve) => {
    const data = body ? JSON.stringify(body) : null;
    const req = https.request({ host: 'discord.com', path: '/api/v10' + path, method,
      headers: Object.assign({ Authorization: 'Bot ' + token }, data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {}) }, (res) => {
      let out = '';
      res.on('data', (c) => { out += c; });
      res.on('end', () => { let j = null; try { j = out ? JSON.parse(out) : null; } catch (e) { j = null; } resolve({ status: res.statusCode, body: j }); });
    });
    req.on('error', () => resolve({ status: 0, body: null }));
    if (data) req.write(data);
    req.end();
  });
}

// --- Bot ----------------------------------------------------------------------------------------------------------
const COMMANDS = [
  { name: 'statut', description: 'État du serveur RoadLine (joueurs, services, météo)' },
  { name: 'rejoindre', description: 'Comment rejoindre RoadLine RP' },
  { name: 'site', description: 'Le site de RoadLine RP' },
  { name: 'rdv', description: 'Les rendez-vous de la semaine' },
];

/** env = { token, connect(url, handlers), rest(method, path, body), presence(), answer(name) → data, log } */
function createBot(env) {
  let ws = null, beat = null, seq = null, appId = null, lastPresence = '', stopped = false, retry = null;
  const send = (op, d) => ws && ws.send(JSON.stringify({ op, d }));
  const bot = {
    state: () => ({ appId, seq, lastPresence }),
    presence(force) {
      const text = env.presence();
      if (!force && text === lastPresence) return false;
      lastPresence = text;
      send(3, { since: null, activities: [{ name: text, type: 3 }], status: 'online', afk: false });
      return true;
    },
    async onMessage(raw) {
      let p;
      try { p = JSON.parse(raw); } catch (e) { return; }
      if (p.s) seq = p.s;
      if (p.op === 10) {
        if (beat) clearInterval(beat);
        beat = setInterval(() => send(1, seq), p.d.heartbeat_interval);
        send(2, { token: env.token, intents: 0, properties: { os: 'linux', browser: 'roadline', device: 'roadline' } });
      } else if (p.op === 1) {
        send(1, seq);
      } else if (p.op === 7 || p.op === 9) {
        ws && ws.close();
      } else if (p.op === 0 && p.t === 'READY') {
        appId = p.d.application.id;
        env.log(`Bot Discord connecté (${p.d.user.username}).`);
        await env.rest('PUT', `/applications/${appId}/commands`, COMMANDS);
        bot.presence(true);
      } else if (p.op === 0 && p.t === 'INTERACTION_CREATE' && p.d.type === 2) {
        const data = env.answer(p.d.data.name);
        await env.rest('POST', `/interactions/${p.d.id}/${p.d.token}/callback`, { type: 4, data: Object.assign({ allowed_mentions: { parse: [] } }, data) });
      }
    },
    start() {
      stopped = false;
      ws = env.connect('wss://gateway.discord.gg/?v=10&encoding=json', {
        message: (t) => { bot.onMessage(t).catch(() => {}); },
        close: (code) => {
          if (beat) clearInterval(beat);
          beat = null;
          if (stopped) return;
          if (code === 4004) { env.log('Jeton du bot refusé par Discord : relance CONFIGURER-DISCORD.bat.'); return; }
          retry = setTimeout(() => bot.start(), 10000);
        },
      });
    },
    stop() { stopped = true; if (beat) clearInterval(beat); if (retry) clearTimeout(retry); ws && ws.close(); },
  };
  return bot;
}

module.exports = { encodeFrame, decodeFrames, createBot, wsConnect, COMMANDS };

// --- Branchement FiveM -----------------------------------------------------------------------------------------
if (typeof GetConvar === 'function') {
  const token = GetConvar('gs_discord_bot_token', '');
  if (token && /^[\w.-]{50,100}$/.test(token)) {
    const res = GetCurrentResourceName();
    const lua = () => exports[res]; // exports Lua de cette ressource (statut, rendez-vous)
    const bot = createBot({
      token,
      connect: wsConnect,
      rest: (m, p, b) => rest(token, m, p, b),
      log: (m) => console.log(`[gs_discord] ${m}`),
      presence: () => `${GetNumPlayerIndices()}/${GetConvarInt('sv_maxclients', 48)} citoyens à Los Santos`,
      answer: (name) => {
        const connect = GetConvar('gs_connect', '');
        if (name === 'statut') return { embeds: [lua().StatusEmbed()] };
        if (name === 'rejoindre') return { embeds: [{ title: 'Rejoindre RoadLine RP', color: 0xb048ff,
          description: `1. Lance FiveM\n2. Touche **F8**\n3. Tape \`connect ${connect || 'adresse du serveur'}\`\n\nFree Access · zéro pay-to-win` }] };
        if (name === 'rdv') return { embeds: [{ title: 'Rendez-vous de la semaine', color: 0xf2c230, description: lua().WeeklyText() }] };
        return { content: GetConvar('gs_site', 'https://roadlinerp.netlify.app') };
      },
    });
    setTimeout(() => bot.start(), 5000);
    setInterval(() => bot.presence(false), 60000);
    on('onResourceStop', (r) => { if (r === res) bot.stop(); });
  }
}
