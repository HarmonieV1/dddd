-- gs_blackmarket : tableau des contrats entre joueurs (économie illégale). Récompense bloquée (argent sale),
-- versée par le commanditaire à la validation. Tout est journalisé pour le staff (litiges : /report).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local C = Config.Contracts

Contracts = { list = {} } -- [id] = { id, kind, title, details, reward, poster, taker, created }

local function started(res) return GetResourceState(res) == 'started' end
local function count(field, cid)
    local n = 0
    for _, c in pairs(Contracts.list) do if c[field] == cid then n = n + 1 end end
    return n
end

local function public(c, cid)
    return { id = c.id, kind = c.kind, kindLabel = C.types[c.kind], title = c.title, details = c.details, reward = c.reward,
        taken = c.taker ~= nil, mine = c.poster == cid, takenByMe = c.taker == cid, created = c.created }
end

local function notifyCid(cid, msg, t)
    local s = cid and Bridge:GetSourceByIdentifier(cid)
    if s then Bridge:Notify(s, msg, t or 'inform') end
end

--- Expiration : contrats non pris depuis 48 h → remboursés (sans la commission) si le commanditaire est en ligne,
--- sinon ils restent jusqu'à sa prochaine visite.
function Contracts.expire()
    local now = os.time()
    for id, c in pairs(Contracts.list) do
        if not c.taker and now - c.created > C.expire then
            local s = Bridge:GetSourceByIdentifier(c.poster)
            if s and Bridge:AddItem(s, Config.DirtyItem, c.reward) then
                Contracts.list[id] = nil
                CStore.delete(id)
                Bridge:Notify(s, ('Ton contrat « %s » a expiré : %d $ rendus.'):format(c.title, c.reward), 'inform')
            end
        end
    end
end

