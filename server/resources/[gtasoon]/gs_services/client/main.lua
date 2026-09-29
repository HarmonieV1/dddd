-- gs_services (client) : à terre sans EMS en service → « [G] Appeler les secours ». Un secouriste PNJ arrive
-- à pied, fait un massage cardiaque, puis le serveur te réanime. Vérif toutes les secondes, dessin seulement à terre.
local busy = false

local function downed()
    local s = LocalPlayer.state['qbx_medical:deathState'] -- [API] qbx_medical : 2 à terre, 3 mort
    return s ~= nil and s >= 2
end

local function drawPrompt(text)
    SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline()
    SetTextColour(40, 224, 255, 240)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.86)
end

local function groundAround(origin)
    for _, dist in ipairs({ 25.0, 15.0, 8.0 }) do
        local a = math.random() * 2 * math.pi
        local x, y = origin.x + math.cos(a) * dist, origin.y + math.sin(a) * dist
        local found, z = GetGroundZFor_3dCoord(x, y, origin.z + 5.0, false)
        if found then return vec3(x, y, z) end
    end
    return vec3(origin.x + 3.0, origin.y, origin.z)
end

local function medicScene(seconds)
    local me = PlayerPedId()
    local c = GetEntityCoords(me)
    local hash = GetHashKey(Config.Medic.model)
    lib.requestModel(hash, 5000)
    local start = groundAround(c)
    local medic = CreatePed(4, hash, start.x, start.y, start.z, 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(medic, true)
    SetBlockingOfNonTemporaryEvents(medic, true)
    TaskGoToEntity(medic, me, -1, 1.0, 2.0, 1073741824, 0) -- court vers toi
    local deadline = GetGameTimer() + seconds * 1000
    local arriveBy = GetGameTimer() + 12000
    while GetGameTimer() < arriveBy and #(GetEntityCoords(medic) - GetEntityCoords(me)) > 1.6 do Wait(250) end
    if #(GetEntityCoords(medic) - GetEntityCoords(me)) > 1.6 then -- bloqué : on le place à côté
        local p = GetOffsetFromEntityInWorldCoords(me, 0.9, 0.0, 0.0)
        SetEntityCoords(medic, p.x, p.y, p.z, false, false, false, false)
    end
    TaskTurnPedToFaceEntity(medic, me, 1000)
    Wait(1000)
    lib.requestAnimDict('mini@cpr@char_a@cpr_str', 3000)
    TaskPlayAnim(medic, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, -8.0, -1, 1, 0, false, false, false)
    while GetGameTimer() < deadline do Wait(250) end
    local ok, msg = lib.callback.await('gs_services:medicDone', false)
    lib.notify({ title = 'Secours', description = msg, type = ok and 'success' or 'error' })
    ClearPedTasks(medic)
    TaskWanderStandard(medic, 10.0, 10)
    RemoveAnimDict('mini@cpr@char_a@cpr_str')
    SetTimeout(15000, function() if DoesEntityExist(medic) then DeleteEntity(medic) end end)
end

CreateThread(function()
    while true do
        if downed() and not busy then
            local status = lib.callback.await('gs_services:medicStatus', false)
            if status and status.available then
                local label = ('[G] Appeler les secours (%d $)'):format(status.fee)
                while downed() and not busy do
                    drawPrompt(label)
                    if IsDisabledControlJustPressed(0, Config.Medic.key) or IsControlJustPressed(0, Config.Medic.key) then
                        local ok, res = lib.callback.await('gs_services:callMedic', false)
                        if ok then
                            busy = true
                            lib.notify({ title = 'Secours', description = 'Un secouriste arrive, tiens bon.', type = 'inform', icon = 'truck-medical' })
                            CreateThread(function() medicScene(res) busy = false end)
                        else
                            lib.notify({ description = res, type = 'error' })
                            Wait(2000)
                        end
                    end
                    Wait(0)
                end
            else
                while downed() do Wait(1000) end -- des EMS joueurs sont en service : on ne propose rien
            end
        end
        Wait(1000)
    end
end)
