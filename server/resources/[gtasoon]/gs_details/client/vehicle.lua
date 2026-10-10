-- gs_details (client) : menu radial véhicule (Z, ox_lib), ceinture (B), kits de réparation / nettoyage.
local belt = false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

-- Radial véhicule (seulement quand on est dans un véhicule) ----------------------------------------------------------
local function door(i)
    return function()
        local veh = cache.vehicle
        if not veh then return end
        if GetVehicleDoorAngleRatio(veh, i) > 0.0 then SetVehicleDoorShut(veh, i, false) else SetVehicleDoorOpen(veh, i, false, false) end
    end
end

local function seat(i)
    return function()
        local veh = cache.vehicle
        if veh and IsVehicleSeatFree(veh, i) and GetEntitySpeed(veh) < 3.0 then SetPedIntoVehicle(cache.ped, veh, i)
        else notify(false, 'Place occupée (ou véhicule en mouvement).') end
    end
end

lib.registerRadial({ id = 'gs_vehicle_doors', items = {
    { label = 'Avant gauche', icon = 'door-open', onSelect = door(0) },
    { label = 'Avant droite', icon = 'door-open', onSelect = door(1) },
    { label = 'Arrière gauche', icon = 'door-open', onSelect = door(2) },
    { label = 'Arrière droite', icon = 'door-open', onSelect = door(3) },
    { label = 'Capot', icon = 'car-burst', onSelect = door(4) },
    { label = 'Coffre', icon = 'box-open', onSelect = door(5) },
} })

lib.registerRadial({ id = 'gs_vehicle_seats', items = {
    { label = 'Conducteur', icon = 'user', onSelect = seat(-1) },
    { label = 'Passager', icon = 'user', onSelect = seat(0) },
    { label = 'Arrière gauche', icon = 'user', onSelect = seat(1) },
    { label = 'Arrière droite', icon = 'user', onSelect = seat(2) },
} })

lib.registerRadial({ id = 'gs_vehicle', items = {
    { label = 'Moteur', icon = 'power-off', onSelect = function()
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then
            SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
        end
    end },
    { label = 'Portes', icon = 'door-open', menu = 'gs_vehicle_doors' },
    { label = 'Places', icon = 'chair', menu = 'gs_vehicle_seats' },
    { label = 'Vitres', icon = 'window-maximize', onSelect = function()
        local veh = cache.vehicle
        if not veh then return end
        if IsVehicleWindowIntact(veh, 0) then for w = 0, 3 do RollDownWindow(veh, w) end else for w = 0, 3 do RollUpWindow(veh, w) end end
    end },
    { label = 'Ceinture', icon = 'user-shield', onSelect = function() ExecuteCommand('ceinture') end },
} })

lib.onCache('vehicle', function(veh)
    if veh then lib.addRadialItem({ id = 'gs_vehicle_menu', label = 'Véhicule', icon = 'car', menu = 'gs_vehicle' })
    else lib.removeRadialItem('gs_vehicle_menu') end
end)
CreateThread(function() if cache.vehicle then lib.addRadialItem({ id = 'gs_vehicle_menu', label = 'Véhicule', icon = 'car', menu = 'gs_vehicle' }) end end)

-- Ceinture + éjection en cas de choc ----------------------------------------------------------------------------------
local function hasBelt(veh)
    local class = GetVehicleClass(veh)
    return class ~= 8 and class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 -- ni moto, vélo, bateau, hélico, avion
end

RegisterCommand('ceinture', function()
    local veh = cache.vehicle
    if not veh or not hasBelt(veh) or IsNuiFocused() then return end -- V11.5 : pas pendant une saisie
    belt = not belt
    PlaySoundFrontend(-1, belt and 'Faster_Click' or 'Faster_Click', 'RESPAWN_ONLINE_SOUNDSET', true)
    lib.notify({ description = belt and 'Ceinture attachée' or 'Ceinture détachée', type = belt and 'success' or 'warning', icon = 'user-shield' })
    LocalPlayer.state:set('gsSeatbelt', belt, false)
end, false)
RegisterKeyMapping('ceinture', 'Ceinture de sécurité', 'keyboard', Config.SeatbeltKey)

lib.onCache('vehicle', function(veh)
    belt = false
    LocalPlayer.state:set('gsSeatbelt', false, false)
    if not veh or not hasBelt(veh) then return end
    CreateThread(function()
        local last = GetEntitySpeed(veh)
        while cache.vehicle == veh do
            local speed = GetEntitySpeed(veh)
            if belt then DisableControlAction(0, 75, true) end -- pas de sortie ceinture attachée
            if not belt and last - speed > Config.Ejection.minDrop and GetPedInVehicleSeat(veh, -1) ~= 0 then
                local ped = cache.ped
                local fwd = GetEntityForwardVector(veh)
                local c = GetEntityCoords(ped)
                SetEntityCoords(ped, c.x + fwd.x * 2.0, c.y + fwd.y * 2.0, c.z + 1.0, false, false, false, false)
                SetEntityVelocity(ped, fwd.x * last * 0.6, fwd.y * last * 0.6, 2.0)
                SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
                ApplyDamageToPed(ped, math.floor(last * 1.5), false)
                break
            end
            last = speed
            Wait(belt and 0 or 100)
        end
    end)
end)

-- Kits (exports appelés par ox_inventory : client.export = 'gs_details.repair' etc.) ----------------------------------
local function targetVehicle()
    local ped = cache.ped
    if cache.vehicle then return nil, 'Descends du véhicule.' end
    local c = GetEntityCoords(ped)
    local best, bestD = nil, Config.Kits.range
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - c)
        if d < bestD then best, bestD = v, d end
    end
    if not best then return nil, 'Aucun véhicule à portée.' end
    return best
end

local function useKit(data, duration, label, scenario, apply)
    local veh, err = targetVehicle()
    if not veh then return notify(false, err) end
    if not lib.progressBar({ duration = duration, label = label, canCancel = true, anim = { scenario = scenario },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    exports.ox_inventory:useItem(data, function(used) -- [API] ox_inventory : l'item n'est consommé qu'une fois le travail fini
        if not used then return end
        NetworkRequestControlOfEntity(veh)
        local timeout = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do Wait(50) end
        apply(veh)
        ClearPedTasks(cache.ped)
    end)
end

exports('repair', function(data)
    useKit(data, Config.Kits.repair.duration, 'Réparation de fortune…', 'PROP_HUMAN_BUM_BIN', function(veh)
        SetVehicleEngineHealth(veh, math.max(GetVehicleEngineHealth(veh), Config.Kits.repair.engine))
        SetVehicleUndriveable(veh, false)
        notify(true, 'Ça roule… pour l\'instant. Passe voir un mécano.')
    end)
end)

exports('advancedRepair', function(data)
    useKit(data, Config.Kits.advancedRepair.duration, 'Réparation complète…', 'PROP_HUMAN_BUM_BIN', function(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        notify(true, 'Véhicule remis à neuf.')
    end)
end)

exports('clean', function(data)
    useKit(data, Config.Kits.clean.duration, 'Nettoyage…', 'WORLD_HUMAN_MAID_CLEAN', function(veh)
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
        notify(true, 'Nickel.')
    end)
end)
