import { useEffect, useRef, useState } from 'react'
import { api } from './api.js'

/** Une fenêtre d'écran tant qu'elle est ouverte et l'onglet visible. V12.64 : flux continu (≈ 2,5 images/s) ; l'appli donne
 *  le numéro de sa dernière image et le serveur ne renvoie l'image que si elle est nouvelle (sinon quelques octets). */
function Screen({ p, onClose, onOpen }) {
  const [img, setImg] = useState('')
  const [msg, setMsg] = useState('Connexion à l\'écran…')
  const [fps, setFps] = useState('')
  const alive = useRef(true)
  useEffect(() => {
    alive.current = true
    let t, since = null
    const times = []
    const tick = async () => {
      if (!alive.current) return
      let wait = 1500
      if (!document.hidden) {
        const r = await api('frame', { id: p.id, since })
        if (!alive.current) return
        if (r.ok && r.same) wait = 300 // rien de neuf : on redemande vite
        else if (r.ok && r.img) {
          since = r.seq ?? null
          setImg(r.img); setMsg('')
          const now = Date.now()
          times.push(now); while (times.length > 6) times.shift()
          if (times.length > 1) setFps(`${((times.length - 1) * 1000 / (now - times[0])).toFixed(1).replace('.', ',')} img/s`)
          wait = 300
        } else { setMsg(r.text || 'Pas d\'image.'); if (r.wait) wait = 500 }
      }
      t = setTimeout(tick, wait)
    }
    tick()
    return () => { alive.current = false; clearTimeout(t) }
  }, [p.id])
  return (
    <figure className="screen">
      <figcaption><i className="rec" aria-hidden="true" /> <b>{p.id}</b> {p.char || p.name}
        <span className="grow" />{fps && <small className="muted">{fps}</small>}<button className="icon" onClick={() => onOpen(p.id)} aria-label="Fiche">☰</button>
        <button className="icon" onClick={() => onClose(p.id)} aria-label="Fermer">✕</button></figcaption>
      {img ? <img src={img} alt={`Écran de ${p.char || p.name}`} /> : <div className="screen-wait">{msg}</div>}
      {img && msg && <div className="screen-note">{msg}</div>}
    </figure>
  )
}

/** Replay 30 s d'un joueur lié à un ticket : images gardées par le serveur, rejouées en boucle. */
export function Replay({ id, name, onClose }) {
  const [frames, setFrames] = useState(null)
  const [i, setI] = useState(0)
  const [err, setErr] = useState('')
  useEffect(() => { api('replay', { id }).then((r) => (r.ok ? setFrames(r.frames.filter((f) => typeof f === 'string' && f.startsWith('data:image/'))) : setErr(r.text))) }, [id])
  useEffect(() => {
    if (!frames || !frames.length) return undefined
    const t = setInterval(() => setI((x) => (x + 1) % frames.length), 1500)
    return () => clearInterval(t)
  }, [frames])
  return (
    <div className="backdrop" onClick={onClose}>
      <div className="replay" onClick={(e) => e.stopPropagation()}>
        <div className="replay-head"><b>⏪ Replay · {name}</b><span className="muted">{frames ? `${i + 1} / ${frames.length}` : ''}</span><button className="icon" onClick={onClose} aria-label="Fermer">✕</button></div>
        {frames && frames.length ? <img src={frames[i]} alt="" /> : <div className="screen-wait">{err || 'Chargement…'}</div>}
      </div>
    </div>
  )
}

/** Vue « Lives » : jusqu'à 4 écrans en grille, ajout depuis la liste. */
export default function Lives({ ov, watching, setWatching, onOpen, onReplay }) {
  const add = (id) => setWatching((w) => (w.includes(id) || w.length >= 4 ? w : [...w, id]))
  const del = (id) => setWatching((w) => w.filter((x) => x !== id))
  const shown = watching.map((id) => ov.players.find((p) => p.id === id)).filter(Boolean)
  const replays = ov.players.filter((p) => p.replay)
  return (
    <div className="lives">
      {!ov.server.lives && <div className="banner warn">screenshot-basic n'est pas démarré sur le serveur : pas d'écran disponible.</div>}
      <div className="lives-grid" data-n={shown.length}>
        {shown.map((p) => <Screen key={p.id} p={p} onClose={del} onOpen={onOpen} />)}
        {shown.length === 0 && <div className="lives-empty"><b>Aucun écran ouvert</b><span>Choisis jusqu'à 4 joueurs dans la liste : leur écran s'affiche ici en continu (environ 2 à 3 images par seconde). Chaque visionnage est noté dans le journal staff.</span></div>}
      </div>
      <aside className="lives-side">
        {replays.length > 0 && (
          <section className="card"><h4>Replays de tickets</h4>
            {replays.map((p) => <button key={p.id} className="row" onClick={() => onReplay(p.id)}><span className="mono">{p.id}</span><span className="grow">{p.char || p.name}</span><span className="pill warn">#{p.replay.ticket}</span></button>)}
          </section>
        )}
        <section className="card"><h4>Joueurs en ville <span className="muted">{shown.length}/4</span></h4>
          {ov.players.map((p) => (
            <button key={p.id} className={watching.includes(p.id) ? 'row on' : 'row'} onClick={() => (watching.includes(p.id) ? del(p.id) : add(p.id))} disabled={!watching.includes(p.id) && shown.length >= 4}>
              <span className="mono">{p.id}</span><span className="grow">{p.char || p.name}</span><span className="muted">{watching.includes(p.id) ? 'LIVE' : '+'}</span>
            </button>
          ))}
        </section>
      </aside>
    </div>
  )
}
