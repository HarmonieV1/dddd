-- gs_store (serveur). Chaîne : Tebex exécute une commande CONSOLE → commande enregistrée (idempotente)
-- → le joueur la réclame sur le personnage de son choix via /boutique → éléments débloqués.
-- Rien ne se perd : une commande payée est toujours enregistrée, même boutique désactivée.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Shop = { unlocks = {} } -- [src] = { ped = { [id] = true }, outfit = { [id] = true } }

local function buyerOf(src)
    return GetPlayerIdentifierByType(src, Config.BuyerIdentifier)
end

local function log(fmt, ...)
    Security:LogStaff(('[Boutique] ' .. fmt):format(...), 'boutique')
end

function Shop.loadUnlocks(src)
    local cid = Bridge:GetIdentifier(src)
    local u = { ped = {}, outfit = {} }
    if cid then
        for _, row in ipairs(Store.unlocks(cid)) do
            if u[row.type] then u[row.type][row.ref] = true end
        end
    end
    Shop.unlocks[src] = u
    return u, cid
end

-- Commandes CONSOLE (Tebex). Refusées en jeu, même pour un admin : personne ne s'offre la boutique.
local function consoleOnly(src)
    if src ~= 0 then
        log('Tentative de commande boutique en jeu par %s (%s)', GetPlayerName(src) or '?', src)
        return false
    end
    return true
end

local function cleanRef(s)
    return type(s) == 'string' and s:match('^[%w%-_%.]+$') and #s <= 64 and s or nil
end

-- gsstore_deliver <transaction> <package> <id acheteur>
RegisterCommand('gsstore_deliver', function(src, args)
    if not consoleOnly(src) then return end
    local transaction, package, buyerId = cleanRef(args[1]), cleanRef(args[2]), cleanRef(args[3])
    if not transaction or not package or not buyerId then
        return print('[gs_store] usage : gsstore_deliver <transaction> <package> <id acheteur>')
    end
    if not Config.Packages[package] then
        log('Package inconnu "%s" (transaction %s) : commande enregistrée, à corriger dans la config', package, transaction)
    end
    local buyer = buyerId:find(':') and buyerId or (Config.BuyerIdentifier .. ':' .. buyerId)
    if not Store.addOrder(transaction, package, buyer) then
        return print(('[gs_store] transaction %s déjà enregistrée : ignorée'):format(transaction))
    end
    log('Achat reçu : %s → %s (transaction %s)', package, buyer, transaction)
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if buyerOf(s) == buyer then Bridge:Notify(s, 'Achat boutique reçu ! Tape /boutique pour le récupérer.', 'success') end
    end
end, true)

-- gsstore_revoke <transaction> (remboursement / chargeback)
RegisterCommand('gsstore_revoke', function(src, args)
    if not consoleOnly(src) then return end
    local transaction = cleanRef(args[1])
    if not transaction then return print('[gs_store] usage : gsstore_revoke <transaction>') end
    local status, cid = Store.revoke(transaction)
    if not status then return print(('[gs_store] transaction %s inconnue'):format(transaction)) end
    if status == 'claimed' then
        log('Révocation %s : déjà réclamée par %s. Skins/tenues retirés ; véhicule éventuel à retirer À LA MAIN.', transaction, cid)
    else
        log('Révocation %s (statut %s)', transaction, status)
    end
    for s in pairs(Shop.unlocks) do Shop.loadUnlocks(s) end
end, true)

-- Joueur ------------------------------------------------------------------------------------------

local function guard(src, key)
    return Security:RateLimit(src, 'gs_store:' .. key, Config.ClaimRateLimit.max, Config.ClaimRateLimit.windowMs)
        and Bridge:IsLoaded(src)
end

