// RoadLine · écran de chargement V11.1
// « Précédemment à Los Santos » : envoyé par le serveur à la connexion (gs_city/server/recap.lua, handover FiveM).
// Sans données (serveur ancien, aperçu) : un résumé générique. Progression réelle envoyée par FiveM (loadProgress, 0 → 1).
const $ = (id) => document.getElementById(id)
const data = (window.nuiHandoverData && window.nuiHandoverData.roadline) || null

// ---- V11.2 : nuit (21 h → 6 h, heure du serveur), accueil personnalisé, bandeau Weazel ----
const hour = data && typeof data.hour === 'number' ? data.hour : new Date().getHours()
function night() { return hour >= 21 || hour < 6 }
if (night()) document.body.classList.add('night')
const me = data && data.me
if (me && me.firstname) {
  const away = me.days == null ? '' : me.days === 0 ? 'de retour aujourd’hui' : me.days === 1 ? 'absent depuis hier' : `absent depuis ${me.days} jours`
  $('welcome').innerHTML = `Bon retour<b>${escapeHtml(me.firstname)} ${escapeHtml(me.lastname || '')}</b>${[me.job, away].filter(Boolean).map(escapeHtml).join(' · ')}`
} else {
  $('welcome').innerHTML = `Bienvenue à<b>Los Santos</b>Ton histoire commence dans quelques secondes.`
}

// ---- Précédemment à Los Santos ----
const recap = data && data.lines && data.lines.length ? data.lines : [
  'La ville ne dort jamais : témoins, rumeurs et faits divers t’attendent.',
  'Les quartiers montent… ou coulent, selon ce que vous en faites.',
  'Une légende est peut-être en train de s’écrire ce soir.',
]
recap.forEach((line, i) => {
  const li = document.createElement('li')
  li.textContent = line
  $('recap').appendChild(li)
  setTimeout(() => li.classList.add('in'), 600 + i * 700)
})
if (data && data.hot && data.hot.length) {
  $('hot').innerHTML = data.hot.slice(0, 4).map((h) =>
    `<span class="${h.level >= 3 ? '' : 'l2'}">${h.level >= 3 ? '🔥' : '⚠'} ${escapeHtml(h.label)}</span>`).join('')
}
if (data && data.next) $('rdv').innerHTML = `Prochain rendez-vous : <b>${escapeHtml(data.next.label)}</b> · ${escapeHtml(data.next.dayName || '')} ${escapeHtml(data.next.from || '')}`
if (data) {
  $('chip-players').innerHTML = `<i class="dot"></i><b>${data.players}/${data.max}</b> en ville`
  const w = String(data.weather || '').toLowerCase()
  const icon = /orage|tonnerre/.test(w) ? '⛈' : /pluie|averse/.test(w) ? '🌧' : /neige|blizzard/.test(w) ? '❄' : /brouillard|brume/.test(w) ? '🌫' : /nuage|couvert/.test(w) ? '☁' : night() ? '☾' : '☀'
  $('chip-weather').innerHTML = `${icon} <b>${escapeHtml(data.weather || 'Los Santos')}</b>`
  $('chip-version').textContent = data.version || 'RoadLine'
} else {
  $('chip-players').style.display = 'none'; $('chip-weather').style.display = 'none'; $('chip-version').textContent = 'RoadLine RP'
}
function escapeHtml(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])) }

// Bandeau Weazel : les faits du jour + la une de la Gazette
const ticker = [...recap]
if (data && data.gazette) ticker.unshift(`La Gazette n°${data.gazette.number} : ${data.gazette.headline}`)
if (data && data.hot && data.hot[0]) ticker.push(`Prudence à ${data.hot[0].label} : le quartier est sous tension`)
ticker.push('Ce soir, la ville appartient à ceux qui l’écrivent')
$('ticker').innerHTML = [...ticker, ...ticker].map((t) => `<span>${escapeHtml(t)}</span>`).join('')

