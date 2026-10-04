-- gs_business (serveur) : préparation (ingrédients retirés de la réserve, produit ajouté à la réserve, durée réelle),
-- caisse client (stock réel de la réserve, prix du patron, argent versé à la caisse du job), comptabilité.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Business = { prices = {}, pending = {} }

local function def(id) return Config.Businesses[id] end
local function staffOnDuty(id)
    return #JobsApi:GetOnDutyPlayers(id) > 0
end
local function isEmployee(src, id) return JobsApi:IsOnDutyAs(src, id) == true end
local function isBoss(src, id)
    local j = Bridge:GetJob(src)
    return j and j.name == id and j.onduty and (j.isboss or j.grade >= 2)
end
local function isOwner(src, id) -- patron, en service ou non
    local j = Bridge:GetJob(src)
    return j ~= nil and j.name == id and (j.isboss == true or (tonumber(j.grade) or 0) >= 2)
end
local function name(src) return Bridge:GetName(src) or GetPlayerName(src) or '?' end

function Business.price(id, item)
    local p = Business.prices[id] and Business.prices[id][item]
    return p or def(id).products[item].price
end

local NPC_LABELS = { beer = 'Bière', sprunk = 'Sprunk', water = 'Eau' }

--- Carte pour le client. Employé en service : produits préparés (stock réel de la réserve). Sinon : libre-service,
--- un barman PNJ sert la carte de base (stock illimité, prix majorés).
function Business.menu(id)
    local b = def(id)
    local staffed = staffOnDuty(id)
    local out = {}
    if staffed then
        for item, p in pairs(b.products) do
            out[#out + 1] = { item = item, label = p.label, stock = Bridge:StashCount(b.stash, item), price = Business.price(id, item) }
        end
    else
        for item, price in pairs(b.npc or {}) do
            out[#out + 1] = { item = item, label = NPC_LABELS[item] or item, stock = 99, price = math.ceil(price * Config.SelfServiceMarkup) }
        end
    end
    table.sort(out, function(a, c) return a.label < c.label end)
    return out, staffed
end

lib.callback.register('gs_business:menu', function(src, id)
    if not Security:RateLimit(src, 'gs_business:menu', 8, 10000) then return nil end
    local b = def(id)
    if not b or not Security:InRange(src, b.register, Config.Range + 2.0) then return nil end
    local items, staffed = Business.menu(id)
    local dbl = Double and Double.list[id]
    return { label = b.label, items = items, staffed = staffed, employee = isEmployee(src, id), boss = isBoss(src, id),
        canDouble = Config.Double.businesses[id] == true and isOwner(src, id), double = dbl and Double.active(id) and dbl.name or nil, hasDouble = dbl ~= nil }
end)

lib.callback.register('gs_business:buy', function(src, id, item, qty)
    if not Security:RateLimit(src, 'gs_business:buy', 4, 10000) then return false, 'Doucement.' end
    local b = def(id)
    if not b then return false, 'Produit inconnu.' end
    if not Security:InRange(src, b.register, Config.Range + 2.0) then return false, 'Trop loin du comptoir.' end
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > Config.MaxQty then return false, ('Quantité : 1 à %d.'):format(Config.MaxQty) end
    local staffed = staffOnDuty(id)
    local unit, label
    if staffed then
        if not b.products[item] then return false, 'Produit inconnu.' end
        unit, label = Business.price(id, item), b.products[item].label
        if Bridge:StashCount(b.stash, item) < qty then return false, 'Rupture de stock.' end
    else
        if not (b.npc or {})[item] then return false, 'Pas servi en libre-service.' end
        unit, label = math.ceil(b.npc[item] * Config.SelfServiceMarkup), NPC_LABELS[item] or item
    end
    local total = unit * qty
    if not Bridge:CanCarry(src, item, qty) then return false, 'Tu ne peux pas tout porter.' end
    if not Bridge:RemoveMoney(src, 'cash', total, 'achat ' .. b.label) and not Bridge:RemoveMoney(src, 'bank', total, 'achat ' .. b.label) then
        return false, ('Total : %d $.'):format(total)
    end
    if staffed and not Bridge:StashRemove(b.stash, item, qty) then
        Bridge:AddMoney(src, 'bank', total, 'remboursement ' .. b.label)
        return false, 'Rupture de stock.'
    end
    Bridge:AddItem(src, item, qty)
    local share = (Double and Double.active(id)) and Config.Double.share or Config.NpcShare -- V9 : la doublure du patron
    local income = staffed and total or math.floor(total * share)
    if GetResourceState('gs_city') == 'started' then -- V10 : le quartier évolue (clientèle aisée ou fuyante)
        local ok, f = pcall(function() return exports.gs_city:SalesFactor(b.register) end)
        if ok and tonumber(f) then income = math.floor(income * f) end
    end
    if income > 0 then JobsApi:AddSocietyMoney(id, income, true) end
    Store.log(id, 'sale', item, qty, income, staffed and name(src) or (name(src) .. ' (libre-service)'))
    return true, ('%d × %s : %d $. Merci !'):format(qty, label, total)
end)

--- Préparation (employé en service) : 2 temps, ingrédients pris dans la réserve au moment de finir.
lib.callback.register('gs_business:craftBegin', function(src, id, item)
    if not Security:RateLimit(src, 'gs_business:craftBegin', 6, 10000) then return false, 'Doucement.' end
    local b = def(id)
    local p = b and b.products[item]
    if not p or not p.needs then return false, 'Recette inconnue.' end
    if not isEmployee(src, id) then return false, 'Réservé aux employés en service.' end
    if not Security:InRange(src, b.craft, Config.Range + 2.0) then return false, 'Trop loin du plan de travail.' end
    for ing, n in pairs(p.needs) do
        if Bridge:StashCount(b.stash, ing) < n then return false, ('Il manque %s dans la réserve.'):format(ing) end
    end
    Business.pending[src] = { id = id, item = item, doneAt = GetGameTimer() + p.time - 500 }
    return true, p.time
end)

lib.callback.register('gs_business:craftFinish', function(src)
    if not Security:RateLimit(src, 'gs_business:craftFinish', 6, 10000) then return false, 'Doucement.' end
    local job = Business.pending[src]
    Business.pending[src] = nil
    if not job or GetGameTimer() < job.doneAt then return false, 'Interrompu.' end
    local b = def(job.id)
    local p = b.products[job.item]
    if not isEmployee(src, job.id) or not Security:InRange(src, b.craft, Config.Range + 2.0) then return false, 'Tu t\'es éloigné.' end
    local taken = {}
    for ing, n in pairs(p.needs) do
        if not Bridge:StashRemove(b.stash, ing, n) then
            for i, m in pairs(taken) do Bridge:StashAdd(b.stash, i, m) end
            return false, 'Il manque des ingrédients.'
        end
        taken[ing] = n
    end
    if not Bridge:StashAdd(b.stash, job.item, 1) then
        for i, m in pairs(taken) do Bridge:StashAdd(b.stash, i, m) end
        return false, 'Réserve pleine.'
    end
    Store.log(job.id, 'craft', job.item, 1, 0, name(src))
    return true, ('%s prêt (en réserve).'):format(p.label)
end)

lib.callback.register('gs_business:setPrice', function(src, id, item, price)
    if not Security:RateLimit(src, 'gs_business:setPrice', 6, 10000) then return false, 'Doucement.' end
    local b = def(id)
    if not b or not b.products[item] then return false, 'Produit inconnu.' end
    if not isBoss(src, id) then return false, 'Réservé au patron en service.' end
    price = math.floor(tonumber(price) or 0)
    if price < Config.MinPrice or price > Config.MaxPrice then return false, ('Prix : %d à %d $.'):format(Config.MinPrice, Config.MaxPrice) end
    Business.prices[id] = Business.prices[id] or {}
    Business.prices[id][item] = price
    Store.setPrice(id, item, price)
    return true, ('%s : %d $.'):format(b.products[item].label, price)
end)

--- Comptabilité (employés) : caisse du job, ventes du jour, dernières opérations.
lib.callback.register('gs_business:books', function(src, id)
    if not Security:RateLimit(src, 'gs_business:books', 4, 10000) then return nil end
    if not def(id) or not isEmployee(src, id) then return nil end
    return { balance = JobsApi:GetSocietyMoney(id) or 0, today = Store.todaySales(id), ledger = Store.ledger(id, 25) }
end)

-- V9 · pour le racket (gs_gangs) : commerces et patron (en service ou non)
exports('GetBusinesses', function()
    local out = {}
    for id, b in pairs(Config.Businesses) do out[id] = { label = b.label, register = b.register } end
    return out
end)
exports('IsOwner', isOwner)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Business.pending[src] = nil end)

CreateThread(function()
    Store.init()
    Business.prices = Store.prices()
end)
