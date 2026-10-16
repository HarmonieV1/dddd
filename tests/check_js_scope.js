// V12.63 · FiveM exécute tous les .js serveur (ou client) d'une ressource dans LE MÊME contexte : deux « const x » au
// premier niveau dans deux fichiers = le second plante au démarrage (backtest : crypto.js de gs_admin, « No such export »).
// On vérifie, pour chaque ressource maison, que les noms déclarés au premier niveau ne se répètent pas d'un fichier à l'autre.
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', 'server', 'resources', '[gtasoon]');
let errors = 0, checked = 0;
for (const res of fs.readdirSync(root)) {
  const man = path.join(root, res, 'fxmanifest.lua');
  if (!fs.existsSync(man)) continue;
  const text = fs.readFileSync(man, 'utf8');
  for (const side of ['server_scripts', 'client_scripts', 'shared_scripts']) {
    const m = text.match(new RegExp(side + '\\s*\\{([^}]*)\\}'));
    if (!m) continue;
    const files = [...m[1].matchAll(/'([^']+\.js)'/g)].map((x) => x[1]).filter((f) => !f.startsWith('@') && !f.includes('*'));
    if (files.length < 2) continue;
    const seen = {};
    for (const f of files) {
      const p = path.join(root, res, f);
      if (!fs.existsSync(p)) continue;
      checked++;
      for (const line of fs.readFileSync(p, 'utf8').split('\n')) {
        const d = line.match(/^(?:const|let|class)\s+([A-Za-z_$][\w$]*)/);
        const names = d ? [d[1]] : [];
        const de = line.match(/^(?:const|let)\s*\{([^}]*)\}/);
        if (de) for (const n of de[1].split(',')) { const k = n.split(':').pop().trim(); if (k) names.push(k); }
        for (const n of names) {
          if (seen[n] && seen[n] !== f) { console.log(`ERREUR ${res} : « ${n} » déclaré au premier niveau dans ${seen[n]} ET ${f} (même contexte FiveM)`); errors++; }
          else seen[n] = f;
        }
      }
    }
  }
}
if (errors) process.exit(1);
console.log(`Portée JS des ressources OK (${checked} fichiers)`);
