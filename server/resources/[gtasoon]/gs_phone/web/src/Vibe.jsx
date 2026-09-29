import { useEffect, useRef, useState } from 'react'
import { nui, isBrowser } from './nui.js'

// Vibe : réseau social de la ville, dans le téléphone (données et règles : ressource gs_social, côté serveur).
const DEMO = {
  handle: 'vice_lucia', canModerate: true, maxLength: 280, title: 'Habitué',
  feed: [
    { id: 3, handle: 'vice_lucia', content: 'Coucher de soleil sur Vespucci, la ville est à nous ce soir 🌴', likes: 12, time: Date.now() / 1000 - 120 },
    { id: 2, handle: 'lspd_officiel', content: 'Rappel : 50 en ville. Même en Infernus. @vice_lucia', likes: 4, time: Date.now() / 1000 - 3600 },
  ],
}

function timeAgo(t) {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
  if (s < 60) return 'à l’instant'
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  return `${Math.floor(s / 86400)} j`
}

// Texte rendu par React (échappé) : aucune injection HTML possible depuis un post.
function Content({ text }) {
  return text.split(/(@[A-Za-z0-9_]+)/g).map((part, i) => (part.startsWith('@') ? <span key={i} className="mention">{part}</span> : part))
}

export default function Vibe({ onBack }) {
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const [liked, setLiked] = useState({})
  const [draft, setDraft] = useState('')
  const [handle, setHandle] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const feedRef = useRef(null)

  useEffect(() => {
    if (!isBrowser) nui('vibe', { op: 'open' }).then((d) => {
      if (!d) return setError('Vibe est indisponible pour le moment.')
      setData(d)
      setLiked(Object.fromEntries(d.feed.map((p) => [p.id, p.liked])))
    })
    const onMessage = ({ data: msg }) => {
      if (msg.action === 'vibeNew') setData((d) => d && { ...d, feed: [msg.post, ...d.feed.filter((p) => p.id !== msg.post.id)].slice(0, 60) })
      else if (msg.action === 'vibeLikes') setData((d) => d && { ...d, feed: d.feed.map((p) => (p.id === msg.id ? { ...p, likes: msg.likes } : p)) })
      else if (msg.action === 'vibeRemoved') setData((d) => d && { ...d, feed: d.feed.filter((p) => p.id !== msg.id) })
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  const act = async (op, body, after) => {
    if (busy) return
    setBusy(true)
    const res = await nui('vibe', { op, ...body })
    setBusy(false)
    if (!res?.ok) return setError(res?.message || 'Action impossible.')
    setError('')
    after?.(res)
  }

  let body
  if (!data) {
    body = <div className="empty">{error || 'Chargement…'}</div>
  } else if (!data.handle) {
    body = (
      <form className="form" onSubmit={(e) => { e.preventDefault(); act('setHandle', { handle }, (r) => setData({ ...data, handle: r.message })) }}>
        <h3>Bienvenue sur Vibe</h3>
        <p className="muted">Choisis ton pseudo. Il est définitif pour ce personnage.</p>
        <input autoFocus maxLength={16} placeholder="@ton_pseudo" value={handle} onChange={(e) => setHandle(e.target.value.replace(/[^A-Za-z0-9_]/g, ''))} />
        <button className="primary" disabled={busy || handle.length < 3}>Créer mon profil</button>
        {error && <div className="vibe-error">{error}</div>}
      </form>
    )
  } else {
    body = (
      <>
        <form className="vibe-composer" onSubmit={(e) => {
          e.preventDefault()
          if (draft.trim()) act('post', { content: draft }, () => { setDraft(''); feedRef.current?.scrollTo({ top: 0, behavior: 'smooth' }) })
        }}>
          <div className="vibe-me">@{data.handle}{data.title && <span className="vibe-title">{data.title}</span>}</div>
          <textarea rows={2} maxLength={data.maxLength} placeholder="Quoi de neuf à Los Santos ?" value={draft} onChange={(e) => setDraft(e.target.value)} />
          <div className="vibe-foot">
            <span className="muted small">{draft.length}/{data.maxLength}</span>
            <button className="primary slim" disabled={busy || !draft.trim()}>Publier</button>
          </div>
          {error && <div className="vibe-error">{error}</div>}
        </form>
        <div className="list" ref={feedRef}>
          {data.feed.length === 0 && <div className="empty">Personne n’a encore rien dit. Lance la conversation.</div>}
          {data.feed.map((p) => {
            const mine = p.handle === data.handle
            return (
              <article key={p.id} className={mine ? 'vibe-post mine' : 'vibe-post'}>
                <div className="vibe-head"><b>@{p.handle}</b>{p.title && <span className="vibe-title">{p.title}</span>}<span className="muted small">{timeAgo(p.time)}</span></div>
                <p><Content text={p.content} /></p>
                <div className="vibe-actions">
                  <button className={liked[p.id] ? 'vibe-like on' : 'vibe-like'} onClick={() => act('like', { id: p.id }, (r) => setLiked({ ...liked, [p.id]: r.message === true }))}>♥ {p.likes}</button>
                  {(mine || data.canModerate) && <button className="mini" onClick={() => act('delete', { id: p.id })}>Supprimer</button>}
                  {!mine && <button className="mini" onClick={() => act('report', { id: p.id }, () => setError('Signalé au staff, merci.'))}>Signaler</button>}
                </div>
              </article>
            )
          })}
        </div>
      </>
    )
  }

  return (
    <>
      <div className="app-header">
        <button className="back" onClick={onBack}>‹</button>
        <h2 className="vibe-logo">Vibe</h2>
        <div className="right" />
      </div>
      {body}
    </>
  )
}
