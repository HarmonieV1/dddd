-- gs_admin (client) : panel NUI (F10), /report, /staff, effets demandés par le serveur. 0 boucle hors jail.
local open = false
local onDuty = false

local function close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openPanel()
    if open then return close() end
    local data = lib.callback.await('gs_admin:open', false)
    if not data then return lib.notify({ description = 'Accès réservé au staff.', type = 'error' }) end
    onDuty = data.onDuty
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterCommand('admin', function()
    if not open and IsNuiFocused() then return end -- V11.5 : pas par-dessus une saisie ou une autre interface
    openPanel()
end, false)
RegisterKeyMapping('admin', 'Panel staff', 'keyboard', Config.Key)

RegisterCommand('staff', function()
    local state = lib.callback.await('gs_admin:toggleDuty', false)
    if state == nil then return lib.notify({ description = 'Accès réservé au staff.', type = 'error' }) end
    onDuty = state
    lib.notify({ description = state and 'Service staff : ON. Tu reçois les tickets.' or 'Service staff : OFF.', type = state and 'success' or 'inform' })
end, false)

RegisterCommand('report', function(_, args)
    local message = table.concat(args, ' ')
    if message == '' then
        local input = lib.inputDialog('Contacter le staff', {
            { type = 'textarea', label = 'Ton problème', required = true, max = Config.Report.maxLength },
        })
        if not input then return end
        message = input[1]
    end
    TriggerServerEvent('gs_admin:server:report', message)
end, false)

-- Callbacks NUI ------------------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) close() cb(true) end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('gs_admin:open', false) or false)
end)

RegisterNUICallback('dossier', function(body, cb)
    cb(lib.callback.await('gs_admin:dossier', false, body.id) or false)
end)

RegisterNUICallback('action', function(body, cb)
    local ok, msg = lib.callback.await('gs_admin:action', false, body.name, body.target, body.data)
    cb({ ok = ok == true, message = msg })
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    local state = lib.callback.await('gs_admin:toggleDuty', false)
    if state ~= nil then onDuty = state end
    cb({ ok = state ~= nil, onDuty = onDuty })
end)

-- Tickets ------------------------------------------------------------------------------------------
RegisterNetEvent('gs_admin:client:ticket', function(t)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
    lib.notify({ title = ('Ticket #%d · %s'):format(t.id, t.name), description = t.message, type = 'warning', icon = 'life-ring', duration = 10000 })
    if open then SendNUIMessage({ action = 'ticketsChanged' }) end
end)

RegisterNetEvent('gs_admin:client:ticketsChanged', function()
    if open then SendNUIMessage({ action = 'ticketsChanged' }) end
end)

-- Effets demandés par le serveur (déjà autorisés côté serveur) -------------------------------------
RegisterNetEvent('gs_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('gs_admin:client:fixveh', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
end)

RegisterNetEvent('gs_admin:client:warn', function(reason)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', false)
    lib.alertDialog({ header = '⚠️ Avertissement du staff', content = ('**Motif :** %s\n\nMerci de respecter le règlement.'):format(reason), centered = true })
end)

RegisterNetEvent('gs_admin:client:announce', function(text)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = 'Annonce du staff', description = text, type = 'inform', icon = 'bullhorn', position = 'top', duration = 15000 })
end)

-- Isolement : compte à rebours affiché seulement pendant la peine ----------------------------------
local jailEnd = 0
RegisterNetEvent('gs_admin:client:jail', function(seconds, reason)
    local wasJailed = jailEnd > GetGameTimer()
    jailEnd = GetGameTimer() + (seconds or 0) * 1000
    if seconds and seconds > 0 then
        lib.notify({ title = 'Salle d\'isolement', description = 'Motif : ' .. (reason or '—'), type = 'error', duration = 10000 })
        if wasJailed then return end
        CreateThread(function()
            while GetGameTimer() < jailEnd do
                local left = math.ceil((jailEnd - GetGameTimer()) / 1000)
                SetTextFont(4)
                SetTextScale(0.0, 0.5)
                SetTextColour(255, 46, 136, 230)
                SetTextOutline()
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(('ISOLEMENT · %d:%02d'):format(left // 60, left % 60))
                EndTextCommandDisplayText(0.5, 0.05)
                Wait(0)
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)

-- Événements staff (Actions.event) : annonce + GPS pour tous ; effet temporaire dans le rayon du point -------------
local eventOn = nil
local UNARMED_HASH = GetHashKey('WEAPON_UNARMED')
RegisterNetEvent('gs_admin:client:eventStart', function(ev)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = 'Événement : ' .. ev.label, description = ev.text, type = 'inform', icon = 'champagne-glasses', position = 'top', duration = 15000 })
    SetNewWaypoint(ev.x, ev.y)
    if not ev.fx then return end
    eventOn = { fx = ev.fx, center = vec3(ev.x, ev.y, ev.z), radius = ev.radius, untilAt = GetGameTimer() + math.min(ev.seconds, 3600) * 1000 }
    CreateThread(function()
        local pid = PlayerId()
        -- par frame : seulement pendant un événement staff (super saut / boxe ont besoin d'un appel à chaque image)
        while eventOn and GetGameTimer() < eventOn.untilAt do
            local inside = #(GetEntityCoords(cache.ped) - eventOn.center) <= eventOn.radius
            if eventOn.fx == 'fastrun' then SetRunSprintMultiplierForPlayer(pid, inside and 1.49 or 1.0)
            elseif eventOn.fx == 'lowgravity' then SetGravityLevel(inside and 1 or 0)
            elseif eventOn.fx == 'superjump' and inside then SetSuperJumpThisFrame(pid)
            elseif eventOn.fx == 'melee' and inside then
                if GetSelectedPedWeapon(cache.ped) ~= UNARMED_HASH then SetCurrentPedWeapon(cache.ped, UNARMED_HASH, true) end
                DisableControlAction(0, 37, true) -- roue des armes
            end
            Wait(0)
        end
        SetRunSprintMultiplierForPlayer(pid, 1.0)
        SetGravityLevel(0)
        eventOn = nil
        lib.notify({ description = 'Fin de l\'événement. Merci d\'avoir joué !', type = 'inform' })
    end)
end)
