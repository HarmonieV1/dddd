import { useEffect, useState } from 'react'
import { nui, isBrowser } from './nui.js'

// App Boulots : petits boulots sans embauche (gs_gigs). Offres, acceptation, boulot en cours.
const DEMO = {
  offers: [
    { id: 1, kind: 'courier', label: 'Livraison express', icon: '📦', desc: 'Un client pressé, un colis fragile. Pas de questions.', legal: true, km: 3.4, pay: 454 },
    { id: 2, kind: 'smuggler', label: 'Passeur', icon: '🕶️', desc: 'Bien payé. Évite les flics. Paiement en liquide sale.', legal: false, km: 5.1, pay: 1526 },
  ],
  active: null, cooldown: 0, refreshIn: 240,
}

export default function Gigs({ onBack, say }) {
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const load = async () => { if (!isBrowser) setData((await nui('gigsList')) || { offers: [], unavailable: true }) }
  useEffect(() => { load() }, [])

  const accept = async (o) => {
    if (isBrowser) return setData({ ...data, active: { label: o.label, step: 'Récupérer le colis', stage: 1, pay: o.pay } })
    const r = await nui('gigsAccept', { id: o.id })
    say(r.message, r.ok)
    load()
  }
  const cancel = async () => { if (!isBrowser) { const r = await nui('gigsCancel'); if (r.ok) say(r.message, true) } load(); if (isBrowser) setData({ ...data, active: null }) }

  let body
  if (!data) body = <div className="empty">Chargement…</div>
  else if (data.unavailable) body = <div className="empty">Service indisponible.</div>
  else body = (
    <div className="list">
      {data.active && (
        <div className="card-bank">
          <span>En cours · {data.active.label}</span>
          <b>{data.active.step}</b>
          <small>Étape {data.active.stage}/2 · {data.active.pay} $ à la clé · suis le GPS</small>
          <button className="secondary" onClick={cancel}>Abandonner</button>
        </div>
      )}
      {!data.active && data.cooldown > 0 && <div className="empty">Prochain boulot dans {data.cooldown} s.</div>}
      {!data.active && data.offers.map((o) => (
        <div key={o.id} className={(o.legal ? 'gig' : 'gig shady') + (o.special ? ' special' : '')}>
          <div className="gig-head"><span className="gig-icon">{o.icon}</span><b>{o.label}</b><span className="gig-pay">{o.pay} $</span></div>
          <p className="muted small">{o.desc}</p>
          <div className="gig-foot"><span className="muted small">{o.km} km{o.legal ? '' : ' · illégal'}</span>
            <button className="primary slim" disabled={data.cooldown > 0} onClick={() => accept(o)}>Accepter</button></div>
        </div>
      ))}
      {!data.active && data.offers.length === 0 && <div className="empty">Plus d’offres pour l’instant. Reviens dans {Math.ceil((data.refreshIn || 0) / 60)} min.</div>}
    </div>
  )

  return (
    <>
      <div className="app-header">
        <button className="back" onClick={onBack}>‹</button>
        <h2>Boulots</h2>
        <div className="right"><button className="link" onClick={load}>↻</button></div>
      </div>
      {body}
    </>
  )
}
