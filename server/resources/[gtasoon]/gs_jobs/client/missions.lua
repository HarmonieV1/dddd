-- Affichage de l'étape de mission courante. Le point n'existe qu'une fois : 0 ms hors de sa zone.
local current -- { point, blip }
local carrying -- V12.39 · { obj, step } : objet porté (sac poubelle) jusqu'au véhicule de service

local function dropCarry()
    if not carrying then return end
    local c = carrying.step.carry
    if DoesEntityExist(carrying.obj) then DeleteEntity(carrying.obj) end
    StopAnimTask(cache.ped, c.anim.dict, c.anim.clip, 1.0)
    carrying = nil
    lib.hideTextUI()
end

local function clear()
    dropCarry()
    if not current then return end
    current.alive = false -- V12.51 : ox_lib appelle encore nearby ~0,3 s après remove() (sinon le [E] restait affiché)
    current.point:remove()
    RemoveBlip(current.blip)
    lib.hideTextUI()
    current = nil
end

--- Véhicule de service le plus proche (modèle du métier, à moins de 12 m) et l'arrière de sa caisse.
local function truckRear(model)
    local hash, me, best, bestD = GetHashKey(model or ''), GetEntityCoords(cache.ped), nil, 12.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if GetEntityModel(v) == hash then
            local d = #(GetEntityCoords(v) - me)
            if d < bestD then best, bestD = v, d end
        end
    end
    if not best then return nil end
    local min = GetModelDimensions(hash)
    return best, GetOffsetFromEntityInWorldCoords(best, 0.0, min.y - 0.6, 0.0)
end

local function deposit(step)
    if not carrying or carrying.busy then return end -- [E] et Alt en même temps : un seul jet
    carrying.busy = true
    local c = step.carry
    local obj = carrying.obj
    lib.hideTextUI()
    StopAnimTask(cache.ped, c.anim.dict, c.anim.clip, 1.0)
    if lib.requestAnimDict(c.throw.dict, 1500) then
        TaskPlayAnim(cache.ped, c.throw.dict, c.throw.clip, 8.0, -8.0, c.throw.duration, 48, 0, false, false, false)
    end
    Wait(c.throw.duration - 300)
    local ok, msg = lib.callback.await('gs_jobs:mission:step', false)
    if ok then
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
        carrying = nil
    elseif carrying then
        carrying.busy = false
        TaskPlayAnim(cache.ped, c.anim.dict, c.anim.clip, 8.0, -8.0, -1, c.anim.flag, 0, false, false, false) -- refusé : on garde le sac
    end
    GSJ.result(ok, msg)
end

--- Le joueur porte le sac : marche seulement (ni sprint, ni saut, ni arme, ni véhicule) jusqu'à l'arrière du camion.
local function startCarry(step)
    local c = step.carry
    local ped = cache.ped
    local hash = GetHashKey(c.prop.model)
    if not lib.requestModel(hash, 3000) or not lib.requestAnimDict(c.anim.dict, 1500) then return end
    local p = GetEntityCoords(ped)
    local obj = CreateObject(hash, p.x, p.y, p.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, c.prop.bone), c.prop.pos.x, c.prop.pos.y, c.prop.pos.z,
        c.prop.rot.x, c.prop.rot.y, c.prop.rot.z, true, true, false, true, 1, true)
    TaskPlayAnim(ped, c.anim.dict, c.anim.clip, 8.0, -8.0, -1, c.anim.flag, 0, false, false, false)
    carrying = { obj = obj, step = step }
    local shown
    -- Ne pas monter en voiture avec le sac : le joueur le pose d'abord (Alt sur la benne, ou [E] à l'arrière).
    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:addModel(step.vehicleModel, { { name = 'gs_jobs_carry', icon = 'fa-solid fa-trash', label = c.label, distance = 4.0,
                canInteract = function() return carrying ~= nil end, onSelect = function() deposit(step) end } })
        end)
    end
    CreateThread(function()
        -- par frame tant que le sac est porté (contrôles à bloquer à chaque image) : quelques dizaines de secondes par étape
        while carrying and carrying.obj == obj do
            DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 44, true)
            if not IsEntityPlayingAnim(ped, c.anim.dict, c.anim.clip, 3) and not IsPedRagdoll(ped) then
                TaskPlayAnim(ped, c.anim.dict, c.anim.clip, 8.0, -8.0, -1, c.anim.flag, 0, false, false, false)
            end
            local veh, rear = truckRear(step.vehicleModel)
            local near = veh and #(GetEntityCoords(ped) - rear) < 2.2
            if near ~= shown then
                shown = near
                lib.showTextUI(near and ('[E] ' .. c.label) or c.hint)
            end
            if near and IsControlJustReleased(0, 38) and not IsNuiFocused() then deposit(step) end
            if IsPedDeadOrDying(ped, true) then dropCarry() break end
            Wait(0)
        end
        if GetResourceState('ox_target') == 'started' then pcall(function() exports.ox_target:removeModel(step.vehicleModel, 'gs_jobs_carry') end) end
    end)
