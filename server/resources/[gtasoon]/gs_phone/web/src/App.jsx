import { useEffect, useRef, useState } from 'react'
import { nui, isBrowser, DEMO } from './nui.js'
import Vibe from './Vibe.jsx'
import Gigs from './Gigs.jsx'

const APPS = [
  { id: 'messages', label: 'Messages', icon: '💬', color: '#28e0ff' },
  { id: 'contacts', label: 'Contacts', icon: '👥', color: '#9b6bff' },
  { id: 'dialer', label: 'Appel', icon: '📞', color: '#39ff9a' },
  { id: 'vibe', label: 'Vibe', icon: '✦', color: '#ff2e88' },
  { id: 'bank', label: 'Banque', icon: '💳', color: '#ffd23f' },
  { id: 'bills', label: 'Factures', icon: '🧾', color: '#ff8a3d' },
  { id: 'job', label: 'Emploi', icon: '💼', color: '#5ab0ff' },
  { id: 'gigs', label: 'Boulots', icon: '🛵', color: '#39ff9a' },
  { id: 'carnet', label: 'Carnet', icon: '🗺️', color: '#ffb347', external: true },
  { id: 'journal', label: 'Weazel', icon: '📰', color: '#e63946', external: true },
  { id: 'orders', label: 'Commandes', icon: '🔧', color: '#8ecae6', external: true },
  { id: 'unknown', label: 'Inconnu', icon: '🕶️', color: '#4a4458', external: true },
  { id: 'emergency', label: 'Urgences', icon: '🚨', color: '#ff4d6d' },
  { id: 'settings', label: 'Réglages', icon: '⚙️', color: '#9b8bb8' },
]

