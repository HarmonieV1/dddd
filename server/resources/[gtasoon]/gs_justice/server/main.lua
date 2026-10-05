-- gs_justice (serveur) : un juge en service ouvre une affaire contre un prévenu présent, un avocat peut être désigné ;
-- le verdict (relaxe / amende / prison) est appliqué par le serveur et inscrit au casier (gs_police). Rien n'est décidé côté client.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local PoliceApi = exports.gs_police

Justice = { consent = {} } -- consent[client] = { lawyer, expires }

local function onDuty(src, job) return JobsApi:IsOnDutyAs(src, job) end
local function name(src) return Bridge:GetName(src) or GetPlayerName(src) or tostring(src) end
local function inCourt(src) return Security:InRange(src, Config.Court, Config.CourtRadius) end

--- Ouvre une affaire : juge en service dans la salle, prévenu présent dans la salle.
function Justice.open(src, target, charge, lawyer)
    if not onDuty(src, Config.JudgeJob) then return false, 'Réservé aux juges en service.' end
    target, lawyer = tonumber(target), tonumber(lawyer)
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Prévenu introuvable.' end
    if not inCourt(src) or not inCourt(target) then return false, 'Le juge et le prévenu doivent être au tribunal.' end
    charge = Security:Sanitize(charge, 200)
    if not charge then return false, 'Chef d\'accusation obligatoire.' end
    local lawyerName = ''
    if lawyer then
        if not onDuty(lawyer, Config.LawyerJob) or not inCourt(lawyer) then return false, 'L\'avocat doit être en service et présent.' end
        lawyerName = name(lawyer)
    end
    local id = Store.open(Bridge:GetIdentifier(target), name(target), charge, name(src), lawyerName)
    Bridge:Notify(target, ('Tu comparais devant le tribunal : %s'):format(charge), 'warning')
    Security:LogStaff(('[Tribunal] affaire #%s ouverte par %s contre %s : %s'):format(id, name(src), name(target), charge), 'jobs')
    return true, id
end

--- Verdict : kind = 'acquit' | 'guilty' ; fine (≥ 0), jail (minutes ≥ 0) ; le prévenu doit être au tribunal pour la prison.
function Justice.verdict(src, id, kind, fine, jail)
    if not onDuty(src, Config.JudgeJob) then return false, 'Réservé aux juges en service.' end
    local case = Store.get(tonumber(id) or 0)
    if not case or case.status ~= 'open' then return false, 'Affaire introuvable ou déjà jugée.' end
    if kind == 'acquit' then
        Store.close(case.id, 'acquitted', 'Relaxe')
        TriggerEvent('gs_justice:server:verdict', 'acquitted') -- V10.2 : fil de la ville (Discord)
        PoliceApi:CloseWarrants(case.defendant)
        local t = Bridge:GetSourceByIdentifier(case.defendant)
        if t then Bridge:Notify(t, 'Le tribunal t\'a relaxé.', 'success') end
        return true, 'Relaxe prononcée.'
    end
    if kind ~= 'guilty' then return false, 'Verdict inconnu.' end
    fine, jail = math.floor(tonumber(fine) or 0), math.floor(tonumber(jail) or 0)
    if fine < 0 or fine > Config.MaxFine or jail < 0 or jail > Config.MaxJail or (fine == 0 and jail == 0) then
        return false, ('Peine : amende 0 à %d $, prison 0 à %d min (au moins une).'):format(Config.MaxFine, Config.MaxJail)
    end
    local t = Bridge:GetSourceByIdentifier(case.defendant)
    if jail > 0 and (not t or not inCourt(t)) then return false, 'Pour une peine de prison, le condamné doit être présent au tribunal.' end
    if fine > 0 then JobsApi:CreateBill(case.defendant, Config.JudgeJob, fine, ('Amende du tribunal (affaire #%d)'):format(case.id), Bridge:GetIdentifier(src), name(src)) end
    if jail > 0 then PoliceApi:Jail(t, jail, ('Tribunal, affaire #%d : %s'):format(case.id, case.charge)) end
    local retained = Pieces and Pieces.retained(case.id) or 0 -- V10.1 : preuves recevables
    local proof = retained > 0 and (' (%d pièce(s) retenue(s))'):format(retained) or ''
    PoliceApi:AddRecord(case.defendant, ('Condamnation : %s%s'):format(case.charge, proof), fine, jail, 'Tribunal · ' .. name(src))
    PoliceApi:CloseWarrants(case.defendant)
    local text = ('Coupable : %s%s%s%s'):format(fine > 0 and (fine .. ' $') or '', fine > 0 and jail > 0 and ' + ' or '', jail > 0 and (jail .. ' min de prison') or '', proof)
    Store.close(case.id, 'guilty', text)
    TriggerEvent('gs_justice:server:verdict', 'guilty')
    if t then Bridge:Notify(t, 'Verdict : ' .. text, 'error') end
    Security:LogStaff(('[Tribunal] affaire #%d : %s (%s)'):format(case.id, text, case.defendant_name), 'jobs')
    return true, text
end

--- Avocat : demande d'accès au casier d'un client présent ; le client doit accepter.
function Justice.requestRecords(src, target)
    if not onDuty(src, Config.LawyerJob) then return false, 'Réservé aux avocats en service.' end
    target = tonumber(target)
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Client introuvable.' end
    if not Security:PlayersInRange(src, target, 5.0) then return false, 'Trop loin.' end
    Justice.consent[target] = { lawyer = src, expires = os.time() + Config.ConsentTimeout }
    TriggerClientEvent('gs_justice:client:consent', target, name(src))
    return true, 'Demande envoyée au client.'
end

function Justice.answerConsent(src, accepted)
    local c = Justice.consent[src]
    Justice.consent[src] = nil
    if not c or os.time() > c.expires or not Bridge:IsLoaded(c.lawyer) then return false end
    if not accepted then Bridge:Notify(c.lawyer, 'Ton client refuse l\'accès à son casier.', 'error') return true end
    TriggerClientEvent('gs_justice:client:records', c.lawyer, name(src), PoliceApi:GetRecords(Bridge:GetIdentifier(src)))
    return true
end

lib.callback.register('gs_justice:open', function(src, target, charge, lawyer)
    if not Security:RateLimit(src, 'gs_justice:open', 3, 10000) then return false, 'Doucement.' end
    return Justice.open(src, target, charge, lawyer)
end)
lib.callback.register('gs_justice:verdict', function(src, id, kind, fine, jail)
    if not Security:RateLimit(src, 'gs_justice:verdict', 3, 10000) then return false, 'Doucement.' end
    return Justice.verdict(src, id, kind, fine, jail)
end)
lib.callback.register('gs_justice:requestRecords', function(src, target)
    if not Security:RateLimit(src, 'gs_justice:requestRecords', 3, 30000) then return false, 'Doucement.' end
    return Justice.requestRecords(src, target)
end)
lib.callback.register('gs_justice:consent', function(src, accepted)
    if not Security:RateLimit(src, 'gs_justice:consent', 3, 10000) then return false end
    return Justice.answerConsent(src, accepted == true)
end)
lib.callback.register('gs_justice:cases', function(src)
    if not Security:RateLimit(src, 'gs_justice:cases', 5, 10000) then return nil end
    if not (onDuty(src, Config.JudgeJob) or onDuty(src, Config.LawyerJob) or onDuty(src, Config.PoliceJob)) then return nil end
    return { cases = Store.list(20), judge = onDuty(src, Config.JudgeJob), lawyer = onDuty(src, Config.LawyerJob) }
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Justice.consent[src] = nil end)

CreateThread(function() Store.init() end)
