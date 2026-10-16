// Actions de l'appli staff, rangées par usage. Le SERVEUR (Admin.remote) revérifie tout et journalise « Web · pseudo ».
// fields : ce que la boîte de dialogue demande avant l'envoi.
export const BAN_SPANS = [['1', '1 jour'], ['3', '3 jours'], ['7', '7 jours'], ['14', '14 jours'], ['30', '30 jours'], ['0', 'Définitif']]

export const GROUPS = [
  {
    id: 'help', title: 'Assistance', actions: [
      { name: 'heal', label: 'Soigner', icon: '✚' },
      { name: 'revive', label: 'Réanimer', icon: '♥' },
      { name: 'fixveh', label: 'Réparer le véhicule', icon: '🔧' },
      { name: 'clearheat', label: 'Effacer la recherche', icon: '★' },
      { name: 'unstuck', label: 'Coincé : dernier endroit sûr', icon: '⤒' },
      { name: 'tp', label: 'Téléporter…', icon: '➜', fields: [{ key: 'dest', label: 'Destination', type: 'dest' }] },
    ],
  },
  {
    id: 'control', title: 'Contrôle', actions: [
      { name: 'freeze', label: 'Geler', icon: '❄', when: (d) => !d.frozen },
      { name: 'unfreeze', label: 'Dégeler', icon: '☀', when: (d) => d.frozen },
      { name: 'message', label: 'Message privé', icon: '✉', fields: [{ key: 'text', label: 'Message (le joueur le voit en jeu)', type: 'textarea' }] },
      { name: 'note', label: 'Note staff', icon: '✎', fields: [{ key: 'text', label: 'Note (visible du staff seulement)', type: 'textarea' }] },
      { name: 'jail', label: 'Isoler', icon: '⛓', danger: true, when: (d) => !(d.jailedFor > 0),
        fields: [{ key: 'minutes', label: 'Durée (minutes)', type: 'minutes' }, { key: 'text', label: 'Motif (publié)', type: 'text' }] },
      { name: 'unjail', label: 'Libérer', icon: '🔓', when: (d) => d.jailedFor > 0 },
    ],
  },
  {
    id: 'sanction', title: 'Sanctions', actions: [
      { name: 'warn', label: 'Avertir', icon: '⚠', danger: true, fields: [{ key: 'text', label: 'Motif (publié)', type: 'text' }] },
      { name: 'kick', label: 'Expulser', icon: '⏏', danger: true, fields: [{ key: 'text', label: 'Motif (publié)', type: 'text' }] },
      { name: 'ban', label: 'Bannir', icon: '⛔', danger: true, fields: [{ key: 'days', label: 'Durée', type: 'days' }, { key: 'text', label: 'Motif (publié)', type: 'text' }] },
    ],
  },
]

/** Corps de la requête « act » à partir des valeurs saisies. */
export function payload(action, id, v) {
  const body = { name: action.name, id, text: v.text || '' }
  if (action.name === 'jail') body.extra = Number(v.minutes) || 15
  if (action.name === 'ban') body.extra = Number(v.days)
  if (action.name === 'tp') body.extra = v.dest && v.dest.startsWith('p:') ? { to: Number(v.dest.slice(2)) } : { place: Number(String(v.dest || '').slice(2)) }
  return body
}
