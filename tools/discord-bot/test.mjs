// Vérifie le bot sans Discord : embed de statut et lecture d'un faux serveur FiveM.
import { createServer } from 'node:http';
import { writeFileSync, existsSync } from 'node:fs';
const cfgPath = new URL('./config.json', import.meta.url);
const created = !existsSync(cfgPath);
if (created) writeFileSync(cfgPath, JSON.stringify({ token: 'x', fivem: 'http://127.0.0.1:30999', connect: 'cfx.re/join/test', name: 'RoadLine RP' }));
process.argv[2] = '--test';
const { fivemStatus, statusEmbed } = await import('./bot.mjs');
const srv = createServer((q, r) => r.end(q.url === '/players.json' ? '[{},{},{}]' : '{"clients":3,"sv_maxclients":48}')).listen(30999);
let ok = true;
const s = await fivemStatus('http://127.0.0.1:30999');
if (!(s.online && s.players === 3 && s.max === 48)) { ok = false; console.error('ÉCHEC lecture FiveM', s); }
const e = statusEmbed(s, { name: 'RoadLine RP', connect: 'x' });
if (!e.description.includes('3 / 48')) { ok = false; console.error('ÉCHEC embed'); }
srv.close();
const off = await fivemStatus('http://127.0.0.1:30998');
if (off.online) { ok = false; console.error('ÉCHEC hors ligne'); }
if (created) (await import('node:fs')).unlinkSync(cfgPath);
console.log(ok ? 'bot Discord : 3 réussis, 0 échoués' : 'bot Discord : échec');
process.exit(ok ? 0 : 1);
