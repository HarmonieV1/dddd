-- Textes FR. [CONFIG] : modifier ici, jamais dans le code. L('clé', ...) formate avec string.format.
local strings = {
    -- Général
    unemployed = 'Sans emploi',
    error = 'Une erreur est survenue.',
    invalid = 'Action invalide.',
    db = 'Erreur base de données.',
    busy = 'Opération déjà en cours, réessaie.',
    slow_down = 'Doucement, tu vas trop vite.',
    too_far = 'Tu es trop loin.',
    duty_no_phone = 'Il te faut un téléphone pour prévenir ton employeur (sinon : au point de service).',
    action_done = 'Terminé.',
    player_not_found = 'Joueur introuvable.',
    not_self = 'Pas sur toi-même.',

    -- Contrats
    not_member = "Tu n'as pas de contrat pour ce job.",
    not_member_target = 'Cette personne ne travaille pas ici.',
    already = 'Déjà sous contrat',
    max_jobs = "Nombre maximum d'emplois atteint, démissionne d'abord.",
    target_max_jobs = "Cette personne a déjà le nombre maximum d'emplois.",
    switched = 'Tu es maintenant : %s.',
    joined = 'Bienvenue chez %s !',
    resigned = 'Tu as démissionné de %s.',
    fired_notify = 'Tu as été licencié de %s.',
    promoted_notify = 'Ton grade chez %s : %s.',

    -- Service
    not_on_duty = 'Tu dois être en service.',
    duty_on = 'Prise de service : %s.',
    duty_off = 'Fin de service.',
    on_duty = 'En service',
    off_duty = 'Hors service',

    -- Direction
    not_boss = 'Accès réservé à la direction.',
    grade_invalid = 'Grade invalide.',
    grade_too_low = 'Grade insuffisant.',
    grade_updated = 'Grade mis à jour.',
    fired = 'Employé licencié.',
    amount_invalid = 'Montant invalide.',
    not_enough_money = "Pas assez d'argent liquide.",
    not_enough_bank = 'Solde bancaire insuffisant.',
    society_empty = 'Fonds de la caisse insuffisants.',
    deposit_ok = '%s $ déposés dans la caisse.',
    withdraw_ok = '%s $ retirés de la caisse.',
    offer_sent = 'Offre envoyée.',
    offer_title = "Offre d'emploi",
    offer_content = '**%s** te propose un poste chez **%s** (%s). Tu acceptes ?',
    offer_expired = 'Offre expirée.',
    offer_declined = 'Offre refusée.',
    offer_accepted = "%s a rejoint l'équipe.",
    accept = 'Accepter',
    decline = 'Refuser',

    -- Paie
    allowance = 'Allocation',
    pay_received = 'Paie reçue : %s $ (%s).',
    pay_afk = "Pas de paie : tu n'as pas bougé depuis la dernière.",
    pay_society_empty = 'Pas de paie : la caisse de ta boîte est vide.',

    -- Garage
    vehicle_out = 'Véhicule sorti.',
    vehicle_stored = 'Véhicule rangé.',
    vehicle_already_out = 'Tu as déjà un véhicule de service sorti.',
    vehicle_too_far = 'Ramène le véhicule au garage.',
    no_vehicle = "Tu n'as pas de véhicule de service.",
    spawn_blocked = 'La place de sortie est encombrée.',
    spawn_failed = 'Impossible de sortir le véhicule.',
    missing_item = 'Il te manque : %s.',

    -- Factures
    bill_sent = 'Facture envoyée.',
    bill_received = 'Nouvelle facture %s : %s $ (%s). Tape /factures pour payer.',
    bill_paid = 'Facture payée : %s $.',
    bill_paid_issuer = 'Commission sur facture : +%s $.',
    bill_not_found = 'Facture introuvable.',
    bill_pay_confirm = 'Payer **%s $** à %s ?',
    too_many_bills = 'Cette personne a trop de factures impayées.',
    no_bills = 'Aucune facture en attente.',

    -- Missions
    mission_started = 'Mission lancée, suis le GPS.',
    mission_already = 'Mission déjà en cours.',
    mission_cooldown = 'Souffle un peu avant la prochaine mission.',
    mission_need_vehicle = 'Il te faut ton véhicule de service à proximité.',
    mission_suspicious = 'Mission annulée : trajet incohérent.',
    mission_step_paid = '+%s $',
    mission_done = 'Mission terminée : %s $ gagnés.',
    mission_cancelled = 'Mission annulée.',
    mission_press = '[E] %s (%d/%d)',

    -- Menus
    menu_title = 'Mes emplois',
    menu_active = 'Actif : %s',
    menu_switch = 'Passer %s',
    menu_duty = 'Prendre / quitter le service',
    menu_mission_start = 'Lancer une mission',
    menu_mission_cancel = 'Annuler la mission',
    menu_bill = 'Facturer la personne la plus proche',
    menu_unemployed = 'Passer sans emploi',
    menu_resign = 'Démissionner',
    menu_resign_confirm = 'Démissionner de **%s** ? Ton grade sera perdu.',
    menu_bills = 'Mes factures',
    job_center = 'Pôle Emploi',
    zone_duty = 'Prendre / quitter le service',
    zone_boss = 'Direction',
    zone_garage = 'Garage de service',
    zone_job_center = 'Pôle Emploi',
    garage_store = 'Ranger le véhicule',
    boss_society = 'Caisse : %s $',
    boss_deposit = 'Déposer',
    boss_withdraw = 'Retirer',
    boss_recruit = 'Recruter',
    boss_employees = 'Employés (%d)',
    boss_set_grade = 'Changer le grade',
    boss_fire = 'Licencier',
    boss_fire_confirm = 'Licencier **%s** ?',
    no_one_nearby = 'Personne à proximité.',
    citizen_id = 'Citoyen #%s',
    player = 'Joueur',
    grade = 'Grade',
    amount = 'Montant ($)',
    reason = 'Motif',
    online = 'En ligne',
    offline = 'Hors ligne',
}

function L(key, ...)
    local s = strings[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end
