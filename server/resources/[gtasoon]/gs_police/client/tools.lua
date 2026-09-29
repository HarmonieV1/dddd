-- gs_police (client) : objets de voirie, herse (crève les pneus), radar de vitesse. Boucles seulement si utiles.
GSPolice = GSPolice or {}
GSPolice.radar = false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

-- Objets de voirie -------------------------------------------------------------------------------------------------
function GSPolice.objectsMenu()
    local options = {}
    for kind, def in pairs(Config.Objects.list) do
        options[#options + 1] = { title = 'Poser : ' .. def.label, icon = kind == 'spikes' and 'road-spikes' or 'road-barrier', onSelect = function()
            local ped = PlayerPedId()
            local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
            local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
            if not lib.progressBar({ duration = 1500, label = 'Mise en place…', anim = { dict = 'pickup_object', clip = 'pickup_low' },
                disable = { move = true, car = true } }) then return end
            notify(lib.callback.await('gs_police:action', false, 'object', nil,
                { kind = kind, coords = { x = c.x, y = c.y, z = found and gz or c.z - 1.0 }, heading = GetEntityHeading(ped) }))
        end }
    end
    table.sort(options, function(a, b) return a.title < b.title end)
    options[#options + 1] = { title = 'Retirer tous mes objets', icon = 'trash', iconColor = '#ff2e88', onSelect = function()
        notify(lib.callback.await('gs_police:action', false, 'clearobjects'))
    end }
    lib.registerContext({ id = 'gs_police_objects', title = 'Objets de voirie', menu = 'gs_police_menu', options = options })
    lib.showContext('gs_police_objects')
end

-- Herse : seulement pour le conducteur, seulement si une herse existe à moins de 60 m ----------------------------------
CreateThread(function()
    while true do
        local spikes = GlobalState.gsSpikes or {}
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local sleep = 1000
        if #spikes > 0 and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local c = GetEntityCoords(veh)
            for _, s in ipairs(spikes) do
                local d = #(c - vec3(s.x, s.y, s.z))
                if d < 60.0 then sleep = 100 end
                if d < 2.5 then
                    for wheel = 0, 7 do SetVehicleTyreBurst(veh, wheel, false, 1000.0) end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-- Radar de vitesse -------------------------------------------------------------------------------------------------
function GSPolice.toggleRadar()
    local job = exports.gs_bridge:GetJob()
    if not job or job.name ~= Config.PoliceJob or not job.onduty then return notify(false, 'Réservé à la police en service.') end
    GSPolice.radar = not GSPolice.radar
    notify(true, GSPolice.radar and 'Radar : ON (en véhicule)' or 'Radar : OFF')
    if not GSPolice.radar then return end
    CreateThread(function()
        local text = ''
        local nextScan = 0
        while GSPolice.radar do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then
                Wait(500)
            else
                if GetGameTimer() > nextScan then
                    nextScan = GetGameTimer() + 250
                    local from = GetOffsetFromEntityInWorldCoords(veh, 0.0, 3.0, 0.5)
                    local to = GetOffsetFromEntityInWorldCoords(veh, 0.0, Config.Radar.range, 0.5)
                    local ray = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 3.0, 2, veh, 7)
                    local _, hit, _, _, ent = GetShapeTestResult(ray)
                    if hit == 1 and ent ~= 0 and IsEntityAVehicle(ent) then
                        text = ('RADAR · %d km/h · %s'):format(math.floor(GetEntitySpeed(ent) * Config.Radar.unit), GetVehicleNumberPlateText(ent))
                    else
                        text = ('RADAR · ma vitesse %d km/h'):format(math.floor(GetEntitySpeed(veh) * Config.Radar.unit))
                    end
                end
                SetTextFont(4) SetTextScale(0.0, 0.45) SetTextColour(40, 224, 255, 240) SetTextOutline() SetTextRightJustify(true)
                SetTextWrap(0.0, 0.985)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(text)
                EndTextCommandDisplayText(0.985, 0.72)
                Wait(0)
            end
        end
    end)
end

RegisterCommand('radar', function() GSPolice.toggleRadar() end, false)
