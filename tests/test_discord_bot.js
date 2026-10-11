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

  // V12.5 · Les 4 symptômes remontés en jeu ---------------------------------------------------------------------
  const { createAnswer, resolveGuild } = require('../server/resources/[gtasoon]/gs_discord/server/bot.js');
  const G = '111111111111111111', OTHER = '222222222222222222';
  // Discord RoadLine : gs_discord_guild vide ou faux → avant, /ticket et /annonce disaient « uniquement sur le Discord RoadLine »
  check('guild réglé et bot présent : gardé', resolveGuild(G, [{ id: G }, { id: OTHER }]) === G);
  const glogs = [];
  check('guild vide, bot sur UN Discord : détecté', resolveGuild('', [{ id: G }], (m) => glogs.push(m)) === G && glogs[0].includes('détecté'));
  check('guild faux, bot sur UN Discord : corrigé + signalé', resolveGuild(OTHER, [{ id: G }], (m) => glogs.push(m)) === G && glogs.some((l) => l.includes('PAS sur ce Discord')));
  check('guild vide, bot sur 2 Discords : refus de deviner', resolveGuild('', [{ id: G }, { id: OTHER }], () => {}) === '');
  check('liste inconnue : réglage conservé', resolveGuild(G, undefined) === G);
  const calls5 = [];
  const bot5 = createBot({ token: 'T'.repeat(60), log: () => {}, presence: () => '', guild: () => '', tickets: () => true,
    connect: () => ({ send: () => {}, close: () => {} }),
    rest: async (m, p, b) => { calls5.push({ m, p, b }); return { status: 200, body: {} }; }, answer: () => ({}) });
  bot5.start();
  await bot5.onMessage(JSON.stringify({ op: 0, t: 'READY', s: 1, d: { application: { id: '42' }, user: { username: 'R' }, guilds: [{ id: G, unavailable: true }] } }));
  check('guild vide : commandes posées sur le Discord détecté (nettoie les anciennes /help /ip)', calls5[0].p === `/applications/42/guilds/${G}/commands`);
  bot5.stop();

  // Réponses
  const posted = [], remotes = [];
  let hookOk = true;
  const mkDeps = (over) => Object.assign({
    conv: (n, d) => ({ gs_connect: '51.38.1.2:30120' })[n] || d || '',
    staffRole: () => '999', ticketsOn: () => true,
    tickets: { open: async () => ({ content: 'Ticket ouvert : <#1>' }), close: async () => ({ content: 'Ticket fermé.' }) },
    adminOn: () => true,
    remote: (a, id, text) => { remotes.push({ a, text }); return { ok: true, text: 'ok' }; },
    statusEmbed: () => ({ title: 'statut' }), weekly: () => 'rdv',
    announce: (t, x, m) => { posted.push({ t, x, m }); return hookOk; },
    post: async (ch, body) => { posted.push({ ch, body }); return { status: 200 }; },
  }, over || {});
  const ans = createAnswer(mkDeps());
  const ctx = { ownerId: '9', guild: G };
  const staffMember = { user: { id: '5', username: 'Modo' }, roles: ['999'], permissions: '0' };
  const plain = { user: { id: '6', username: 'Joueur' }, roles: [], permissions: '0' };
  const it = (name, options, member, guild) => ({ guild_id: guild === undefined ? G : guild, channel_id: '300', member: member || plain,
    data: { name, options: Object.entries(options || {}).map(([k, v]) => ({ name: k, value: v })) } });

  // 1. /help donnait le site
  const h = await ans('help', it('help'), ctx);
  check('/help : liste des commandes (plus le site)', h.embeds && h.embeds[0].title === 'Commandes RoadLine' && h.embeds[0].description.includes('/ip'));
  check('commande inconnue : l\'aide, pas le site', (await ans('vieille', it('vieille'), ctx)).embeds[0].title === 'Commandes RoadLine');
  check('/site : toujours le lien du site', (await ans('site', it('site'), ctx)).content.startsWith('https://'));
  // 2. /ip ne donnait pas l'IP
  const ip = await ans('ip', it('ip'), ctx);
  check('/ip : adresse + commande F8', ip.embeds && ip.embeds[0].description.includes('connect 51.38.1.2:30120'));
  const ipEmpty = await createAnswer(mkDeps({ conv: (n, d) => d || '' }))('ip', it('ip'), ctx);
  check('/ip sans adresse réglée : message clair', ipEmpty.content.includes('gs_connect'));
  check('/ip et /help déclarées', CMDS.some((c) => c.name === 'ip') && CMDS.some((c) => c.name === 'help'));
  // 3. /annonce n'écrivait pas sur Discord
  const a1 = await ans('annonce', it('annonce', { texte: 'Ouverture samedi 21h', titre: 'Grande ouverture', mention: 'everyone' }, staffMember), ctx);
  check('/annonce : publiée dans #annonces avec titre et @everyone', a1.content.startsWith('✅') && posted[0].t === 'Grande ouverture' && posted[0].m === 'everyone');
  check('/annonce : pas en jeu par défaut', remotes.length === 0);
  posted.length = 0;
  await ans('annonce', it('annonce', { texte: 'Tempête ce soir', en_jeu: true }, staffMember), ctx);
  check('/annonce en_jeu : aussi en ville', remotes.length === 1 && remotes[0].a === 'announce' && posted[0].t === '📢 Annonce');
  posted.length = 0; hookOk = false;
  const a3 = await ans('annonce', it('annonce', { texte: 'Test' }, staffMember), ctx);
  check('/annonce sans webhook #annonces : publiée dans le salon courant', posted.some((x) => x.ch === '300') && a3.content.includes('ce salon'));
  hookOk = true; posted.length = 0;
  check('/annonce : refusée à un joueur', (await ans('annonce', it('annonce', { texte: 'x' }), ctx)).content === 'Réservé au staff.' && posted.length === 0);
  check('/annonce : texte max 1800 (avant 200)', CMDS.find((c) => c.name === 'annonce').options[0].max_length === 1800);
  // 4. /ticket disait « sois sur le Discord » alors qu'on y était
  check('/ticket sur le Discord RoadLine : ouvert', (await ans('ticket', it('ticket', { sujet: 'bug' }), ctx)).content.includes('Ticket ouvert'));
  const wrong = await ans('ticket', it('ticket', { sujet: 'bug' }), { ownerId: '9', guild: '' });
  check('/ticket Discord non reconnu : dit QUOI corriger', wrong.content.includes('gs_discord_guild') && wrong.content.includes('CONFIGURER-DISCORD'));
  // Staff via le bot : inchangé
  const g2 = await ans('geler', it('geler', { id: 4 }, staffMember), ctx);
  check('commande staff : toujours relayée à gs_admin', g2.content.startsWith('✅') && remotes[remotes.length - 1].a === 'freeze');

  // V12.8 · Message de bienvenue : intent « membres » demandé seulement si #bienvenue est réglé ; nouveau membre → message avec mention
  const { welcomeText } = require('../server/resources/[gtasoon]/gs_discord/server/bot.js');
  const sentW = [], callsW = [], logsW = [];
  let hW = null;
  const botW = createBot({ token: 'T'.repeat(60), log: (m) => logsW.push(m), presence: () => '0/48', guild: () => '123', welcome: () => ({ channelId: '777', text: '' }),
    connect: (u, h) => { hW = h; return { send: (t) => sentW.push(JSON.parse(t)), close: () => {} }; },
    rest: async (m, p, b) => { callsW.push({ m, p, b }); return { status: 200 }; }, answer: () => ({}) });
  botW.start();
  await botW.onMessage(JSON.stringify({ op: 10, d: { heartbeat_interval: 999999 } }));
  check('V12.8 intent « membres » demandé quand #bienvenue est réglé', sentW[0].op === 2 && sentW[0].d.intents === 2);
  await botW.onMessage(JSON.stringify({ op: 0, t: 'GUILD_MEMBER_ADD', s: 3, d: { guild_id: '123', user: { id: '555', username: 'nouveau' } } }));
  const wMsg = callsW.find((c) => c.p === '/channels/777/messages');
  check('V12.8 nouveau membre → message de bienvenue avec mention', !!wMsg && wMsg.m === 'POST' && wMsg.b.content.includes('<@555>') && wMsg.b.allowed_mentions.users[0] === '555');
  callsW.length = 0;
  await botW.onMessage(JSON.stringify({ op: 0, t: 'GUILD_MEMBER_ADD', s: 4, d: { guild_id: '123', user: { id: '555', username: 'nouveau' } } }));
  await botW.onMessage(JSON.stringify({ op: 0, t: 'GUILD_MEMBER_ADD', s: 5, d: { guild_id: '999', user: { id: '556' } } }));
  await botW.onMessage(JSON.stringify({ op: 0, t: 'GUILD_MEMBER_ADD', s: 6, d: { guild_id: '123', user: { id: '557', bot: true } } }));
  check('V12.8 déjà accueilli, autre Discord ou bot : ignoré', callsW.length === 0);
  hW.close(4014);
  check('V12.8 intent refusé par le portail (4014) : bienvenue coupée, bot gardé, message clair', botW.state().membersDenied === true && logsW.some((m) => /Server Members Intent/.test(m)));
  botW.stop();
  check('V12.8 texte de bienvenue : {membre} remplacé, mention ajoutée sinon', welcomeText('Bienvenue {membre} !', '1') === 'Bienvenue <@1> !' && welcomeText('', '2').includes('<@2>') && welcomeText('Salut', '3') === '<@3> Salut');

  console.log(`bot Discord intégré : ${passed} réussis, ${failed} échoués`);
  process.exit(failed ? 1 : 0);
});
