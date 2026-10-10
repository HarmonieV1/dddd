// Pont NUI <-> client Lua. Hors jeu (navigateur, npm run dev) : réponses simulées pour développer l'UI.
const inGame = typeof window.GetParentResourceName === 'function'
const resource = inGame ? window.GetParentResourceName() : 'gs_social'

export async function nui(action, body = {}) {
  if (!inGame) return mock(action, body)
  const res = await fetch(`https://${resource}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  })
  return res.json()
}

export const isBrowser = !inGame

let mockId = 3
function mock(action, body) {
  if (action === 'setHandle') return { ok: true, message: body.handle }
  if (action === 'post') {
    window.postMessage({ action: 'new', post: { id: ++mockId, handle: 'alpha', content: body.content, likes: 0, time: Date.now() / 1000 } })
    return { ok: true }
  }
  if (action === 'like') return { ok: true, message: true }
  return { ok: true }
}
