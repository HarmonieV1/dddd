// Tests du bot Discord intégré (gs_discord/server/bot.js) : trames WebSocket (petites, moyennes, fragmentées, masquées),
// vraie connexion WebSocket locale (poignée de main + aller-retour), logique du bot (identification, commandes, réponses).
'use strict';
const http = require('http');
const crypto = require('crypto');
const { encodeFrame, decodeFrames, createBot, wsConnect } = require('../server/resources/[gtasoon]/gs_discord/server/bot.js');
let passed = 0, failed = 0;
const check = (name, cond) => { if (cond) passed++; else { failed++; console.error('ÉCHEC : ' + name); } };

// 1. Trames
for (const n of [5, 300, 70000]) {
  const t = 'é'.repeat(n);
  const { frames, rest } = decodeFrames(encodeFrame(t));
  check(`trame masquée de ${n} caractères`, frames.length === 1 && frames[0].payload.toString('utf8') === t && rest.length === 0);
}
const serverFrame = (text, fin = true, opcode = 1) => {
  const p = Buffer.from(text); const h = p.length < 126 ? Buffer.from([(fin ? 0x80 : 0) | opcode, p.length]) : Buffer.concat([Buffer.from([(fin ? 0x80 : 0) | opcode, 126]), Buffer.from([p.length >> 8, p.length & 255])]);
  return Buffer.concat([h, p]);
};
const two = Buffer.concat([serverFrame('{"a":', false), serverFrame('1}', true, 0)]);
const half = decodeFrames(two.slice(0, 4));
check('trame incomplète : attend la suite', half.frames.length === 0 && half.rest.length === 4);
const all = decodeFrames(two);
check('message fragmenté : 2 trames', all.frames.length === 2 && !all.frames[0].fin && all.frames[1].opcode === 0);

