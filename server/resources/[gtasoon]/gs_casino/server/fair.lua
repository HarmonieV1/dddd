-- gs_casino (serveur) · V12.62 « Jetons de fête foraine » (proposition n° 142). Une seule monnaie pour les jeux de la ville :
-- achat / revente au guichet (salle de jeu) ou à la caisse du casino, ticket à gratter contre des jetons, échange 1 pour 1
-- avec les tickets des scripts d'activité installés à part. Tout est vérifié ici (position, argent, place dans le sac).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local F = Config.Fair

Fair = {}

--- Où est le joueur ? 'booth' (guichet), 'casino' (caisse du casino) ou nil
function Fair.where(src)
    if Security:InRange(src, F.booth, F.range + 2.0) then return 'booth' end
    if Security:InRange(src, Config.Lotto.cashier, Config.Lotto.range + 2.0) then return 'casino' end
    return nil
end

--- Tickets des scripts tiers réellement présents dans ox_inventory
function Fair.exchangeList()
    local out = {}
    for i, e in ipairs(F.exchange or {}) do
        if type(e) == 'table' and type(e.item) == 'string' and Bridge:ItemExists(e.item) then out[#out + 1] = { i = i, item = e.item, label = e.label or e.item } end
    end
    return out
end

local function amount(n)
    n = math.floor(tonumber(n) or 0)
    return n >= 1 and n <= F.maxPerAction and n or nil
end

function Fair.action(src, action, a, b)
    local at = Fair.where(src)
    if not at then return false, 'Approche-toi du guichet des jetons.' end
    if action == 'info' then
        return true, { count = Bridge:GetItemCount(src, F.item), price = F.price, buyBack = F.buyBack, at = at, scratchFor = F.scratchFor,
            exchange = Fair.exchangeList() }
    end
    if action == 'buy' then
        local n = amount(a)
        if not n then return false, ('Entre 1 et %d jetons.'):format(F.maxPerAction) end
        if not Bridge:CanCarry(src, F.item, n) then return false, 'Plus de place dans ton sac.' end
        if not Bridge:RemoveMoney(src, 'cash', n * F.price, 'jetons de fête foraine') then return false, ('Il te faut %d $ en liquide.'):format(n * F.price) end
        Bridge:AddItem(src, F.item, n)
        return true, ('%d jeton%s achetés.'):format(n, n > 1 and 's' or '')
    end
    if action == 'sell' then
        local n = amount(a)
        if not n then return false, ('Entre 1 et %d jetons.'):format(F.maxPerAction) end
        if not Bridge:RemoveItem(src, F.item, n) then return false, 'Tu n\'as pas autant de jetons.' end
        Bridge:AddMoney(src, 'cash', n * F.buyBack, 'jetons de fête foraine')
        return true, ('%d jeton%s repris : +%d $.'):format(n, n > 1 and 's' or '', n * F.buyBack)
    end
    if action == 'scratch' then
        if at ~= 'casino' then return false, 'Les tickets à gratter se prennent à la caisse du casino.' end
        if not Bridge:CanCarry(src, 'scratch_ticket', 1) then return false, 'Plus de place dans ton sac.' end
        if not Bridge:RemoveItem(src, F.item, F.scratchFor) then return false, ('Il te faut %d jetons.'):format(F.scratchFor) end
        Bridge:AddItem(src, 'scratch_ticket', 1)
        return true, 'Un ticket à gratter contre des jetons. Bonne chance !'
    end
    if action == 'toScript' or action == 'fromScript' then
        local e = (F.exchange or {})[tonumber(a) or 0]
        local n = amount(b)
        if type(e) ~= 'table' or not Bridge:ItemExists(e.item) then return false, 'Ce jeu n\'est pas installé.' end
        if not n then return false, ('Entre 1 et %d.'):format(F.maxPerAction) end
        local from, to = F.item, e.item
        if action == 'fromScript' then from, to = e.item, F.item end
        if not Bridge:CanCarry(src, to, n) then return false, 'Plus de place dans ton sac.' end
        if not Bridge:RemoveItem(src, from, n) then return false, 'Tu n\'en as pas autant.' end
        Bridge:AddItem(src, to, n)
        return true, ('Échange fait : %d × %s.'):format(n, action == 'toScript' and (e.label or e.item) or 'jeton de fête foraine')
    end
    return false
end

--- V12.63 · Photomaton (n° 189) : jetons pris, photo imprimée par gs_evidence (rendus si l'impression échoue)
function Fair.photo(src, url)
    if not Security:InRange(src, F.photobooth, F.range + 2.0) then return false, 'Entre dans la cabine du photomaton.' end
    if GetResourceState('gs_evidence') ~= 'started' then return false, 'Le photomaton est en panne.' end
    if not Bridge:CanCarry(src, 'gs_photo', 1) then return false, 'Plus de place dans ton sac.' end
    if not Bridge:RemoveItem(src, F.item, F.photoCost) then return false, ('Il te faut %d jetons de fête foraine.'):format(F.photoCost) end
    local ok, r = pcall(function() return exports.gs_evidence:Souvenir(src, F.photoPlace, url, F.photoRange) end)
    if not ok or type(r) ~= 'table' or not r.ok then
        Bridge:AddItem(src, F.item, F.photoCost)
        return false, (ok and type(r) == 'table' and r.msg) or 'Le photomaton est en panne : jetons rendus.'
    end
    return true, r.msg
end

lib.callback.register('gs_casino:photobooth', function(src, url)
    if not Security:RateLimit(src, 'gs_casino:photobooth', 2, 15000) then return false, 'Doucement.' end
    return Fair.photo(src, url)
end)

lib.callback.register('gs_casino:fair', function(src, action, a, b)
    if not Security:RateLimit(src, 'gs_casino:fair', 6, 10000) then return false, 'Doucement.' end
    return Fair.action(src, action, a, b)
end)
