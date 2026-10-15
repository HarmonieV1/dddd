// Appli staff externe : appels à server/web.lua (POST api). Le jeton de session (pas le mot de passe) est gardé dans le navigateur.
const KEY = 'rlstaff.token'
const read = () => { try { return localStorage.getItem(KEY) || sessionStorage.getItem(KEY) || '' } catch { return '' } }
let token = read()
export const hasToken = () => !!token
export function setToken(t, remember) {
  token = t || ''
  try {
    localStorage.removeItem(KEY); sessionStorage.removeItem(KEY)
    if (t) (remember ? localStorage : sessionStorage).setItem(KEY, t)
  } catch { /* navigateur privé : la session dure le temps de l'onglet */ }
}

// Démo hors serveur (npm run dev) : données fictives clairement marquées
const DEMO = import.meta.env.DEV && location.port === '5173'

export async function api(action, body = {}) {
  if (DEMO) return (await import('./demo.js')).demoApi(action, body)
  try {
    const r = await fetch('api', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...body, action, token }) })
    const j = await r.json()
    if (j && j.auth === false && action !== 'login') setToken('')
    return j || { ok: false, text: 'Réponse vide.' }
  } catch {
    return { ok: false, text: 'Serveur injoignable : vérifie la connexion.' }
  }
}
