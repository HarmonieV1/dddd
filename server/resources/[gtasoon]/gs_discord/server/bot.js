// gs_discord (serveur, JS) · V9.1 « Bot RoadLine » intégré au serveur FiveM : rien à installer, il démarre avec le serveur
// (en local comme chez l'hébergeur) dès que `set gs_discord_bot_token` est rempli (CONFIGURER-DISCORD.bat).
// Présence « 12/48 citoyens à Los Santos », commandes /statut /rejoindre /site /rdv /aide, tickets /ticket /fermer (V11.4),
// commandes staff. Le jeton ne sort jamais du serveur.
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
  { name: 'aide', description: 'Les commandes du bot RoadLine' },
];

// V11.4 · Tickets en fil privé dans le salon #tickets (`gs_discord_ticket_channel`). `set gs_discord_tickets "false"`
// les retire (bot de tickets externe à la place).
const TICKET_COMMANDS = ['ticket', 'fermer'];
COMMANDS.push(
  { name: 'ticket', description: 'Ouvrir un ticket privé avec le staff', dm_permission: false,
    options: [{ name: 'sujet', description: 'En quelques mots : ton problème ou ta demande', type: 3, required: true, max_length: 100 }] },
  { name: 'fermer', description: 'Fermer ce ticket (dans le fil du ticket)', dm_permission: false },
);
const SLOW = new Set(TICKET_COMMANDS); // plusieurs appels à Discord : réponse différée (sinon délai de 3 s dépassé)

// V10.1 · Modération depuis Discord (téléphone compris). V11.4 : uniquement sur le Discord RoadLine (`gs_discord_guild`),
// pour le rôle staff (`gs_discord_staff_role`) ou le propriétaire du Discord. Plus de passe-droit « administrateur » :
// le bot pouvait être invité ailleurs, où n'importe qui est administrateur. Réponses visibles par l'auteur seulement.
const ID = { name: 'id', description: 'Identifiant du joueur en ville (voir /joueurs)', type: 4, required: true, min_value: 1 };
const TEXT = (d) => ({ name: 'texte', description: d, type: 3, required: true, max_length: 200 });
const MINUTES = { name: 'minutes', description: 'Durée en minutes (1 à 240)', type: 4, required: true, min_value: 1, max_value: 240 };
const STAFF = {
  joueurs: { action: 'players', description: 'Staff : joueurs en ville (identifiant, nom, ping)', options: [] },
  geler: { action: 'freeze', description: 'Staff : geler un joueur (il ne peut plus bouger)', options: [ID] },
  degeler: { action: 'unfreeze', description: 'Staff : dégeler un joueur', options: [ID] },
  avertir: { action: 'warn', description: 'Staff : avertir un joueur (note au dossier)', options: [ID, TEXT('Motif')] },
  expulser: { action: 'kick', description: 'Staff : expulser un joueur du serveur', options: [ID, TEXT('Motif')] },
  message: { action: 'message', description: 'Staff : message privé à un joueur en jeu', options: [ID, TEXT('Message')] },
  annonce: { action: 'announce', description: 'Staff : annonce à toute la ville en jeu', options: [TEXT('Annonce')] },
  // V12.3
  isoler: { action: 'jail', description: 'Staff : isoler un joueur (cour de Bolingbroke, hors RP)', options: [ID, MINUTES, TEXT('Motif')] },
  liberer: { action: 'unjail', description: 'Staff : libérer un joueur de l\'isolement', options: [ID] },
  reanimer: { action: 'revive', description: 'Staff : réanimer et soigner un joueur', options: [ID] },
};
for (const [name, c] of Object.entries(STAFF)) COMMANDS.push({ name, description: c.description, options: c.options, dm_permission: false });

