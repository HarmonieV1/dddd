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
  check('administrateur Discord : autorisé', staffAllowed({ roles: [], permissions: '8' }, ''));
  check('membre simple : refusé', !staffAllowed({ roles: ['222'], permissions: '1024' }, '111') && !staffAllowed(null, '111'));
  check('options lues', optionsOf({ data: { options: [{ name: 'id', value: 4 }, { name: 'texte', value: 'triche' }] } }).texte === 'triche');
  await bot.onMessage(JSON.stringify({ op: 1 }));
  check('battement de cœur demandé : renvoyé', sent[sent.length - 1].op === 1 && sent[sent.length - 1].d === 2);
  bot.stop();
  console.log(`bot Discord intégré : ${passed} réussis, ${failed} échoués`);
  process.exit(failed ? 1 : 0);
});
