import { useEffect, useMemo, useState } from 'react'
import { nui, isBrowser } from './nui.js'
import { DEMO, DEMO_DOSSIER } from './demo.js'

// Actions du panel : l'affichage dépend du niveau, mais le SERVEUR revérifie tout.
// level : 1 helper, 2 modo, 3 admin. fields : formulaire demandé avant envoi.
const ACTIONS = [
  { name: 'goto', label: 'Aller à', level: 1 },
  { name: 'bring', label: 'Amener', level: 2 },
  { name: 'heal', label: 'Soigner', level: 2 },
  { name: 'revive', label: 'Réanimer', level: 2 },
  { name: 'fixveh', label: 'Réparer véhicule', level: 2 },
  { name: 'freeze', label: 'Figer / libérer', level: 2 },
  { name: 'clearheat', label: 'Effacer recherche', level: 2 },
  { name: 'note', label: 'Note staff', level: 2, fields: [{ key: 'text', label: 'Note (visible staff uniquement)', type: 'textarea' }] },
  { name: 'warn', label: 'Avertir', level: 2, danger: true, fields: [{ key: 'reason', label: 'Motif (publié)' }] },
  { name: 'jail', label: 'Isoler', level: 2, danger: true, fields: [{ key: 'minutes', label: 'Minutes', type: 'number' }, { key: 'reason', label: 'Motif (publié)' }] },
  { name: 'unjail', label: 'Libérer isolement', level: 2 },
  { name: 'kick', label: 'Expulser', level: 2, danger: true, fields: [{ key: 'reason', label: 'Motif (publié)' }] },
  { name: 'givemoney', label: 'Donner argent', level: 4, fields: [{ key: 'account', label: 'Compte', type: 'select', options: ['cash', 'bank'] }, { key: 'amount', label: 'Montant', type: 'number' }, { key: 'reason', label: 'Motif (journal)' }] },
  { name: 'removemoney', label: 'Retirer argent', level: 4, danger: true, fields: [{ key: 'account', label: 'Compte', type: 'select', options: ['cash', 'bank'] }, { key: 'amount', label: 'Montant', type: 'number' }, { key: 'reason', label: 'Motif (journal)' }] },
  { name: 'giveitem', label: 'Donner item', level: 4, fields: [{ key: 'item', label: 'Nom de l’item' }, { key: 'amount', label: 'Quantité', type: 'number' }, { key: 'reason', label: 'Motif (journal)' }] },
  { name: 'addjob', label: 'Ajouter contrat', level: 3, fields: [{ key: 'job', label: 'Job', type: 'select', options: ['police', 'ambulance', 'mechanic', 'taxi', 'delivery', 'garbage'] }, { key: 'grade', label: 'Grade', type: 'number' }] },
  { name: 'removejob', label: 'Retirer contrat', level: 3, danger: true, fields: [{ key: 'job', label: 'Job', type: 'select', options: ['police', 'ambulance', 'mechanic', 'taxi', 'delivery', 'garbage'] }] },
]

const TABS = [['players', 'Joueurs'], ['tickets', 'Tickets'], ['server', 'Serveur'], ['logs', 'Journal']]