/** Staff = rôle staff configuré, propriétaire du Discord, ou administrateur du Discord RoadLine (serveur vérifié par fromGuild) */
function staffAllowed(member, roleId, ownerId) {
  if (!member) return false;
  const uid = member.user && member.user.id;
  if (ownerId && uid && uid === ownerId) return true;
  // V12.3 : les administrateurs du Discord RoadLine passent aussi (fromGuild est vérifié avant : jamais depuis un autre Discord)
  try { if ((BigInt(member.permissions || '0') & 8n) === 8n) return true; } catch (e) { /* permissions illisibles */ }
  return !!roleId && Array.isArray(member.roles) && member.roles.includes(roleId);
}
/** La commande vient bien du Discord RoadLine (jamais d'un autre serveur où le bot aurait été invité) */
function fromGuild(interaction, guildId) {
  return !!guildId && !!interaction && interaction.guild_id === guildId;
}
function optionsOf(d) {
  const o = {};
  for (const x of (d && d.data && d.data.options) || []) o[x.name] = x.value;
  return o;
}
/** Liste des commandes à enregistrer (sans les tickets si désactivés) */
function commandsFor(opts) {
  return COMMANDS.filter((c) => !(opts && opts.tickets === false && TICKET_COMMANDS.includes(c.name)));
}

/**
 * Tickets en fil privé. env = { rest, channelId, roleId, store: { load() → {}, save(obj) }, now() → ms }
 * open : un ticket ouvert par membre, 2 min entre deux ouvertures. close : auteur du ticket ou staff.
 */
function createTickets(env) {
  const COOLDOWN = 120000;
  const last = {};
  let open = null; // open[userId] = threadId, gardé entre deux redémarrages (store)
  const load = () => { if (!open) { try { open = env.store.load() || {}; } catch (e) { open = {}; } } return open; };
  const save = () => { try { env.store.save(open); } catch (e) { /* stockage indisponible */ } };
  const slug = (s) => String(s || 'membre').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'membre';
  return {
    async open(interaction, subject) {
      if (!env.channelId) return { content: 'Les tickets ne sont pas encore configurés (salon #tickets).' };
      const user = interaction.member && interaction.member.user;
      if (!user) return { content: 'Membre introuvable.' };
      const list = load();
      const existing = list[user.id];
      if (existing) {
        const r = await env.rest('GET', `/channels/${existing}`);
        if (r.status === 200 && r.body && !(r.body.thread_metadata && r.body.thread_metadata.archived)) {
          return { content: `Tu as déjà un ticket ouvert : <#${existing}>` };
        }
        delete list[user.id]; save();
      }
      const t = env.now();
      if (last[user.id] && t - last[user.id] < COOLDOWN) return { content: 'Attends deux minutes avant d\'ouvrir un nouveau ticket.' };
      const th = await env.rest('POST', `/channels/${env.channelId}/threads`,
        { name: `ticket-${slug(user.global_name || user.username)}`, type: 12, invitable: false, auto_archive_duration: 10080 });
      if (!th.body || !th.body.id || (th.status !== 200 && th.status !== 201)) {
        return { content: 'Impossible d\'ouvrir le ticket : le bot n\'a pas les droits sur #tickets (prévenir le staff).' };
      }
      const tid = th.body.id;
      last[user.id] = t;
      list[user.id] = tid; save();
      await env.rest('PUT', `/channels/${tid}/thread-members/${user.id}`);
      const clean = String(subject || '').replace(/[@<>]/g, '').slice(0, 100);
      await env.rest('POST', `/channels/${tid}/messages`, {
        content: `<@${user.id}> ton ticket est ouvert. Explique ta demande ici (clips bienvenus), un membre du staff arrive.\n**Sujet :** ${clean}`
          + (env.roleId ? `\n<@&${env.roleId}>` : '') + '\nPour le fermer : `/fermer`.',
        allowed_mentions: { users: [user.id], roles: env.roleId ? [env.roleId] : [] },
      });
      return { content: `✅ Ticket ouvert : <#${tid}>` };
    },
    async close(interaction, isStaff) {
      const ch = interaction.channel || {};
      const tid = interaction.channel_id;
      if (!env.channelId || ch.parent_id !== env.channelId) return { content: 'Utilise `/fermer` dans le fil du ticket.' };
      const list = load();
      const user = interaction.member && interaction.member.user;
      const author = Object.keys(list).find((k) => list[k] === tid);
      if (!isStaff && !(user && author === user.id)) return { content: 'Seuls l\'auteur du ticket et le staff peuvent le fermer.' };
      const who = (user && (user.global_name || user.username)) || '?';
      await env.rest('POST', `/channels/${tid}/messages`, { content: `🔒 Ticket fermé par ${who.replace(/[@<>]/g, '')}.`, allowed_mentions: { parse: [] } });
      const r = await env.rest('PATCH', `/channels/${tid}`, { archived: true, locked: true });
      if (author) { delete list[author]; save(); }
      return { content: (r.status === 200) ? 'Ticket fermé.' : 'Message posté, mais le bot n\'a pas pu archiver le fil (droit « Gérer les fils »).' };
    },
  };
}

