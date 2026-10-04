-- gs_accords (serveur) · V9 « Contrats signés ». Proposition → signature face à face → le serveur applique :
-- prélèvements à échéance, argent en dépôt si le bénéficiaire est absent, retards majorés, litige au-delà.
-- Rôles : a = celui qui propose, b = celui qui signe. Config.Types[kind].payer dit qui paie.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Accords = { list = {}, pending = {}, endAsk = {} } -- list[id] = contrat ; pending[signataire] = proposition

local function now() return os.time() end
local function notify(src, msg, t) if src then Bridge:Notify(src, msg, t or 'inform') end end
local function online(cid) return cid and Bridge:GetSourceByIdentifier(cid) or nil end
local function int(v) return math.floor(tonumber(v) or 0) end
local function within(v, l) return v >= l[1] and v <= l[2] end

local function payerOf(c) return Config.Types[c.kind].payer == 'a' and c.a_cid or c.b_cid end
local function payeeOf(c) return Config.Types[c.kind].payer == 'a' and c.b_cid or c.a_cid end
local function nameOf(c, cid) return cid == c.a_cid and c.a_name or c.b_name end

local function countActive(cid)
    local n = 0
    for _, c in pairs(Accords.list) do if (c.a_cid == cid or c.b_cid == cid) and c.status ~= 'done' and c.status ~= 'ended' then n = n + 1 end end
    return n
end

--- Texte lisible du contrat (copie papier, fenêtre de signature)
function Accords.describe(c)
    local T = Config.Types[c.kind]
    if not T.money then return ('%s entre %s et %s.%s'):format(T.label, c.a_name, c.b_name, c.terms ~= '' and (' ' .. c.terms) or '') end
    local payer, payee = nameOf(c, payerOf(c)), nameOf(c, payeeOf(c))
    local head = c.kind == 'loan' and ('%s prête %d $ à %s. '):format(c.a_name, c.loan or 0, c.b_name) or ''
    return ('%s%s verse %d $ à %s tous les %d j, %d fois.%s'):format(head, payer, c.principal, payee, c.every_days, c.total,
        c.terms ~= '' and (' Clause : ' .. c.terms) or '')
end

--- Proposition (a = src) à un joueur présent (b = target)
function Accords.propose(src, target, data)
    target = int(target)
    data = type(data) == 'table' and data or {}
    local T = Config.Types[data.kind or '']
    if not T then return false, 'Type de contrat inconnu.' end
    if target == src or not Bridge:IsLoaded(target) then return false, 'Personne en face.' end
    if not Security:PlayersInRange(src, target, Config.Range) then return false, 'Il faut signer face à face.' end
    local acid, bcid = Bridge:GetIdentifier(src), Bridge:GetIdentifier(target)
    if countActive(acid) >= Config.MaxActive or countActive(bcid) >= Config.MaxActive then return false, ('%d contrats en cours au maximum.'):format(Config.MaxActive) end
    local c = { kind = data.kind, a_cid = acid, a_name = Bridge:GetName(src) or '?', b_cid = bcid, b_name = Bridge:GetName(target) or '?',
        principal = 0, total = 0, every_days = 0, terms = Security:Sanitize(data.terms or '', 200) or '' }
    if T.money then
        local amount, count, every = int(data.amount), int(data.count), int(data.every)
        if not within(amount, Config.Limits.amount) then return false, ('Montant : %d à %d $.'):format(Config.Limits.amount[1], Config.Limits.amount[2]) end
        if not within(count, Config.Limits.count) then return false, ('Échéances : %d à %d.'):format(Config.Limits.count[1], Config.Limits.count[2]) end
        if not within(every, Config.Limits.every) then return false, ('Intervalle : %d à %d jours.'):format(Config.Limits.every[1], Config.Limits.every[2]) end
        c.total, c.every_days = count, every
        if data.kind == 'loan' then
            local rate = math.max(0, math.min(T.maxRate, tonumber(data.rate) or 0))
            c.loan = amount
            c.principal = math.ceil(amount * (1 + rate) / count)
        else
            c.principal = amount
        end
    else
        for _, o in pairs(Accords.list) do
            if o.kind == 'union' and o.status == 'active' and (o.a_cid == acid or o.b_cid == acid or o.a_cid == bcid or o.b_cid == bcid) then
                return false, 'L\'un de vous est déjà uni à quelqu\'un.'
            end
        end
    end
    c.amount = c.principal
    Accords.pending[target] = { from = src, c = c, at = now() }
    TriggerClientEvent('gs_accords:client:offer', target, { label = T.label, icon = T.icon, text = Accords.describe(c), from = c.a_name })
    return true, 'Contrat présenté. En attente de sa signature.'
