// V10 · Nouvelles applis du téléphone : Que faire ?, Plans, Ville, Notes.
import { useEffect, useState } from 'react'
import { nui, isBrowser } from './nui.js'

function Header({ title, onBack, right }) {
  return (
    <div className="app-header">
      <button className="back" onClick={onBack}>‹</button>
      <h2>{title}</h2>
      <div className="right">{right}</div>
    </div>
  )
}

const DEMO_GUIDE = {
  live: [
    { ref: 'live:1', icon: 'calendar-check', color: '#b048ff', label: 'Prochain rendez-vous : Vendredi des courses', desc: 'vendredi à 21:00' },
    { ref: 'live:2', icon: 'users', color: '#5aff8c', label: 'En service : EMS 1 · Mécanos 0 · Police 2 · Taxis 0', desc: 'Aucun mécano en ville : le métier t’attend !' },
  ],
  sections: [
    { id: 'legal', label: 'Gagner ma vie', color: '#4fd8ff', items: [{ ref: 'legal:1', label: 'Pôle emploi', desc: 'Choisir un métier libre', gps: true }] },
    { id: 'fun', label: 'Me détendre', color: '#a24bff', items: [{ ref: 'fun:1', label: 'Casino', desc: 'Roue du jour, loto', gps: true }] },
  ],
}
const SECTION_ICON = { legal: '💼', dark: '🕶️', fun: '🌴', life: '🙂', help: '❓' }

export function QueFaire({ onBack, say }) {
  const [g, setG] = useState(isBrowser ? DEMO_GUIDE : null)
  const [open, setOpen] = useState(null)
  useEffect(() => { if (!isBrowser) nui('guide').then((d) => setG(d || { live: [], sections: [] })) }, [])
  const act = async (it) => {
    await nui('guideAction', { ref: it.ref })
    if (it.gps) say('GPS réglé.')
  }
  if (!g) return (<><Header title="Que faire ?" onBack={onBack} /><div className="empty">Chargement…</div></>)
  const section = open && g.sections.find((s) => s.id === open)
  return (
    <>
      <Header title={section ? section.label : 'Que faire ?'} onBack={section ? () => setOpen(null) : onBack} />
      <div className="list">
        {!section && (
          <>
            <div className="qf-title">En ce moment</div>
            {g.live.map((l) => (
              <button key={l.ref} className="qf-live" style={{ borderColor: l.color }} onClick={() => act(l)}>
                <b>{l.label}</b>{l.desc && <span className="muted">{l.desc}</span>}
              </button>
            ))}
            <div className="qf-title">Envie de…</div>
            <div className="qf-grid">
              {g.sections.map((s) => (
                <button key={s.id} className="qf-cat" style={{ background: `linear-gradient(135deg, ${s.color}, #1a0f2e)` }} onClick={() => setOpen(s.id)}>
                  <span>{SECTION_ICON[s.id] || '•'}</span><b>{s.label}</b><small>{s.items.length} idées</small>
                </button>
              ))}
            </div>
          </>
        )}
        {section && section.items.map((it) => (
          <button key={it.ref} className="row" onClick={() => act(it)}>
            <div className="row-main"><b>{it.label}</b><span className="muted">{it.desc}</span></div>
            <span className="qf-tag">{it.gps ? 'GPS' : 'Ouvrir'}</span>
          </button>
        ))}
      </div>
    </>
  )
}

