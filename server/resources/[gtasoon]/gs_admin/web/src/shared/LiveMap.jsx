import { useEffect, useRef, useState } from 'react'
import './livemap.css'

// Carte en direct de Los Santos (F10 et appli staff). Image 1080 × 1470 du site, même calage que la carte publique.
// Points : un par joueur ; couleur = son état (staff, recherché, isolé, gelé). Molette / pincer / boutons pour zoomer, glisser pour déplacer.
const W = 1080, H = 1470
export const mapX = (x) => ((0.02072 * x + 117.3) * 4 - 180) * 1.5
export const mapY = (y) => ((-0.0205 * y + 172.8) * 4 - 30) * 1.5

export function stateOf(p) {
  if (p.jailed) return 'jail'
  if (p.frozen) return 'frozen'
  if (p.heat > 0) return 'wanted'
  if (p.staff) return 'staff'
  return 'civil'
}
export const STATE_LABEL = { civil: 'Citoyen', staff: 'Staff', wanted: 'Recherché', jail: 'Isolé', frozen: 'Gelé' }

// V12.65 · incidents de la soirée (tickets, joueurs à terre, alertes anti-triche) : petits repères par type
export const INCIDENT_LABEL = { ticket: 'Ticket', death: 'À terre', ac: 'Anti-triche' }

export default function LiveMap({ players = [], incidents = [], selected, onSelect, src = './carte-ls.webp', compact = false }) {
  const [view, setView] = useState({ k: 1, x: 0, y: 0 })
  const drag = useRef(null)
  const box = useRef(null)
  const clamp = (v) => {
    const k = Math.min(6, Math.max(1, v.k))
    const r = box.current ? box.current.getBoundingClientRect() : { width: 1, height: 1 }
    const mx = (r.width * (k - 1)) / 2, my = (r.height * (k - 1)) / 2
    return { k, x: Math.min(mx, Math.max(-mx, v.x)), y: Math.min(my, Math.max(-my, v.y)) }
  }
  const zoom = (f) => setView((v) => clamp({ ...v, k: v.k * f }))
  // molette : écouteur non passif (sinon la page défile en même temps que la carte zoome)
  useEffect(() => {
    const el = box.current
    if (!el) return undefined
    const h = (e) => { e.preventDefault(); setView((v) => clamp({ ...v, k: v.k * (e.deltaY < 0 ? 1.2 : 1 / 1.2) })) }
    el.addEventListener('wheel', h, { passive: false })
    return () => el.removeEventListener('wheel', h)
  }, [])
  const onDown = (e) => { drag.current = { sx: e.clientX, sy: e.clientY, v: view, moved: false }; e.currentTarget.setPointerCapture?.(e.pointerId) }
  const onMove = (e) => {
    const d = drag.current
    if (!d) return
    const dx = e.clientX - d.sx, dy = e.clientY - d.sy
    if (Math.abs(dx) + Math.abs(dy) > 4) d.moved = true
    setView(clamp({ ...d.v, x: d.v.x + dx, y: d.v.y + dy }))
  }
  const onUp = () => { setTimeout(() => { drag.current = null }, 0) }
  const pick = (id) => { if (!drag.current || !drag.current.moved) onSelect?.(id) }

  return (
    <div className={compact ? 'lmap compact' : 'lmap'} ref={box} onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
      <div className="lmap-stage" style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.k})` }}>
        <img src={src} alt="Carte de Los Santos" draggable="false" />
        {incidents.filter((i) => Number.isFinite(i.x) && Number.isFinite(i.y)).map((i, n) => {
          const left = (mapX(i.x) / W) * 100, top = (mapY(i.y) / H) * 100
          if (left < 0 || left > 100 || top < 0 || top > 100) return null
          const when = new Date(i.at * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
          return <span key={`i${n}`} className={`lmap-inc ${i.kind}`} style={{ left: `${left}%`, top: `${top}%`, '--inv': 1 / view.k }}
            title={`${when} · ${INCIDENT_LABEL[i.kind] || i.kind} · ${i.text || ''}`} aria-label={`${INCIDENT_LABEL[i.kind] || i.kind} à ${when}`} />
        })}
        {players.filter((p) => Number.isFinite(p.x) && Number.isFinite(p.y)).map((p) => {
          const st = stateOf(p)
          const left = (mapX(p.x) / W) * 100, top = (mapY(p.y) / H) * 100
          if (left < 0 || left > 100 || top < 0 || top > 100) return null
          return (
            <button key={p.id} className={`lmap-dot ${st}${selected === p.id ? ' on' : ''}${p.ticket ? ' ticket' : ''}`} style={{ left: `${left}%`, top: `${top}%`, '--inv': 1 / view.k }}
              onClick={(e) => { e.stopPropagation(); pick(p.id) }} title={`${p.id} · ${p.char || p.name}${p.ticket ? ` · ticket #${p.ticket}` : ''}`} aria-label={`${p.id} · ${p.char || p.name} (${STATE_LABEL[st]})${p.ticket ? `, ticket #${p.ticket}` : ''}`}>
              <span className="lmap-tag">{p.id}</span>
            </button>
          )
        })}
      </div>
      <div className="lmap-tools">
        <button onClick={() => zoom(1.4)} aria-label="Zoomer">+</button>
        <button onClick={() => zoom(1 / 1.4)} aria-label="Dézoomer">−</button>
        <button onClick={() => setView({ k: 1, x: 0, y: 0 })} aria-label="Recentrer">⤢</button>
      </div>
      <div className="lmap-legend">
        {Object.entries(STATE_LABEL).map(([k, v]) => <span key={k}><i className={`lmap-key ${k}`} />{v}</span>)}
        {players.some((p) => p.ticket) && <span><i className="lmap-key ticket" />Ticket ouvert</span>}
        {incidents.length > 0 && Object.entries(INCIDENT_LABEL).map(([k, v]) => <span key={k}><i className={`lmap-inc key ${k}`} />{v}</span>)}
      </div>
    </div>
  )
}