lib.callback.register('gs_contracts:list', function(src)
    if not Security:RateLimit(src, 'gs_contracts:list', 5, 10000) then return nil end
    local ok, msg = Market.access(src)
    if not ok then return nil, msg end
    Contracts.expire()
    local cid = Bridge:GetIdentifier(src)
    local l = {}
    for _, c in pairs(Contracts.list) do
        if not c.taker or c.poster == cid or c.taker == cid then l[#l + 1] = public(c, cid) end
    end
    table.sort(l, function(a, b) return a.id > b.id end)
    return l
end)

lib.callback.register('gs_contracts:post', function(src, kind, title, details, reward)
    if not Security:RateLimit(src, 'gs_contracts:post', 2, 30000) then return false, 'Doucement.' end
    local ok, msg = Market.access(src)
    if not ok then return false, msg end
    if not C.types[kind] then return false, 'Type invalide.' end
    title = Security:Sanitize(title, 80)
    details = Security:Sanitize(details, 400) or ''
    reward = tonumber(reward)
    if not title then return false, 'Titre obligatoire.' end
    if not reward or reward ~= math.floor(reward) or reward < C.minReward or reward > C.maxReward then
        return false, ('Récompense entre %d et %d $.'):format(C.minReward, C.maxReward)
    end
    local cid = Bridge:GetIdentifier(src)
    if count('poster', cid) >= C.maxOpen then return false, ('%d contrats ouverts maximum.'):format(C.maxOpen) end
    local fee = math.ceil(reward * C.fee)
    if not Bridge:RemoveItem(src, Config.DirtyItem, reward + fee) then return false, ('Il te faut %d $ en argent sale (commission comprise).'):format(reward + fee) end
    local c = { kind = kind, title = title, details = details, reward = reward, poster = cid, created = os.time() }
    c.id = CStore.insert(c)
    if not c.id then Bridge:AddItem(src, Config.DirtyItem, reward + fee) return false, 'Erreur BDD.' end
    Contracts.list[c.id] = c
    if started('gs_wanted') and math.random() < C.leakChance then
        exports.gs_wanted:ReportCrime(src, 'contract', GetEntityCoords(GetPlayerPed(src)))
    end
    Security:LogStaff(('[Contrat #%d] %s publie %s « %s » (%d $) : %s'):format(c.id, GetPlayerName(src) or src, C.types[kind], title, reward, details), 'jobs')
    return true, ('Contrat #%d publié (%d $ bloqués, commission %d $).'):format(c.id, reward, fee)
end)

lib.callback.register('gs_contracts:take', function(src, id)
    if not Security:RateLimit(src, 'gs_contracts:take', 3, 10000) then return false, 'Doucement.' end
    local ok, msg = Market.access(src)
    if not ok then return false, msg end
    local c = Contracts.list[tonumber(id)]
    local cid = Bridge:GetIdentifier(src)
    if not c or c.taker then return false, 'Contrat indisponible.' end
    if c.poster == cid then return false, 'Pas ton propre contrat.' end
    if count('taker', cid) >= C.maxTaken then return false, ('%d contrats en cours maximum.'):format(C.maxTaken) end
    c.taker = cid
    CStore.setTaker(c.id, cid)
    notifyCid(c.poster, ('Ton contrat « %s » a été accepté.'):format(c.title), 'success')
    Security:LogStaff(('[Contrat #%d] accepté par %s'):format(c.id, GetPlayerName(src) or src), 'jobs')
    return true, 'Contrat accepté. Quand c\'est fait, le commanditaire valide et tu es payé.'
end)

--- Le preneur abandonne : le contrat redevient disponible.
lib.callback.register('gs_contracts:drop', function(src, id)
    if not Security:RateLimit(src, 'gs_contracts:drop', 3, 10000) then return false, 'Doucement.' end
    local c = Contracts.list[tonumber(id)]
    if not c or c.taker ~= Bridge:GetIdentifier(src) then return false, 'Invalide.' end
    c.taker = nil
    CStore.setTaker(c.id, nil)
    notifyCid(c.poster, ('Ton contrat « %s » a été abandonné, il est de nouveau disponible.'):format(c.title))
    return true, 'Contrat abandonné.'
end)

--- Le commanditaire valide (payé au preneur, qui doit être en ligne) ou annule (seulement s'il n'est pas pris).
lib.callback.register('gs_contracts:close', function(src, id, action)
    if not Security:RateLimit(src, 'gs_contracts:close', 3, 10000) then return false, 'Doucement.' end
    local c = Contracts.list[tonumber(id)]
    if not c or c.poster ~= Bridge:GetIdentifier(src) then return false, 'Invalide.' end
    if action == 'cancel' then
        if c.taker then return false, 'Déjà pris : le preneur doit abandonner, ou valide-le.' end
        if not Bridge:AddItem(src, Config.DirtyItem, c.reward) then return false, 'Tu ne peux pas porter l\'argent.' end
        Contracts.list[c.id] = nil
        CStore.delete(c.id)
        return true, ('Contrat annulé : %d $ rendus (commission perdue).'):format(c.reward)
    end
    if not c.taker then return false, 'Personne n\'a pris ce contrat.' end
    local taker = Bridge:GetSourceByIdentifier(c.taker)
    if not taker then return false, 'Le preneur doit être en ville pour être payé.' end
    if not Bridge:AddItem(taker, Config.DirtyItem, c.reward) then return false, 'Le preneur ne peut pas porter l\'argent.' end
    Contracts.list[c.id] = nil
    CStore.delete(c.id)
    Bridge:Notify(taker, ('Contrat « %s » validé : %d $ en argent sale.'):format(c.title, c.reward), 'success')
    if started('gs_reputation') then exports.gs_reputation:Add(taker, 'street', 2) end
    Security:LogStaff(('[Contrat #%d] validé : %d $ versés'):format(c.id, c.reward), 'jobs')
    return true, 'Contrat validé, le preneur est payé.'
end)

CreateThread(function()
    CStore.init()
    for _, c in ipairs(CStore.all()) do Contracts.list[c.id] = c end
end)
