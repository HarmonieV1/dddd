// Données de démo pour développer le panel dans un navigateur (npm run dev), hors jeu.
const now = Date.now() / 1000

export const DEMO = {
  level: 3, levelName: 'Admin', me: 1, onDuty: true, maxJail: 240,
  players: [
    { id: 1, name: 'Alpha Boss', account: 'Alpha', ping: 32, job: 'police', duty: true, heat: 0, staff: true, jailed: false },
    { id: 4, name: 'Vice Lucia', account: 'lucia_rp', ping: 58, job: 'mechanic', duty: false, heat: 45, staff: false, jailed: false },
    { id: 7, name: 'Jason Neon', account: 'jneon', ping: 71, job: 'unemployed', duty: false, heat: 80, staff: false, jailed: true },
  ],
  tickets: [
    { id: 12, src: 4, name: 'Vice Lucia [4]', message: 'Je suis bloqué sous la map près du port.', time: now - 95, status: 'open', online: true },
    { id: 11, src: 7, name: 'Jason Neon [7]', message: 'Un joueur m’a tué sans RP à Vespucci.', time: now - 600, status: 'claimed', claimedBy: 'Modo [3]', online: true },
  ],
  logs: [
    { staff: 'Alpha Boss [1]', action: 'jail', target: 'Jason Neon [7]', details: 'Isolé 30 min', time: now - 300 },
    { staff: 'Modo [3]', action: 'ticket_claim', target: null, details: 'Ticket #11 pris', time: now - 580 },
  ],
  server: { players: 3, maxPlayers: 48, staffOnDuty: 2, duty: { police: 1, ambulance: 0, mechanic: 0 }, weather: 'CLEAR', weatherEvent: null },
  weathers: ['CLEAR', 'CLOUDS', 'EXTRASUNNY', 'FOGGY', 'RAIN', 'THUNDER'],
  events: [{ id: 'storm', label: 'Tempête tropicale' }, { id: 'heatwave', label: 'Canicule' }, { id: 'fog', label: 'Brouillard épais' }],
}

export const DEMO_DOSSIER = {
  id: 4, name: 'Vice Lucia', account: 'lucia_rp', ping: 58, citizenid: 'ABC12345', level: 0, session: 5400,
  job: { name: 'mechanic', label: 'Mécano LS Customs', onduty: false }, contracts: { mechanic: 1, taxi: 0 },
  heat: 45, handle: 'vice_lucia', gang: 'ballas (grade 1)', duo: 'Jason Neon [7]', duoLevel: 2, frozen: false, jailedFor: 0,
  license: 'license:3f2a…', money: { cash: 1250, bank: 48200 },
  notes: [{ kind: 'warn', text: 'Conduite hors RP répétée', staff: 'Modo [3]', time: now - 86400 }],
}
