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

local function depotOf(job)
    local g = Jobs[job].points.garage and Jobs[job].points.garage[1]
    return g and g.coords or nil
end

local function sendStep(src, m)
    local mdef = Jobs[m.job].mission
    if m.returning then -- V12.39 · tournée finie : retour au dépôt pour être payé
        TriggerClientEvent('gs_jobs:client:missionStep', src, {
            kind = 'depot', index = #m.steps, total = #m.steps, coords = depotOf(m.job),
            label = L('mission_depot'), duration = 1500,
        })
        return
    end
    TriggerClientEvent('gs_jobs:client:missionStep', src, {
        index = m.index,
        total = #m.steps,
        coords = m.steps[m.index],
        label = mdef.stepLabels and mdef.stepLabels[m.index] or mdef.stepLabel or '',
        duration = mdef.stepDuration or 2000,
        anim = mdef.anim, prop = mdef.prop,
        carry = mdef.carry, -- V12.39 · objet à porter jusqu'au véhicule (sac poubelle → benne)
        vehicleModel = mdef.carry and Jobs[m.job].vehicles and Jobs[m.job].vehicles[1] and Jobs[m.job].vehicles[1].model or nil,
    })
end

--- Fin de mission payée (dernière étape, ou retour au dépôt pour les métiers payés au dépôt).
local function finish(src, m, pay)
    if pay > 0 and Bridge:AddMoney(src, 'bank', pay, 'mission ' .. m.job) then m.earned = m.earned + pay end
    Active[src] = nil
    Cooldown[src] = os.time() + Config.Missions.cooldown
    DB.audit('mission', m.job, GSJ.cid(src), nil, m.earned, ('%d étapes, %.1f km'):format(#m.steps, m.distance / 1000))
    TriggerClientEvent('gs_jobs:client:missionEnd', src, 'done', m.earned)
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Reward(src, 'job_mission') end
end



local function stop(src, reason)
    if not Active[src] then return end
    Active[src] = nil
    Cooldown[src] = os.time() + Config.Missions.cooldown
    TriggerClientEvent('gs_jobs:client:missionEnd', src, reason, 0)
end

--- Contrôles communs : mission active, même métier, en service.
local function current(src)
    local m = Active[src]
    if not m then return nil, L('invalid') end
    local job = Bridge:GetJob(src)
    if not job or job.name ~= m.job or not job.onduty then
        stop(src, 'cancel')
        return nil, L('not_on_duty')
    end
    return m, Jobs[m.job].mission
end

--- Anti-TP : durée minimale crédible depuis l'étape précédente (false = mission annulée).
local function credible(src, m, target)
    local dist = #(target - m.lastPos)
    local elapsed = (GetGameTimer() - m.lastAt) / 1000
    if elapsed < dist / Config.Missions.maxSpeed then
        GSJ.log('Mission suspecte : %s (%s) job %s, %.0f m en %.1f s', GetPlayerName(src), GSJ.cid(src), m.job, dist, elapsed)
        DB.audit('mission_suspect', m.job, GSJ.cid(src), nil, nil, ('%.0f m en %.1f s'):format(dist, elapsed))
        stop(src, 'cancel')
        return false
    end
    m.distance = m.distance + dist
    m.lastPos, m.lastAt = target, GetGameTimer()
    return true
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
        job = job.name, steps = steps, index = 1, distance = 0, earned = 0, pending = 0, carrying = false, returning = false,
        lastPos = pos, lastAt = GetGameTimer(),
    }
    sendStep(src, Active[src])
    return true, L('mission_started')
end)

