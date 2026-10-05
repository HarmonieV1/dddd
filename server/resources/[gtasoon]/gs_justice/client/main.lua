-- gs_justice (client) : /tribunal (juges, avocats, police) : rôle des audiences, ouvrir une affaire, rendre un verdict,
-- demander l'accès au casier d'un client. Consentement du client par boîte de dialogue.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function pickPlayer(radius)
    local list = {}
    for _, pid in ipairs(lib.getNearbyPlayers(GetEntityCoords(cache.ped), radius, false)) do
        local id = GetPlayerServerId(pid.id)
        list[#list + 1] = { value = tostring(id), label = ('[%d] %s'):format(id, GetPlayerName(pid.id)) }
    end
    return list
end

local function openCase()
    local people = pickPlayer(30.0)
    if #people == 0 then return notify(false, 'Personne dans la salle.') end
    local lawyers = { { value = '', label = 'Aucun avocat' } }
    for _, p in ipairs(people) do lawyers[#lawyers + 1] = p end
    local r = lib.inputDialog('Nouvelle affaire', {
        { type = 'select', label = 'Prévenu', options = people, required = true },
        { type = 'input', label = 'Chef d\'accusation', required = true, max = 200 },
        { type = 'select', label = 'Avocat de la défense', options = lawyers },
    })
    if r then notify(lib.callback.await('gs_justice:open', false, tonumber(r[1]), r[2], tonumber(r[3] or ''))) end
end

local function verdict(c)
    local r = lib.inputDialog(('Verdict · affaire #%d'):format(c.id), {
        { type = 'select', label = 'Décision', required = true, options = { { value = 'guilty', label = 'Coupable' }, { value = 'acquit', label = 'Relaxe' } } },
        { type = 'number', label = 'Amende ($, 0 = aucune)', default = 0, min = 0 },
        { type = 'number', label = 'Prison (minutes, 0 = aucune)', default = 0, min = 0 },
    })
    if r then notify(lib.callback.await('gs_justice:verdict', false, c.id, r[1], r[2], r[3])) end
end

-- V10.1 · Pièces du dossier : verser une photo / un scellé (police, avocat), le juge retient ou écarte
local STATUS = { pending = { 'En attente', '#ffd23f' }, retained = { 'Retenue', '#5aff8c' }, rejected = { 'Écartée', '#ff5470' } }
local function photos()
    local list = {}
    local ok, items = pcall(function() return exports.ox_inventory:Search('slots', Config.Pieces.photoItem) end) -- [API] ox_inventory
    for _, it in ipairs(ok and items or {}) do
        if it.metadata and it.metadata.photo then list[#list + 1] = { value = it.metadata.photo, label = it.metadata.label or 'Photo' } end
    end
    return list
end

local function caseMenu(c, d)
    local ok, list = lib.callback.await('gs_justice:pieces', false, 'list', c.id)
    local options = {}
    if d.judge then options[#options + 1] = { title = 'Rendre le verdict', icon = 'gavel', onSelect = function() verdict(c) end } end
    if d.judge then options[#options + 1] = { title = 'Convoquer un jury', icon = 'users', description = '5 citoyens tirés au sort votent coupable / non coupable (3 min)',
        onSelect = function() notify(lib.callback.await('gs_justice:jury', false, c.id)) end } end
    options[#options + 1] = { title = 'Verser une photo', icon = 'image', description = 'La photo reste sous la garde du tribunal', onSelect = function()
        local l = photos()
        if #l == 0 then return notify(false, 'Aucune photo sur toi.') end
        local r = lib.inputDialog('Verser une photo', { { type = 'select', label = 'Photo', options = l, required = true } })
        if r then notify(lib.callback.await('gs_justice:pieces', false, 'deposit', c.id, 'photo', r[1])) end
    end }
    options[#options + 1] = { title = 'Verser un scellé analysé', icon = 'box-archive', description = 'Numéro du scellé (labo de la police)', onSelect = function()
        local r = lib.inputDialog('Verser un scellé', { { type = 'number', label = 'N° du scellé', required = true, min = 1 } })
        if r then notify(lib.callback.await('gs_justice:pieces', false, 'deposit', c.id, 'seal', r[1])) end
    end }
    for _, p in ipairs(ok and list or {}) do
        local st = STATUS[p.status] or STATUS.pending
        options[#options + 1] = { title = ('Pièce n°%d · %s'):format(p.id, st[1]), icon = p.kind == 'photo' and 'image' or 'box-archive', iconColor = st[2],
            description = ('%s (versée par %s)'):format(p.text, p.by), readOnly = not d.judge, onSelect = d.judge and function()
                local a = lib.alertDialog({ header = ('Pièce n°%d'):format(p.id), content = p.text, centered = true, cancel = true,
                    labels = { confirm = 'Retenir', cancel = 'Écarter' } })
                notify(lib.callback.await('gs_justice:pieces', false, 'decide', c.id, p.id, a == 'confirm'))
            end or nil }
    end
    lib.registerContext({ id = 'gs_justice_case', title = ('Affaire #%d · %s'):format(c.id, c.defendant_name), menu = 'gs_justice', options = options })
    lib.showContext('gs_justice_case')
end

RegisterCommand(Config.Command, function()
    local d = lib.callback.await('gs_justice:cases', false)
    if not d then return notify(false, 'Réservé aux juges, avocats et policiers en service.') end
    local options = {}
    if d.judge then options[#options + 1] = { title = 'Ouvrir une affaire', icon = 'gavel', onSelect = openCase } end
    if d.lawyer then options[#options + 1] = { title = 'Consulter le casier d\'un client (avec son accord)', icon = 'folder-open', onSelect = function()
        local people = pickPlayer(5.0)
        if #people == 0 then return notify(false, 'Aucun client à côté de toi.') end
        local r = lib.inputDialog('Client', { { type = 'select', label = 'Client', options = people, required = true } })
        if r then notify(lib.callback.await('gs_justice:requestRecords', false, tonumber(r[1]))) end
    end } end
    for _, c in ipairs(d.cases) do
        local open = c.status == 'open'
        options[#options + 1] = { title = ('#%d · %s'):format(c.id, c.defendant_name), icon = open and 'scale-unbalanced' or 'scale-balanced',
            iconColor = open and '#ffd23f' or '#6b6380',
            description = ('%s · juge %s%s · %s%s'):format(c.charge, c.judge, c.lawyer ~= '' and (' · avocat ' .. c.lawyer) or '', c.date, open and '' or (' · ' .. c.verdict)),
            arrow = open, onSelect = open and function() caseMenu(c, d) end or nil, readOnly = not open }
    end
    lib.registerContext({ id = 'gs_justice', title = 'Tribunal de Los Santos', options = options })
    lib.showContext('gs_justice')
end, false)

RegisterNetEvent('gs_justice:client:consent', function(lawyer)
    local answer = lib.alertDialog({ header = 'Accès à ton casier', content = ('Ton avocat **%s** demande à consulter ton casier judiciaire.'):format(lawyer),
        centered = true, cancel = true, labels = { confirm = 'Accepter', cancel = 'Refuser' } })
    lib.callback.await('gs_justice:consent', false, answer == 'confirm')
end)

RegisterNetEvent('gs_justice:client:records', function(client, records)
    local options = {}
    for _, r in ipairs(records or {}) do
        options[#options + 1] = { title = r.charge, icon = 'scale-balanced', readOnly = true,
            description = ('%s · %s%s · %s'):format(r.date or '', (r.fine or 0) > 0 and (r.fine .. ' $ ') or '', (r.jail or 0) > 0 and (r.jail .. ' min') or '', r.officer or '') }
    end
    if #options == 0 then options[1] = { title = 'Casier vierge', icon = 'circle-check', readOnly = true } end
    lib.registerContext({ id = 'gs_justice_records', title = 'Casier de ' .. client, options = options })
    lib.showContext('gs_justice_records')
end)

CreateThread(function()
    exports.gs_markers:Add('gs_justice:court', { coords = Config.Court, style = 'hidden', prompt = 'Tribunal : /tribunal' })
end)
