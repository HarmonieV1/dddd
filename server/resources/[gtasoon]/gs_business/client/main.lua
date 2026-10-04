-- gs_business (client) : comptoir (clients : carte ; employés : comptes ; patron : prix) et plan de travail (préparation).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function books(id)
    local d = lib.callback.await('gs_business:books', false, id)
    if not d then return notify(false, 'Réservé aux employés en service.') end
    local options = { { title = ('Caisse : %d $'):format(d.balance), description = ('Ventes du jour : %d $'):format(d.today), icon = 'cash-register', readOnly = true } }
    for _, l in ipairs(d.ledger) do
        options[#options + 1] = { title = l.kind == 'sale' and ('Vente · %d × %s · +%d $'):format(l.qty, l.item, l.amount) or ('Préparation · %s'):format(l.item),
            description = ('%s · %s'):format(l.who, l.date), icon = l.kind == 'sale' and 'arrow-down' or 'utensils', readOnly = true }
    end
    lib.registerContext({ id = 'gs_business_books', title = 'Comptabilité', menu = 'gs_business_counter', options = options })
    lib.showContext('gs_business_books')
end

AddEventHandler('gs_business:client:counter', function(id)
    local d = lib.callback.await('gs_business:menu', false, id)
    if not d then return end
    local options = {}
    if not d.staffed then options[1] = { title = d.double and ('La doublure de %s vous sert'):format(d.double) or 'Libre-service : le barman sert la carte de base',
        description = 'Aucun employé en service · prix majorés', icon = d.double and 'user-tie' or 'martini-glass', readOnly = true } end
    for _, it in ipairs(d.items) do
        options[#options + 1] = { title = ('%s · %d $'):format(it.label, it.price),
            description = not d.staffed and 'Servi par le barman' or (it.stock > 0 and ('En stock : %d'):format(it.stock) or 'Rupture'),
            icon = 'bag-shopping', disabled = it.stock == 0, onSelect = function()
                local r = lib.inputDialog(it.label, { { type = 'number', label = 'Quantité', default = 1, min = 1, max = math.min(10, it.stock), required = true } })
                if r then notify(lib.callback.await('gs_business:buy', false, id, it.item, r[1])) end
            end }
        if d.boss and d.staffed then
            options[#options + 1] = { title = '   Changer le prix', icon = 'tag', onSelect = function()
                local r = lib.inputDialog('Prix · ' .. it.label, { { type = 'number', label = 'Prix ($)', default = it.price, min = 1, max = 1000, required = true } })
                if r then notify(lib.callback.await('gs_business:setPrice', false, id, it.item, r[1])) end
            end }
        end
    end
    if d.employee then options[#options + 1] = { title = 'Comptabilité', icon = 'book', onSelect = function() books(id) end } end
    if d.canDouble then -- V9 : la doublure
        options[#options + 1] = d.hasDouble
            and { title = 'Reprendre ma place (retirer ma doublure)', icon = 'user-xmark', onSelect = function() notify(lib.callback.await('gs_business:double', false, 'clear', id)) end }
            or { title = 'Laisser ma doublure au comptoir', icon = 'user-tie', description = 'Un PNJ à ton apparence sert quand personne n\'est en service (meilleure part de la recette). Il peut être braqué.',
                onSelect = function() notify(lib.callback.await('gs_business:double', false, 'set', id)) end }
    end
    lib.registerContext({ id = 'gs_business_counter', title = d.label, options = options })
    lib.showContext('gs_business_counter')
end)

AddEventHandler('gs_business:client:craft', function(id)
    local b = Config.Businesses[id]
    local options = {}
    for item, p in pairs(b.products) do
        if p.needs then
            local needs = {}
            for ing, n in pairs(p.needs) do needs[#needs + 1] = ('%d × %s'):format(n, ing) end
            options[#options + 1] = { title = p.label, description = table.concat(needs, ', ') .. ' (dans la réserve)', icon = 'blender', onSelect = function()
                local ok, ms = lib.callback.await('gs_business:craftBegin', false, id, item)
                if not ok then return notify(false, ms) end
                if not lib.progressBar({ duration = ms, label = 'Préparation : ' .. p.label, canCancel = true,
                    anim = { scenario = 'PROP_HUMAN_BBQ' }, disable = { move = true, car = true, combat = true } }) then ClearPedTasks(cache.ped) return end
                ClearPedTasks(cache.ped)
                notify(lib.callback.await('gs_business:craftFinish', false))
            end }
        end
    end
    lib.registerContext({ id = 'gs_business_craft', title = 'Préparation · ' .. b.label, options = options })
    lib.showContext('gs_business_craft')
end)

CreateThread(function()
    for id, b in pairs(Config.Businesses) do
        exports.gs_markers:Add('gs_business:counter:' .. id, { coords = b.register, style = 'shop', label = b.label, event = 'gs_business:client:counter',
            args = { id }, prompt = 'Comptoir · ' .. b.label, reach = Config.Range, distance = 20.0 })
        exports.gs_markers:Add('gs_business:craft:' .. id, { coords = b.craft, style = 'job', label = 'Préparation', event = 'gs_business:client:craft',
            args = { id }, prompt = 'Préparer (employés)', reach = Config.Range, distance = 10.0 })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_business:') end
end)