--- V12.39 · Ramasser l'objet à porter (sac poubelle) à l'étape : le véhicule de service doit être garé à côté.
lib.callback.register('gs_jobs:mission:pickup', function(src)
    if not GSJ.guard(src, 'mission_pickup', 3, 5000) then return false, L('slow_down') end
    local m, mdef = current(src)
    if not m then return false, mdef end
    if not mdef.carry or m.returning then return false, L('invalid') end
    if m.carrying then return false, L('mission_carrying') end
    local target = m.steps[m.index]
    if #(GetEntityCoords(GetPlayerPed(src)) - target) > Config.Missions.checkpointRadius + Config.ServerTolerance then return false, L('too_far') end
    local veh = GSJ.getJobVehicle(src)
    if mdef.vehicleRequired ~= false and (not veh or #(GetEntityCoords(veh) - target) > Config.Missions.vehicleRadius) then
        return false, L('mission_need_vehicle')
    end
    m.carrying = true
    return true
end)

lib.callback.register('gs_jobs:mission:step', function(src)
    if not GSJ.guard(src, 'mission_step', 3, 5000) then return false, L('slow_down') end
    local m, mdef = current(src)
    if not m then return false, mdef end
    if m.returning then return false, L('mission_go_depot') end

    local target = m.steps[m.index]
    local pos = GetEntityCoords(GetPlayerPed(src))
    if mdef.carry then
        -- V12.39 · l'étape se valide en jetant le sac dans le véhicule de service, garé près de l'étape
        if not m.carrying then return false, L('mission_pick_first') end
        local veh = GSJ.getJobVehicle(src)
        if not veh or #(GetEntityCoords(veh) - target) > Config.Missions.vehicleRadius then return false, L('mission_need_vehicle') end
        if #(pos - GetEntityCoords(veh)) > Config.Missions.depositRadius then return false, L('too_far') end
    else
        if #(pos - target) > Config.Missions.checkpointRadius + Config.ServerTolerance then return false, L('too_far') end
        if mdef.vehicleRequired ~= false then
            local veh = GSJ.getJobVehicle(src)
            if not veh or #(GetEntityCoords(veh) - target) > Config.Missions.vehicleRadius then
                return false, L('mission_need_vehicle')
            end
        end
    end

    if not credible(src, m, target) then return false, L('mission_suspicious') end
    m.carrying = false
    local last = m.index == #m.steps
    local pay = mdef.payPerStop and math.random(mdef.payPerStop[1], mdef.payPerStop[2]) or 0
    if last then
        pay = pay + math.floor(m.distance / 1000 * (mdef.perKm or 0)) + (mdef.completionBonus or 0)
    end

    if mdef.payAtDepot then
        -- V12.39 · rien n'est versé en route : tout est payé au retour au dépôt
        m.pending = m.pending + pay
        if last then
            m.returning = true
            sendStep(src, m)
            return true, L('mission_return', m.pending)
        end
        m.index = m.index + 1
        sendStep(src, m)
        return true, L('mission_step_pending', m.pending)
    end

    if last then
        finish(src, m, pay)
        return true
    end
    if pay > 0 and Bridge:AddMoney(src, 'bank', pay, 'mission ' .. m.job) then m.earned = m.earned + pay end
    m.index = m.index + 1
    sendStep(src, m)
    return true, pay > 0 and L('mission_step_paid', pay) or nil
end)

--- V12.39 · Retour au dépôt (métiers payés au dépôt) : la tournée est payée en une fois.
lib.callback.register('gs_jobs:mission:depot', function(src)
    if not GSJ.guard(src, 'mission_depot', 3, 5000) then return false, L('slow_down') end
    local m, mdef = current(src)
    if not m then return false, mdef end
    if not m.returning then return false, L('invalid') end
    local depot = depotOf(m.job)
    if not depot or #(GetEntityCoords(GetPlayerPed(src)) - depot) > Config.Missions.checkpointRadius + Config.ServerTolerance then return false, L('too_far') end
    if mdef.vehicleRequired ~= false then
        local veh = GSJ.getJobVehicle(src)
        if not veh or #(GetEntityCoords(veh) - depot) > Config.Missions.vehicleRadius then return false, L('mission_need_vehicle') end
    end
    if not credible(src, m, depot) then return false, L('mission_suspicious') end
    finish(src, m, m.pending)
    return true
end)

RegisterNetEvent('gs_jobs:server:missionCancel', function()
    if Security:RateLimit(source, 'gs_jobs:mission_cancel', 2, 10000) then stop(source, 'cancel') end
end)
AddEventHandler('gs_jobs:internal:endService', function(src) stop(src, 'cancel') end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Active[src], Cooldown[src] = nil, nil end)
