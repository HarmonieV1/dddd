import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { api, hasToken, setToken } from './api.js'
import LiveMap, { stateOf, STATE_LABEL } from '../shared/LiveMap.jsx'
import Sheet from './Sheet.jsx'
import Lives, { Replay } from './Lives.jsx'
import { Dialog, Sparkline, actionFr, ago, SEVERE } from './ui.jsx'

const VIEWS = [
  ['dash', 'Tableau de bord', '◧'], ['players', 'Joueurs', '☰'], ['map', 'Carte', '⌖'], ['lives', 'Lives', '◉'],
  ['tickets', 'Tickets', '✉'], ['bans', 'Sanctions', '⛔'], ['logs', 'Journal', '≡'],
]

function Login({ onIn }) {
  const [pseudo, setPseudo] = useState(() => { try { return localStorage.getItem('rlstaff.pseudo') || '' } catch { return '' } })
  const [password, setPassword] = useState('')
  const [remember, setRemember] = useState(true)
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const submit = async (e) => {
    e.preventDefault()
    setBusy(true); setErr('')
    const r = await api('login', { pseudo: pseudo.trim(), password })
    setBusy(false)
    if (!r.ok) return setErr(r.text || 'Connexion refusée.')
    try { localStorage.setItem('rlstaff.pseudo', pseudo.trim()) } catch { /* rien */ }
    setToken(r.token, remember)
    onIn(r.who)
  }
  return (
    <main className="login">
      <div className="login-glow" aria-hidden="true" />
      <form className="login-card" onSubmit={submit}>
        <div className="brand big">ROAD<span>LINE</span></div>
        <p className="kicker">Salle de contrôle du staff</p>
        <label className="field"><span>Pseudo staff (signe tes actions dans le journal)</span>
          <input id="pseudo" autoComplete="username" value={pseudo} onChange={(e) => setPseudo(e.target.value)} maxLength={20} required /></label>
        <label className="field"><span>Mot de passe</span>
          <input id="password" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></label>
        <label className="check"><input id="remember" type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} /> Rester connecté sur cet appareil</label>
        {err && <p className="errline">{err}</p>}
        <button className="btn pink wide" disabled={busy}>{busy ? 'Connexion…' : 'Entrer'}</button>
        <p className="muted small">5 essais ratés = accès bloqué 15 min depuis cette connexion. Chaque connexion est notée dans le journal staff.</p>
      </form>
    </main>
  )
}

function Kpi({ label, value, sub, tone, children }) {
  return (
    <div className={`kpi ${tone || ''}`}>
      <span className="kpi-label">{label}</span>
      <b className="kpi-value">{value}</b>
      {sub && <span className="kpi-sub">{sub}</span>}
      {children}
    </div>
  )
}

function PlayerRow({ p, on, onClick }) {
  const st = stateOf(p)
  return (
    <button className={on ? 'prow on' : 'prow'} onClick={onClick}>
      <span className={`avatar sm ${st}`}>{p.id}</span>
      <span className="prow-name"><b>{p.char || p.name}</b><small className="mono">{p.name}</small></span>
      <span className="prow-tags">
        {st !== 'civil' && <span className={`pill ${st}`}>{STATE_LABEL[st]}</span>}
        {p.job && p.job !== 'unemployed' && <span className={p.duty ? 'pill ok' : 'pill'}>{p.job}</span>}
        {p.replay && <span className="pill warn">⏪</span>}
        <span className={p.ping > 150 ? 'ping bad' : 'ping'}>{p.ping} ms</span>
      </span>
    </button>
  )
}

function TicketCard({ t, onAct, onOpen, onReplay, replay }) {
  return (
    <article className={t.status === 'open' ? 'ticket open' : 'ticket'}>
      <header><b>#{t.id}</b> {t.name}<span className="grow" /><span className="muted">il y a {ago(t.time)}{!t.online ? ' · déconnecté' : ''}</span></header>
      <p>{t.message}</p>
      <footer>
        {t.status === 'open' ? <button className="btn pink sm" onClick={() => onAct('ticket_claim', t.id)}>Prendre en charge</button> : <span className="pill">Pris par {t.claimedBy}</span>}
        <button className="btn ghost sm" disabled={!t.online} onClick={() => onOpen(t.src)}>Fiche</button>
        {replay && <button className="btn ghost sm" onClick={() => onReplay(t.src)}>⏪ Replay</button>}
        <span className="grow" />
        <button className="btn ghost sm" onClick={() => onAct('ticket_close', t.id)}>Clôturer</button>
      </footer>
    </article>
  )
}

