-- Affichage de l'étape de mission courante. Le point n'existe qu'une fois : 0 ms hors de sa zone.
local current -- { point, blip }

local function clear()
    if not current then return end
    current.point:remove()
    RemoveBlip(current.blip)
    lib.hideTextUI()
    current = nil
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

    function point:nearby()
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 4.0, 1.0,
            255, 46, 136, 120, false, false, 2, false, nil, nil, false)
        local inside = self.currentDistance <= Config.Missions.checkpointRadius
        if inside ~= shown and not busy then
            shown = inside
            if inside then lib.showTextUI(text) else lib.hideTextUI() end
        end
        if inside and not busy and IsControlJustReleased(0, 38) then
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
                    local ok, msg = lib.callback.await('gs_jobs:mission:step', false)
                    GSJ.result(ok, msg)
                end
                busy = false
            end)
        end
    end

    function point:onExit()
        if shown then lib.hideTextUI() shown = false end
    end

    current = { point = point, blip = blip }
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
