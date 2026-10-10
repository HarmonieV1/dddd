// Pont NUI <-> client Lua. Hors jeu (navigateur) : données de démo pour développer l'UI.
import { DEMO, DEMO_DOSSIER } from './demo.js'

const inGame = typeof window.GetParentResourceName === 'function'
const resource = inGame ? window.GetParentResourceName() : 'gs_admin'
export const isBrowser = !inGame

export async function nui(action, body = {}) {
  if (!inGame) {
    if (action === 'refresh') return DEMO
    if (action === 'dossier') return DEMO_DOSSIER
    if (action === 'toggleDuty') return { ok: true, onDuty: !DEMO.onDuty }
    return { ok: true, message: `${body.name || action} : ok (démo)` }
  }
  const res = await fetch(`https://${resource}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  })
  return res.json()
}