end

function GSJ.missionActive()
    return current ~= nil
end

RegisterNetEvent('gs_jobs:client:missionStep', function(step)
    clear()
    local c = step.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipColour(blip, 48)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 48)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(step.label)
    EndTextCommandSetBlipName(blip)

    local text = L('mission_press', step.label, step.index, step.total)
    local shown, busy = false, false
    local point = lib.points.new({ coords = c, distance = 60.0 })
    local me = { point = point, blip = blip, alive = true }

    function point:nearby()
        if not me.alive then return end
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 4.0, 1.0,
            90, 200, 255, 70, false, false, 2, false, nil, nil, false)
        local inside = self.currentDistance <= Config.Missions.checkpointRadius
        if carrying then return end -- V12.39 · sac en main : l'étape se valide à la benne
        if inside ~= shown and not busy then
            shown = inside
            if inside then lib.showTextUI(text) else lib.hideTextUI() end
        end
        if inside and not busy and IsControlJustReleased(0, 38) and not IsNuiFocused() then
            busy, shown = true, false
            lib.hideTextUI()
            CreateThread(function()
                -- Animation du métier (à pied seulement), ex : carton porté, sac poubelle jeté
                local onFoot = not cache.vehicle
                local done = lib.progressBar({
                    duration = step.duration, label = step.label, canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = onFoot and step.anim or nil, prop = onFoot and step.prop or nil,
                })
                if done then
                    if step.kind == 'depot' then -- V12.39 · tournée rendue au dépôt : payée ici
                        local ok, msg = lib.callback.await('gs_jobs:mission:depot', false)
                        GSJ.result(ok, msg)
                    elseif step.carry then -- V12.39 · on ramasse le sac, l'étape se valide en le jetant dans la benne
                        local ok, msg = lib.callback.await('gs_jobs:mission:pickup', false)
                        if ok then startCarry(step) else GSJ.result(ok, msg) end
                    else
                        local ok, msg = lib.callback.await('gs_jobs:mission:step', false)
                        GSJ.result(ok, msg)
                    end
                end
                busy = false
            end)
        end
    end

    function point:onExit()
        if shown and me.alive then lib.hideTextUI() shown = false end
    end

    current = me
end)

RegisterNetEvent('gs_jobs:client:missionEnd', function(reason, earned)
    clear()
    if reason == 'done' then
        GSJ.notify(L('mission_done', earned or 0), 'success')
        if not cache.vehicle then -- petite animation de fin de service
            lib.requestAnimDict('gestures@m@standing@casual', 1500)
            TaskPlayAnim(cache.ped, 'gestures@m@standing@casual', 'gesture_pleased', 8.0, -8.0, 2000, 48, 0, false, false, false)
        end
    else
        GSJ.notify(L('mission_cancelled'), 'inform')
    end
end)

AddEventHandler('gs_bridge:client:playerUnloaded', clear)
