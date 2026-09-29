-- gs_bank (client) : ox_target sur les props de distributeurs, [E] aux guichets, menu ox_lib (solde, retrait, dépôt, historique).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local fmt = function(n) return tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '') end

local function openBank(kind, coords)
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    local info = lib.callback.await('gs_bank:info', false, kind, coords)
    if not info then return notify(false, 'Service indisponible ici.') end
    local function ask(action, title)
        local r = lib.inputDialog(title, { { type = 'number', label = 'Montant ($)', min = 1, max = info.perOperation, required = true } })
        if not r then return end
        if action == 'withdraw' then notify(lib.callback.await('gs_bank:withdraw', false, kind, coords, r[1]))
        else notify(lib.callback.await('gs_bank:deposit', false, kind, coords, r[1])) end
        openBank(kind, coords)
    end
    local options = {
        { title = ('Compte : %s $'):format(fmt(info.bank)), description = ('Liquide : %s $'):format(fmt(info.cash)), icon = 'building-columns', readOnly = true },
        { title = 'Retirer', icon = 'money-bill-transfer', description = ('Reste aujourd\'hui : %s $ · max %s $ par opération'):format(fmt(info.leftToday), fmt(info.perOperation)),
          onSelect = function() ask('withdraw', 'Retrait') end },
        { title = 'Déposer', icon = 'piggy-bank', onSelect = function() ask('deposit', 'Dépôt') end },
    }
    for _, h in ipairs(info.history) do
        options[#options + 1] = { title = ('%s%s $'):format(h.amount > 0 and '+' or '', fmt(h.amount)), icon = h.amount > 0 and 'arrow-down' or 'arrow-up',
            iconColor = h.amount > 0 and '#5aff8c' or '#ff8a3d', readOnly = true, description = ('%s · solde %s $'):format(h.date, fmt(h.balance)) }
    end
    lib.registerContext({ id = 'gs_bank_menu', title = info.place == 'atm' and 'Distributeur' or 'Guichet', options = options })
    lib.showContext('gs_bank_menu')
end

AddEventHandler('gs_bank:client:counter', function() openBank('counter') end)

CreateThread(function()
    exports.ox_target:addModel(Config.AtmModels, { { -- [API] ox_target
        name = 'gs_bank:atm', icon = 'fa-solid fa-credit-card', label = 'Distributeur', distance = 1.8,
        onSelect = function(data)
            local c = GetEntityCoords(data.entity)
            openBank('atm', { x = c.x, y = c.y, z = c.z })
        end,
    } })
    for i, c in ipairs(Config.Counters) do
        exports.gs_markers:Add('gs_bank:counter:' .. i, { coords = c.coords, style = 'shop', label = c.label, event = 'gs_bank:client:counter',
            prompt = 'Guichet · ' .. c.label, distance = 15.0, reach = 2.2 })
        local b = AddBlipForCoord(c.coords.x, c.coords.y, c.coords.z)
        SetBlipSprite(b, 108) SetBlipColour(b, 2) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(c.label) EndTextCommandSetBlipName(b)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_bank:') end
end)