function LogLine({ l }) {
  return (
    <div className={SEVERE[l.action] ? 'logl severe' : 'logl'}>
      <span className="muted mono">{ago(l.time)}</span>
      <span><b>{l.staff}</b> · <span className="act-name">{actionFr(l.action)}</span> {l.target ? <>→ {l.target}</> : null} {l.details ? <span className="muted">· {l.details}</span> : null}</span>
    </div>
  )
}

function Bans({ toast }) {
  const [q, setQ] = useState('')
  const [list, setList] = useState(null)
  const [confirm, setConfirm] = useState(null)
  const load = useCallback(async (s) => { const r = await api('bans', { q: s }); setList(r.ok ? r.data : []) }, [])
  useEffect(() => { load('') }, [load])
  return (
    <div className="pad view-narrow">
      <div className="toolbar"><input id="ban-q" className="search" placeholder="Rechercher un banni (nom ou licence)" value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && load(q)} />
        <button className="btn ghost" onClick={() => load(q)}>Rechercher</button></div>
      {list === null && <p className="muted">Chargement…</p>}
      {list && list.length === 0 && <p className="empty">Aucun bannissement actif.</p>}
      {list && list.map((b) => (
        <div key={b.license} className="ban">
          <div><b>{b.name}</b> <span className="pill red">{b.when}</span><div className="muted small">{b.reason} · par {b.staff}</div><div className="mono small muted">{b.license}</div></div>
          <button className="btn ghost sm" onClick={() => setConfirm(b)}>Débannir</button>
        </div>
      ))}
      {confirm && (
        <Dialog title={`Débannir ${confirm.name} ?`} onCancel={() => setConfirm(null)} confirmLabel="Débannir" onConfirm={async () => {
          const r = await api('act', { name: 'unban', text: confirm.license }); toast(r); setConfirm(null); load(q)
        }}><p className="muted">La levée du bannissement est publiée et journalisée à ton nom.</p></Dialog>
      )}
    </div>
  )
}

