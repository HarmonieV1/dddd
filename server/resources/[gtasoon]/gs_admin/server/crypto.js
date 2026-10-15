// gs_admin (serveur) · V12.63 : jetons de session de l'appli staff, tirés au hasard par le système (crypto de Node),
// pas par math.random de Lua (prévisible).
const crypto = require('crypto');
exports('RandomToken', () => crypto.randomBytes(24).toString('hex'));
exports('SafeEqual', (a, b) => {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
});