// 2. Vraie connexion locale
const srv = http.createServer();
srv.on('upgrade', (req, sock) => {
  const accept = crypto.createHash('sha1').update(req.headers['sec-websocket-key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  sock.write(Buffer.concat([serverFrame('{"op":10,', false), serverFrame('"d":{"heartbeat_interval":45000}}', true, 0)])); // fragmenté
  let buf = Buffer.alloc(0);
  sock.on('data', (c) => {
    buf = Buffer.concat([buf, c]);
    const r = decodeFrames(buf); buf = r.rest;
    for (const f of r.frames) if (f.opcode === 1) { sock.write(serverFrame('echo:' + f.payload.toString())); sock.end(Buffer.from([0x88, 2, 0x03, 0xe8])); }
  });
});
srv.listen(0, async () => {
  const got = [];
  await new Promise((resolve) => {
    const ws = wsConnect(`ws://127.0.0.1:${srv.address().port}/?v=10`, {
      message: (t) => { got.push(t); if (got.length === 1) ws.send('{"op":2}'); },
      close: (code) => { got.push('close:' + code); resolve(); },
    });
    setTimeout(resolve, 3000);
  });
  check('poignée de main + message fragmenté reçu', got[0] === '{"op":10,"d":{"heartbeat_interval":45000}}');
  check('envoi masqué compris par le serveur', got[1] === 'echo:{"op":2}');
  check('fermeture propre', got[2] === 'close:1000');
  srv.close();

  // 3. Logique du bot
  const sent = [], calls = [];
  const bot = createBot({
    token: 'T'.repeat(60), log: () => {}, presence: () => '3/48 citoyens à Los Santos',
    connect: () => ({ send: (t) => sent.push(JSON.parse(t)), close: () => {} }),
    rest: async (m, p, b) => { calls.push({ m, p, b }); return { status: 200 }; },
    answer: (name) => ({ content: 'réponse ' + name }),
  });
  bot.start();
  await bot.onMessage(JSON.stringify({ op: 10, d: { heartbeat_interval: 999999 } }));
  check('identification avec le jeton, sans intents', sent[0].op === 2 && sent[0].d.token.length === 60 && sent[0].d.intents === 0);
  await bot.onMessage(JSON.stringify({ op: 0, t: 'READY', s: 1, d: { application: { id: '42' }, user: { username: 'RoadLine' } } }));
  check('commandes enregistrées', calls[0].m === 'PUT' && calls[0].p === '/applications/42/commands' && calls[0].b.some((c) => c.name === 'statut'));
  check('présence envoyée', sent.some((x) => x.op === 3 && x.d.activities[0].name === '3/48 citoyens à Los Santos'));
  check('présence inchangée : pas de renvoi', bot.presence(false) === false);
  await bot.onMessage(JSON.stringify({ op: 0, t: 'INTERACTION_CREATE', s: 2, d: { type: 2, id: '7', token: 'abc', data: { name: 'statut' } } }));
  const r = calls[1];
  check('réponse à /statut', r.m === 'POST' && r.p === '/interactions/7/abc/callback' && r.b.type === 4 && r.b.data.content === 'réponse statut' && r.b.data.allowed_mentions);
  // V10.1 : commandes staff
  const { STAFF, staffAllowed, optionsOf, COMMANDS: CMDS } = require('../server/resources/[gtasoon]/gs_discord/server/bot.js');
  check('commandes staff déclarées (hors messages privés)', ['joueurs', 'geler', 'expulser', 'annonce'].every((n) => CMDS.some((c) => c.name === n && c.dm_permission === false)));
  check('geler : identifiant obligatoire', STAFF.geler.options[0].name === 'id' && STAFF.geler.options[0].required);
  check('rôle staff : autorisé', staffAllowed({ roles: ['111'], permissions: '0' }, '111'));
  check('V12.3 administrateur du Discord RoadLine sans le rôle : autorisé (serveur vérifié avant)', staffAllowed({ user: { id: '5' }, roles: [], permissions: '8' }, '111', '9'));
  check('V12.3 isoler / libérer / réanimer déclarées', ['isoler', 'liberer', 'reanimer'].every((n) => CMDS.some((c) => c.name === n)) && STAFF.isoler.options[1].name === 'minutes');
  check('V11.4 propriétaire du Discord : autorisé', staffAllowed({ user: { id: '9' }, roles: [], permissions: '0' }, '', '9'));
  check('membre simple : refusé', !staffAllowed({ roles: ['222'], permissions: '1024' }, '111') && !staffAllowed(null, '111'));
  const { fromGuild, commandsFor, createTickets } = require('../server/resources/[gtasoon]/gs_discord/server/bot.js');
  check('V11.4 commande depuis un autre Discord : refusée', !fromGuild({ guild_id: '999' }, '123') && fromGuild({ guild_id: '123' }, '123') && !fromGuild({ guild_id: '123' }, ''));
  check('V11.4 tickets désactivables (bot externe)', !commandsFor({ tickets: false }).some((c) => c.name === 'ticket') && commandsFor({ tickets: true }).some((c) => c.name === 'fermer'));
  check('options lues', optionsOf({ data: { options: [{ name: 'id', value: 4 }, { name: 'texte', value: 'triche' }] } }).texte === 'triche');
  await bot.onMessage(JSON.stringify({ op: 1 }));
  check('battement de cœur demandé : renvoyé', sent[sent.length - 1].op === 1 && sent[sent.length - 1].d === 2);
  bot.stop();

  // V11.4 · Discord configuré : commandes sur ce Discord seulement, propriétaire lu, réponse différée pour /ticket
  const sent2 = [], calls2 = [];
  let gotCtx = null;
  const bot2 = createBot({
    token: 'T'.repeat(60), log: () => {}, presence: () => '0/48', guild: () => '123', tickets: () => true,
    connect: () => ({ send: (t) => sent2.push(JSON.parse(t)), close: () => {} }),
    rest: async (m, p, b) => { calls2.push({ m, p, b }); return p === '/guilds/123' ? { status: 200, body: { owner_id: '9' } } : { status: 200 }; },
    answer: async (name, i, ctx) => { gotCtx = ctx; return { content: 'ok ' + name }; },
  });
  bot2.start();
  await bot2.onMessage(JSON.stringify({ op: 0, t: 'READY', s: 1, d: { application: { id: '42' }, user: { username: 'RoadLine' } } }));
  check('commandes enregistrées sur le Discord RoadLine', calls2[0].m === 'PUT' && calls2[0].p === '/applications/42/guilds/123/commands');
  check('commandes globales vidées (pas de doublons ailleurs)', calls2[1].p === '/applications/42/commands' && calls2[1].b.length === 0);
  check('propriétaire du Discord lu', bot2.state().ownerId === '9');
  calls2.length = 0;
  await bot2.onMessage(JSON.stringify({ op: 0, t: 'INTERACTION_CREATE', s: 2, d: { type: 2, id: '8', token: 'tok', guild_id: '123', data: { name: 'ticket' } } }));
  check('/ticket : réponse différée puis message édité', calls2[0].b.type === 5 && calls2[0].b.data.flags === 64 && calls2[1].m === 'PATCH'
    && calls2[1].p === '/webhooks/42/tok/messages/@original' && calls2[1].b.content === 'ok ticket');
  check('contexte transmis (propriétaire, Discord)', gotCtx && gotCtx.ownerId === '9' && gotCtx.guild === '123');
  bot2.stop();

  // V11.4 · Connexion morte (pas d'accusé de battement) et attente croissante entre deux reconnexions
  let handlers = null, closes = 0;
  const bot3 = createBot({ token: 'T'.repeat(60), log: () => {}, presence: () => '', rest: async () => ({ status: 200 }), answer: () => ({}),
    connect: (u, h) => { handlers = h; return { send: () => {}, close: () => { closes++; } }; } });
  bot3.start();
  await bot3.onMessage(JSON.stringify({ op: 10, d: { heartbeat_interval: 20 } }));
  await new Promise((r) => setTimeout(r, 70));
  check('battement sans accusé : connexion coupée', closes >= 1);
  handlers.close(1006);
  check('reconnexion : attente doublée', bot3.state().delay === 20000);
  const logs = [];
  const bot4 = createBot({ token: 'T'.repeat(60), log: (m) => logs.push(m), presence: () => '', rest: async () => ({ status: 200 }), answer: () => ({}),
    connect: (u, h) => { handlers = h; return { send: () => {}, close: () => {} }; } });
  bot4.start();
  handlers.close(4004);
  check('jeton refusé : pas de reconnexion en boucle', bot4.state().delay === 10000 && logs.some((l) => l.includes('4004')));
  bot3.stop(); bot4.stop();

  // V11.4 · Tickets en fil privé
  const tcalls = [];
  let stored = {}, clock = 1000000;
  const archived = {};
  const T = createTickets({
    channelId: '500', roleId: '111', now: () => clock,
    store: { load: () => JSON.parse(JSON.stringify(stored)), save: (o) => { stored = JSON.parse(JSON.stringify(o)); } },
    rest: async (m, p, b) => {
      tcalls.push({ m, p, b });
      if (m === 'POST' && p === '/channels/500/threads') return { status: 201, body: { id: '700' } };
      if (m === 'GET' && p === '/channels/700') return { status: 200, body: { id: '700', thread_metadata: { archived: !!archived['700'] } } };
      return { status: 200, body: {} };
    },
  });
  const member = { user: { id: '77', username: 'Jean Dupont' }, roles: [] };
  let r1 = await T.open({ member }, '<@&1> remboursement voiture');
  const th = tcalls.find((c) => c.p === '/channels/500/threads');
  check('ticket : fil privé créé dans #tickets', th && th.b.type === 12 && th.b.invitable === false && th.b.name === 'ticket-jean-dupont');
  check('ticket : joueur ajouté au fil', tcalls.some((c) => c.m === 'PUT' && c.p === '/channels/700/thread-members/77'));
  const first = tcalls.find((c) => c.p === '/channels/700/messages');
  check('ticket : staff prévenu, mentions limitées, sujet nettoyé', first && first.b.content.includes('<@&111>') && first.b.allowed_mentions.roles[0] === '111'
    && first.b.allowed_mentions.users[0] === '77' && !first.b.content.includes('<@&1>'));
  check('ticket : lien renvoyé et mémorisé', r1.content.includes('<#700>') && stored['77'] === '700');
  let r2 = await T.open({ member }, 'encore');
  check('ticket : un seul ouvert à la fois', r2.content.includes('déjà un ticket') && tcalls.filter((c) => c.p === '/channels/500/threads').length === 1);
  const other = { member: { user: { id: '88', username: 'X' }, roles: [] }, channel_id: '700', channel: { parent_id: '500' } };
  check('fermer : refusé à un autre membre', (await T.close(other, false)).content.includes('Seuls'));
  check('fermer : hors d\'un fil de ticket, refusé', (await T.close({ member, channel_id: '1', channel: { parent_id: '2' } }, true)).content.includes('/fermer'));
  const rc = await T.close({ member, channel_id: '700', channel: { parent_id: '500' } }, false);
  check('fermer : par l\'auteur, fil archivé et verrouillé', rc.content === 'Ticket fermé.' && tcalls.some((c) => c.m === 'PATCH' && c.p === '/channels/700' && c.b.locked && c.b.archived) && !stored['77']);
  archived['700'] = true;
  check('nouveau ticket trop tôt : attente', (await T.open({ member }, 'x')).content.includes('Attends'));
  clock += 130000;
  check('nouveau ticket après 2 min : ouvert', (await T.open({ member }, 'x')).content.includes('Ticket ouvert'));
  const T2 = createTickets({ channelId: '', roleId: '', now: () => 0, store: { load: () => ({}), save: () => {} }, rest: async () => ({ status: 200 }) });
  check('tickets non configurés : message clair', (await T2.open({ member }, 'x')).content.includes('pas encore configurés'));
  const T3 = createTickets({ channelId: '500', roleId: '', now: () => 0, store: { load: () => ({}), save: () => {} }, rest: async () => ({ status: 403, body: { code: 50013 } }) });
  check('bot sans droits sur #tickets : message clair', (await T3.open({ member }, 'x')).content.includes('droits'));

  console.log(`bot Discord intégré : ${passed} réussis, ${failed} échoués`);
  process.exit(failed ? 1 : 0);
});
