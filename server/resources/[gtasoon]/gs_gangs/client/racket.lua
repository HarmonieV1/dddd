-- gs_gangs (client) · V9 racket : /racket à la caisse d'un commerce de joueur (gang : réclamer, faire passer le message ;
-- patron : voir / arrêter la protection). Le patron reçoit l'offre en direct et choisit.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function act(...) return lib.callback.await('gs_gangs:racket', false, ...) end

RegisterCommand('racket', function()
    local i = act('info')
    if not i then return notify(false, 'Va à la caisse d\'un commerce (bar, club…).') end
    local options = {}
    if i.deal then
        options[#options + 1] = { title = ('Protégé par les %s'):format(i.deal.gang), icon = 'shield-halved', readOnly = true,
            description = ('%d $ par semaine · prochain prélèvement dans %d j'):format(i.deal.amount, i.deal.days) }
        if i.owner then
            options[#options + 1] = { title = 'Arrêter de payer', icon = 'hand', iconColor = '#ff5470', description = 'Ils auront 30 min pour se venger.',
                onSelect = function() notify(act('stop', i.biz)) end }
        end
    end
    if i.canDemand then
        options[#options + 1] = { title = 'Proposer une « protection »', icon = 'sack-dollar', description = ('%d à %d $ par semaine, pris sur la caisse du commerce'):format(i.min, i.max),
            onSelect = function()
                local r = lib.inputDialog('Protection', { { type = 'number', label = 'Montant par semaine ($)', min = i.min, max = i.max, required = true } })
                if r then notify(act('demand', r[1])) end
            end }
    end
    if i.canPunish then
        options[#options + 1] = { title = 'Faire passer le message', icon = 'hammer', iconColor = '#ff5470', description = 'Vitrine cassée, dégâts sur la caisse. Les témoins parleront.',
            onSelect = function()
                if not lib.progressBar({ duration = 6000, label = 'Saccage…', canCancel = true, anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
                    disable = { move = true, car = true } }) then return end
                notify(act('punish'))
            end }
    end
    if #options == 0 then options[1] = { title = i.label, description = 'Rien à faire ici.', icon = 'store', readOnly = true } end
    lib.registerContext({ id = 'gs_racket', title = i.label, options = options })
    lib.showContext('gs_racket')
end, false)

RegisterNetEvent('gs_gangs:client:racketOffer', function(o)
    lib.registerContext({ id = 'gs_racket_offer', title = ('Les %s veulent « protéger » le %s'):format(o.gang, o.label), options = { -- Échap = pas de réponse (l'offre expire)
        { title = ('Payer %d $ tous les %d jours'):format(o.amount, o.every), icon = 'sack-dollar', description = 'Prélevé sur la caisse du commerce.',
            onSelect = function() notify(act('answer', o.biz, 'accept')) end },
        { title = 'Refuser', icon = 'xmark', description = 'Ils risquent de revenir casser la vitrine.', onSelect = function() notify(act('answer', o.biz, 'refuse')) end },
        { title = 'Refuser et prévenir la police', icon = 'phone', onSelect = function() notify(act('answer', o.biz, 'police')) end },
    } })
    lib.showContext('gs_racket_offer')
end)
