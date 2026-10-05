-- gs_justice (serveur) · V11.2 « Les jurés de Los Santos ». Tirage au sort, votes, décision qui lie le juge.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local J = Config.Jury

Jury = { sessions = {}, results = {}, served = {} } -- sessions[case] ; results[case] = { verdict, guilty, total } ; served[cid] = fin du repos

local function now() return os.time() end
local function onDuty(src, job) local ok, v = pcall(function() return JobsApi:IsOnDutyAs(src, job) end) return ok and v end
local function name(src) return Bridge:GetName(src) or GetPlayerName(src) or tostring(src) end

--- Citoyens éligibles : connectés, pas parties à l'affaire, pas police / juge / avocat en service, pas juré récemment
function Jury.eligible(exclude)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local cid = Bridge:IsLoaded(s) and Bridge:GetIdentifier(s)
        if cid and not exclude[s] and not exclude[cid] and (Jury.served[cid] or 0) <= now()
            and not onDuty(s, Config.PoliceJob) and not onDuty(s, Config.JudgeJob) and not onDuty(s, Config.LawyerJob) then
            out[#out + 1] = s
        end
    end
    return out
end

function Jury.summon(src, id)
    if not onDuty(src, Config.JudgeJob) then return false, 'Réservé aux juges en service.' end
    local case = Store.get(tonumber(id) or 0)
    if not case or case.status ~= 'open' then return false, 'Affaire introuvable ou déjà jugée.' end
    if Jury.sessions[case.id] then return false, 'Le jury délibère déjà.' end
    if Jury.results[case.id] then return false, 'Le jury a déjà rendu sa décision.' end
    local pool = Jury.eligible({ [src] = true, [case.defendant] = true })
    if #pool < J.min then return false, ('Pas assez de citoyens disponibles (%d sur %d minimum).'):format(#pool, J.min) end
    for i = #pool, 2, -1 do local k = math.random(i) pool[i], pool[k] = pool[k], pool[i] end
    local s = { judge = src, endsAt = now() + J.seconds, jurors = {}, votes = {}, n = 0 }
    local retained = Pieces and Pieces.retained(case.id) or 0
    for i = 1, math.min(J.size, #pool) do
        local j = pool[i]
        s.jurors[j], s.n = Bridge:GetIdentifier(j), s.n + 1
        TriggerClientEvent('gs_justice:client:jury', j, { id = case.id, charge = case.charge, defendant = case.defendant_name,
            pieces = retained, seconds = J.seconds, fee = J.fee })
    end
    Jury.sessions[case.id] = s
    Security:LogStaff(('[Tribunal] affaire #%d : jury de %d citoyens convoqué par %s'):format(case.id, s.n, name(src)), 'jobs')
    return true, ('Jury convoqué : %d citoyens tirés au sort, %d min pour voter.'):format(s.n, J.seconds // 60)
end

function Jury.vote(src, id, guilty)
    local s = Jury.sessions[tonumber(id) or 0]
    if not s or not s.jurors[src] then return false, 'Tu n\'es pas juré dans cette affaire.' end
    if s.votes[src] ~= nil then return false, 'Ton vote est déjà enregistré.' end
    if now() > s.endsAt then return false, 'Le temps de délibération est écoulé.' end
    s.votes[src] = guilty == true
    local count = 0
    for _ in pairs(s.votes) do count = count + 1 end
    if count >= s.n then Jury.close(tonumber(id)) end
    return true, 'Vote enregistré. Merci pour ton service, citoyen.'
end

function Jury.close(id)
    local s = Jury.sessions[id]
    if not s then return end
    Jury.sessions[id] = nil
    local guilty, total = 0, 0
    for src, v in pairs(s.votes) do
        total = total + 1
        if v then guilty = guilty + 1 end
        if J.fee > 0 then Bridge:AddMoney(src, 'bank', J.fee) end
    end
    for _, cid in pairs(s.jurors) do Jury.served[cid] = now() + J.cooldown end
    if total == 0 then
        if Bridge:IsLoaded(s.judge) then Bridge:Notify(s.judge, ('Affaire #%d : aucun juré n\'a voté, tu juges seul.'):format(id), 'warning') end
        return
    end
    local verdict = guilty * 2 > total and 'guilty' or 'acquit'
    Jury.results[id] = { verdict = verdict, guilty = guilty, total = total }
    if Bridge:IsLoaded(s.judge) then
        Bridge:Notify(s.judge, ('Affaire #%d · le jury a voté : %d coupable(s), %d non coupable(s) → %s.'):format(id, guilty, total - guilty,
            verdict == 'guilty' and 'COUPABLE (à toi de fixer la peine)' or 'RELAXE'), 'inform')
    end
    TriggerEvent('gs_justice:server:jury', id, guilty, total)
end

--- Le juge peut-il rendre ce verdict ? (le jury lie le juge sur la culpabilité)
function Jury.allows(id, kind)
    if Jury.sessions[id] then return false, 'Le jury délibère encore.' end
    local r = Jury.results[id]
    if not r or not J.binding then return true end
    if r.verdict ~= kind then
        return false, r.verdict == 'guilty' and 'Le jury a déclaré l\'accusé coupable : fixe une peine.' or 'Le jury a relaxé l\'accusé : relaxe obligatoire.'
    end
    return true
end
function Jury.note(id)
    local r = Jury.results[id]
    return r and (' · jury %d-%d'):format(r.guilty, r.total - r.guilty) or ''
end

lib.callback.register('gs_justice:jury', function(src, id)
    if not Security:RateLimit(src, 'gs_justice:jury', 2, 15000) then return false, 'Doucement.' end
    return Jury.summon(src, id)
end)
lib.callback.register('gs_justice:juryVote', function(src, id, guilty)
    if not Security:RateLimit(src, 'gs_justice:juryVote', 3, 10000) then return false, 'Doucement.' end
    return Jury.vote(src, id, guilty == true)
end)

CreateThread(function()
    while true do
        Wait(5000)
        for id, s in pairs(Jury.sessions) do if now() > s.endsAt then Jury.close(id) end end
    end
end)
