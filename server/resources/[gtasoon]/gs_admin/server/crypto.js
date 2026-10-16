// gs_admin (serveur) · V12.63 : jetons de session de l'appli staff, tirés au hasard par le système (crypto de Node),
// pas par math.random de Lua (prévisible).
// Isolé dans sa propre fonction : FiveM exécute tous les .js d'une ressource dans le même contexte ; maps.js déclare déjà
// « const crypto » au premier niveau, un second « const crypto » ici faisait planter ce fichier (« No such export RandomToken »).
(() => {
  const nodeCrypto = require('crypto');
  exports('RandomToken', () => nodeCrypto.randomBytes(24).toString('hex'));
  exports('SafeEqual', (a, b) => {
    if (typeof a !== 'string' || typeof b !== 'string') return false;
    const x = Buffer.from(a), y = Buffer.from(b);
    return x.length === y.length && nodeCrypto.timingSafeEqual(x, y);
  });
})();