const fmtMoney = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`
function timeAgo(t) {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
  if (s < 60) return 'maintenant'
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  return `${Math.floor(s / 86400)} j`
}

function Header({ title, onBack, right }) {
  return (
    <div className="app-header">
      <button className="back" onClick={onBack}>‹</button>
      <h2>{title}</h2>
      <div className="right">{right}</div>
    </div>
  )
}

export default function App() {
  const [visible, setVisible] = useState(isBrowser)
  const [hidden, setHidden] = useState(false) // masqué le temps d'une photo
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const [screen, setScreen] = useState('home')
  const [peer, setPeer] = useState(null)
  const [thread, setThread] = useState([])
  const [draft, setDraft] = useState('')
  const [call, setCall] = useState(null) // { id, number, state: 'incoming'|'outgoing'|'active' }
  const [toast, setToast] = useState(null)
  const [bills, setBills] = useState([])
  const [form, setForm] = useState({})
  const threadRef = useRef(null)
  const peerRef = useRef(null)
  peerRef.current = peer

  const say = (text, ok = true) => { setToast({ text, ok }); setTimeout(() => setToast(null), 3000) }
  const nameOf = (number) => data?.contacts.find((c) => c.number === number)?.name || number

  useEffect(() => {
    const onMessage = ({ data: msg }) => {
      if (msg.action === 'open') { setData(msg.data); setVisible(true) }
      else if (msg.action === 'close') setVisible(false)
      else if (msg.action === 'hide') setHidden(true)
      else if (msg.action === 'show') setHidden(false)
      else if (msg.action === 'clock') setData((d) => d && { ...d, clock: msg.clock })
      else if (msg.action === 'message') {
        const m = msg.message
        if (peerRef.current === m.from) setThread((t) => [{ id: Date.now(), content: m.content, time: m.time, mine: false }, ...t])
        setData((d) => d && {
          ...d,
          conversations: [{ peer: m.from, last: m.content, time: m.time, mine: false, unread: peerRef.current === m.from ? 0 : 1 },
            ...d.conversations.filter((c) => c.peer !== m.from)],
        })
      }
      else if (msg.action === 'incoming') setCall({ id: msg.call.id, number: msg.call.number, state: 'incoming' })
      else if (msg.action === 'callStarted') setCall((c) => c && { ...c, state: 'active' })
      else if (msg.action === 'callEnded') { setCall(null); if (msg.reason) say(msg.reason, false) }
    }
    const onKey = (e) => { if (e.key === 'Escape') nui('close') }
    window.addEventListener('message', onMessage)
    window.addEventListener('keydown', onKey)
    return () => { window.removeEventListener('message', onMessage); window.removeEventListener('keydown', onKey) }
  }, [])

  if (!visible || !data) return null

  const openApp = async (id) => {
    if (id === 'jobs' || APPS.find((a) => a.id === id)?.external) return nui('openApp', { app: id })
    if (id === 'bills') setBills(await nui('bills'))
    setForm({})
    setScreen(id)
  }

  const openThread = async (number) => {
    setPeer(number)
    setScreen('thread')
    setThread(await nui('thread', { peer: number }))
    setData({ ...data, conversations: data.conversations.map((c) => (c.peer === number ? { ...c, unread: 0 } : c)) })
  }

  const send = async (e) => {
    e.preventDefault()
    if (!draft.trim()) return
    const res = await nui('send', { peer, text: draft })
    if (!res.ok) return say(res.message, false)
    setThread([res.message, ...thread])
    setDraft('')
    setData({ ...data, conversations: [{ peer, last: res.message.content, time: res.message.time, mine: true, unread: 0 },
      ...data.conversations.filter((c) => c.peer !== peer)] })
  }

  const startCall = async (number) => {
    const res = await nui('call', { number })
    if (!res.ok) return say(res.message, false)
    setCall({ id: res.message, number, state: 'outgoing' })
  }
  const answer = async () => { const r = await nui('answer', { id: call.id }); if (r.ok) setCall({ ...call, state: 'active' }) }
  const hangup = () => { nui('hangup'); setCall(null) }

  const submit = async (action, body, after) => {
    const res = await nui(action, body)
    say(typeof res.message === 'string' ? res.message : res.ok ? 'Fait.' : 'Refusé.', res.ok)
    if (res.ok) after?.(res)
  }

  const unread = data.conversations.reduce((n, c) => n + (c.unread || 0), 0)
  const home = () => { setScreen('home'); setPeer(null) }

  let content
  if (call) {
    content = (
      <div className="call-screen">
        <div className="avatar big">{nameOf(call.number).slice(0, 1)}</div>
        <h2>{nameOf(call.number)}</h2>
        <div className="muted">{call.state === 'incoming' ? 'Appel entrant…' : call.state === 'outgoing' ? 'Appel en cours…' : 'En ligne'}</div>
        <div className="call-actions">
          {call.state === 'incoming' && <button className="round green" onClick={answer}>📞</button>}
          <button className="round red" onClick={hangup}>✕</button>
        </div>
      </div>
    )
  } else if (screen === 'home') {
    content = (
      <div className="home">
        <div className="home-clock">{data.clock}</div>
        <div className="home-sub">Los Santos · {data.number}</div>
        <div className="grid">
          {APPS.map((a) => (
            <button key={a.id} className="app" onClick={() => openApp(a.id)}>
              <span className="icon" style={{ background: `linear-gradient(135deg, ${a.color}, #1a0f2e)` }}>{a.icon}</span>
              {a.id === 'messages' && unread > 0 && <span className="badge">{unread}</span>}
              <span className="label">{a.label}</span>
            </button>
          ))}
        </div>
      </div>
    )
  } else if (screen === 'gigs') {
    content = <Gigs onBack={home} say={say} />
  } else if (screen === 'vibe') {
    content = <Vibe onBack={home} />
  } else if (screen === 'messages') {
    content = (
      <>
        <Header title="Messages" onBack={home} right={<button className="link" onClick={() => setScreen('newMessage')}>Nouveau</button>} />
        <div className="list">
          {data.conversations.length === 0 && <div className="empty">Aucun message.</div>}
          {data.conversations.map((c) => (
            <button key={c.peer} className="row" onClick={() => openThread(c.peer)}>
              <div className="avatar">{nameOf(c.peer).slice(0, 1)}</div>
              <div className="row-main"><b>{nameOf(c.peer)}</b><span className="muted">{c.mine && 'Toi : '}{c.last}</span></div>
              <div className="row-side"><span className="muted small">{timeAgo(c.time)}</span>{c.unread > 0 && <span className="dot">{c.unread}</span>}</div>
            </button>
          ))}
        </div>
      </>
    )
  } else if (screen === 'newMessage') {
    content = (
      <>
        <Header title="Nouveau message" onBack={() => setScreen('messages')} />
        <form className="form" onSubmit={(e) => { e.preventDefault(); if (/^\d{3}-\d{4}$/.test(form.number || '')) openThread(form.number) }}>
          <input autoFocus placeholder="555-1234" value={form.number || ''} onChange={(e) => setForm({ number: e.target.value })} />
          {data.contacts.map((c) => <button type="button" key={c.id} className="row slim" onClick={() => openThread(c.number)}>{c.name} <span className="muted">{c.number}</span></button>)}
          <button className="primary">Écrire</button>
        </form>
      </>
    )
  } else if (screen === 'thread') {
    content = (
      <>
        <Header title={nameOf(peer)} onBack={() => setScreen('messages')} right={<button className="link" onClick={() => startCall(peer)}>📞</button>} />
        <div className="thread" ref={threadRef}>
          {thread.map((m) => <div key={m.id} className={m.mine ? 'bubble mine' : 'bubble'}>{m.content}<span>{timeAgo(m.time)}</span></div>)}
        </div>
        <form className="composer" onSubmit={send}>
          <input autoFocus maxLength={data.maxLength} placeholder="Message" value={draft} onChange={(e) => setDraft(e.target.value)} />
          <button className="send" disabled={!draft.trim()}>➤</button>
        </form>
      </>
    )
  } else if (screen === 'contacts') {
    content = (
      <>
        <Header title="Contacts" onBack={home} />
        <form className="form inline" onSubmit={(e) => { e.preventDefault(); submit('addContact', form, (r) => { setData({ ...data, contacts: r.message }); setForm({}) }) }}>
          <input placeholder="Nom" value={form.name || ''} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input placeholder="555-1234" value={form.number || ''} onChange={(e) => setForm({ ...form, number: e.target.value })} />
          <button className="primary">+</button>
        </form>
        <div className="list">
          {data.contacts.map((c) => (
            <div key={c.id} className="row">
              <div className="avatar">{c.name.slice(0, 1)}</div>
              <div className="row-main"><b>{c.name}</b><span className="muted">{c.number}</span></div>
              <div className="row-side">
                <button className="mini" onClick={() => openThread(c.number)}>💬</button>
                <button className="mini" onClick={() => startCall(c.number)}>📞</button>
                <button className="mini" onClick={() => submit('deleteContact', { id: c.id }, (r) => setData({ ...data, contacts: r.message }))}>🗑</button>
              </div>
            </div>
          ))}
        </div>
      </>
    )
  } else if (screen === 'dialer') {
    const digits = form.number || ''
    const press = (d) => { const raw = (digits.replace('-', '') + d).slice(0, 7); setForm({ number: raw.length > 3 ? `${raw.slice(0, 3)}-${raw.slice(3)}` : raw }) }
    content = (
      <>
        <Header title="Appel" onBack={home} />
        <div className="dial-display">{digits || ' '}</div>
        <div className="keypad">
          {['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'].map((k, i) => (
            <button key={i} className="key" disabled={!k} onClick={() => (k === '⌫' ? setForm({ number: digits.slice(0, -1).replace(/-$/, '') }) : press(k))}>{k}</button>
          ))}
        </div>
        <button className="round green center" disabled={!/^\d{3}-\d{4}$/.test(digits)} onClick={() => startCall(digits)}>📞</button>
      </>
    )
  } else if (screen === 'bank') {
    content = (
      <>
        <Header title="Banque" onBack={home} />
        <div className="card-bank"><span>Compte courant</span><b>{fmtMoney(data.money.bank)}</b><small>Liquide : {fmtMoney(data.money.cash)}</small></div>
        <form className="form" onSubmit={(e) => { e.preventDefault(); submit('transfer', { number: form.number, amount: Number(form.amount) }, () => {
          setData({ ...data, money: { ...data.money, bank: data.money.bank - Number(form.amount) } }); setForm({}) }) }}>
          <h3>Virement</h3>
          <input placeholder="Numéro du destinataire (555-1234)" value={form.number || ''} onChange={(e) => setForm({ ...form, number: e.target.value })} />
          <input type="number" placeholder="Montant" value={form.amount || ''} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
          <button className="primary" disabled={!form.number || !form.amount}>Envoyer</button>
        </form>
      </>
    )
  } else if (screen === 'bills') {
    content = (
      <>
        <Header title="Factures" onBack={home} />
        <div className="list">
          {bills.length === 0 && <div className="empty">Aucune facture. 👌</div>}
          {bills.map((b) => (
            <div key={b.id} className="row">
              <div className="row-main"><b>{fmtMoney(b.amount)} · {b.job}</b><span className="muted">{b.reason} · {b.issuer_name} · {b.date}</span></div>
              <button className="mini pay" onClick={() => submit('payBill', { id: b.id }, () => setBills(bills.filter((x) => x.id !== b.id)))}>Payer</button>
            </div>
          ))}
        </div>
      </>
    )
  } else if (screen === 'job') {
    content = (
      <>
        <Header title="Emploi" onBack={home} />
        <div className="card-bank"><span>Poste actuel</span><b>{data.job?.label || 'Sans emploi'}</b><small>{data.job?.onduty ? '● En service' : '○ Hors service'}</small></div>
        <div className="form">
          <button className="primary" onClick={() => { nui('duty'); setData({ ...data, job: { ...data.job, onduty: !data.job?.onduty } }) }}>Prendre / quitter le service</button>
          <button className="secondary" onClick={() => nui('openApp', { app: 'jobs' })}>Mes emplois (F6)</button>
        </div>
      </>
    )
  } else if (screen === 'emergency') {
    content = (
      <>
        <Header title="Urgences" onBack={home} />
        <form className="form" onSubmit={(e) => { e.preventDefault(); submit('emergency', { service: form.service, text: form.text }, () => setForm({})) }}>
          <div className="chips">
            {data.emergency.map((s) => (
              <button type="button" key={s.id} className={form.service === s.id ? 'chip on' : 'chip'} onClick={() => setForm({ ...form, service: s.id })}>{s.label}</button>
            ))}
          </div>
          <textarea rows={4} maxLength={200} placeholder="Décris la situation (ta position est envoyée)" value={form.text || ''} onChange={(e) => setForm({ ...form, text: e.target.value })} />
          <button className="danger" disabled={!form.service || !form.text?.trim()}>Appeler</button>
        </form>
      </>
    )
  } else if (screen === 'settings') {
    content = (
      <>
        <Header title="Réglages" onBack={home} />
        <div className="form">
          <div className="setting"><span>Mon numéro</span><b>{data.number}</b></div>
          <label className="setting">
            <span>Filtre Vice (couleurs sunset)</span>
            <input type="checkbox" checked={!!data.vice} onChange={(e) => { nui('viceFilter', { on: e.target.checked }); setData({ ...data, vice: e.target.checked }) }} />
          </label>
          <label className="setting">
            <span>Mode silencieux</span>
            <input type="checkbox" checked={data.silent} onChange={(e) => { nui('silent', { silent: e.target.checked }); setData({ ...data, silent: e.target.checked }) }} />
          </label>
        </div>
      </>
    )
  }

  return (
    <div className="phone" style={hidden ? { visibility: 'hidden' } : undefined}>
      <div className="notch" />
      <div className="status"><span>{data.clock}</span><span>5G ▮▮▮</span></div>
      <div className="screen">{content}</div>
      {toast && <div className={toast.ok ? 'toast ok' : 'toast ko'}>{toast.text}</div>}
      <button className="home-bar" onClick={home} aria-label="Accueil" />
    </div>
  )
}
