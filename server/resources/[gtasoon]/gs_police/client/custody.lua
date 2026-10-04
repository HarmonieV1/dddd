-- gs_police (client) · V8 : garde à vue (compte à rebours, /droits), menu K9 (chien de la police).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

-- Garde à vue ---------------------------------------------------------------------------------------------------
local custodyEnd = 0
local function rights()
    if custodyEnd <= GetGameTimer() then return notify(false, 'Tu n\'es pas en garde à vue.') end
    lib.registerContext({ id = 'gs_police_rights', title = 'Tes droits (garde à vue)', options = {
        { title = 'Demander un avocat', icon = 'scale-balanced', description = 'Les avocats en service sont prévenus',
          onSelect = function() notify(lib.callback.await('gs_police:custodyRight', false, 'lawyer')) end },
        { title = 'Garder le silence', icon = 'comment-slash', onSelect = function() notify(lib.callback.await('gs_police:custodyRight', false, 'silence')) end },
        { title = 'Passer aux aveux', icon = 'handshake', description = ('Peine réduite de %d %% si tu es incarcéré'):format(math.floor(Config.Custody.confessDiscount * 100)),
          onSelect = function()
              if lib.alertDialog({ header = 'Passer aux aveux ?', content = 'Tes aveux seront notés au dossier.', centered = true, cancel = true }) == 'confirm' then
                  notify(lib.callback.await('gs_police:custodyRight', false, 'confess'))
              end
          end },
    } })
    lib.showContext('gs_police_rights')
end
RegisterCommand('droits', rights, false)

RegisterNetEvent('gs_police:client:custody', function(seconds)
    local was = custodyEnd > GetGameTimer()
    custodyEnd = GetGameTimer() + (seconds or 0) * 1000
    if not seconds or seconds <= 0 or was then return end
    SetTimeout(1500, rights)
    CreateThread(function()
        while GetGameTimer() < custodyEnd do
            local left = math.ceil((custodyEnd - GetGameTimer()) / 1000)
            SetTextFont(4) SetTextScale(0.0, 0.5) SetTextColour(79, 216, 255, 230) SetTextOutline() SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('GARDE À VUE · %d:%02d · /droits'):format(left // 60, left % 60))
            EndTextCommandDisplayText(0.5, 0.05)
            Wait(0)
        end
    end)
end)

-- K9 ------------------------------------------------------------------------------------------------------------
local dog
local function dogFollow()
    if dog and DoesEntityExist(dog) then ClearPedTasks(dog) TaskFollowToOffsetOfEntity(dog, cache.ped, 0.5, -1.0, 0.0, 5.0, -1, 1.0, true) end
end

local function nearestVehicle(range)
    local me, best, bestD = GetEntityCoords(cache.ped), 0, range
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - me)
        if d < bestD then best, bestD = v, d end
    end
    return best
end

local function sniffAnim(target)
    if not dog then return end
    TaskGoToEntity(dog, target, 6000, 1.0, 2.0, 0, 0)
    Wait(3500)
    if lib.requestAnimDict('creatures@rottweiler@amb@world_dog_sitting@idle_a', 2000) then
        TaskPlayAnim(dog, 'creatures@rottweiler@amb@world_dog_sitting@idle_a', 'idle_b', 4.0, -4.0, 2500, 0, 0, false, false, false)
    end
    Wait(2500)
end

function GSPolice_K9Menu()
    local options = {}
    if not dog or not DoesEntityExist(dog) then
        options[1] = { title = 'Sortir le chien', icon = 'dog', onSelect = function()
            local h = GetHashKey(Config.K9.model)
            if not lib.requestModel(h, 5000) then return end
            local c = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, -1.5, 0.0)
            dog = CreatePed(28, h, c.x, c.y, c.z, GetEntityHeading(cache.ped), true, true)
            SetModelAsNoLongerNeeded(h)
            SetPedRelationshipGroupHash(dog, GetHashKey('COP'))
            SetBlockingOfNonTemporaryEvents(dog, true)
            SetEntityInvincible(dog, true)
            dogFollow()
        end }
    else
        options = {
            { title = 'Au pied', icon = 'person-walking', onSelect = dogFollow },
            { title = 'Renifler le véhicule le plus proche', icon = 'car', onSelect = function()
                local veh = nearestVehicle(Config.K9.range)
                if veh == 0 then return notify(false, 'Aucun véhicule proche.') end
                sniffAnim(veh)
                notify(lib.callback.await('gs_police:action', false, 'k9', nil, { netId = VehToNet(veh) }))
                dogFollow()
            end },
            { title = 'Renifler une personne', icon = 'user', onSelect = function()
                local me, best, bestD = GetEntityCoords(cache.ped), nil, Config.K9.range
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        local d = #(GetEntityCoords(GetPlayerPed(pid)) - me)
                        if d < bestD then best, bestD = pid, d end
                    end
                end
                if not best then return notify(false, 'Personne à portée.') end
                sniffAnim(GetPlayerPed(best))
                notify(lib.callback.await('gs_police:action', false, 'k9', nil, { target = GetPlayerServerId(best) }))
                dogFollow()
            end },
            { title = 'Monter dans le véhicule', icon = 'car-side', onSelect = function()
                local veh = cache.vehicle or nearestVehicle(8.0)
                if veh == 0 then return notify(false, 'Aucun véhicule.') end
                TaskEnterVehicle(dog, veh, 8000, 0, 2.0, 1, 0)
            end },
            { title = 'Rentrer le chien', icon = 'house', onSelect = function() DeleteEntity(dog) dog = nil end },
        }
    end
    lib.registerContext({ id = 'gs_police_k9', title = 'Chien K9', menu = 'gs_police_menu', options = options })
    lib.showContext('gs_police_k9')
end

AddEventHandler('gs_bridge:client:jobUpdated', function(job)
    if dog and (not job or not job.onduty or not Config.PoliceJobs[job.name]) then if DoesEntityExist(dog) then DeleteEntity(dog) end dog = nil end
end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and dog and DoesEntityExist(dog) then DeleteEntity(dog) end end)