// ---- Cartes postales (signatures), façon bande-annonce ----
// [titre, texte, emblème, dégradé de la « photo »]
const cards = [
  ['La ville se souvient', 'Témoins, preuves, cicatrices : chaque acte laisse une trace. Même ta voiture a un carnet.', '👁', 'linear-gradient(135deg,#3a0f5c,#e43bd1)'],
  ['Les jurés de Los Santos', 'Ton téléphone vibre : tu es tiré au sort. Coupable ou non ? C’est toi qui décides.', '⚖', 'linear-gradient(135deg,#1a1440,#4fd8ff)'],
  ['Black-out', 'Un transformateur saboté, et tout un quartier plonge dans le noir. Pour quinze minutes.', '⚡', 'linear-gradient(135deg,#05020f,#2b0d45 60%,#ffc08f)'],
  ['La Gazette du dimanche', 'Chaque dimanche à 20 h, la semaine de la ville en une page. Seras-tu à la une ?', '📰', 'linear-gradient(135deg,#f3ead8,#9b1d3a)'],
  ['Les rumeurs deviennent vraies', 'Glisse un bruit au comptoir. Si assez de monde le répète… il arrive.', '🍸', 'linear-gradient(135deg,#2a0c4a,#ff5f6d)'],
  ['Lieux de mémoire', 'Un grand casse, une cavale légendaire, un mariage : la ville en garde une plaque.', '🕯', 'linear-gradient(135deg,#140a24,#ffc08f)'],
  ['Ville de jour, ville de nuit', 'Après 22 h, d’autres gens sortent. Les marchés de nuit ouvrent.', '🌙', 'linear-gradient(135deg,#0a0420,#a24bff)'],
  ['Zéro pay-to-win', 'Ici, l’argent se gagne en jeu. La boutique ne vend que du style.', '💎', 'linear-gradient(135deg,#ff2340,#a24bff)'],
]
let ci = Math.floor(Math.random() * cards.length)
cards.forEach(() => $('dots').appendChild(document.createElement('i')))
function showCard() {
  const [t, x, icon, bg] = cards[ci % cards.length]
  $('card-scene').style.background = bg
  $('card-scene').innerHTML = `<i>${icon}</i>`
  const card = $('card')
  card.classList.remove('swap'); void card.offsetWidth; card.classList.add('swap')
  $('card-title').textContent = t; $('card-text').textContent = x
  ;[...$('dots').children].forEach((d, k) => d.classList.toggle('on', k === ci % cards.length))
  ci++
}
showCard(); setInterval(showCard, 6500)

// ---- Astuces ----
const tips = [
  'Un crime sans témoin reste souvent un secret. La nuit et le brouillard sont tes alliés… ou ceux des autres.',
  'Que faire ? Ouvre ton téléphone (F1) : tout ce qui se passe maintenant en ville, GPS compris.',
  'Les prix bougent : si tout le monde achète de l’eau pendant la canicule, elle devient hors de prix.',
  'Les commerçants se souviennent de toi : un habitué est salué par son prénom.',
  'Une amende LSPD se paie avec /factures. Oui, même si tu roulais « juste un peu vite ».',
  'Le coucher de soleil dure plus longtemps chez nous. Profite de la golden hour.',
  'Un souci ? /report en jeu : le staff le reçoit tout de suite, même sur son téléphone.',
]
let ti = Math.floor(Math.random() * tips.length)
$('tip').textContent = tips[ti++ % tips.length]
setInterval(() => {
  $('tip').style.opacity = 0
  setTimeout(() => { $('tip').textContent = tips[ti++ % tips.length]; $('tip').style.opacity = 1 }, 400)
}, 7500)

// ---- Progression réelle ----
const stages = [[0.15, 'Connexion à Los Santos…'], [0.4, 'Chargement de la carte…'], [0.65, 'Réveil des habitants…'], [0.9, 'Allumage des néons…'], [1, 'Presque prêt…']]
window.addEventListener('message', (e) => {
  if (!e.data || e.data.eventName !== 'loadProgress') return
  const p = Math.max(0, Math.min(1, e.data.loadFraction || 0))
  $('fill').style.width = `${Math.round(p * 100)}%`
  $('pct').textContent = `${Math.round(p * 100)} %`
  $('status').textContent = (stages.find(([max]) => p <= max) || stages[stages.length - 1])[1]
})