const FATAL = new Set([4004, 4010, 4011, 4012, 4013, 4014]); // jeton refusé, intents invalides… : réessayer ne sert à rien

/** env = { token, connect(url, handlers), rest(method, path, body), presence(), answer(name, interaction, ctx) → data, log, guild()?, tickets()? } */
function createBot(env) {
  let ws = null, beat = null, seq = null, appId = null, ownerId = null, lastPresence = '', stopped = false, retry = null;
  let acked = true, delay = 10000;
  const send = (op, d) => ws && ws.send(JSON.stringify({ op, d }));
  const guild = () => (env.guild ? env.guild() : '');
  const bot = {
    state: () => ({ appId, seq, lastPresence, ownerId, delay }),
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
        acked = true;
        // Pas d'accusé de réception depuis le dernier battement : connexion morte, on la coupe (reconnexion auto)
        beat = setInterval(() => { if (!acked) { ws && ws.close(); return; } acked = false; send(1, seq); }, p.d.heartbeat_interval);
        send(2, { token: env.token, intents: 0, properties: { os: 'linux', browser: 'roadline', device: 'roadline' } });
      } else if (p.op === 11) {
        acked = true;
      } else if (p.op === 1) {
        send(1, seq);
      } else if (p.op === 7 || p.op === 9) {
        ws && ws.close();
      } else if (p.op === 0 && p.t === 'READY') {
        appId = p.d.application.id;
        delay = 10000;
        env.log(`Bot Discord connecté (${p.d.user.username}).`);
        const list = commandsFor({ tickets: env.tickets ? env.tickets() : true });
        const g = guild();
        if (g) {
          // Commandes enregistrées sur le Discord RoadLine seulement (visibles nulle part ailleurs, mises à jour immédiates)
          const r = await env.rest('PUT', `/applications/${appId}/guilds/${g}/commands`, list);
          if (r.status === 200) await env.rest('PUT', `/applications/${appId}/commands`, []);
          else { env.log(`Commandes non enregistrées sur le Discord ${g} (bot absent ou identifiant faux) : commandes globales.`); await env.rest('PUT', `/applications/${appId}/commands`, list); }
          const info = await env.rest('GET', `/guilds/${g}`);
          ownerId = (info.body && info.body.owner_id) || null;
        } else {
          env.log('gs_discord_guild vide : commandes staff et tickets désactivés (CONFIGURER-DISCORD.bat).');
          await env.rest('PUT', `/applications/${appId}/commands`, list);
        }
        bot.presence(true);
      } else if (p.op === 0 && p.t === 'INTERACTION_CREATE' && p.d.type === 2) {
        const name = p.d.data.name;
        const ctx = { ownerId, guild: guild() };
        if (SLOW.has(name)) {
          await env.rest('POST', `/interactions/${p.d.id}/${p.d.token}/callback`, { type: 5, data: { flags: 64 } });
          let data;
          try { data = await env.answer(name, p.d, ctx); } catch (e) { data = { content: 'Erreur, réessaie dans un instant.' }; }
          await env.rest('PATCH', `/webhooks/${appId}/${p.d.token}/messages/@original`, Object.assign({ allowed_mentions: { parse: [] } }, data));
          return;
        }
        let data;
        try { data = await env.answer(name, p.d, ctx); } catch (e) { data = { content: 'Erreur, réessaie dans un instant.', flags: 64 }; }
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
          if (FATAL.has(code)) { env.log(`Connexion refusée par Discord (code ${code}) : jeton à vérifier, relance CONFIGURER-DISCORD.bat.`); return; }
          // Attente qui double à chaque échec (10 s → 5 min) : Discord limite les connexions par jour
          retry = setTimeout(() => bot.start(), delay);
          delay = Math.min(delay * 2, 300000);
        },
      });
    },
    stop() { stopped = true; if (beat) clearInterval(beat); if (retry) clearTimeout(retry); ws && ws.close(); },
  };
  return bot;
}

