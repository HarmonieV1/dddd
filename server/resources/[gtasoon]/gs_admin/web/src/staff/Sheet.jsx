import { useEffect, useState } from 'react'
import { api } from './api.js'
import { GROUPS, payload } from './actions.js'
import { ActionDialog, ago, dur } from './ui.jsx'
import { stateOf, STATE_LABEL } from '../shared/LiveMap.jsx'

/** Fiche d'un joueur : identité, état, dossier staff, et toutes les actions à distance. */
export default function Sheet({ id, ov, onClose, toast, onWatch, onReplay, refresh }) {
  const [d, setD] = useState(null)
  const [form, setForm] = useState(null)
  const p = ov.players.find((x) => x.id === id)
  const load = async () => { const r = await api('dossier', { id }); if (r.ok) setD(r.data); else { setD(null); toast(r) } }
  useEffect(() => { setD(null); load() }, [id]) // eslint-disable-line react-hooks/exhaustive-deps

  if (!p) return (
    <aside className="sheet"><div className="sheet-head"><h2>Joueur parti</h2><button className="icon" onClick={onClose} aria-label="Fermer">✕</button></div>
      <p className="muted pad">Ce joueur n'est plus en ville.</p></aside>
  )
  const run = async (action, values = {}) => {
    const r = await api('act', payload(action, id, values))
    toast(r)
    if (r.ok) { refresh(); if (action.name !== 'kick' && action.name !== 'ban') load() }
  }
  const st = stateOf(p)
  const facts = d ? [
    ['Personnage', d.name || '—'], ['Compte', d.account || p.name], ['Métier', d.job ? `${d.job.label || d.job.name}${d.job.onduty ? ' · en service' : ''}` : '—'],
    ['Session', dur(d.session || 0)], ['Recherche', d.heat > 0 ? `${'★'.repeat(Math.min(5, Math.ceil(d.heat / 20)))} (${d.heat})` : 'aucune'],
    ['Gang', d.gang || '—'], ['Argent', d.money ? `${d.money.cash.toLocaleString('fr-FR')} $ · banque ${d.money.bank.toLocaleString('fr-FR')} $` : '—'],
    ['Isolement', d.jailedFor > 0 ? `encore ${dur(d.jailedFor)}` : 'non'], ['CitizenID', d.citizenid || '—'],
  ] : []
  return (
    <aside className="sheet" aria-label={`Fiche de ${p.char || p.name}`}>
      <div className="sheet-head">
        <div className="who">
          <span className={`avatar ${st}`}>{p.id}</span>
          <div><h2>{p.char || p.name}</h2><div className="muted mono">{p.name} · {p.ping} ms</div></div>
        </div>
        <button className="icon" onClick={onClose} aria-label="Fermer">✕</button>
      </div>
      <div className="chips">
        <span className={`pill ${st}`}>{STATE_LABEL[st]}</span>
        {p.staff && <span className="pill staff">Staff niv. {d?.level ?? '?'}</span>}
        {p.job && p.job !== 'unemployed' && <span className={p.duty ? 'pill ok' : 'pill'}>{p.job}{p.duty ? ' · service' : ''}</span>}
        {p.replay && <span className="pill warn">Ticket #{p.replay.ticket} · replay</span>}
      </div>
      <div className="sheet-quick">
        <button className="btn cyan" onClick={() => onWatch(p.id)} disabled={!ov.server.lives}>◉ Voir son écran</button>
        {p.replay && <button className="btn ghost" onClick={() => onReplay(p.id)}>⏪ Revoir 30 s</button>}
      </div>
      {!d && <p className="muted pad">Chargement de la fiche…</p>}
      {d && <dl className="facts">{facts.map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}</dl>}
      {GROUPS.map((g) => (
        <section key={g.id} className={`act-group ${g.id}`}>
          <h4>{g.title}</h4>
          <div className="act-grid">
            {g.actions.filter((a) => !a.when || (d && a.when(d))).map((a) => (
              <button key={a.name} className={a.danger ? 'act danger' : 'act'} onClick={() => (a.fields ? setForm(a) : run(a))} disabled={!d}>
                <i aria-hidden="true">{a.icon}</i>{a.label}
              </button>
            ))}
          </div>
        </section>
      ))}
      {d?.notes && (
        <section className="history">
          <h4>Dossier staff</h4>
          {d.notes.length === 0 && <p className="muted">Rien à signaler.</p>}
          {d.notes.map((n, i) => (
            <div key={i} className={`hist ${n.kind}`}><b>{n.kind === 'warn' ? 'Sanction' : 'Note'}</b> {n.text}<div className="muted small">{n.staff} · il y a {ago(n.time)}</div></div>
          ))}
        </section>
      )}
      {form && (
        <ActionDialog action={form} target={p.char || p.name} places={ov.places} players={ov.players.filter((x) => x.id !== id)} maxJail={ov.maxJail}
          onCancel={() => setForm(null)} onSubmit={(v) => { const a = form; setForm(null); run(a, v) }} />
      )}
    </aside>
  )
}
