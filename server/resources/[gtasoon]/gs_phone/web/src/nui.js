// Pont NUI <-> client Lua. Hors jeu (navigateur) : données de démo pour développer l'UI.
const inGame = typeof window.GetParentResourceName === 'function'
const resource = inGame ? window.GetParentResourceName() : 'gs_phone'
export const isBrowser = !inGame

const now = () => Date.now() / 1000
export const DEMO = {
  number: '555-0142', clock: '19:42', silent: false, maxLength: 300,
  money: { cash: 1250, bank: 48200 },
  job: { name: 'mechanic', label: 'Mécano LS Customs', grade: 1, onduty: true },
  contacts: [{ id: 1, name: 'Lucia', number: '555-7788' }, { id: 2, name: 'Garage Benny', number: '555-2020' }],
  conversations: [
    { peer: '555-7788', unread: 2, last: 'On se retrouve à Vespucci au coucher du soleil ?', time: now() - 60, mine: false },
    { peer: '555-9001', unread: 0, last: 'Ok je passe au garage', time: now() - 3600, mine: true },
  ],
  emergency: [{ id: 'mechanic', label: 'Dépanneuse' }, { id: 'police', label: 'Police (LSPD)' }, { id: 'ems', label: 'Urgences médicales (EMS)' }],
}

export async function nui(action, body = {}) {
  if (!inGame) {
    if (action === 'thread') return [
      { id: 2, content: 'On se retrouve à Vespucci au coucher du soleil ?', time: now() - 60, mine: false },
      { id: 1, content: 'Yo, t’es dispo ce soir ?', time: now() - 300, mine: true },
    ]
    if (action === 'send') return { ok: true, message: { id: Date.now(), content: body.text, time: now(), mine: true } }
    if (action === 'bills') return [{ id: 7, job: 'police', amount: 350, reason: 'Excès de vitesse', issuer_name: 'Agent Ramirez', date: '28/09 21:10' }]
    if (action === 'addContact') return { ok: true, message: [...DEMO.contacts, { id: 3, name: body.name, number: body.number }] }
    return { ok: true, message: 'ok (démo)' }
  }
  const res = await fetch(`https://${resource}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  })
  return res.json()
}