export function Plans({ onBack, say, contacts, sendTo }) {
  const [places, setPlaces] = useState(isBrowser ? [{ id: 1, name: 'Mon garage', x: -205, y: -1310 }] : [])
  const [name, setName] = useState('')
  const [share, setShare] = useState(false)
  useEffect(() => { if (!isBrowser) nui('places').then((l) => setPlaces(l || [])) }, [])
  const save = async (e) => {
    e.preventDefault()
    const r = await nui('placeSave', { name })
    if (r.ok) { setPlaces(r.message); setName(''); say('Lieu enregistré.') } else say(r.message, false)
  }
  const shareWith = async (number) => {
    const p = await nui('myPosition')
    const ok = await sendTo(number, `📍 Position : ${p.street} (${p.x}, ${p.y})`)
    if (ok) { say('Position envoyée.'); setShare(false) }
  }
  return (
    <>
      <Header title="Plans" onBack={onBack} />
      <form className="form inline" onSubmit={save}>
        <input placeholder="Nom du lieu (ici)" value={name} maxLength={30} onChange={(e) => setName(e.target.value)} />
        <button className="primary">+</button>
      </form>
      <div className="form"><button className="secondary" onClick={() => setShare(!share)}>📍 Partager ma position par SMS</button></div>
      <div className="list">
        {share && contacts.map((c) => (
          <button key={c.id} className="row slim" onClick={() => shareWith(c.number)}>{c.name} <span className="muted">{c.number}</span></button>
        ))}
        {!share && places.length === 0 && <div className="empty">Enregistre ton garage, ta planque, ton QG… pour y retourner en un clic.</div>}
        {!share && places.map((p) => (
          <div key={p.id} className="row">
            <div className="row-main"><b>{p.name}</b></div>
            <div className="row-side">
              <button className="mini" onClick={() => nui('placeGo', { x: p.x, y: p.y }).then(() => say('GPS réglé.'))}>🧭</button>
              <button className="mini" onClick={() => nui('placeDelete', { id: p.id }).then((r) => setPlaces(r.message))}>🗑</button>
            </div>
          </div>
        ))}
      </div>
    </>
  )
}

const LEVEL = ['', '☀️ calme', '⚠️ tendu', '🔥 chaud']
export function City({ onBack }) {
  const [c, setC] = useState(isBrowser ? { weather: 'Ensoleillé', clock: '19:42', districts: [
    { label: 'Vespucci et Del Perro', level: 1, name: 'calme', pct: 5, standing: 'en plein essor' },
    { label: 'South Los Santos', level: 3, name: 'chaud', pct: 80, standing: 'à l’abandon' }] } : null)
  useEffect(() => { if (!isBrowser) nui('city').then(setC) }, [])
  if (!c) return (<><Header title="Ville" onBack={onBack} /><div className="empty">Chargement…</div></>)
  return (
    <>
      <Header title="Ville" onBack={onBack} />
      <div className="card-bank"><span>Los Santos · {c.clock}</span><b>{c.weather}</b><small>{c.storm ? '⛈️ Tempête en cours : routes de campagne fermées' : 'Bonne route !'}</small></div>
      <div className="list">
        {c.districts.map((d) => (
          <div key={d.label} className="row">
            <div className="row-main"><b>{d.label}</b><span className="muted">{LEVEL[d.level] || d.name}{d.standing ? ` · ${d.standing}` : ''}</span></div>
            <div className="meter"><i style={{ width: `${d.pct}%`, background: d.level >= 3 ? 'var(--red)' : d.level === 2 ? '#ffb347' : 'var(--green)' }} /></div>
          </div>
        ))}
      </div>
    </>
  )
}

export function Notes({ onBack, say }) {
  const [notes, setNotes] = useState(isBrowser ? [{ id: 1, text: 'Acheter une canne à pêche', time: 0 }] : [])
  const [edit, setEdit] = useState(null)
  useEffect(() => { if (!isBrowser) nui('notes').then((l) => setNotes(l || [])) }, [])
  const save = async () => {
    const r = await nui('noteSave', edit)
    if (!r.ok) return say(r.message, false)
    setNotes(r.message); setEdit(null)
  }
  if (edit) return (
    <>
      <Header title="Note" onBack={() => setEdit(null)} right={<button className="link" onClick={save}>OK</button>} />
      <div className="form"><textarea rows={14} maxLength={600} autoFocus value={edit.text} onChange={(e) => setEdit({ ...edit, text: e.target.value })} /></div>
    </>
  )
  return (
    <>
      <Header title="Notes" onBack={onBack} right={<button className="link" onClick={() => setEdit({ text: '' })}>Nouvelle</button>} />
      <div className="list">
        {notes.length === 0 && <div className="empty">Aucune note.</div>}
        {notes.map((n) => (
          <div key={n.id} className="row">
            <button className="row-main" onClick={() => setEdit(n)}><b>{(n.text.split('\n')[0] || 'Sans titre').slice(0, 40)}</b><span className="muted">{n.text.slice(0, 60)}</span></button>
            <button className="mini" onClick={() => nui('noteDelete', { id: n.id }).then((r) => setNotes(r.message))}>🗑</button>
          </div>
        ))}
      </div>
    </>
  )
}
