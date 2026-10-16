import { useEffect, useState } from 'react'
import { BAN_SPANS } from './actions.js'

export const ago = (t) => {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - (t || 0)))
  if (s < 60) return `${s} s`
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  return `${Math.floor(s / 86400)} j`
}
export const dur = (s) => (s >= 3600 ? `${Math.floor(s / 3600)} h ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}` : `${Math.max(0, Math.floor(s / 60))} min`)

const ACTION_FR = { freeze: 'gel', unfreeze: 'dégel', warn: 'avertissement', message: 'message', kick: 'expulsion', announce: 'annonce', jail: 'isolement',
  unjail: 'libération', revive: 'réanimation', heal: 'soin', fixveh: 'réparation', clearheat: 'recherche effacée', note: 'note', tp: 'téléportation',
  ban: 'bannissement', unban: 'débannissement', ticket_claim: 'ticket pris', ticket_close: 'ticket clos', goto: 'aller à', bring: 'amener',
  staff_on: 'mode staff', staff_off: 'fin du mode staff', power: 'pouvoir', spectate: 'spectateur', setjob: 'métier',
  watch: 'surveillance', unwatch: 'surveillance levée', lockdown: 'arrivées', offlineban: 'ban hors ligne', evasion: 'contournement de ban ?', unstuck: 'coincé ramené' }
export const actionFr = (a) => ACTION_FR[a] || a
export const SEVERE = { ban: true, kick: true, jail: true, warn: true, freeze: true, offlineban: true, evasion: true, lockdown: true }

export function Sparkline({ points = [], height = 36 }) {
  if (points.length < 2) return <svg className="spark" viewBox="0 0 100 36" aria-hidden="true" />
  const max = Math.max(1, ...points.map((p) => p.n))
  const xy = points.map((p, i) => [(i / (points.length - 1)) * 100, height - 3 - (p.n / max) * (height - 8)])
  const line = xy.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ')
  const [lx, ly] = xy[xy.length - 1]
  return (
    <svg className="spark" viewBox={`0 0 100 ${height}`} preserveAspectRatio="none" aria-hidden="true">
      <path d={`${line} L100,${height} L0,${height} Z`} className="spark-area" />
      <path d={line} className="spark-line" vectorEffect="non-scaling-stroke" />
      <circle cx={lx} cy={ly} r="2.2" className="spark-dot" />
    </svg>
  )
}

export function Dialog({ title, danger, children, onCancel, onConfirm, confirmLabel = 'Confirmer', busy }) {
  useEffect(() => {
    const k = (e) => { if (e.key === 'Escape') onCancel() }
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [onCancel])
  return (
    <div className="backdrop" onClick={onCancel}>
      <form className={danger ? 'dialog danger' : 'dialog'} onClick={(e) => e.stopPropagation()} onSubmit={(e) => { e.preventDefault(); onConfirm() }}>
        <h3>{title}</h3>
        {children}
        <div className="dialog-actions">
          <button type="button" className="btn ghost" onClick={onCancel}>Annuler</button>
          <button className={danger ? 'btn red' : 'btn pink'} disabled={busy}>{busy ? '…' : confirmLabel}</button>
        </div>
      </form>
    </div>
  )
}

/** Boîte d'une action (motif, durée, destination…). values → onSubmit. */
export function ActionDialog({ action, target, places, players, maxJail, onCancel, onSubmit }) {
  const init = {}
  for (const f of action.fields || []) init[f.key] = f.type === 'minutes' ? '15' : f.type === 'days' ? '1' : f.type === 'dest' ? 'l:1' : ''
  const [v, setV] = useState(init)
  const [err, setErr] = useState('')
  const set = (k, x) => setV((o) => ({ ...o, [k]: x }))
  const submit = () => {
    for (const f of action.fields || []) {
      if ((f.type === 'text' || f.type === 'textarea') && !String(v[f.key] || '').trim()) return setErr(`${f.label} : à remplir.`)
      if (f.type === 'minutes') { const n = Number(v[f.key]); if (!(n >= 1 && n <= maxJail)) return setErr(`Durée : 1 à ${maxJail} minutes.`) }
    }
    onSubmit(v)
  }
  return (
    <Dialog title={`${action.label} · ${target}`} danger={action.danger} onCancel={onCancel} onConfirm={submit} confirmLabel={action.label.replace('…', '')}>
      {(action.fields || []).map((f) => (
        <label key={f.key} className="field">
          <span>{f.label}</span>
          {f.type === 'textarea' && <textarea id={`f-${f.key}`} rows={3} maxLength={200} value={v[f.key]} onChange={(e) => set(f.key, e.target.value)} autoFocus />}
          {f.type === 'text' && <input id={`f-${f.key}`} maxLength={200} value={v[f.key]} onChange={(e) => set(f.key, e.target.value)} autoFocus={f === action.fields[0]} />}
          {f.type === 'minutes' && <input id={`f-${f.key}`} type="number" min="1" max={maxJail} value={v[f.key]} onChange={(e) => set(f.key, e.target.value)} />}
          {f.type === 'days' && (
            <div className="seg">{BAN_SPANS.map(([d, l]) => <button type="button" key={d} className={v.days === d ? 'on' : ''} onClick={() => set('days', d)}>{l}</button>)}</div>
          )}
          {f.type === 'dest' && (
            <select id={`f-${f.key}`} value={v.dest} onChange={(e) => set('dest', e.target.value)}>
              <optgroup label="Lieux">{places.map((p, i) => <option key={p} value={`l:${i + 1}`}>{p}</option>)}</optgroup>
              <optgroup label="À côté d'un joueur">{players.map((p) => <option key={p.id} value={`p:${p.id}`}>{p.id} · {p.char || p.name}</option>)}</optgroup>
            </select>
          )}
        </label>
      ))}
      {action.danger && <p className="warnline">Action publiée et journalisée à ton nom.</p>}
      {err && <p className="errline">{err}</p>}
    </Dialog>
  )
}
