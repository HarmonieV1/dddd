-- Missions à étapes (taxi, livraison, poubelles...). Le serveur choisit les étapes, n'envoie que
-- l'étape courante, vérifie la position + le véhicule de service + un temps de trajet crédible, puis paie.
local Active = {}   -- [src] = { job, steps, index, lastPos, lastAt, distance, earned }
local Cooldown = {} -- [src] = os.time() de fin de cooldown

--- Tire `count` étapes distinctes, chacune à au moins minStepDistance de la précédente
--- (la première à au moins minStepDistance du joueur : pas d'étape validée sans rouler).
local function pickSteps(pool, count, from)
    local points = Locations[pool]
    if not points or #points < count then return nil end
    local steps, used = {}, {}
    for _ = 1, 100 do
        if #steps == count then break end
        local i = math.random(#points)
        local p = points[i]
        local prev = steps[#steps] or from
        if not used[i] and #(p - prev) >= Config.Missions.minStepDistance then
            used[i] = true
            steps[#steps + 1] = p
        end
    end
    return #steps == count and steps or nil
end

local function sendStep(src, m)
    local mdef = Jobs[m.job].mission
    TriggerClientEvent('gs_jobs:client:missionStep', src, {
        index = m.index,
        total = #m.steps,
        coords = m.steps[m.index],
        label = mdef.stepLabels and mdef.stepLabels[m.index] or mdef.stepLabel or '',
        duration = mdef.stepDuration or 2000,
        anim = mdef.anim, prop = mdef.prop,
    })
end

local function stop(src, reason)
    if not Active[src] then return end
    Active[src] = nil
    Cooldown[src] = os.time() + Config.Missions.cooldown
    TriggerClientEvent('gs_jobs:client:missionEnd', src, reason, 0)
end

lib.callback.register('gs_jobs:mission:start', function(src)
    if not GSJ.guard(src, 'mission_start', 3, 10000) then return false, L('slow_down') end
    local job, def = GSJ.activeJob(src)
    local mdef = def and def.mission
    if not mdef or not job.onduty then return false, L('not_on_duty') end
    if Active[src] then return false, L('mission_already') end
    if (Cooldown[src] or 0) > os.time() then return false, L('mission_cooldown') end
    if mdef.vehicleRequired ~= false and not GSJ.getJobVehicle(src) then return false, L('mission_need_vehicle') end
    local pos = GetEntityCoords(GetPlayerPed(src))
    local steps = pickSteps(mdef.pool, mdef.stops, pos)
    if not steps then return false, L('error') end

    Active[src] = {
        job = job.name, steps = steps, index = 1, distance = 0, earned = 0,
        lastPos = pos, lastAt = GetGameTimer(),
    }
    sendStep(src, Active[src])
    return true, L('mission_started')
end)

lib.callback.register('gs_jobs:mission:step', function(src)
    if not GSJ.guard(src, 'mission_step', 3, 5000) then return false, L('slow_down') end
    local m = Active[src]
    if not m then return false, L('invalid') end
    local job = Bridge:GetJob(src)
    if not job or job.name ~= m.job or not job.onduty then
        stop(src, 'cancel')
        return false, L('not_on_duty')
    end

    local mdef = Jobs[m.job].mission
    local target = m.steps[m.index]
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - target) > Config.Missions.checkpointRadius + Config.ServerTolerance then return false, L('too_far') end
    if mdef.vehicleRequired ~= false then
        local veh = GSJ.getJobVehicle(src)
        if not veh or #(GetEntityCoords(veh) - target) > Config.Missions.vehicleRadius then
            return false, L('mission_need_vehicle')
        end
    end

    -- Anti-TP : durée minimale crédible depuis l'étape précédente.
    local dist = #(target - m.lastPos)
    local elapsed = (GetGameTimer() - m.lastAt) / 1000
    if elapsed < dist / Config.Missions.maxSpeed then
        GSJ.log('Mission suspecte : %s (%s) job %s, %.0f m en %.1f s', GetPlayerName(src), GSJ.cid(src), m.job, dist, elapsed)
        DB.audit('mission_suspect', m.job, GSJ.cid(src), nil, nil, ('%.0f m en %.1f s'):format(dist, elapsed))
        stop(src, 'cancel')
        return false, L('mission_suspicious')
    end

    m.distance = m.distance + dist
    m.lastPos, m.lastAt = target, GetGameTimer()
    local last = m.index == #m.steps
    local pay = mdef.payPerStop and math.random(mdef.payPerStop[1], mdef.payPerStop[2]) or 0
    if last then
        pay = pay + math.floor(m.distance / 1000 * (mdef.perKm or 0)) + (mdef.completionBonus or 0)
    end
    if pay > 0 and Bridge:AddMoney(src, 'bank', pay, 'mission ' .. m.job) then m.earned = m.earned + pay end

    if last then
        Active[src] = nil
        Cooldown[src] = os.time() + Config.Missions.cooldown
        DB.audit('mission', m.job, GSJ.cid(src), nil, m.earned, ('%d étapes, %.1f km'):format(#m.steps, m.distance / 1000))
        TriggerClientEvent('gs_jobs:client:missionEnd', src, 'done', m.earned)
        if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Reward(src, 'job_mission') end
        return true
    end
    m.index = m.index + 1
    sendStep(src, m)
    return true, pay > 0 and L('mission_step_paid', pay) or nil
end)

RegisterNetEvent('gs_jobs:server:missionCancel', function()
    if Security:RateLimit(source, 'gs_jobs:mission_cancel', 2, 10000) then stop(source, 'cancel') end
end)
AddEventHandler('gs_jobs:internal:endService', function(src) stop(src, 'cancel') end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Active[src], Cooldown[src] = nil, nil end)
