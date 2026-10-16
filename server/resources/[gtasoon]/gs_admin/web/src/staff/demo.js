// Données de DÉMONSTRATION (npm run dev uniquement, jamais servies par le serveur) : pour travailler l'interface hors ligne.
const now = () => Math.floor(Date.now() / 1000)
const P = [
  { id: 3, name: 'demo_alex', char: 'Alex Moreno', ping: 42, job: 'police', duty: true, heat: 0, staff: false, jailed: false, frozen: false, x: 441, y: -982 },
  { id: 7, name: 'demo_jade', char: 'Jade Kova', ping: 61, job: 'ambulance', duty: true, heat: 0, staff: false, jailed: false, frozen: false, x: 298, y: -584 },
  { id: 12, name: 'demo_sam', char: 'Sam Ortega', ping: 88, job: 'unemployed', duty: false, heat: 45, staff: false, jailed: false, frozen: false, x: -1300, y: -1100, replay: { ticket: 4, frames: 12 } },
  { id: 15, name: 'demo_lea', char: 'Léa Brun', ping: 35, job: 'cardealer', duty: true, heat: 0, staff: true, jailed: false, frozen: false, x: -40, y: -1100 },
  { id: 21, name: 'demo_tom', char: 'Tom Vidal', ping: 120, job: 'unemployed', duty: false, heat: 0, staff: false, jailed: true, frozen: false, x: 1850, y: 2600 },
  { id: 24, name: 'demo_nina', char: 'Nina Roux', ping: 54, job: 'taxi', duty: true, heat: 0, staff: false, jailed: false, frozen: true, x: 1853, y: 3686 },
]
const history = Array.from({ length: 48 }, (_, i) => ({ t: now() - (47 - i) * 300, n: Math.max(0, Math.round(8 + 6 * Math.sin(i / 6) + (i % 5))) }))
const OVERVIEW = () => ({
  who: 'Démo', players: P, history,
  tickets: [{ id: 4, src: 12, name: 'Sam Ortega', message: 'Un joueur me fonce dessus en boucle au parking.', time: now() - 420, status: 'open', online: true },
    { id: 5, src: 7, name: 'Jade Kova', message: 'Mon véhicule de service a disparu.', time: now() - 1600, status: 'claimed', claimedBy: 'Web · Modo', online: true }],
  logs: [{ staff: 'Web · Modo', action: 'freeze', target: 'Nina Roux [24]', details: 'Vérification', time: now() - 120 },
    { staff: 'Joe Morgan [2]', action: 'revive', target: 'Jade Kova [7]', time: now() - 900 },
    { staff: 'Discord · Prout', action: 'warn', target: 'Tom Vidal [21]', details: 'Conduite hors RP', time: now() - 2400 }],
  places: ['Hôpital Pillbox', 'Commissariat Mission Row', 'Mairie', 'Parking de Legion Square', 'Aéroport LSIA', 'Sandy Shores', 'Paleto Bay'],
  server: { players: P.length, max: 48, staffOnDuty: 2, version: 'V12.63 (démo)', weather: 'CLEAR', lives: true }, maxJail: 120, txadmin: '',
})
export async function demoApi(action, body) {
  if (action === 'login') return { ok: true, token: 'demo', who: body.pseudo || 'Démo' }
  if (action === 'overview') return { ok: true, data: OVERVIEW() }
  if (action === 'dossier') {
    const p = P.find((x) => x.id === body.id) || P[0]
    return { ok: true, data: { id: p.id, name: p.char, account: p.name, ping: p.ping, citizenid: 'DEMO' + p.id, level: p.staff ? 2 : 0, session: 3600,
      job: { name: p.job, label: p.job, onduty: p.duty }, contracts: { [p.job]: 1 }, heat: p.heat, frozen: p.frozen, jailedFor: p.jailed ? 600 : 0,
      money: { cash: 1250, bank: 48200 }, license: 'license:demo', notes: [{ kind: 'warn', text: 'Conduite hors RP', staff: 'Discord · Prout', time: now() - 86400 }] } }
  }
  if (action === 'bans') return { ok: true, data: [{ license: 'license:demo-ban', name: 'Demo Banni', reason: 'Triche (démo)', staff: 'Anti-triche', when: 'définitif' }] }
  if (action === 'moderation') return { ok: true, data: { locked: null, canLock: true, canOfflineBan: true, // V12.63 : modération avancée (démo)
    watch: [{ license: 'license:demo-w', name: 'Kevin Douteux', reason: 'Insultes répétées (démo)', staff: 'Web · Démo', at: 0, online: 7 }],
    departed: [{ license: 'license:demo-d', name: 'Rage Quit', account: 'rq_demo', ago: 140, session: 1800, reason: 'Quitté', banned: false }] } }
  if (action === 'frame' || action === 'replay') return { ok: false, text: 'Pas d\'écran en démo.' }
  return { ok: true, text: `${body.name || action} : fait (démo).` }
}
