-- gs_civil (serveur) : mariage (demande → accord du partenaire, tous deux au guichet, frais), divorce, conjoint (export).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Civil = { proposals = {} } -- proposals[target] = { from, expires }

local function atDesk(src) return Security:InRange(src, Config.Desk, Config.Range) end
local function name(src) return Bridge:GetName(src) or GetPlayerName(src) or '?' end

local function officiant()
    for _, s in ipairs(JobsApi:GetOnDutyPlayers(Config.Job)) do
        if atDesk(s) then return s end
    end
end

local function pay(src, price, reason)
    return Bridge:RemoveMoney(src, 'bank', price, reason) or Bridge:RemoveMoney(src, 'cash', price, reason)
end

function Civil.propose(src, target)
    target = tonumber(target)
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Personne introuvable.' end
    if not atDesk(src) or not atDesk(target) then return false, 'Présentez-vous tous les deux au guichet de l\'état civil.' end
    local a, b = Bridge:GetIdentifier(src), Bridge:GetIdentifier(target)
    if Store.spouse(a) then return false, 'Tu es déjà marié(e).' end
    if Store.spouse(b) then return false, 'Cette personne est déjà mariée.' end
    Civil.proposals[target] = { from = src, expires = os.time() + Config.ProposalTimeout }
    TriggerClientEvent('gs_civil:client:proposal', target, name(src))
    return true, 'Demande envoyée. Réponse attendue…'
end

function Civil.answer(src, accepted)
    local p = Civil.proposals[src]
    Civil.proposals[src] = nil
    if not p or os.time() > p.expires or not Bridge:IsLoaded(p.from) then return false, 'Demande expirée.' end
    if not accepted then Bridge:Notify(p.from, 'Ta demande en mariage a été refusée.', 'error') return true, 'Refusé.' end
    if not atDesk(src) or not atDesk(p.from) then return false, 'Il faut être tous les deux au guichet.' end
    local a, b = Bridge:GetIdentifier(p.from), Bridge:GetIdentifier(src)
    if Store.spouse(a) or Store.spouse(b) then return false, 'L\'un de vous est déjà marié.' end
    if Bridge:GetMoney(p.from, 'bank') + Bridge:GetMoney(p.from, 'cash') < Config.MarriageFee
        or Bridge:GetMoney(src, 'bank') + Bridge:GetMoney(src, 'cash') < Config.MarriageFee then
        return false, ('Frais : %d $ chacun.'):format(Config.MarriageFee)
    end
    pay(p.from, Config.MarriageFee, 'mariage') pay(src, Config.MarriageFee, 'mariage')
    Store.marry(a, b, name(p.from), name(src))
    local off = officiant()
    local who = off and ('célébré par %s'):format(name(off)) or 'enregistré au guichet'
    for _, s in ipairs({ src, p.from }) do Bridge:Notify(s, ('Félicitations ! Mariage %s.'):format(who), 'success') end
    if off then Bridge:Notify(off, ('Tu as célébré le mariage de %s et %s.'):format(name(p.from), name(src)), 'success') end
    Security:LogStaff(('[État civil] mariage %s + %s (%s)'):format(name(p.from), name(src), who))
    TriggerEvent('gs_civil:server:married', GetEntityCoords(GetPlayerPed(src)), ('%s et %s'):format(name(p.from), name(src))) -- V12 : mémoire des lieux
    return true, 'Marié(e) !'
end

function Civil.divorce(src)
    if not atDesk(src) then return false, 'Présente-toi au guichet de l\'état civil.' end
    local cid = Bridge:GetIdentifier(src)
    local sp = Store.spouse(cid)
    if not sp then return false, 'Tu n\'es pas marié(e).' end
    if not pay(src, Config.DivorceFee, 'divorce') then return false, ('Frais de divorce : %d $.'):format(Config.DivorceFee) end
    Store.divorce(cid)
    local other = Bridge:GetSourceByIdentifier(sp.cid)
    if other then Bridge:Notify(other, ('%s a demandé le divorce. Vous n\'êtes plus mariés.'):format(name(src)), 'error') end
    return true, 'Divorce prononcé.'
end

lib.callback.register('gs_civil:info', function(src)
    if not Security:RateLimit(src, 'gs_civil:info', 6, 10000) then return nil end
    if not atDesk(src) then return nil end
    local sp = Store.spouse(Bridge:GetIdentifier(src))
    return { spouse = sp and sp.name, marriageFee = Config.MarriageFee, divorceFee = Config.DivorceFee }
end)
lib.callback.register('gs_civil:propose', function(src, target)
    if not Security:RateLimit(src, 'gs_civil:propose', 2, 30000) then return false, 'Doucement.' end
    return Civil.propose(src, target)
end)
lib.callback.register('gs_civil:answer', function(src, accepted)
    if not Security:RateLimit(src, 'gs_civil:answer', 3, 10000) then return false end
    return Civil.answer(src, accepted == true)
end)
lib.callback.register('gs_civil:divorce', function(src)
    if not Security:RateLimit(src, 'gs_civil:divorce', 2, 30000) then return false, 'Doucement.' end
    return Civil.divorce(src)
end)

exports('GetSpouseName', function(cid) local sp = cid and Store.spouse(cid) return sp and sp.name or nil end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Civil.proposals[src] = nil end)
CreateThread(function() Store.init() end)
