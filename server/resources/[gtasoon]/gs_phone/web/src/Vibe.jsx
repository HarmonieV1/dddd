import { useEffect, useRef, useState } from 'react'
import { nui, isBrowser } from './nui.js'

// Vibe : réseau social de la ville, dans le téléphone (données et règles : ressource gs_social, côté serveur).
// Onglets Fil / Top de la semaine, profils publics avec abonnement, badges vérifié / influenceur.
const now = () => Date.now() / 1000
const DEMO = {
  handle: 'vice_lucia', canModerate: true, maxLength: 280, title: 'Habitué', badge: 'influencer', followers: 31,
  feed: [
    { id: 3, handle: 'vice_lucia', content: 'Coucher de soleil sur Vespucci, la ville est à nous ce soir 🌴', likes: 12, time: now() - 120, badge: 'influencer' },
    { id: 2, handle: 'lspd_officiel', content: 'Rappel : 50 en ville. Même en Infernus. @vice_lucia', likes: 4, time: now() - 3600, badge: 'verified' },
  ],
}
const DEMO_TOP = {
  posts: [{ id: 3, handle: 'vice_lucia', content: 'Coucher de soleil sur Vespucci, la ville est à nous ce soir 🌴', likes: 12, time: now() - 120, badge: 'influencer' }],
  creators: [{ handle: 'vice_lucia', likes: 58, posts: 9, badge: 'influencer' }, { handle: 'lspd_officiel', likes: 21, posts: 4, badge: 'verified' }],
  followers: [{ handle: 'vice_lucia', followers: 31, badge: 'influencer' }, { handle: 'lspd_officiel', followers: 12, badge: 'verified' }],
  races: [{ id: 'sprint', label: 'Sprint centre-ville', top: [{ name: '@vice_lucia', time: '6:41.220' }, { name: 'Jason N.', time: '6:58.870' }] },
    { id: 'boucle', label: 'Boucle des plages', top: [] }],
}
const demo = (op, body) => {
  if (op === 'top') return DEMO_TOP
  if (op === 'profile') return { handle: body.handle, badge: body.handle === 'lspd_officiel' ? 'verified' : null, verified: body.handle === 'lspd_officiel',
    followers: 12, following: false, mine: body.handle === DEMO.handle, posts: DEMO.feed.filter((p) => p.handle === body.handle) }
  if (op === 'follow') return { ok: true, message: { following: true, followers: 13 } }
  return { ok: true, message: true }
}
const call = (op, body = {}) => (isBrowser ? Promise.resolve(demo(op, body)) : nui('vibe', { op, ...body }))

function timeAgo(t) {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
  if (s < 60) return 'à l’instant'
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  return `${Math.floor(s / 86400)} j`
}

function Badge({ kind }) {
  if (kind === 'verified') return <span className="vibe-badge verified" title="Compte vérifié">✔</span>
  if (kind === 'influencer') return <span className="vibe-badge influencer" title="Influenceur">★</span>
  return null
}

// Texte rendu par React (échappé) : aucune injection HTML possible depuis un post.
function Content({ text, onHandle }) {
  return text.split(/(@[A-Za-z0-9_]+)/g).map((part, i) => (part.startsWith('@')
    ? <span key={i} className="mention" onClick={() => onHandle(part.slice(1))}>{part}</span> : part))
}