end

--- Signature (ou refus) par b
function Accords.sign(src, accept)
    local p = Accords.pending[src]
    Accords.pending[src] = nil
    if not p or now() - p.at > Config.Answer then return false, 'Plus de contrat à signer.' end
    local a = p.from
    if not accept then notify(a, 'Contrat refusé.', 'error') return true, 'Contrat refusé.' end
    if not Bridge:IsLoaded(a) or Bridge:GetIdentifier(a) ~= p.c.a_cid then return false, 'L\'autre partie est partie.' end
    if not Security:PlayersInRange(src, a, Config.Range) then return false, 'Il faut signer face à face.' end
    local c = p.c
    if c.kind == 'loan' then
        if not Bridge:RemoveMoney(a, 'bank', c.loan, 'prêt à ' .. c.b_name) then
            notify(a, 'Ton compte ne couvre pas le prêt.', 'error')
            return false, 'Le prêteur n\'a pas les fonds.'
        end
        Bridge:AddMoney(src, 'bank', c.loan, 'prêt de ' .. c.a_name)
    end
    c.created_at = now()
    c.next_at = Config.Types[c.kind].money and now() + c.every_days * 86400 or 0
    c.paid, c.missed, c.held, c.status = 0, 0, 0, 'active'
    c.terms = c.kind == 'loan' and (('Prêt de %d $. '):format(c.loan) .. c.terms):sub(1, 255) or c.terms
    c.id = Store.insert(c)
    Accords.list[c.id] = c
    local text = Accords.describe(c)
    for _, s in ipairs({ a, src }) do
        if Bridge:ItemExists(Config.Item) then
            Bridge:AddItem(s, Config.Item, 1, { label = ('Contrat n°%d · %s'):format(c.id, Config.Types[c.kind].label), description = text })
        end
    end
    notify(a, ('Contrat n°%d signé.'):format(c.id), 'success')
    return true, ('Contrat n°%d signé. Une copie est dans ton sac.'):format(c.id)
end

local function judges(msg)
    if GetResourceState('gs_jobs') ~= 'started' then return end
    for _, job in ipairs({ Config.JudgeJob, Config.LawyerJob }) do
        local ok, l = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
        for _, s in ipairs(ok and l or {}) do notify(s, msg, 'warning') end
    end
end

--- Échéances, dépôts, retards (toutes les 5 min)
function Accords.tick()
    for _, c in pairs(Accords.list) do
        if (c.status == 'active' or c.status == 'dispute') and Config.Types[c.kind].money then
            local changed = false
            local payee = online(payeeOf(c))
            if c.held > 0 and payee and Bridge:AddMoney(payee, 'bank', c.held, ('contrat n°%d'):format(c.id)) then
                notify(payee, ('Contrat n°%d : %d $ versés (en dépôt pendant ton absence).'):format(c.id, c.held), 'success')
                c.held, changed = 0, true
            end
            if now() >= c.next_at then
                local payer = online(payerOf(c))
                if payer and Bridge:RemoveMoney(payer, 'bank', c.amount, ('contrat n°%d'):format(c.id)) then
                    if payee and Bridge:AddMoney(payee, 'bank', c.amount, ('contrat n°%d'):format(c.id)) then
                        notify(payee, ('Contrat n°%d : +%d $ de %s.'):format(c.id, c.amount, nameOf(c, payerOf(c))), 'success')
                    else
                        c.held = c.held + c.amount
                    end
                    notify(payer, ('Contrat n°%d : échéance de %d $ prélevée (%d/%d).'):format(c.id, c.amount, c.paid + 1, c.total), 'inform')
                    c.paid, c.amount, c.missed = c.paid + 1, c.principal, 0
                    c.next_at = c.next_at + c.every_days * 86400
                    if c.status == 'dispute' then c.status = 'active' end
                    if c.paid >= c.total then
                        c.status = c.held > 0 and 'active' or 'done'
                        notify(payer, ('Contrat n°%d honoré jusqu\'au bout.'):format(c.id), 'success')
                        notify(payee, ('Contrat n°%d honoré jusqu\'au bout.'):format(c.id), 'success')
                    end
                    changed = true
                elseif now() >= c.next_at + Config.Grace * 3600 then
                    c.missed = c.missed + 1
                    c.amount = math.floor(c.amount * (1 + Config.Penalty) + 0.5)
                    c.next_at = c.next_at + Config.Grace * 3600
                    notify(online(payerOf(c)), ('Contrat n°%d : échéance impayée, majorée à %d $.'):format(c.id, c.amount), 'error')
                    notify(payee, ('Contrat n°%d : %s n\'a pas payé (%d retard(s)).'):format(c.id, nameOf(c, payerOf(c)), c.missed), 'warning')
                    if c.missed >= Config.Dispute and c.status ~= 'dispute' then
                        c.status = 'dispute'
                        judges(('Litige : contrat n°%d (%s) entre %s et %s, %d échéances impayées.'):format(c.id, Config.Types[c.kind].label, c.a_name, c.b_name, c.missed))
                    end
                    changed = true
                end
            end
            if c.status == 'active' and c.paid >= c.total and c.held == 0 then c.status, changed = 'done', true end
            if changed then Store.save(c) end
        end
    end
