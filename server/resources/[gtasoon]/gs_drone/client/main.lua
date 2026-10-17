-- gs_drone (client) · V12.64 · Drone de repérage. Le pilote reste sur place, tablette en main ; la caméra suit le drone.
-- Commandes (affichées à l'écran) : [Z/Q/S/D] ou [W/A/S/D] avancer / tourner les côtés, [Espace] monter, [Ctrl] descendre,
-- souris : regarder, molette : zoom, [E] vision (normale / nuit / thermique selon le drone), [G] marquer un suspect (police),
-- [Retour arrière] ou [X] : rappeler le drone. Le drone ne dépasse pas sa portée (l'image grésille près de la limite).
local flying = nil -- { drone, cam, opts, t0, vision, fov, heading, pitch, tablet, hits }
local airborne = {} -- [net] = true : drones des autres joueurs en vol (pour pouvoir les abattre)

local function notify(ok, msg) if msg then lib.notify({ title = 'Drone', description = msg, type = ok and 'success' or 'error', duration = 6000 }) end end

local function rotToDir(r)
    local z, x = math.rad(r.z), math.rad(r.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function setVision(v, thermal)
    SetNightvision(v == 1)
    SetSeethrough(v == 2 and thermal)
end

local function tabletOn()
    local ped = cache.ped
    local dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
    if lib.requestAnimDict(dict, 2000) then TaskPlayAnim(ped, dict, 'base', 3.0, 3.0, -1, 49, 0, false, false, false) end
    local h = GetHashKey('prop_cs_tablet')
    if not lib.requestModel(h, 2000) then return nil end
    local c = GetEntityCoords(ped)
    local t = CreateObject(h, c.x, c.y, c.z + 0.2, true, true, false)
    AttachEntityToEntity(t, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(h)
    return t
end

--- Fin du vol : caméra rendue, effets coupés, drone repris (ou laissé tomber s'il est abattu)
local function stop(crashed)
    local f = flying
    if not f then return end
    flying = nil
    lib.hideTextUI()
    RenderScriptCams(false, false, 0, true, false)
    if f.cam then DestroyCam(f.cam, false) end
    ClearTimecycleModifier()
    setVision(0, false)
    ClearFocus()
    StopAnimTask(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
    if f.tablet and DoesEntityExist(f.tablet) then DeleteEntity(f.tablet) end
    if f.drone and DoesEntityExist(f.drone) then
        if crashed then -- abattu : étincelles, il tombe, puis disparaît
            local d = f.drone
            local c = GetEntityCoords(d)
            if lib.requestNamedPtfxAsset('core', 1000) then
                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord('ent_sht_electrical_box', c.x, c.y, c.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
            end
            FreezeEntityPosition(d, false)
            ActivatePhysics(d)
            SetTimeout(8000, function() if DoesEntityExist(d) then DeleteEntity(d) end end)
        else
            DeleteEntity(f.drone)
        end
    end
    if not crashed then TriggerServerEvent('gs_drone:server:land') end
end

--- Suspect au centre de l'écran (police) : joueur à pied ou conducteur d'un véhicule
local function aimedPlayer(f)
    local c = GetCamCoord(f.cam)
    local e = c + rotToDir(GetCamRot(f.cam, 2)) * Config.Mark.maxDistance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(c.x, c.y, c.z, e.x, e.y, e.z, 1 | 2 | 8, f.drone, 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if not (hit == 1 or hit == true) or not ent or ent == 0 then return nil end
    if IsEntityAVehicle(ent) then ent = GetPedInVehicleSeat(ent, -1) end
    if not ent or ent == 0 or not IsEntityAPed(ent) or not IsPedAPlayer(ent) or ent == cache.ped then return nil end
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(ent))
end

local function help(f)
    local o = f.opts
    lib.showTextUI(('%s · [ZQSD/WASD] voler · [Espace/Ctrl] monter/descendre · [Molette] zoom · [E] vision%s · [X] rappeler'):format(
        o.label, o.mark and ' · [G] marquer un suspect' or ''), { position = 'top-center', icon = 'satellite-dish' })
end

local function launch(kind)
    if flying then return stop() end
    if cache.vehicle then return notify(false, 'Descends du véhicule pour piloter.') end
    local ok, o = lib.callback.await('gs_drone:launch', false, kind)
    if not ok then return notify(false, o) end
    local h = GetHashKey(o.model)
    if not lib.requestModel(h, 4000) then TriggerServerEvent('gs_drone:server:land') return notify(false, 'Modèle du drone introuvable.') end
    local ped = cache.ped
    local start = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.2, 0.6)
    local drone = CreateObject(h, start.x, start.y, start.z, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not drone or drone == 0 then TriggerServerEvent('gs_drone:server:land') return notify(false, 'Le drone ne démarre pas.') end
    SetEntityHeading(drone, GetEntityHeading(ped))
    FreezeEntityPosition(drone, true)
    SetEntityCollision(drone, true, true)
    lib.callback.await('gs_drone:spawned', false, NetworkGetNetworkIdFromEntity(drone))
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    AttachCamToEntity(cam, drone, 0.0, 0.0, -0.25, true)
    SetCamFov(cam, 60.0)
    RenderScriptCams(true, false, 0, true, false)
    SetFocusEntity(drone)
    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(1.0)
    flying = { drone = drone, cam = cam, opts = o, t0 = GetGameTimer(), vision = 0, fov = 60.0, heading = GetEntityHeading(ped), pitch = -10.0,
        tablet = tabletOn(), hp = GetEntityHealth(ped) }
    help(flying)
    notify(true, ('%s en l\'air : batterie %d s, portée %d m.'):format(o.label, o.battery, math.floor(o.range)))
    CreateThread(function()
        local fuzz = false
        while flying and flying.drone == drone do -- par frame : pilotage du drone (seulement pendant un vol)
            local f = flying
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- parler (pma-voice) pendant le vol
            HideHudAndRadarThisFrame()
            local dt = GetFrameTime()
            -- regard (souris), zoom (molette)
            f.heading = (f.heading - GetDisabledControlNormal(0, 1) * 8.0) % 360.0
            f.pitch = math.max(-89.0, math.min(30.0, f.pitch - GetDisabledControlNormal(0, 2) * 8.0))
            if IsDisabledControlJustPressed(0, 241) then f.fov = math.max(15.0, f.fov - 5.0) end
            if IsDisabledControlJustPressed(0, 242) then f.fov = math.min(80.0, f.fov + 5.0) end
            SetCamFov(f.cam, f.fov)
            SetCamRot(f.cam, f.pitch, 0.0, f.heading, 2)
            SetEntityHeading(drone, f.heading)
            -- déplacement (repère du drone), plafonné à la portée et à la hauteur max, jamais dans un mur ni sous le sol
            local fwd = (IsDisabledControlPressed(0, 32) and 1 or 0) - (IsDisabledControlPressed(0, 33) and 1 or 0)
            local side = (IsDisabledControlPressed(0, 35) and 1 or 0) - (IsDisabledControlPressed(0, 34) and 1 or 0)
            local up = (IsDisabledControlPressed(0, 22) and 1 or 0) - (IsDisabledControlPressed(0, 36) and 1 or 0)
            if fwd ~= 0 or side ~= 0 or up ~= 0 then
                local r = math.rad(f.heading)
                local sp = f.opts.speed * dt * (IsDisabledControlPressed(0, 21) and 1.8 or 1.0)
                local p = GetEntityCoords(drone)
                local nx = p.x + (-math.sin(r) * fwd + math.cos(r) * side) * sp
                local ny = p.y + (math.cos(r) * fwd + math.sin(r) * side) * sp
                local nz = p.z + up * sp * 0.7
                local found, gz = GetGroundZFor_3dCoord(nx, ny, nz + 2.0, false)
                if found then nz = math.max(gz + 0.6, math.min(gz + f.opts.maxHeight, nz)) end
                local home = GetEntityCoords(cache.ped)
                local inRange = #(vector3(nx, ny, nz) - home) <= f.opts.range
                local ray = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z, nx + (nx - p.x) * 4.0, ny + (ny - p.y) * 4.0, nz + (nz - p.z) * 4.0, 1 | 16, drone, 7)
                local _, hit = GetShapeTestResult(ray)
                if inRange and not (hit == 1 or hit == true) then SetEntityCoordsNoOffset(drone, nx, ny, nz, false, false, false) end
            end
            -- image qui grésille près de la limite de portée
            local far = #(GetEntityCoords(drone) - GetEntityCoords(cache.ped)) > f.opts.range * 0.85
            if far ~= fuzz then
                fuzz = far
                SetTimecycleModifier(far and 'CAMERA_secuirity_FUZZ' or 'scanline_cam_cheap')
            end
            if IsDisabledControlJustPressed(0, 38) then -- [E] vision
                f.vision = (f.vision + 1) % (f.opts.thermal and 3 or 2)
                setVision(f.vision, f.opts.thermal)
            end
            if f.opts.mark and IsDisabledControlJustPressed(0, 47) then -- [G] marquer
                local id = aimedPlayer(f)
                if id then TriggerServerEvent('gs_drone:server:mark', id) notify(true, 'Suspect marqué : tes collègues le suivent sur la carte.')
                else notify(false, 'Vise un suspect (au centre de l\'image).') end
            end
            -- batterie, pilote bousculé ou blessé, rappel
            local left = f.opts.battery - (GetGameTimer() - f.t0) / 1000
            if left <= 0 then notify(false, 'Batterie vide : le drone rentre.') stop() break end
            if left < 15 and not f.lowWarn then f.lowWarn = true notify(false, 'Batterie faible : 15 s.') end
            if IsPedRagdoll(cache.ped) or IsPedDeadOrDying(cache.ped, true) or GetEntityHealth(cache.ped) < f.hp - 10 then
                notify(false, 'Tu lâches la tablette : le drone rentre.') stop() break
            end
            if IsDisabledControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 177) then stop() break end
            Wait(0)
        end
    end)
end

exports('Launch', function(kind) launch(kind == 'police' and 'police' or 'gang') end) -- F4 police (gs_police)
exports('useItem', function() launch('gang') end) -- objet « Drone de repérage » (ox_inventory)
RegisterCommand(Config.Command, function() launch('police') end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Police en service : drone de surveillance (refaire pour le rappeler)')

RegisterNetEvent('gs_drone:client:hurt', function(n) notify(false, ('Ton drone est touché (%d/%d) !'):format(n, Config.HitPoints)) end)
RegisterNetEvent('gs_drone:client:destroyed', function(lost)
    stop(true)
    notify(false, lost and 'Ton drone a été abattu : il est perdu.' or 'Le drone de service a été abattu.')
end)

-- Police : suspect marqué par un drone (blip rafraîchi, jamais le nom), drone de gang repéré par le radar
local marks = {}
RegisterNetEvent('gs_drone:client:mark', function(id, pos, left)
    local b = marks[id]
    if not pos or (tonumber(left) or 0) <= 0 then if b then RemoveBlip(b) marks[id] = nil end return end
    if not b then
        b = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(b, 627) SetBlipColour(b, 1) SetBlipScale(b, 0.9) SetBlipFlashes(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Suspect (drone)') EndTextCommandSetBlipName(b)
        marks[id] = b
        lib.notify({ title = 'Drone LSPD', description = 'Un suspect est suivi par le drone : il apparaît sur ta carte.', type = 'inform', duration = 7000 })
    else SetBlipCoords(b, pos.x, pos.y, pos.z) end
end)
RegisterNetEvent('gs_drone:client:radar', function(zone, radius)
    local b = AddBlipForRadius(zone.x, zone.y, zone.z, radius + 0.0)
    SetBlipColour(b, 1) SetBlipAlpha(b, 90)
    lib.notify({ title = 'Radar LSPD', description = 'Drone non identifié signalé dans la zone.', type = 'inform', duration = 8000 })
    SetTimeout(60000, function() RemoveBlip(b) end)
end)

-- Abattre un drone : seulement pendant qu'un drone vole quelque part, et seulement près de lui (par frame en tir)
local watching, lastImpact = false, nil
RegisterNetEvent('gs_drone:client:airborne', function(net, on)
    airborne[net] = on and true or nil
    if not on or watching then return end
    watching = true
    CreateThread(function()
        while next(airborne) ~= nil do
            local near
            local me = GetEntityCoords(cache.ped)
            for n in pairs(airborne) do
                if NetworkDoesNetworkIdExist(n) then
                    local d = NetworkGetEntityFromNetworkId(n)
                    if d and d ~= 0 and DoesEntityExist(d) and (not flying or flying.drone ~= d) and #(GetEntityCoords(d) - me) < Config.Shooter.radius then
                        near = near or {}
                        near[n] = d
                    end
                end
            end
            if not near then Wait(1000) else
                if IsPedShooting(cache.ped) then
                    local okI, impact = GetPedLastWeaponImpactCoord(cache.ped)
                    if okI and (not lastImpact or #(impact - lastImpact) > 0.01) then -- une balle = un envoi (la dernière impact reste lue)
                        lastImpact = impact
                        for n, d in pairs(near) do
                            if #(GetEntityCoords(d) - impact) < 1.2 then TriggerServerEvent('gs_drone:server:hit', n) break end
                        end
                    end
                end
                Wait(0)
            end
        end
        watching = false
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stop()
    for _, b in pairs(marks) do RemoveBlip(b) end
end)
