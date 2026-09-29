-- gs_economy (serveur) : source de vérité des prix. Tout achat / revente passe par ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Market = { pressure = {}, events = {}, dirty = false }

--- Multiplicateur d'événement courant pour un item.
function Market.eventMult(item)
    local m = 1.0
    for id in pairs(Market.events) do
        m = m * ((Config.EventMultipliers[id] or {})[item] or 1.0)
    end
    return m
end

function Market.buyPrice(item) return Pricing.buyPrice(item, Market.pressure[item], Market.eventMult(item)) end
function Market.sellPrice(item) return Pricing.sellPrice(item, Market.pressure[item], Market.eventMult(item)) end

function Market.push(item, delta)
    local def = Config.Items[item]
    Market.pressure[item] = (Market.pressure[item] or 0) + delta / def.volume
    Market.dirty = true
end

--- Retour vers l'équilibre.
function Market.tick()
    for item, p in pairs(Market.pressure) do
        local new = p * (1 - Config.DecayPerTick)
        if math.abs(new) < 0.001 then new = nil end
        Market.pressure[item] = new
    end
    Market.dirty = true
end

--- Prix affichables pour une liste d'items.
function Market.quote(items, selling)
    local list = {}
    for _, item in ipairs(items) do
        list[#list + 1] = {
            item = item,
            label = Config.Items[item].label,
            price = selling and Market.sellPrice(item) or Market.buyPrice(item),
            trend = Pricing.trend(item, Market.pressure[item], Market.eventMult(item)),
        }
    end
    return list
end

local function listHas(list, item)
    for _, i in ipairs(list) do if i == item then return true end end
    return false
end

local function near(src, place)
    return Security:InRange(src, place.coords, Config.InteractRadius + Config.ServerTolerance)
end

local function validQty(q)
    return type(q) == 'number' and q == math.floor(q) and q >= 1 and q <= Config.MaxQuantity
end

lib.callback.register('gs_economy:quote', function(src, kind, index)
    if not Security:RateLimit(src, 'gs_economy:quote', 10, 10000) then return nil end
    local place = (kind == 'sell' and Config.Resellers or Config.Shops)[index]
    if not place or not near(src, place) then return nil end
    return Market.quote(place.items, kind == 'sell')
end)

lib.callback.register('gs_economy:buy', function(src, index, item, qty)
    if not Security:RateLimit(src, 'gs_economy:buy', 5, 10000) then return false, 'Doucement.' end
    local shop = Config.Shops[index]
    qty = tonumber(qty)
    if not shop or not listHas(shop.items, item) or not validQty(qty) then return false, 'Achat invalide.' end
    if Config.Items[item].buy == false then return false, 'Achat invalide.' end
    if not near(src, shop) then return false, 'Tu es trop loin.' end
    if not Bridge:CanCarry(src, item, qty) then return false, 'Tu ne peux pas porter ça.' end

    local total = Market.buyPrice(item) * qty
    local paid = Bridge:RemoveMoney(src, 'cash', total, 'achat ' .. item) and 'cash'
        or (Bridge:RemoveMoney(src, 'bank', total, 'achat ' .. item) and 'bank')
    if not paid then return false, ('Il te faut %d $.'):format(total) end
    if not Bridge:AddItem(src, item, qty) then
        Bridge:AddMoney(src, paid, total, 'remboursement achat')
        return false, 'Erreur inventaire, remboursé.'
    end
    Market.push(item, qty)
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'shop_buy') end
    return true, ('%d × %s pour %d $.'):format(qty, Config.Items[item].label, total)
end)

lib.callback.register('gs_economy:sell', function(src, index, item, qty)
    if not Security:RateLimit(src, 'gs_economy:sell', 5, 10000) then return false, 'Doucement.' end
    local reseller = Config.Resellers[index]
    qty = tonumber(qty)
    if not reseller or not listHas(reseller.items, item) or not validQty(qty) then return false, 'Revente invalide.' end
    if not near(src, reseller) then return false, 'Tu es trop loin.' end

    local unit = Market.sellPrice(item)
    if unit < 1 then return false, 'Plus personne n\'en veut.' end
    if Bridge:GetItemCount(src, item) < qty or not Bridge:RemoveItem(src, item, qty) then
        return false, 'Tu n\'as pas assez de ' .. Config.Items[item].label .. '.'
    end
    Bridge:AddMoney(src, 'cash', unit * qty, 'revente ' .. item)
    Market.push(item, -qty)
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'sell') end
    return true, ('%d × %s revendus %d $.'):format(qty, Config.Items[item].label, unit * qty)
end)

-- Événements météo ---------------------------------------------------------------------------------
AddEventHandler('gs_weather:server:eventStarted', function(id) Market.events[id] = true end)
AddEventHandler('gs_weather:server:eventEnded', function(id) Market.events[id] = nil end)

--- Désactive proprement les items absents d'ox_inventory (sinon achats en erreur).
local function validateItems()
    for item in pairs(Config.Items) do
        if not Bridge:ItemExists(item) then
            print(('^3[gs_economy] item "%s" absent d\'ox_inventory : retiré des commerces^7'):format(item))
            Config.Items[item] = nil
        end
    end
    for _, list in ipairs({ Config.Shops, Config.Resellers }) do
        for _, place in ipairs(list) do
            for i = #place.items, 1, -1 do
                if not Config.Items[place.items[i]] then table.remove(place.items, i) end
            end
        end
    end
end

function Market.init()
    validateItems()
    for item, p in pairs(Store.load()) do
        if Config.Items[item] then Market.pressure[item] = p end
    end
    if GetResourceState('gs_weather') == 'started' then
        local ev = exports.gs_weather:GetEvent()
        if ev then Market.events[ev] = true end
    end
end

local function save()
    if not Market.dirty then return end
    Market.dirty = false
    Store.save(Market.pressure)
end

CreateThread(function()
    Market.init()
    local nextTick = os.time() + Config.TickMinutes * 60
    while true do
        Wait(Config.SaveMinutes * 60000)
        if os.time() >= nextTick then
            Market.tick()
            nextTick = os.time() + Config.TickMinutes * 60
        end
        save()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then save() end
end)

lib.addCommand('marche', { help = 'Prix actuels du marché (staff)', restricted = 'group.admin' }, function(src)
    local lines = {}
    for item in pairs(Config.Items) do
        lines[#lines + 1] = ('%s %d$/%d$ (p=%.2f)'):format(item, Market.buyPrice(item), Market.sellPrice(item), Market.pressure[item] or 0)
    end
    table.sort(lines)
    local text = table.concat(lines, ' | ')
    if src == 0 then print(text) else TriggerClientEvent('ox_lib:notify', src, { description = text, duration = 15000 }) end
end)

-- API pour d'autres commerces (garages, armureries...) ----------------------------------------------
exports('GetBuyPrice', Market.buyPrice)
exports('GetSellPrice', Market.sellPrice)
exports('RecordBuy', function(item, qty) if Config.Items[item] and qty > 0 then Market.push(item, qty) end end)
exports('RecordSell', function(item, qty) if Config.Items[item] and qty > 0 then Market.push(item, -qty) end end)