export default function App() {
  const [who, setWho] = useState(hasToken() ? '…' : null)
  const [ov, setOv] = useState(null)
  const [view, setView] = useState(() => { const h = location.hash.slice(1); return VIEWS.some(([v]) => v === h) ? h : 'dash' })
  const [sel, setSel] = useState(null)
  const [q, setQ] = useState('')
  const [filter, setFilter] = useState('all')
  const [toastMsg, setToastMsg] = useState(null)
  const [watching, setWatching] = useState([])
  const [replay, setReplay] = useState(null)
  const [announce, setAnnounce] = useState('')
  const timer = useRef(null)

  const toast = useCallback((r) => {
    if (!r || !r.text) return
    setToastMsg({ ok: r.ok, text: r.text })
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setToastMsg(null), 4000)
  }, [])
  const logout = useCallback(async () => { await api('logout'); setToken(''); setWho(null); setOv(null) }, [])
  const refresh = useCallback(async () => {
    const r = await api('overview')
    if (r.ok) { setOv(r.data); setWho(r.data.who) } else if (r.auth === false) { setWho(null); setOv(null) }
  }, [])
  useEffect(() => {
    if (!who) return undefined
    refresh()
    const t = setInterval(() => { if (!document.hidden) refresh() }, 5000)
    return () => clearInterval(t)
  }, [who, refresh])
  useEffect(() => { try { history.replaceState(null, '', `#${view}`) } catch { /* rien */ } }, [view])
  useEffect(() => { if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {}) }, [])

  const players = useMemo(() => {
    if (!ov) return []
    const s = q.trim().toLowerCase()
    return ov.players.filter((p) => {
      if (s && !`${p.id} ${p.name} ${p.char} ${p.job || ''}`.toLowerCase().includes(s)) return false
      if (filter === 'wanted') return p.heat > 0
      if (filter === 'jail') return p.jailed || p.frozen
      if (filter === 'staff') return p.staff
      if (filter === 'duty') return p.duty
      return true
    })
  }, [ov, q, filter])

  if (!who) return <Login onIn={(w) => setWho(w)} />
  if (!ov) return <main className="loading"><div className="brand big">ROAD<span>LINE</span></div><p className="muted">Connexion à la ville…</p></main>

  const act = async (name, extra) => { const r = await api('act', { name, extra }); toast(r); refresh() }
  const open = (id) => { setSel(id); if (view === 'dash' || view === 'tickets' || view === 'lives') setView('players') }
  const watch = (id) => { setWatching((w) => (w.includes(id) ? w : [...w.slice(-3), id])); setView('lives') }
  const S = ov.server
  const wanted = ov.players.filter((p) => p.heat > 0).length
  const held = ov.players.filter((p) => p.jailed || p.frozen).length
  const openT = ov.tickets.filter((t) => t.status === 'open').length
  const severe24 = ov.logs.filter((l) => SEVERE[l.action] && Date.now() / 1000 - l.time < 86400).length
  const sheet = sel != null && <Sheet id={sel} ov={ov} onClose={() => setSel(null)} toast={toast} onWatch={watch} onReplay={setReplay} refresh={refresh} />

  return (
    <div className="shell">
      <aside className="side">
        <div className="brand">ROAD<span>LINE</span><small>STAFF</small></div>
        <nav>
          {VIEWS.map(([v, label, icon]) => (
            <button key={v} className={view === v ? 'nav on' : 'nav'} onClick={() => setView(v)} aria-current={view === v ? 'page' : undefined}>
              <i aria-hidden="true">{icon}</i><span>{label}</span>
              {v === 'tickets' && openT > 0 && <em>{openT}</em>}
              {v === 'lives' && watching.length > 0 && <em className="cy">{watching.length}</em>}
            </button>
          ))}
        </nav>
        <div className="side-foot">
          <div className="me"><span className="dot live" />{who}</div>
          <button className="btn ghost sm" onClick={logout}>Se déconnecter</button>
        </div>
      </aside>

      <div className="main">
        <header className="top">
          <h1>{VIEWS.find(([v]) => v === view)[1]}</h1>
          <div className="status">
            <span className="stat"><span className="dot live" />En ligne · {S.version}</span>
            <span className="stat mono">{S.players}/{S.max}</span>
            {S.weather && <span className="stat">{S.weather}</span>}
            {ov.txadmin && <a className="stat link" href={ov.txadmin} target="_blank" rel="noreferrer">txAdmin ↗</a>}
          </div>
        </header>

        {view === 'dash' && (
          <div className="dash">
            <div className="kpis">
              <Kpi label="En ville" value={<>{S.players}<small>/{S.max}</small></>} sub="dernières 24 h"><Sparkline points={ov.history} /></Kpi>
              <Kpi label="Staff en service" value={S.staffOnDuty} sub={S.staffOnDuty ? 'en jeu, mode staff' : 'personne en jeu'} tone={S.staffOnDuty ? 'cyan' : 'warn'} />
              <Kpi label="Tickets" value={ov.tickets.length} sub={openT ? `${openT} en attente` : 'tous pris en charge'} tone={openT ? 'pink' : ''} />
              <Kpi label="Recherchés" value={wanted} sub="police IA ou joueurs" tone={wanted ? 'orange' : ''} />
              <Kpi label="Isolés / gelés" value={held} sub={`${severe24} sanction(s) récentes`} tone={held ? 'red' : ''} />
            </div>
            <div className="dash-grid">
              <section className="card map-card">
                <div className="card-head"><h4>Los Santos en direct</h4><button className="btn ghost sm" onClick={() => setView('map')}>Plein écran</button></div>
                <LiveMap players={ov.players} selected={sel} onSelect={(id) => { setSel(id); setView('map') }} compact />
              </section>
              <div className="dash-col">
                <section className="card">
                  <div className="card-head"><h4>Tickets</h4><button className="btn ghost sm" onClick={() => setView('tickets')}>Tout voir</button></div>
                  {ov.tickets.length === 0 && <p className="empty sm">Aucun ticket ouvert.</p>}
                  {ov.tickets.slice(0, 3).map((t) => <TicketCard key={t.id} t={t} onAct={act} onOpen={open} onReplay={setReplay} replay={ov.players.find((p) => p.id === t.src)?.replay} />)}
                </section>
                <section className="card">
                  <div className="card-head"><h4>Journal staff</h4><button className="btn ghost sm" onClick={() => setView('logs')}>Tout voir</button></div>
                  {ov.logs.slice(0, 7).map((l, i) => <LogLine key={i} l={l} />)}
                  {ov.logs.length === 0 && <p className="empty sm">Rien pour l'instant.</p>}
                </section>
                <form className="card" onSubmit={async (e) => {
                  e.preventDefault()
                  if (!announce.trim()) return
                  const r = await api('act', { name: 'announce', text: announce }); toast(r); if (r.ok) setAnnounce('')
                }}>
                  <h4>Annonce à toute la ville</h4>
                  <div className="toolbar"><input id="announce" maxLength={200} value={announce} onChange={(e) => setAnnounce(e.target.value)} placeholder="Redémarrage dans 10 min…" />
                    <button className="btn pink" disabled={!announce.trim()}>Envoyer</button></div>
                </form>
              </div>
            </div>
          </div>
        )}

        {view === 'players' && (
          <div className={sel != null ? 'split with-sheet' : 'split'}>
            <div className="list-pane">
              <div className="toolbar"><input id="q" className="search" placeholder="Rechercher : n°, pseudo, personnage, métier" value={q} onChange={(e) => setQ(e.target.value)} /></div>
              <div className="seg filters">
                {[['all', 'Tous'], ['wanted', 'Recherchés'], ['jail', 'Isolés / gelés'], ['staff', 'Staff'], ['duty', 'En service']].map(([f, l]) => (
                  <button key={f} className={filter === f ? 'on' : ''} onClick={() => setFilter(f)}>{l}</button>
                ))}
              </div>
              <div className="plist">
                {players.map((p) => <PlayerRow key={p.id} p={p} on={sel === p.id} onClick={() => setSel(p.id)} />)}
                {players.length === 0 && <p className="empty">{ov.players.length ? 'Personne ne correspond.' : 'Personne en ville pour l\'instant.'}</p>}
              </div>
            </div>
            {sheet}
          </div>
        )}

        {view === 'map' && (
          <div className={sel != null ? 'split map-split with-sheet' : 'split map-split'}>
            <div className="map-pane"><LiveMap players={ov.players} selected={sel} onSelect={setSel} compact /></div>
            {sheet || (
              <aside className="sheet light">
                <h4>Sur la carte <span className="muted">{ov.players.length}</span></h4>
                <div className="plist">{ov.players.map((p) => <PlayerRow key={p.id} p={p} on={false} onClick={() => setSel(p.id)} />)}</div>
              </aside>
            )}
          </div>
        )}

        {view === 'lives' && <Lives ov={ov} watching={watching} setWatching={setWatching} onOpen={(id) => { setSel(id); setView('players') }} onReplay={setReplay} />}

        {view === 'tickets' && (
          <div className="pad view-narrow">
            {ov.tickets.length === 0 && <p className="empty">Aucun ticket ouvert. La ville est calme.</p>}
            {ov.tickets.map((t) => <TicketCard key={t.id} t={t} onAct={act} onOpen={open} onReplay={setReplay} replay={ov.players.find((p) => p.id === t.src)?.replay} />)}
          </div>
        )}

        {view === 'bans' && <Bans toast={toast} />}

        {view === 'logs' && (
          <div className="pad view-narrow">
            {ov.logs.map((l, i) => <LogLine key={i} l={l} />)}
            {ov.logs.length === 0 && <p className="empty">Journal vide depuis le dernier redémarrage.</p>}
          </div>
        )}
      </div>

      <nav className="tabbar">
        {VIEWS.filter(([v]) => v !== 'logs').map(([v, label, icon]) => (
          <button key={v} className={view === v ? 'on' : ''} onClick={() => setView(v)}><i aria-hidden="true">{icon}</i><span>{label.split(' ')[0]}</span>
            {v === 'tickets' && openT > 0 && <em>{openT}</em>}</button>
        ))}
      </nav>
      {replay != null && <Replay id={replay} name={(ov.players.find((p) => p.id === replay) || {}).char || `#${replay}`} onClose={() => setReplay(null)} />}
      {toastMsg && <div className={toastMsg.ok ? 'toast ok' : 'toast ko'} role="status">{toastMsg.text}</div>}
    </div>
  )
}
