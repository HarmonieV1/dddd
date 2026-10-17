import { useEffect, useRef, useState } from 'react'
import { api } from './api.js'

// V12.65 · Outils staff de l'appli : chat staff (synchronisé avec /sc en jeu), événements programmés, bans définitifs à valider.

const hhmm = (t) => new Date(t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })

/** Chat staff : les messages viennent de l'aperçu (rafraîchi toutes les 5 s), l'envoi rafraîchit tout de suite. */
export function StaffChat({ chat = [], refresh, toast }) {
  const [text, setText] = useState('')
  const box = useRef(null)
  useEffect(() => { if (box.current) box.current.scrollTop = box.current.scrollHeight }, [chat.length])
  const send = async (e) => {
    e.preventDefault()
    if (!text.trim()) return
    const r = await api('chat', { text })
    if (r.ok) { setText(''); refresh() } else toast(r)
  }
  return (
    <section className="card">
      <div className="card-head"><h4>Chat staff</h4><span className="muted">aussi /sc en jeu</span></div>
      <div className="chat" ref={box}>
        {chat.length === 0 && <p className="empty sm">Aucun message.</p>}
        {chat.map((m) => (
          <p key={m.id} className="chat-line"><span className="muted mono">{hhmm(m.at)}</span> <b>{m.who}</b>{m.origin === 'appli' && <em className="muted"> · appli</em>} : {m.text}</p>
        ))}
      </div>
      <form className="toolbar" onSubmit={send}>
        <input maxLength={300} value={text} onChange={(e) => setText(e.target.value)} placeholder="Message au staff…" aria-label="Message au staff" />
        <button className="btn cyan" disabled={!text.trim()}>Envoyer</button>
      </form>
    </section>
  )
}

/** Programmer un événement à une heure donnée (heure du serveur), au lieu choisi si l'événement en a besoin. */
export function Schedule({ ov, refresh, toast }) {
  const kinds = ov.kinds || []
  const [kind, setKind] = useState('')
  const [place, setPlace] = useState('')
  const [time, setTime] = useState('21:00')
  const k = kinds.find((x) => x.id === kind)
  const plan = async (e) => {
    e.preventDefault()
    const r = await api('plan', { kind, time, place: place ? Number(place) : null })
    toast(r)
    if (r.ok) refresh()
  }
  return (
    <section className="card">
      <div className="card-head"><h4>Événements programmés</h4><span className="muted">admin et plus</span></div>
      {(ov.schedule || []).length === 0 && <p className="empty sm">Rien de prévu.</p>}
      {(ov.schedule || []).map((s) => (
        <div key={s.id} className="row-line">
          <span><b>{new Date(s.at * 1000).toLocaleString('fr-FR', { weekday: 'short', hour: '2-digit', minute: '2-digit' })}</b> · {s.label}{s.place ? ` · ${s.place}` : ''}</span>
          <button className="btn ghost sm" onClick={async () => { const r = await api('unplan', { id: s.id }); toast(r); refresh() }}>Annuler</button>
        </div>
      ))}
      <form className="toolbar wrap" onSubmit={plan}>
        <select value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Événement">
          <option value="">Événement…</option>
          {kinds.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}
        </select>
        {k && k.place && (
          <select value={place} onChange={(e) => setPlace(e.target.value)} aria-label="Lieu">
            <option value="">Lieu…</option>
            {(ov.places || []).map((p, i) => <option key={p} value={i + 1}>{p}</option>)}
          </select>
        )}
        <input type="time" value={time} onChange={(e) => setTime(e.target.value)} aria-label="Heure" />
        <button className="btn pink" disabled={!kind || (k && k.place && !place)}>Programmer</button>
      </form>
    </section>
  )
}

/** Bans définitifs en attente d'un 2e admin. */
export function BanReviews({ list = [], refresh, toast }) {
  if (!list.length) return null
  const decide = async (id, ok) => { const r = await api(ok ? 'banconfirm' : 'banreject', { id }); toast(r); refresh() }
  return (
    <section className="card warn-card">
      <div className="card-head"><h4>Bans définitifs à valider</h4><span className="muted">un 2e admin décide</span></div>
      {list.map((b) => (
        <div key={b.id} className="row-line">
          <span><b>{b.name}</b> · {b.reason} <span className="muted">(par {b.by}, il y a {Math.floor(b.ago / 60)} min)</span></span>
          <span className="toolbar">
            <button className="btn pink sm" onClick={() => decide(b.id, true)}>Valider</button>
            <button className="btn ghost sm" onClick={() => decide(b.id, false)}>Refuser</button>
          </span>
        </div>
      ))}
    </section>
  )
}
