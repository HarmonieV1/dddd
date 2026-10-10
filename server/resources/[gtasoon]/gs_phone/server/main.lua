-- gs_phone (serveur). Numéro unique par personnage, messages persistés, appels vocaux via pma-voice,
-- virements, appels d'urgence. Le client n'envoie que des numéros et des textes : tout est validé ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Phone = {
    numbers = {},  -- [src] = numéro
    owners = {},   -- [numéro] = src (en ligne)
    calls = {},    -- [id] = { id, caller, callee, state, channel }
    inCall = {},   -- [src] = id
    nextCall = 0,
}

local NUMBER_PATTERN = '^%d%d%d%-%d%d%d%d$'

function Phone.validNumber(n) return type(n) == 'string' and n:match(NUMBER_PATTERN) ~= nil end

function Phone.clean(text, max)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%c', ' '):gsub('[<>]', '')
    if Config.BlockLinks then
        text = text:gsub('https?://%S+', '[lien]'):gsub('[%w%.%-]+%.gg/%S+', '[lien]'):gsub('www%.%S+', '[lien]')
    end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    return text ~= '' and text:sub(1, max) or nil
end

local function guard(src, key, max, window)
    return Security:RateLimit(src, 'gs_phone:' .. key, max, window) and Phone.numbers[src] ~= nil
end

local function hasPhone(src)
    return not Config.RequireItem or Bridge:GetItemCount(src, Config.RequireItem) > 0
end

-- Numéros ------------------------------------------------------------------------------------------