function ago(t) {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)} min`
  return `${Math.floor(s / 3600)} h`
}
const duration = (s) => (s >= 3600 ? `${Math.floor(s / 3600)} h ${Math.floor((s % 3600) / 60)} min` : `${Math.floor(s / 60)} min`)

function ActionForm({ action, onCancel, onSubmit, maxJail }) {
  const [values, setValues] = useState(() => Object.fromEntries((action.fields || []).map((f) => [f.key, f.options ? f.options[0] : ''])))
  const set = (k, v) => setValues({ ...values, [k]: v })
  return (
    <div className="modal-backdrop" onClick={onCancel}>
      <form className="modal" onClick={(e) => e.stopPropagation()} onSubmit={(e) => { e.preventDefault(); onSubmit(values) }}>
        <h3>{action.label}</h3>
        {action.fields.map((f) => (
          <label key={f.key}>
            <span>{f.label}{f.key === 'minutes' ? ` (max ${maxJail})` : ''}</span>
            {f.type === 'select' ? (
              <select value={values[f.key]} onChange={(e) => set(f.key, e.target.value)}>
                {f.options.map((o) => <option key={o}>{o}</option>)}
              </select>
            ) : f.type === 'textarea' ? (
              <textarea rows={3} value={values[f.key]} onChange={(e) => set(f.key, e.target.value)} />
            ) : (
              <input autoFocus={f === action.fields[0]} type={f.type === 'number' ? 'number' : 'text'} value={values[f.key]}
                onChange={(e) => set(f.key, e.target.value)} />
            )}
          </label>
        ))}
        <div className="modal-actions">
          <button type="button" className="ghost" onClick={onCancel}>Annuler</button>
          <button className={action.danger ? 'danger' : 'primary'}>Confirmer</button>
        </div>
      </form>
    </div>
  )
}

function Dossier({ d, level, maxJail, onAction }) {
  const [form, setForm] = useState(null)
  const run = (a) => (a.fields ? setForm(a) : onAction(a.name, d.id, {}))
  return (
    <div className="dossier">
      <div className="dossier-head">
        <div>
          <h2>{d.name || d.account}</h2>
          <div className="muted">#{d.id} · {d.account} · {d.ping} ms · session {duration(d.session)}</div>
        </div>
        {d.level > 0 && <span className="badge staff">Staff niv. {d.level}</span>}
      </div>

      <div className="facts">
        <div><span>Job actif</span>{d.job ? `${d.job.label || d.job.name} ${d.job.onduty ? '· en service' : ''}` : '—'}</div>
        <div><span>Contrats</span>{Object.entries(d.contracts || {}).map(([j, g]) => `${j} (${g})`).join(', ') || 'aucun'}</div>
        <div><span>Recherche</span>{d.heat > 0 ? `${'★'.repeat(Math.ceil(d.heat / 20))} (${d.heat})` : 'aucune'}</div>
        <div><span>Duo</span>{d.duo ? `${d.duo} · niv. ${d.duoLevel}` : '—'}</div>
        <div><span>Vibe</span>{d.handle ? `@${d.handle}` : '—'}</div>
        <div><span>Gang</span>{d.gang || '—'}</div>
        {d.progress && <div><span>Progression</span>{`Niv. ${d.progress.level} · ${d.progress.title} · série ${d.progress.streak} j`}</div>}
        {d.progress && <div><span>Badges</span>{d.progress.badges.length ? d.progress.badges.join(', ') : 'aucun'}</div>}
        <div><span>État</span>{[d.frozen && 'figé', d.jailedFor > 0 && `isolé ${duration(d.jailedFor)}`].filter(Boolean).join(', ') || 'normal'}</div>
        {d.money && <div><span>Argent</span>{d.money.cash.toLocaleString('fr-FR')} $ · banque {d.money.bank.toLocaleString('fr-FR')} $</div>}
        {d.citizenid && <div><span>CitizenID</span>{d.citizenid}</div>}
        {d.license && <div><span>Licence</span><code>{d.license}</code></div>}
      </div>

      <div className="action-grid">
        {ACTIONS.filter((a) => a.level <= level).map((a) => (
          <button key={a.name} className={a.danger ? 'act danger' : 'act'} onClick={() => run(a)}>{a.label}</button>
        ))}
      </div>

      {d.notes && (
        <div className="notes">
          <h4>Historique staff</h4>
          {d.notes.length === 0 && <div className="muted">Rien à signaler.</div>}
          {d.notes.map((n, i) => (
            <div key={i} className={`note ${n.kind}`}>
              <b>{n.kind === 'warn' ? 'Avertissement' : 'Note'}</b> · {n.text}
              <div className="muted small">{n.staff} · il y a {ago(n.time)}</div>
            </div>
          ))}
        </div>
      )}
      {form && <ActionForm action={form} maxJail={maxJail} onCancel={() => setForm(null)} onSubmit={(v) => { setForm(null); onAction(form.name, d.id, v) }} />}
    </div>
  )
}

export default function App() {
  const [visible, setVisible] = useState(isBrowser)
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const [tab, setTab] = useState('players')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState(null)
  const [dossier, setDossier] = useState(null)
  const [toast, setToast] = useState(null)
  const [announce, setAnnounce] = useState('')

  const refresh = async () => { const d = await nui('refresh'); if (d) setData(d) }
  const loadDossier = async (id) => { setSelected(id); const d = await nui('dossier', { id }); setDossier(d || null) }

  useEffect(() => {
    const onMessage = ({ data: msg }) => {
      if (msg.action === 'open') { setData(msg.data); setVisible(true) }
      else if (msg.action === 'close') setVisible(false)
      else if (msg.action === 'ticketsChanged') refresh()
    }
    const onKey = (e) => { if (e.key === 'Escape') nui('close') }
    window.addEventListener('message', onMessage)
    window.addEventListener('keydown', onKey)
    if (isBrowser) setDossier(DEMO_DOSSIER)
    return () => { window.removeEventListener('message', onMessage); window.removeEventListener('keydown', onKey) }
  }, [])

  const players = useMemo(() => {
    if (!data) return []
    const q = search.toLowerCase()
    return data.players.filter((p) => !q || `${p.id} ${p.name} ${p.account} ${p.job || ''}`.toLowerCase().includes(q))
  }, [data, search])

  if (!visible || !data) return null

  const act = async (name, target, values = {}) => {
    const res = await nui('action', { name, target, data: values })
    setToast({ ok: res.ok, text: res.message || (res.ok ? 'Fait.' : 'Refusé.') })
    setTimeout(() => setToast(null), 3500)
    if (res.ok) { refresh(); if (target && selected === target && name !== 'kick') loadDossier(target) }
  }

  const toggleDuty = async () => { const r = await nui('toggleDuty'); if (r.ok) setData({ ...data, onDuty: r.onDuty }) }

  return (
    <div className="panel">
      <header>
        <div className="brand">GS <span>STAFF</span></div>
        <nav>
          {TABS.map(([id, name]) => (
            <button key={id} className={tab === id ? 'tab on' : 'tab'} onClick={() => setTab(id)}>
              {name}{id === 'tickets' && data.tickets.length > 0 && <span className="count">{data.tickets.length}</span>}
            </button>
          ))}
        </nav>
        <div className="me">
          <span className="badge">{data.levelName}</span>
          <button className={data.onDuty ? 'duty on' : 'duty'} onClick={toggleDuty}>{data.onDuty ? 'En service' : 'Hors service'}</button>
          <button className="ghost" onClick={() => nui('close')}>✕</button>
        </div>
      </header>

      {tab === 'players' && (
        <div className="split">
          <aside>
            <input className="search" placeholder="Rechercher (id, nom, job…)" value={search} onChange={(e) => setSearch(e.target.value)} />
            <div className="list">
              {players.map((p) => (
                <button key={p.id} className={selected === p.id ? 'row on' : 'row'} onClick={() => loadDossier(p.id)}>
                  <span className="pid">{p.id}</span>
                  <span className="pname">{p.name}<small>{p.account}</small></span>
                  <span className="tags">
                    {p.staff && <i className="t staff">staff</i>}
                    {p.job && p.job !== 'unemployed' && <i className={p.duty ? 't job on' : 't job'}>{p.job}</i>}
                    {p.heat > 0 && <i className="t heat">★{Math.ceil(p.heat / 20)}</i>}
                    {p.jailed && <i className="t jail">isolé</i>}
                  </span>
                </button>
              ))}
            </div>
          </aside>
          <section>{dossier ? <Dossier d={dossier} level={data.level} maxJail={data.maxJail} onAction={act} /> : <div className="empty">Sélectionne un joueur.</div>}</section>
        </div>
      )}

      {tab === 'tickets' && (
        <div className="pad">
          {!data.onDuty && <div className="hint">Passe en service pour être notifié des nouveaux tickets.</div>}
          {data.tickets.length === 0 && <div className="empty">Aucun ticket ouvert. 🎉</div>}
          {data.tickets.map((t) => (
            <div key={t.id} className="ticket">
              <div className="ticket-head"><b>#{t.id} · {t.name}</b><span className="muted">il y a {ago(t.time)} {!t.online && '· déconnecté'}</span></div>
              <p>{t.message}</p>
              <div className="ticket-actions">
                {t.status === 'open' ? <button className="primary" onClick={() => act('ticket_claim', null, { id: t.id })}>Prendre</button>
                  : <span className="muted">Pris par {t.claimedBy}</span>}
                <button className="act" disabled={!t.online} onClick={() => act('ticket_goto', null, { id: t.id })}>Aller au joueur</button>
                <button className="act" disabled={!t.online} onClick={() => { setTab('players'); loadDossier(t.src) }}>Fiche</button>
                <button className="ghost" onClick={() => act('ticket_close', null, { id: t.id })}>Clôturer</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === 'server' && (
        <div className="pad grid2">
          <div className="card">
            <h4>En ligne</h4>
            <div className="big">{data.server.players}<small>/{data.server.maxPlayers}</small></div>
            <div className="muted">{data.server.staffOnDuty} staff en service</div>
          </div>
          <div className="card">
            <h4>Services</h4>
            {Object.entries(data.server.duty).map(([j, n]) => <div key={j} className="kv"><span>{j}</span><b>{n}</b></div>)}
          </div>
          <div className="card">
            <h4>Météo</h4>
            <div className="kv"><span>Actuelle</span><b>{data.server.weather || '—'}</b></div>
            <div className="kv"><span>Événement</span><b>{data.server.weatherEvent || 'aucun'}</b></div>
            {data.level >= 3 && (
              <div className="chips">
                {data.weathers.map((w) => <button key={w} className="chip" onClick={() => act('weather', null, { type: w, minutes: 30 })}>{w}</button>)}
                {data.events.map((e) => <button key={e.id} className="chip hot" onClick={() => act('weather', null, { event: e.id })}>{e.label}</button>)}
                <button className="chip" onClick={() => act('weather', null, { event: 'stop' })}>Stop événement</button>
              </div>
            )}
          </div>
          {data.level >= 3 && (
            <form className="card" onSubmit={(e) => { e.preventDefault(); if (announce.trim()) { act('announce', null, { text: announce }); setAnnounce('') } }}>
              <h4>Annonce serveur</h4>
              <textarea rows={3} maxLength={200} value={announce} onChange={(e) => setAnnounce(e.target.value)} placeholder="Redémarrage dans 10 min…" />
              <button className="primary" disabled={!announce.trim()}>Envoyer à tous</button>
            </form>
          )}
          <div className="card wide muted small">
            <p style={{ margin: 0 }}>Pouvoirs (vol libre, spectate, animaux, véhicules, points de métier) : menu <code>F11</code> (raccourcis staff : Ctrl+Y TP marqueur, Ctrl+U vol libre, Ctrl+O noms). Bans : txAdmin (<code>/tx</code>). Ce panneau gère le staff : tickets, fiches, sanctions, économie, journal.</p>
          </div>
        </div>
      )}

      {tab === 'logs' && (
        <div className="pad">
          {data.level < 2 && <div className="empty">Journal réservé aux modérateurs.</div>}
          {data.logs.map((l, i) => (
            <div key={i} className="log">
              <span className="muted">{ago(l.time)}</span> <b>{l.staff}</b> <span className="action">{l.action}</span> {l.target} <span className="muted">{l.details}</span>
            </div>
          ))}
        </div>
      )}

      {toast && <div className={toast.ok ? 'toast ok' : 'toast ko'}>{toast.text}</div>}
    </div>
  )
}
