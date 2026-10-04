-- gs_accords (client) : /contrat → rédiger un contrat pour la personne en face, voir ses contrats, y mettre fin.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function nearestPlayer()
    local me, best, bd = GetEntityCoords(cache.ped), nil, Config.Range
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= cache.playerId then
            local d = #(GetEntityCoords(GetPlayerPed(p)) - me)
            if d <= bd then best, bd = GetPlayerServerId(p), d end
        end
    end
    return best
end

local function draft(kind)
    local T = Config.Types[kind]
    local target = nearestPlayer()
    if not target then return notify(false, 'Approche-toi de la personne (face à face).') end
    local L = Config.Limits
    local fields
    if T.money then
        fields = {
            { type = 'number', label = kind == 'loan' and 'Somme prêtée ($)' or 'Montant de chaque échéance ($)', min = L.amount[1], max = L.amount[2], required = true },
            { type = 'number', label = 'Nombre d\'échéances', min = L.count[1], max = L.count[2], default = 4, required = true },
            { type = 'number', label = 'Tous les … jours', min = L.every[1], max = L.every[2], default = 7, required = true },
        }
        if kind == 'loan' then fields[#fields + 1] = { type = 'number', label = 'Intérêts (%)', min = 0, max = math.floor(T.maxRate * 100), default = 10 } end
    else
        fields = {}
    end
    fields[#fields + 1] = { type = 'input', label = 'Clause libre (facultatif)', max = 200 }
    local r = lib.inputDialog(T.label, fields)
    if not r then return end
    local data = { kind = kind, terms = r[#r] }
    if T.money then data.amount, data.count, data.every = r[1], r[2], r[3] data.rate = kind == 'loan' and (tonumber(r[4]) or 0) / 100 or 0 end
    notify(lib.callback.await('gs_accords:propose', false, target, data))
end

local function mine()
    local list = lib.callback.await('gs_accords:mine', false) or {}
    local o = {}
    for _, c in ipairs(list) do
        local status = c.status == 'dispute' and ' · LITIGE' or ''
        o[#o + 1] = { title = ('n°%d · %s%s'):format(c.id, c.label, status), icon = c.icon, iconColor = c.status == 'dispute' and '#ff5470' or nil,
            description = c.text .. (c.money and ('\nPayé : %d/%d · prochaine échéance %d $'):format(c.paid, c.total, c.amount) or ''),
            readOnly = not c.mine }
        if c.mine then
            o[#o + 1] = { title = c.asked and '   ↳ Accepter la fin demandée' or (c.payee and '   ↳ Mettre fin (renoncer au reste)' or '   ↳ Demander la fin'),
                icon = 'file-circle-xmark', onSelect = function()
                    if lib.alertDialog({ header = ('Contrat n°%d'):format(c.id), content = 'Mettre fin à ce contrat ?', centered = true, cancel = true }) == 'confirm' then
                        notify(lib.callback.await('gs_accords:terminate', false, c.id))
                    end
                end }
        end
    end
    if #o == 0 then o[1] = { title = 'Aucun contrat en cours', icon = 'file', readOnly = true } end
    lib.registerContext({ id = 'gs_accords_mine', title = 'Mes contrats', menu = 'gs_accords', options = o })
    lib.showContext('gs_accords_mine')
end

RegisterCommand('contrat', function()
    local o = { { title = 'Mes contrats', icon = 'folder-open', arrow = true, onSelect = mine } }
    for _, k in ipairs({ 'loan', 'salary', 'rent' }) do -- le mariage, c'est à la mairie (gs_civil)
        local T = Config.Types[k]
        o[#o + 1] = { title = 'Rédiger : ' .. T.label, icon = T.icon, description = T.help, onSelect = function() draft(k) end }
    end
    lib.registerContext({ id = 'gs_accords', title = 'Contrats signés', options = o })
    lib.showContext('gs_accords')
end, false)

RegisterNetEvent('gs_accords:client:offer', function(d)
    local choice = lib.alertDialog({ header = ('%s · proposé par %s'):format(d.label, d.from), content = d.text .. '\n\nLe serveur appliquera ce contrat (prélèvements automatiques, retards majorés, litige au tribunal).',
        centered = true, cancel = true, labels = { confirm = 'Signer', cancel = 'Refuser' } })
    notify(lib.callback.await('gs_accords:sign', false, choice == 'confirm'))
end)