function Phone.assign(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local number = Store.getNumber(cid)
    for _ = 1, 30 do
        if number then break end
        local candidate = ('%s-%04d'):format(Config.NumberPrefix, math.random(0, 9999))
        if Store.createNumber(cid, candidate) then number = candidate end
    end
    if not number then return nil end
    Phone.numbers[src], Phone.owners[number] = number, src
    return number
end

AddEventHandler('gs_bridge:server:playerLoaded', function(src) Phone.assign(src) end)

-- Appels ---------------------------------------------------------------------------------------------

local function setVoice(src, channel)
    if GetResourceState('pma-voice') ~= 'started' then return end
    pcall(function() exports['pma-voice']:setPlayerCall(src, channel) end) -- [API] pma-voice
end

function Phone.endCall(id, reason)
    local c = Phone.calls[id]
    if not c then return end
    Phone.calls[id] = nil
    for _, s in ipairs({ c.caller, c.callee }) do
        if Phone.inCall[s] == id then Phone.inCall[s] = nil end
        if c.state == 'active' then setVoice(s, 0) end
        TriggerClientEvent('gs_phone:client:callEnded', s, reason)
    end
end

lib.callback.register('gs_phone:call', function(src, number)
    if not guard(src, 'call', 3, 10000) then return false, 'Doucement.' end
    if not hasPhone(src) then return false, 'Pas de téléphone.' end
    if not Phone.validNumber(number) then return false, 'Numéro invalide.' end
    if Phone.inCall[src] then return false, 'Déjà en appel.' end
    local target = Phone.owners[number]
    if not target or target == src or not hasPhone(target) then return false, 'Numéro injoignable.' end
    if Phone.inCall[target] then return false, 'Ligne occupée.' end

    Phone.nextCall = Phone.nextCall + 1
    local id = Phone.nextCall
    Phone.calls[id] = { id = id, caller = src, callee = target, state = 'ringing', channel = 1000 + id }
    Phone.inCall[src], Phone.inCall[target] = id, id
    TriggerClientEvent('gs_phone:client:incoming', target, { id = id, number = Phone.numbers[src] })
    SetTimeout(Config.RingSeconds * 1000, function()
        local c = Phone.calls[id]
        if c and c.state == 'ringing' then Phone.endCall(id, 'Pas de réponse') end
    end)
    return true, id
end)

lib.callback.register('gs_phone:answer', function(src, id)
    if not guard(src, 'answer', 5, 10000) then return false end
    local c = Phone.calls[tonumber(id)]
    if not c or c.callee ~= src or c.state ~= 'ringing' then return false end
    c.state = 'active'
    setVoice(c.caller, c.channel)
    setVoice(c.callee, c.channel)
    TriggerClientEvent('gs_phone:client:callStarted', c.caller, { id = c.id, number = Phone.numbers[c.callee] })
    return true
end)

RegisterNetEvent('gs_phone:server:hangup', function()
    local src = source
    if not Security:RateLimit(src, 'gs_phone:hangup', 5, 10000) then return end
    local id = Phone.inCall[src]
    if id then Phone.endCall(id, 'Appel terminé') end
end)

-- Ouverture / messages / contacts ---------------------------------------------------------------------

--- V11.5 · Menotté (gs_police) ou mort / dans le coma (qbx_medical) : pas de téléphone, même avec un client modifié
local function unableToUse(src)
    local okC, cuffed = pcall(function() return exports.gs_police:IsCuffed(src) end)
    if okC and cuffed == true then return true end
    local st = Player(src).state
    return st and st.isDead == true
end
Phone.unableToUse = unableToUse

lib.callback.register('gs_phone:open', function(src)
    if not guard(src, 'open', 10, 10000) then return nil end
    if not hasPhone(src) then return false end
    if unableToUse(src) then return nil end
    local me = Phone.numbers[src]
    local conversations = {}
    for _, row in ipairs(Store.conversations(me)) do
        local last = Store.messageById(row.last_id)
        conversations[#conversations + 1] = {
            peer = row.peer, unread = tonumber(row.unread) or 0,
            last = last and last.content or '', time = last and last.time or 0, mine = last and last.sender == me,
        }
    end
    local job = Bridge:GetJob(src)
    return {
        number = me, contacts = Store.contacts(me), conversations = conversations,
        money = { cash = Bridge:GetMoney(src, 'cash'), bank = Bridge:GetMoney(src, 'bank') },
        job = job, emergency = (function()
            local l = {}
            for id, e in pairs(Config.Emergency) do l[#l + 1] = { id = id, label = e.label } end
            table.sort(l, function(a, b) return a.label < b.label end)
            return l
        end)(),
        maxLength = Config.MessageMaxLength,
    }
end)

lib.callback.register('gs_phone:thread', function(src, peer)
    if not guard(src, 'thread', 15, 10000) or not Phone.validNumber(peer) then return {} end
    local me = Phone.numbers[src]
    Store.markRead(me, peer)
    local list = Store.thread(me, peer)
    for _, m in ipairs(list) do m.mine = m.sender == me m.sender = nil end
    return list
end)

lib.callback.register('gs_phone:send', function(src, peer, text)
    if not guard(src, 'send', 5, 10000) then return false, 'Doucement.' end
    if not hasPhone(src) then return false, 'Pas de téléphone.' end
    if not Phone.validNumber(peer) then return false, 'Numéro invalide.' end
    local me = Phone.numbers[src]
    if peer == me then return false, 'Pas à toi-même.' end
    text = Phone.clean(text, Config.MessageMaxLength)
    if not text then return false, 'Message vide.' end
    local id = Store.addMessage(me, peer, text)
    if not id then return false, 'Erreur, réessaie.' end
    local target = Phone.owners[peer]
    if target and hasPhone(target) then
        TriggerClientEvent('gs_phone:client:message', target, { from = me, content = text, time = os.time() })
    end
    return true, { id = id, content = text, time = os.time(), mine = true }
end)

lib.callback.register('gs_phone:addContact', function(src, name, number)
    if not guard(src, 'contact', 10, 10000) then return false, 'Doucement.' end
    name = Phone.clean(name, 40)
    if not name or not Phone.validNumber(number) then return false, 'Nom ou numéro invalide (555-1234).' end
    local me = Phone.numbers[src]
    if Store.countContacts(me) >= Config.MaxContacts then return false, 'Répertoire plein.' end
    Store.addContact(me, name, number)
    return true, Store.contacts(me)
end)

lib.callback.register('gs_phone:deleteContact', function(src, id)
    if not guard(src, 'contact', 10, 10000) then return false end
    local me = Phone.numbers[src]
    Store.deleteContact(me, tonumber(id) or 0)
    return true, Store.contacts(me)
end)

-- Banque ----------------------------------------------------------------------------------------------

lib.callback.register('gs_phone:transfer', function(src, number, amount)
    if not guard(src, 'transfer', 3, 30000) then return false, 'Doucement.' end
    amount = tonumber(amount)
    if not Phone.validNumber(number) then return false, 'Numéro invalide.' end
    if not amount or amount ~= math.floor(amount) or amount < 1 or amount > Config.TransferMax then return false, 'Montant invalide.' end
    local target = Phone.owners[number]
    if not target or target == src then return false, 'Destinataire injoignable (doit être en ville).' end
    if not Bridge:RemoveMoney(src, 'bank', amount, 'virement ' .. number) then return false, 'Solde insuffisant.' end
    if not Bridge:AddMoney(target, 'bank', amount, 'virement ' .. Phone.numbers[src]) then
        Bridge:AddMoney(src, 'bank', amount, 'remboursement virement')
        return false, 'Virement échoué, remboursé.'
    end
    Bridge:Notify(target, ('Virement reçu : %d $ de %s'):format(amount, Phone.numbers[src]), 'success')
    if amount >= 50000 then
        Security:LogStaff(('[Téléphone] gros virement %d $ : %s → %s'):format(amount, Phone.numbers[src], number))
    end
    return true, ('%d $ envoyés à %s'):format(amount, number)
end)

-- Urgences ---------------------------------------------------------------------------------------------

lib.callback.register('gs_phone:emergency', function(src, service, text)
    if not guard(src, 'emergency', 2, 60000) then return false, 'Un appel est déjà en cours de traitement.' end
    local e = Config.Emergency[service]
    text = Phone.clean(text, 200)
    if not e or not text then return false, 'Décris la situation.' end
    local c = GetEntityCoords(GetPlayerPed(src))
    local alert = { service = e.label, number = Phone.numbers[src], text = text, coords = { x = c.x, y = c.y, z = c.z } }
    local reached = 0
    for _, job in ipairs(e.jobs) do
        for _, s in ipairs(JobsApi:GetOnDutyPlayers(job)) do
            TriggerClientEvent('gs_phone:client:emergency', s, alert)
            reached = reached + 1
        end
    end
    -- V12 : scanner police piraté (gs_gangs) : les appels police fuitent vers le gang
    if service == 'police' then
        local okL, listeners = pcall(function() return exports.gs_gangs:ScannerListeners() end)
        for _, s in ipairs(okL and listeners or {}) do TriggerClientEvent('gs_phone:client:emergency', s, alert) end
    end
    if reached == 0 then return true, 'Aucune unité disponible pour le moment. Ton appel est enregistré.' end
    return true, ('Appel transmis à %d unité(s).'):format(reached)
end)

-- Cycle de vie ------------------------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    local id = Phone.inCall[src]
    if id then Phone.endCall(id, 'Correspondant déconnecté') end
    local n = Phone.numbers[src]
    if n and Phone.owners[n] == src then Phone.owners[n] = nil end
    Phone.numbers[src] = nil
end)

CreateThread(function()
    Store.init()
    for _, src in ipairs(Bridge:GetPlayers()) do Phone.assign(src) end
end)

exports('GetNumber', function(src) return Phone.numbers[src] end)
exports('GetSourceByNumber', function(number) return Phone.owners[number] end)