local function catalog(list, owned)
    local out = {}
    for id in pairs(owned) do
        if list[id] then out[#out + 1] = { id = id, label = list[id].label } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

lib.callback.register('gs_store:data', function(src)
    if not guard(src, 'data') then return nil end
    local u = Shop.unlocks[src] or Shop.loadUnlocks(src)
    local pending = {}
    local buyer = buyerOf(src)
    if buyer then
        for _, o in ipairs(Store.pending(buyer)) do
            local p = Config.Packages[o.package]
            pending[#pending + 1] = { transaction = o.transaction, label = p and p.label or o.package }
        end
    end
    return {
        enabled = Config.Enabled,
        pending = pending,
        peds = catalog(Config.Peds, u.ped),
        outfits = catalog(Config.Outfits, u.outfit),
    }
end)

lib.callback.register('gs_store:claim', function(src, transaction)
    if not guard(src, 'claim') then return false, 'Doucement.' end
    if not Config.Enabled then return false, 'Boutique bientôt disponible.' end
    local buyer, cid = buyerOf(src), Bridge:GetIdentifier(src)
    transaction = cleanRef(transaction)
    if not buyer or not cid or not transaction then return false, 'Compte Cfx.re introuvable : relance FiveM connecté.' end

    local order
    for _, o in ipairs(Store.pending(buyer)) do
        if o.transaction == transaction then order = o break end
    end
    local package = order and Config.Packages[order.package]
    if not order then return false, 'Achat introuvable ou déjà récupéré.' end
    if not package then return false, 'Pack inconnu : contacte le staff (transaction ' .. transaction .. ').' end
    if not Store.claim(transaction, buyer, cid) then return false, 'Achat déjà récupéré.' end

    local given, failed = {}, {}
    for _, g in ipairs(package.grants) do
        if g.type == 'vehicle' then
            if Bridge:GiveVehicle(src, g.model) then given[#given + 1] = g.label or g.model else failed[#failed + 1] = g.model end
        elseif (g.type == 'ped' and Config.Peds[g.id]) or (g.type == 'outfit' and Config.Outfits[g.id]) then
            Store.unlock(cid, g.type, g.id, transaction)
            given[#given + 1] = (g.type == 'ped' and Config.Peds or Config.Outfits)[g.id].label
        else
            failed[#failed + 1] = tostring(g.id or g.model)
        end
    end
    Shop.loadUnlocks(src)
    log('Réclamé : %s (%s) par %s / %s', package.label, transaction, buyer, cid)
    if #failed > 0 then
        log('LIVRAISON PARTIELLE %s pour %s : %s à livrer à la main', transaction, cid, table.concat(failed, ', '))
        return true, ('Reçu : %s. Le reste sera livré par le staff.'):format(table.concat(given, ', '))
    end
    return true, 'Reçu : ' .. table.concat(given, ', ')
end)

lib.callback.register('gs_store:applyPed', function(src, id)
    if not guard(src, 'apply') then return nil end
    local u = Shop.unlocks[src] or Shop.loadUnlocks(src)
    if not Config.Enabled or not Config.Peds[id] or not u.ped[id] then return nil end
    Store.setPed(Bridge:GetIdentifier(src), id)
    return Config.Peds[id].model
end)

lib.callback.register('gs_store:resetPed', function(src)
    if not guard(src, 'apply') then return false end
    Store.setPed(Bridge:GetIdentifier(src), nil)
    return true
end)

lib.callback.register('gs_store:applyOutfit', function(src, id)
    if not guard(src, 'apply') then return nil end
    local u = Shop.unlocks[src] or Shop.loadUnlocks(src)
    if not Config.Enabled or not Config.Outfits[id] or not u.outfit[id] then return nil end
    return Config.Outfits[id]
end)

-- Au chargement : débloqués en mémoire + skin actif réappliqué s'il est toujours possédé.
AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local u, cid = Shop.loadUnlocks(src)
    if not Config.Enabled or not cid then return end
    local ped = Store.getPed(cid)
    if ped and u.ped[ped] and Config.Peds[ped] then
        TriggerClientEvent('gs_store:client:applyPed', src, Config.Peds[ped].model)
    end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Shop.unlocks[src] = nil end)

CreateThread(function()
    Store.init()
    if not Config.Enabled then print('^3[gs_store] boutique DÉSACTIVÉE (Config.Enabled) : les achats Tebex sont enregistrés, pas réclamables^7') end
end)