export default function Vibe({ onBack }) {
  const [data, setData] = useState(isBrowser ? DEMO : null)
  const [liked, setLiked] = useState({})
  const [tab, setTab] = useState('feed')
  const [top, setTop] = useState(null)
  const [profile, setProfile] = useState(null)
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
    const res = await call(op, body)
    setBusy(false)
    if (!res?.ok) return setError(res?.message || 'Action impossible.')
    setError('')
    after?.(res)
  }

  const openProfile = async (h) => {
    const p = await call('profile', { handle: h })
    if (!p) return setError('Profil introuvable.')
    setError('')
    setProfile(p)
  }
  const openTop = async () => { setTab('top'); setProfile(null); setTop(await call('top')) }

  const Author = ({ h, badge }) => <b className="vibe-author" onClick={() => openProfile(h)}>@{h}<Badge kind={badge} /></b>

  const Post = ({ p, actions = true }) => {
    const mine = p.handle === data.handle
    return (
      <article className={mine ? 'vibe-post mine' : 'vibe-post'}>
        <div className="vibe-head"><Author h={p.handle} badge={p.badge} />{p.title && <span className="vibe-title">{p.title}</span>}<span className="muted small">{timeAgo(p.time)}</span></div>
        <p><Content text={p.content} onHandle={openProfile} /></p>
        {actions ? (
          <div className="vibe-actions">
            <button className={liked[p.id] ? 'vibe-like on' : 'vibe-like'} onClick={() => act('like', { id: p.id }, (r) => setLiked({ ...liked, [p.id]: r.message === true }))}>♥ {p.likes}</button>
            {(mine || data.canModerate) && <button className="mini" onClick={() => act('delete', { id: p.id })}>Supprimer</button>}
            {!mine && <button className="mini" onClick={() => act('report', { id: p.id }, () => setError('Signalé au staff, merci.'))}>Signaler</button>}
          </div>
        ) : <div className="vibe-actions"><span className="vibe-like">♥ {p.likes}</span></div>}
      </article>
    )
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
  } else if (profile) {
    body = (
      <div className="list">
        <div className="vibe-profile">
          <div className="avatar big">{profile.handle.slice(0, 1).toUpperCase()}</div>
          <h3>@{profile.handle}<Badge kind={profile.badge} /></h3>
          <div className="muted">{profile.followers} abonné{profile.followers > 1 ? 's' : ''}</div>
          <div className="vibe-profile-actions">
            {!profile.mine && (
              <button className={profile.following ? 'secondary' : 'primary slim'} onClick={() => act('follow', { handle: profile.handle },
                (r) => setProfile({ ...profile, following: r.message.following, followers: r.message.followers }))}>
                {profile.following ? 'Abonné ✓' : 'S’abonner'}
              </button>
            )}
            {data.canModerate && (
              <button className="mini" onClick={() => act('verify', { handle: profile.handle },
                (r) => setProfile({ ...profile, verified: r.message === true, badge: r.message === true ? 'verified' : null }))}>
                {profile.verified ? 'Retirer le badge vérifié' : 'Certifier le compte'}
              </button>
            )}
          </div>
          {error && <div className="vibe-error">{error}</div>}
        </div>
        {profile.posts.length === 0 && <div className="empty">Aucun post pour l’instant.</div>}
        {profile.posts.map((p) => <Post key={p.id} p={{ ...p, badge: profile.badge }} actions={false} />)}
      </div>
    )
  } else if (tab === 'top') {
    body = (
      <div className="list">
        {!top && <div className="empty">Chargement…</div>}
        {top && (
          <>
            <h4 className="vibe-section">🔥 Posts de la semaine</h4>
            {top.posts.length === 0 && <div className="empty">Rien cette semaine. Lance la tendance.</div>}
            {top.posts.map((p) => <Post key={p.id} p={p} actions={false} />)}
            <h4 className="vibe-section">🏆 Créateurs les plus aimés (7 jours)</h4>
            {top.creators.map((c, i) => (
              <div key={c.handle} className="vibe-rank"><span className="vibe-pos">{i + 1}</span><Author h={c.handle} badge={c.badge} /><span className="muted small">♥ {c.likes} · {c.posts} post{c.posts > 1 ? 's' : ''}</span></div>
            ))}
            {top.races?.length > 0 && <h4 className="vibe-section">🏁 Courses de rue</h4>}
            {top.races?.map((r) => (
              <div key={r.id} className="vibe-race">
                <b>{r.label}</b>
                {r.top.length === 0 && <span className="muted small">Aucun temps</span>}
                {r.top.map((t, i) => <div key={i} className="vibe-rank"><span className="vibe-pos">{i + 1}</span><b>{t.name}</b><span className="muted small">{t.time}</span></div>)}
              </div>
            ))}
            <h4 className="vibe-section">⭐ Plus suivis</h4>
            {top.followers.map((f, i) => (
              <div key={f.handle} className="vibe-rank"><span className="vibe-pos">{i + 1}</span><Author h={f.handle} badge={f.badge} /><span className="muted small">{f.followers} abonnés</span></div>
            ))}
          </>
        )}
      </div>
    )
  } else {
    body = (
      <>
        <form className="vibe-composer" onSubmit={(e) => {
          e.preventDefault()
          if (draft.trim()) act('post', { content: draft }, () => { setDraft(''); feedRef.current?.scrollTo({ top: 0, behavior: 'smooth' }) })
        }}>
          <div className="vibe-me"><span onClick={() => openProfile(data.handle)}>@{data.handle}<Badge kind={data.badge} /></span>
            {data.title && <span className="vibe-title">{data.title}</span>}<span className="muted small vibe-count">{data.followers || 0} abonnés</span></div>
          <textarea rows={2} maxLength={data.maxLength} placeholder="Quoi de neuf à Los Santos ?" value={draft} onChange={(e) => setDraft(e.target.value)} />
          <div className="vibe-foot">
            <span className="muted small">{draft.length}/{data.maxLength}</span>
            <button className="primary slim" disabled={busy || !draft.trim()}>Publier</button>
          </div>
          {error && <div className="vibe-error">{error}</div>}
        </form>
        <div className="list" ref={feedRef}>
          {data.feed.length === 0 && <div className="empty">Personne n’a encore rien dit. Lance la conversation.</div>}
          {data.feed.map((p) => <Post key={p.id} p={p} />)}
        </div>
      </>
    )
  }

  const back = () => (profile ? setProfile(null) : onBack())
  return (
    <>
      <div className="app-header">
        <button className="back" onClick={back}>‹</button>
        <h2 className="vibe-logo">Vibe</h2>
        <div className="right" />
      </div>
      {data?.handle && !profile && (
        <div className="vibe-tabs">
          <button className={tab === 'feed' ? 'on' : ''} onClick={() => setTab('feed')}>Fil</button>
          <button className={tab === 'top' ? 'on' : ''} onClick={openTop}>Top semaine</button>
        </div>
      )}
      {body}
    </>
  )
}
