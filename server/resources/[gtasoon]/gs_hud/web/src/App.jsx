import { useEffect, useState } from 'react'

const inGame = typeof window.GetParentResourceName === 'function'
const DEMO = {
  health: 82, armor: 40, hunger: 64, thirst: 23, talking: true, voice: 'Normal', cash: 1250, bank: 48200,
  job: 'Mécano LS Customs', duty: true, stars: 2, time: '19:42', weather: 'Dégagé', street: 'Vespucci Blvd',
  zone: 'Del Perro', inVehicle: true, speed: 128, fuel: 34, engine: 92, gear: 4,
}

const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`

// Anneau de statut : se colore en alerte sous 25 %.
function Ring({ value, color, icon, label }) {
  const v = Math.max(0, Math.min(100, value ?? 100))
  const r = 17, c = 2 * Math.PI * r
  const low = v <= 25
  return (
    <div className={low ? 'ring low' : 'ring'} title={label}>
      <svg viewBox="0 0 44 44">
        <circle cx="22" cy="22" r={r} className="track" />
        <circle cx="22" cy="22" r={r} className="bar" style={{ stroke: low ? '#ff4d6d' : color, strokeDasharray: c, strokeDashoffset: c * (1 - v / 100) }} />
      </svg>
      <span>{icon}</span>
    </div>
  )
}

export default function App() {
  const [s, setS] = useState(inGame ? {} : DEMO)
  const [visible, setVisible] = useState(!inGame)

  useEffect(() => {
    const onMessage = ({ data: msg }) => {
      if (msg.action === 'update') setS((prev) => ({ ...prev, ...msg.data }))
      else if (msg.action === 'visible') setVisible(msg.visible)
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  if (!visible) return null

  return (
    <>
      <div className="top-right">
        <div className="clock">{s.time}<small>{s.weather}</small></div>
        <div className="money"><span>💵 {money(s.cash)}</span><span>🏦 {money(s.bank)}</span></div>
        <div className="job">{s.job}{s.duty && <i> · en service</i>}</div>
        {s.stars > 0 && <div className="stars">{'★'.repeat(s.stars)}<span>{'★'.repeat(5 - s.stars)}</span></div>}
      </div>

      <div className={s.inVehicle ? 'status with-map' : 'status'}>
        <Ring value={s.health} color="#39ff9a" icon="♥" label="Santé" />
        {s.armor > 0 && <Ring value={s.armor} color="#28e0ff" icon="⛨" label="Armure" />}
        <Ring value={s.hunger} color="#ff8a3d" icon="🍔" label="Faim" />
        <Ring value={s.thirst} color="#5ab0ff" icon="💧" label="Soif" />
        <div className={s.talking ? 'voice on' : 'voice'} title="Voix">🎙<small>{s.voice || ''}</small></div>
      </div>

      <div className={s.inVehicle ? 'location with-map' : 'location'}>
        <b>{s.street}</b><span>{s.zone}</span>
      </div>

      {s.inVehicle && (
        <div className="speedo">
          <div className="speed">{s.speed ?? 0}<small>km/h</small></div>
          <div className="gear">{s.gear === 0 ? 'R' : s.gear}</div>
          <div className="gauges">
            <div className="gauge"><span>⛽</span><div className="track"><div style={{ width: `${s.fuel ?? 0}%` }} className={s.fuel <= 15 ? 'fill low' : 'fill'} /></div></div>
            <div className="gauge"><span>🔧</span><div className="track"><div style={{ width: `${s.engine ?? 100}%` }} className={s.engine <= 30 ? 'fill low' : 'fill engine'} /></div></div>
          </div>
        </div>
      )}
    </>
  )
}
