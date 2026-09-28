-- Contrats multi-job. Notre table gs_job_members fait foi ; le framework ne connaît que le job ACTIF.
Members = {} -- [src] = { cid = string, jobs = { [job] = grade } }

local locks = {}

--- Exécute fn en exclusivité pour un citizenid (évite les doubles embauches / doubles paiements).
function GSJ.withLock(cid, fn)
    if locks[cid] then return false, 'busy' end
    locks[cid] = true
    local okCall, ok, err = pcall(fn)
    locks[cid] = nil
    if not okCall then
        print(('[gs_jobs] erreur : %s'):format(ok))
        return false, 'error'
    end
    return ok, err
end

function GSJ.countJobs(src)
    local n = 0
    for _ in pairs(Members[src] and Members[src].jobs or {}) do n = n + 1 end
    return n
end

function GSJ.cid(src)
    return Members[src] and Members[src].cid
end

function GSJ.sync(src)
    local m = Members[src]
    if m then TriggerClientEvent('gs_jobs:client:memberships', src, m.jobs) end
end

--- Fin de service (changement de job, hors service, licenciement, déco) : les modules nettoient.
function GSJ.endService(src)
    TriggerEvent('gs_jobs:internal:endService', src)
end

function GSJ.load(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local jobs = {}
    for _, row in ipairs(DB.getMemberships(cid)) do
        if Jobs[row.job] and Jobs[row.job].grades[row.grade] then jobs[row.job] = row.grade end
    end
    Members[src] = { cid = cid, jobs = jobs }
    DB.updateName(cid, Bridge:GetName(src) or '')

    -- Réconciliation : un job actif sans contrat (ex : /setjob sauvage) est retiré.
    local active = Bridge:GetJob(src)
    if active and active.name ~= Config.UnemployedJob then
        local grade = jobs[active.name]
        if grade == nil then
            Bridge:SetJob(src, Config.UnemployedJob, 0)
            GSJ.log('Réconciliation : %s (%s) avait le job %s sans contrat, remis au chômage', GetPlayerName(src), cid, active.name)
        elseif grade ~= active.grade then
            Bridge:SetJob(src, active.name, grade)
        end
    end
    Bridge:SetDuty(src, false) -- toujours hors service à la connexion
    GSJ.sync(src)
end

-- Opérations sur les contrats (cid peut être hors ligne) ------------------------------

function GSJ.addMembership(cid, job, grade, name)
    if not Jobs[job] or not Jobs[job].grades[grade] then return false, 'invalid' end
    local ok, err = GSJ.withLock(cid, function()
        if DB.getMember(cid, job) then return false, 'already' end
        if DB.countMemberships(cid) >= Config.MaxJobs then return false, 'max_jobs' end
        if not DB.addMember(cid, job, grade, name or '') then return false, 'db' end
        return true
    end)
    if ok then
        local src = Bridge:GetSourceByIdentifier(cid)
        if src and Members[src] then
            Members[src].jobs[job] = grade
            GSJ.sync(src)
        end
    end
    return ok, err
end

function GSJ.removeMembership(cid, job)
    local ok, err = GSJ.withLock(cid, function()
        if not DB.removeMember(cid, job) then return false, 'not_member_target' end
        return true
    end)
    if not ok then return ok, err end
    Bridge:ForgetJob(cid, job)
    local src = Bridge:GetSourceByIdentifier(cid)
    if src and Members[src] then
        Members[src].jobs[job] = nil
        local active = Bridge:GetJob(src)
        if active and active.name == job then
            GSJ.endService(src)
            Bridge:SetJob(src, Config.UnemployedJob, 0)
        end
        GSJ.sync(src)
    end
    return true
end

function GSJ.setMembershipGrade(cid, job, grade)
    if not Jobs[job] or not Jobs[job].grades[grade] then return false, 'grade_invalid' end
    local ok, err = GSJ.withLock(cid, function()
        if not DB.getMember(cid, job) then return false, 'not_member_target' end
        DB.setGrade(cid, job, grade)
        return true
    end)
    if not ok then return ok, err end
    local src = Bridge:GetSourceByIdentifier(cid)
    if src and Members[src] then
        Members[src].jobs[job] = grade
        local active = Bridge:GetJob(src)
        if active and active.name == job then
            Bridge:SetJob(src, job, grade)
            if active.onduty then Bridge:SetDuty(src, true) end
        end
        GSJ.notify(src, L('promoted_notify', GSJ.jobLabel(job), GSJ.gradeLabel(job, grade)), 'inform')
        GSJ.sync(src)
    end
    return true
end

-- Events joueur ------------------------------------------------------------------------

RegisterNetEvent('gs_jobs:server:switch', function(job)
    local src = source
    if not GSJ.guard(src, 'switch', 3, 10000) then return end
    local m = Members[src]
    if not m or type(job) ~= 'string' then return end
    local current = Bridge:GetJob(src)
    if current and current.name == job then return end
    local grade = 0
    if job ~= Config.UnemployedJob then
        grade = m.jobs[job]
        if grade == nil then return GSJ.notify(src, L('not_member'), 'error') end
    end
    GSJ.endService(src)
    Bridge:SetJob(src, job, grade)
    Bridge:SetDuty(src, false)
    GSJ.notify(src, L('switched', GSJ.jobLabel(job)), 'success')
end)

RegisterNetEvent('gs_jobs:server:toggleDuty', function()
    local src = source
    if not GSJ.guard(src, 'duty', 3, 10000) then return end
    local job, def = GSJ.activeJob(src)
    if not job or not def then return end
    if not def.dutyAnywhere and not GSJ.nearAny(src, def.points.duty) then
        return GSJ.notify(src, L('too_far'), 'error')
    end
    local on = not job.onduty
    if not on then GSJ.endService(src) end
    Bridge:SetDuty(src, on)
    GSJ.notify(src, on and L('duty_on', def.label) or L('duty_off'), 'success')
    DB.audit(on and 'duty_on' or 'duty_off', job.name, GSJ.cid(src), nil, nil, nil)
end)

RegisterNetEvent('gs_jobs:server:resign', function(job)
    local src = source
    if not GSJ.guard(src, 'resign', 2, 10000) then return end
    local cid = GSJ.cid(src)
    if not cid or type(job) ~= 'string' or Members[src].jobs[job] == nil then return end
    local ok = GSJ.removeMembership(cid, job)
    if ok then
        GSJ.notify(src, L('resigned', GSJ.jobLabel(job)), 'inform')
        GSJ.log('Démission : %s (%s) quitte %s', GetPlayerName(src), cid, job)
        DB.audit('resign', job, cid, cid, nil, nil)
    end
end)

RegisterNetEvent('gs_jobs:server:joinPublic', function(job)
    local src = source
    if not GSJ.guard(src, 'join', 2, 10000) then return end
    local def = Jobs[job]
    local cid = GSJ.cid(src)
    if not cid or not def or def.whitelisted then return end
    if not Security:InRange(src, Config.JobCenter.coords, Config.ZoneRadius + Config.ServerTolerance) then
        return GSJ.notify(src, L('too_far'), 'error')
    end
    local ok, err = GSJ.addMembership(cid, job, 0, Bridge:GetName(src))
    if not ok then return GSJ.notify(src, L(err), 'error') end
    GSJ.notify(src, L('joined', def.label), 'success')
    DB.audit('join', job, cid, cid, nil, nil)
end)

lib.callback.register('gs_jobs:getMemberships', function(src)
    if not GSJ.guard(src, 'memberships', 3, 10000) then return {} end
    return Members[src] and Members[src].jobs or {}
end)

-- Cycle de vie -------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerLoaded', function(src) GSJ.load(src) end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    if not Members[src] then return end
    GSJ.endService(src)
    Members[src] = nil
end)

-- API pour les autres ressources gs_* (serveur) -------------------------------------------

exports('HasJob', function(src, job, minGrade)
    local grade = Members[src] and Members[src].jobs[job]
    return grade ~= nil and grade >= (minGrade or 0)
end)

exports('IsOnDutyAs', function(src, job)
    local j = Bridge:GetJob(src)
    return j ~= nil and j.name == job and j.onduty
end)

exports('GetMemberships', function(src)
    return Members[src] and Members[src].jobs or {}
end)
