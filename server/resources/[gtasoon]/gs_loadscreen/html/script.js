// Astuces tournantes + progression réelle envoyée par FiveM (loadProgress, 0 → 1).
const tips = [
  'Un crime sans témoin reste souvent un secret. La nuit et le brouillard sont tes alliés… ou ceux des autres.',
  'Les prix bougent : si tout le monde achète de l’eau pendant la canicule, elle devient hors de prix.',
  'En duo, tout se partage : la paie, les contrats… et la chaleur quand la police vous cherche.',
  'Jusqu’à 3 emplois par personnage. F6 pour passer de l’un à l’autre.',
  'Le Pôle Emploi (mairie) propose taxi, livreur et éboueur. Le métier le plus respecté de LS. Si, si.',
  'Néon (F3) : ton réseau social. Pas de lien, pas de pub, juste du RP.',
  'Tempête tropicale annoncée ? Rentre les flamants roses et évite les coupures de courant.',
  'Une amende LSPD se paie avec /factures. Oui, même si tu roulais « juste un peu vite ».',
  'Zéro pay-to-win ici : la boutique ne vend que du style, jamais d’avantage.',
  'Le coucher de soleil dure plus longtemps chez nous. Profite de la golden hour.',
]
const tipEl = document.getElementById('tip')
const fill = document.getElementById('fill')
const status = document.getElementById('status')
let i = Math.floor(Math.random() * tips.length)

function nextTip() {
  tipEl.style.opacity = 0
  setTimeout(() => { tipEl.textContent = tips[i++ % tips.length]; tipEl.style.opacity = 1 }, 400)
}
tipEl.textContent = tips[i++ % tips.length]
setInterval(nextTip, 7000)

const labels = [[0.2, 'Chargement de la carte…'], [0.5, 'Réveil des habitants…'], [0.8, 'Allumage des néons…'], [1, 'Presque prêt…']]
window.addEventListener('message', (e) => {
  if (!e.data || e.data.eventName !== 'loadProgress') return
  const p = Math.max(0, Math.min(1, e.data.loadFraction || 0))
  fill.style.width = `${Math.round(p * 100)}%`
  status.textContent = (labels.find(([max]) => p <= max) || labels[labels.length - 1])[1]
})
