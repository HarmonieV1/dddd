-- Menu Direction : recrutement (avec consentement), grades, licenciement, caisse.
-- Règle : un patron ne gère que les grades STRICTEMENT inférieurs au sien.
local Offers = {} -- [cible] = { job, grade, from, expires }

local function bossContext(src)
    local job, def, grade = GSJ.activeJob(src)
    if not def or not def.whitelisted or not grade or not grade.boss then return nil end
    if not GSJ.nearAny(src, def.points.boss) then return nil end
    return job, def
end

lib.callback.register('gs_jobs:boss:getData', function(src)
    if not GSJ.guard(src, 'boss_data', 5, 10000) then return nil end
    local job, def = bossContext(src)
    if not job then return nil end

    local online = {}
    for _, m in pairs(Members) do online[m.cid] = true end
    local employees = DB.getEmployees(job.name)
    for _, e in ipairs(employees) do
        e.online = online[e.citizenid] == true
        e.gradeLabel = GSJ.gradeLabel(job.name, e.grade)
    end
    return {
        job = job.name,
        myGrade = job.grade,
        myCid = GSJ.cid(src),
        society = def.society and Society.balance(job.name) or nil,
        employees = employees,
    }
end)

local actions = {}

function actions.hire(src, job, def, data)
    local target = tonumber(data.target)
    if not target or target == src or not Members[target] then return false, L('player_not_found') end
    if not Security:PlayersInRange(src, target, Config.PlayerActionRange) then return false, L('too_far') end
    local grade = tonumber(data.grade) or 0
    if not def.grades[grade] or grade >= job.grade then return false, L('grade_invalid') end
    if Members[target].jobs[job.name] then return false, L('already') end
    if GSJ.countJobs(target) >= Config.MaxJobs then return false, L('target_max_jobs') end
    Offers[target] = { job = job.name, grade = grade, from = src, expires = os.time() + Config.OfferTimeout }
    TriggerClientEvent('gs_jobs:client:offer', target, {
        job = def.label, grade = GSJ.gradeLabel(job.name, grade), from = Bridge:GetName(src) or '?',
    })
    return true, L('offer_sent')
end

function actions.setGrade(src, job, def, data)
    local cid, grade = data.cid, tonumber(data.grade)
    if type(cid) ~= 'string' or not grade or not def.grades[grade] then return false, L('grade_invalid') end
    if cid == GSJ.cid(src) then return false, L('not_self') end
    local member = DB.getMember(cid, job.name)
    if not member then return false, L('not_member_target') end
    if member.grade >= job.grade or grade >= job.grade then return false, L('grade_invalid') end
    local ok, err = GSJ.setMembershipGrade(cid, job.name, grade)
    if not ok then return false, L(err) end
    GSJ.log('Grade : %s (%s) passe %s au grade %s chez %s', GetPlayerName(src), GSJ.cid(src), cid, grade, job.name)
    DB.audit('set_grade', job.name, GSJ.cid(src), cid, grade, nil)
    return true, L('grade_updated')
end

function actions.fire(src, job, def, data)
    local cid = data.cid
    if type(cid) ~= 'string' then return false, L('invalid') end
    if cid == GSJ.cid(src) then return false, L('not_self') end
    local member = DB.getMember(cid, job.name)
    if not member then return false, L('not_member_target') end
    if member.grade >= job.grade then return false, L('grade_invalid') end
    local ok, err = GSJ.removeMembership(cid, job.name)
    if not ok then return false, L(err) end
    local target = Bridge:GetSourceByIdentifier(cid)
    if target then GSJ.notify(target, L('fired_notify', def.label), 'error') end
    GSJ.log('Licenciement : %s (%s) licencie %s de %s', GetPlayerName(src), GSJ.cid(src), cid, job.name)
    DB.audit('fire', job.name, GSJ.cid(src), cid, nil, nil)
    return true, L('fired')
end

function actions.deposit(src, job, def, data)
    local amount = tonumber(data.amount)
    if not def.society or not GSJ.isInt(amount, 1, 10000000) then return false, L('amount_invalid') end
    if not Bridge:RemoveMoney(src, 'cash', amount, 'dépôt caisse ' .. job.name) then return false, L('not_enough_money') end
    if not Society.add(job.name, amount) then
        Bridge:AddMoney(src, 'cash', amount, 'remboursement dépôt')
        return false, L('error')
    end
    GSJ.log('Caisse %s : dépôt de %s $ par %s (%s)', job.name, amount, GetPlayerName(src), GSJ.cid(src))
    DB.audit('deposit', job.name, GSJ.cid(src), nil, amount, nil)
    return true, L('deposit_ok', amount)
end

function actions.withdraw(src, job, def, data)
    local amount = tonumber(data.amount)
    if not def.society or not GSJ.isInt(amount, 1, 10000000) then return false, L('amount_invalid') end
    if not Society.remove(job.name, amount) then return false, L('society_empty') end
    if not Bridge:AddMoney(src, 'cash', amount, 'retrait caisse ' .. job.name) then
        Society.add(job.name, amount)
        return false, L('error')
    end
    GSJ.log('Caisse %s : retrait de %s $ par %s (%s)', job.name, amount, GetPlayerName(src), GSJ.cid(src))
    DB.audit('withdraw', job.name, GSJ.cid(src), nil, amount, nil)
    return true, L('withdraw_ok', amount)
end

lib.callback.register('gs_jobs:boss:action', function(src, action, data)
    if not GSJ.guard(src, 'boss_action', 5, 10000) then return false, L('slow_down') end
    local fn = actions[action]
    if not fn or type(data) ~= 'table' then return false, L('invalid') end
    local job, def = bossContext(src)
    if not job then return false, L('not_boss') end
    return fn(src, job, def, data)
end)

RegisterNetEvent('gs_jobs:server:answerOffer', function(accept)
    local src = source
    if not GSJ.guard(src, 'offer', 3, 10000) then return end
    local offer = Offers[src]
    Offers[src] = nil
    if not offer then return end
    if os.time() > offer.expires then return GSJ.notify(src, L('offer_expired'), 'error') end
    if accept ~= true then return GSJ.notify(offer.from, L('offer_declined'), 'inform') end

    local cid = GSJ.cid(src)
    local ok, err = GSJ.addMembership(cid, offer.job, offer.grade, Bridge:GetName(src))
    if not ok then
        GSJ.notify(src, L(err), 'error')
        return GSJ.notify(offer.from, L(err), 'error')
    end
    GSJ.notify(src, L('joined', GSJ.jobLabel(offer.job)), 'success')
    GSJ.notify(offer.from, L('offer_accepted', Bridge:GetName(src) or '?'), 'success')
    GSJ.log('Embauche : %s (%s) recrute %s (%s) chez %s grade %s',
        GetPlayerName(offer.from) or '?', GSJ.cid(offer.from) or '?', GetPlayerName(src), cid, offer.job, offer.grade)
    DB.audit('hire', offer.job, GSJ.cid(offer.from), cid, offer.grade, nil)
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Offers[src] = nil end)
