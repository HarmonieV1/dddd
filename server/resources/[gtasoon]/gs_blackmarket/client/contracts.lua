-- /contrats : tableau des contrats entre joueurs (gang ou réputation de rue).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end
local openBoard

local function post()
    local types = {}
    for k, v in pairs(Config.Contracts.types) do types[#types + 1] = { value = k, label = v } end
    local r = lib.inputDialog('Publier un contrat', {
        { type = 'select', label = 'Type', options = types, required = true },
        { type = 'input', label = 'Titre', required = true, max = 80 },
        { type = 'textarea', label = 'Détails (lieu, cible, délai…)', max = 400 },
        { type = 'number', label = 'Récompense (argent sale, bloquée)', min = Config.Contracts.minReward, max = Config.Contracts.maxReward, required = true },
    })
    if r then notify(lib.callback.await('gs_contracts:post', false, r[1], r[2], r[3], r[4])) end
end

local function detail(c)
    local options = {}
    if c.mine then
        if c.taken then options[#options + 1] = { title = 'Valider (payer le preneur)', icon = 'check', onSelect = function() notify(lib.callback.await('gs_contracts:close', false, c.id, 'done')) end }
        else options[#options + 1] = { title = 'Annuler (remboursé, commission perdue)', icon = 'xmark', onSelect = function() notify(lib.callback.await('gs_contracts:close', false, c.id, 'cancel')) end } end
    elseif c.takenByMe then
        options[#options + 1] = { title = 'Abandonner', icon = 'person-walking-arrow-right', onSelect = function() notify(lib.callback.await('gs_contracts:drop', false, c.id)) end }
    else
        options[#options + 1] = { title = 'Accepter le contrat', icon = 'handshake', onSelect = function() notify(lib.callback.await('gs_contracts:take', false, c.id)) end }
    end
    options[#options + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = function() openBoard() end }
    lib.registerContext({ id = 'gs_contract', title = ('#%d · %s · %d $'):format(c.id, c.kindLabel, c.reward), options = {
        { title = c.title, description = c.details ~= '' and c.details or 'Pas de détails.', readOnly = true, icon = 'file-signature' },
        table.unpack(options) } })
    lib.showContext('gs_contract')
end

function openBoard()
    local list, msg = lib.callback.await('gs_contracts:list', false)
    if not list then return notify(false, msg) end
    local options = { { title = 'Publier un contrat', icon = 'plus', onSelect = post } }
    for _, c in ipairs(list) do
        options[#options + 1] = { title = ('%s · %s'):format(c.kindLabel, c.title), icon = c.mine and 'user-secret' or c.takenByMe and 'person-running' or 'file-signature',
            description = ('%d $%s'):format(c.reward, c.mine and ' · ton contrat' or c.takenByMe and ' · en cours' or ''), arrow = true, onSelect = function() detail(c) end }
    end
    lib.registerContext({ id = 'gs_contracts', title = 'Contrats (rue)', options = options })
    lib.showContext('gs_contracts')
end

RegisterCommand('contrats', function() openBoard() end, false)
