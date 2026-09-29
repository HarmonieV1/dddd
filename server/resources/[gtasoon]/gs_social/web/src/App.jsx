import { useEffect, useRef, useState } from 'react'
import { nui, isBrowser } from './nui.js'

const DEMO = {
  handle: null, canModerate: true, maxLength: 280, muted: false,
  feed: [
    { id: 3, handle: 'vice_lucia', content: 'Coucher de soleil sur Vespucci, la ville est à nous ce soir 🌴', likes: 12, time: Date.now() / 1000 - 120 },
    { id: 2, handle: 'lspd_officiel', content: 'Rappel : la vitesse est limitée à 50 en ville. Même en Infernus.', likes: 4, time: Date.now() / 1000 - 3600 },
  ],
}

function timeAgo(t) {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
  if (s < 60) return 'à l’instant'
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  return `${Math.floor(s / 86400)} j`
}

// Contenu rendu en TEXTE (React échappe tout) : pas d'injection HTML possible depuis un post.
function Content({ text }) {
  return text.split(/(@[A-Za-z0-9_]+)/g).map((part, i) =>
    part.startsWith('@') ? <span key={i} className="mention">{part}</span> : part)
}

export default function App() {
  const [visible, setVisible] = useState(isBrowser)
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const [draft, setDraft] = useState('')
  const [handleInput, setHandleInput] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [liked, setLiked] = useState({})
  const feedRef = useRef(null)

  useEffect(() => {
    const onMessage = ({ data: msg }) => {
      if (msg.action === 'open') {
        setData(msg.data)
        setLiked(Object.fromEntries(msg.data.feed.map((p) => [p.id, p.liked])))
        setVisible(true)
        setError('')
      } else if (msg.action === 'close') {
        setVisible(false)
      } else if (msg.action === 'new') {
        setData((d) => d && { ...d, feed: [msg.post, ...d.feed.filter((p) => p.id !== msg.post.id)].slice(0, 60) })
      } else if (msg.action === 'likes') {
        setData((d) => d && { ...d, feed: d.feed.map((p) => (p.id === msg.id ? { ...p, likes: msg.likes } : p)) })
      } else if (msg.action === 'removed') {
        setData((d) => d && { ...d, feed: d.feed.filter((p) => p.id !== msg.id) })
      }
    }
    const onKey = (e) => { if (e.key === 'Escape') nui('close') }
    window.addEventListener('message', onMessage)
    window.addEventListener('keydown', onKey)
    return () => { window.removeEventListener('message', onMessage); window.removeEventListener('keydown', onKey) }
  }, [])

  if (!visible || !data) return null

  const run = async (action, body, after) => {
    if (busy) return
    setBusy(true)
    const res = await nui(action, body)
    setBusy(false)
    if (!res.ok) { setError(res.message || 'Action impossible.'); return }
    setError('')
    after?.(res)
  }

  const submitHandle = (e) => {
    e.preventDefault()
    run('setHandle', { handle: handleInput.trim() }, (res) => setData({ ...data, handle: res.message }))
  }

  const submitPost = (e) => {
    e.preventDefault()
    if (!draft.trim()) return
    run('post', { content: draft }, () => { setDraft(''); feedRef.current?.scrollTo({ top: 0, behavior: 'smooth' }) })
  }

  const toggleLike = (post) => run('like', { id: post.id }, (res) => setLiked({ ...liked, [post.id]: res.message === true }))

  const toggleMute = () => { nui('mute', { muted: !data.muted }); setData({ ...data, muted: !data.muted }) }

  return (
    <div className="phone">
      <header>
        <div className="logo">NÉON</div>
        <div className="actions">
          <button className="ghost" title={data.muted ? 'Notifications coupées' : 'Notifications actives'} onClick={toggleMute}>
            {data.muted ? '🔕' : '🔔'}
          </button>
          <button className="ghost" title="Fermer (Échap)" onClick={() => nui('close')}>✕</button>
        </div>
      </header>

      {!data.handle ? (
        <form className="onboarding" onSubmit={submitHandle}>
          <h2>Bienvenue sur Néon</h2>
          <p>Choisis ton pseudo. Il est définitif pour ce personnage.</p>
          <div className="handle-input">
            <span>@</span>
            <input autoFocus maxLength={16} value={handleInput} placeholder="ton_pseudo"
              onChange={(e) => setHandleInput(e.target.value.replace(/[^A-Za-z0-9_]/g, ''))} />
          </div>
          <button className="primary" disabled={busy || handleInput.length < 3}>Créer mon profil</button>
          {error && <div className="error">{error}</div>}
        </form>
      ) : (
        <>
          <form className="composer" onSubmit={submitPost}>
            <div className="me">@{data.handle}{data.title && <span className="title-badge">{data.title}</span>}</div>
            <textarea value={draft} maxLength={data.maxLength} rows={3} placeholder="Quoi de neuf à Los Santos ?"
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) submitPost(e) }} />
            <div className="composer-footer">
              <span className={draft.length > data.maxLength - 20 ? 'count warn' : 'count'}>{draft.length}/{data.maxLength}</span>
              <button className="primary" disabled={busy || !draft.trim()}>Publier</button>
            </div>
            {error && <div className="error">{error}</div>}
          </form>

          <div className="feed" ref={feedRef}>
            {data.feed.length === 0 && <div className="empty">Personne n’a encore rien dit. Lance la conversation.</div>}
            {data.feed.map((post) => {
              const mine = post.handle === data.handle
              return (
                <article key={post.id} className={mine ? 'post mine' : 'post'}>
                  <div className="post-head">
                    <span className="author">@{post.handle}{post.title && <span className="title-badge">{post.title}</span>}</span>
                    <span className="time">{timeAgo(post.time)}</span>
                  </div>
                  <p><Content text={post.content} /></p>
                  <div className="post-actions">
                    <button className={liked[post.id] ? 'like on' : 'like'} onClick={() => toggleLike(post)}>
                      ♥ {post.likes}
                    </button>
                    {(mine || data.canModerate) && (
                      <button className="ghost small" onClick={() => run('delete', { id: post.id })}>Supprimer</button>
                    )}
                    {!mine && (
                      <button className="ghost small" onClick={() => run('report', { id: post.id }, () => setError('Signalé au staff, merci.'))}>
                        Signaler
                      </button>
                    )}
                  </div>
                </article>
              )
            })}
          </div>
        </>
      )}
    </div>
  )
}