end

--- Fin du contrat. Bénéficiaire : peut toujours y mettre fin (il renonce au reste). Payeur : demande, que le bénéficiaire accepte.
--- Union : chacun peut la rompre (frais si l'autre n'a pas demandé aussi).
function Accords.terminate(src, id)
    local c = Accords.list[int(id)]
    local cid = Bridge:GetIdentifier(src)
    if not c or (c.a_cid ~= cid and c.b_cid ~= cid) or c.status == 'done' or c.status == 'ended' then return false, 'Contrat introuvable.' end
    local other = cid == c.a_cid and c.b_cid or c.a_cid
    if c.kind == 'union' then
        if Accords.endAsk[c.id] ~= other then
            if not Bridge:RemoveMoney(src, 'bank', Config.DivorceFee, 'rupture d\'union') then return false, ('Frais de rupture : %d $.'):format(Config.DivorceFee) end
        end
    elseif cid ~= payeeOf(c) and Accords.endAsk[c.id] ~= other then
        Accords.endAsk[c.id] = cid
        notify(online(other), ('%s demande à mettre fin au contrat n°%d (/contrat pour accepter).'):format(nameOf(c, cid), c.id), 'warning')
        return true, 'Demande envoyée : l\'autre partie doit accepter.'
    end
    if c.held > 0 then
        local payee = online(payeeOf(c))
        if payee then Bridge:AddMoney(payee, 'bank', c.held, ('contrat n°%d'):format(c.id)) c.held = 0 end
    end
    c.status = c.held > 0 and 'active' or 'ended'
    if c.held > 0 then c.total = c.paid end -- plus d'échéance : le dépôt sera versé au retour du bénéficiaire
    Accords.endAsk[c.id] = nil
    Store.save(c)
    notify(online(other), ('Contrat n°%d terminé par %s.'):format(c.id, nameOf(c, cid)), 'inform')
    return true, ('Contrat n°%d terminé.'):format(c.id)
end

--- Contrats du joueur (et litiges pour les juges en service)
function Accords.mine(src)
    local cid = Bridge:GetIdentifier(src)
    local judge = GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:IsOnDutyAs(src, Config.JudgeJob)
    local out = {}
    for _, c in pairs(Accords.list) do
        local mine = c.a_cid == cid or c.b_cid == cid
        if (mine or (judge and c.status == 'dispute')) and c.status ~= 'done' and c.status ~= 'ended' then
            out[#out + 1] = { id = c.id, label = Config.Types[c.kind].label, icon = Config.Types[c.kind].icon, text = Accords.describe(c),
                status = c.status, paid = c.paid, total = c.total, amount = c.amount, next = c.next_at, mine = mine,
                asked = Accords.endAsk[c.id] ~= nil and Accords.endAsk[c.id] ~= cid, payee = payeeOf(c) == cid, money = Config.Types[c.kind].money }
        end
    end
    table.sort(out, function(x, y) return x.id < y.id end)
    return out
end

lib.callback.register('gs_accords:propose', function(src, target, data)
    if not Security:RateLimit(src, 'gs_accords:propose', 2, 10000) then return false, 'Doucement.' end
    return Accords.propose(src, target, data)
end)
lib.callback.register('gs_accords:sign', function(src, accept)
    if not Security:RateLimit(src, 'gs_accords:sign', 3, 5000) then return false, 'Doucement.' end
    return Accords.sign(src, accept == true)
end)
lib.callback.register('gs_accords:mine', function(src)
    if not Security:RateLimit(src, 'gs_accords:mine', 4, 5000) then return {} end
    return Accords.mine(src)
end)
lib.callback.register('gs_accords:terminate', function(src, id)
    if not Security:RateLimit(src, 'gs_accords:terminate', 3, 10000) then return false, 'Doucement.' end
    return Accords.terminate(src, id)
end)

AddEventHandler('playerDropped', function() Accords.pending[source] = nil end)

CreateThread(function()
    Store.init()
    for _, c in ipairs(Store.active()) do Accords.list[c.id] = c end
    while true do Wait(300000) Accords.tick() end
end)