if (typeof module !== 'undefined' && module.exports) module.exports = { encodeFrame, decodeFrames, createBot, createTickets, wsConnect, COMMANDS, STAFF, staffAllowed, fromGuild, optionsOf, commandsFor }; // tests Node seulement (absent dans FiveM)

// --- Branchement FiveM -----------------------------------------------------------------------------------------
if (typeof GetConvar === 'function') {
  const token = GetConvar('gs_discord_bot_token', '');
  if (token && /^[\w.-]{50,100}$/.test(token)) {
    const res = GetCurrentResourceName();
    const lua = () => exports[res]; // exports Lua de cette ressource (statut, rendez-vous)
    const guildId = () => { const g = GetConvar('gs_discord_guild', ''); return /^\d{15,22}$/.test(g) ? g : ''; };
    const staffRole = () => GetConvar('gs_discord_staff_role', '');
    const ticketsOn = () => GetConvar('gs_discord_tickets', 'true') !== 'false';
    const call = (m, p, b) => rest(token, m, p, b);
    const tickets = createTickets({
      rest: call,
      get channelId() { const c = GetConvar('gs_discord_ticket_channel', ''); return /^\d{15,22}$/.test(c) ? c : ''; },
      get roleId() { return staffRole(); },
      store: {
        load: () => { try { return JSON.parse(GetResourceKvpString('tickets') || '{}'); } catch (e) { return {}; } },
        save: (o) => SetResourceKvp('tickets', JSON.stringify(o)),
      },
      now: () => Date.now(),
    });
    const bot = createBot({
      token,
      connect: wsConnect,
      rest: call,
      guild: guildId,
      tickets: ticketsOn,
      log: (m) => console.log(`[gs_discord] ${m}`),
      presence: () => `${GetNumPlayerIndices()}/${GetConvarInt('sv_maxclients', 48)} citoyens à Los Santos`,
      answer: async (name, interaction, ctx) => {
        const member = interaction && interaction.member;
        if (TICKET_COMMANDS.includes(name)) {
          if (!ticketsOn()) return { content: 'Les tickets passent par un autre bot sur ce Discord.' };
          if (!fromGuild(interaction, ctx.guild)) return { content: 'Commande disponible uniquement sur le Discord RoadLine.' };
          if (name === 'ticket') return tickets.open(interaction, optionsOf(interaction).sujet);
          return tickets.close(interaction, staffAllowed(member, staffRole(), ctx.ownerId));
        }
        if (name === 'aide') {
          const lines = ['`/statut` état du serveur', '`/rejoindre` comment se connecter', '`/rdv` rendez-vous de la semaine', '`/site` le site'];
          if (ticketsOn()) lines.push('`/ticket sujet` ouvrir un ticket privé avec le staff', '`/fermer` fermer ton ticket');
          if (staffAllowed(member, staffRole(), ctx.ownerId)) lines.push('', '**Staff** : ' + Object.keys(STAFF).map((n) => '`/' + n + '`').join(' '));
          return { embeds: [{ title: 'Commandes RoadLine', color: 0xb048ff, description: lines.join('\n') }], flags: 64 };
        }
        const staff = STAFF[name];
        if (staff) {
          if (!fromGuild(interaction, ctx.guild)) return { content: 'Commandes staff utilisables uniquement sur le Discord RoadLine.', flags: 64 };
          if (!staffAllowed(member, staffRole(), ctx.ownerId)) {
            return { content: staffRole() ? 'Réservé au staff.' : 'Rôle staff non configuré (CONFIGURER-DISCORD.bat).', flags: 64 };
          }
          if (GetResourceState('gs_admin') !== 'started') return { content: 'Outils staff indisponibles (gs_admin arrêté).', flags: 64 };
          const o = optionsOf(interaction);
          const who = (member.user && (member.user.global_name || member.user.username)) || '?';
          let r = null;
          try { r = exports.gs_admin.RemoteAction(staff.action, o.id || 0, o.texte || '', who, o.minutes); } catch (e) { r = null; }
          const text = r && r.text ? String(r.text) : 'Pas de réponse du serveur.';
          return { content: ((r && r.ok) ? '✅ ' : '❌ ') + text.slice(0, 1900), flags: 64 };
        }
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
