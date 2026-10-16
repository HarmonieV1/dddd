-- gs_admin (client) · V12.63 · Mises en scène du staff, jouées chez le joueur visé. Le serveur a déjà décidé de la sanction
-- et l'appliquera même si la scène échoue (pas de route, modèle absent…) : ici, seulement l'image.
--   · Enlèvement : camionnette noire sur la route la plus proche, un inconnu descend, le joueur lève les mains, il est embarqué,
--     la camionnette repart ; « un sac sur la tête », écran noir → expulsion.
--   · Arrestation PNJ : un policier arrive en courant (« Police ! »), plaque le joueur, le menotte ; fondu → cellule.
-- Entités créées en réseau (les autres joueurs voient la scène), signalées au serveur qui les supprime à la fin.
-- Chasse au trésor : zone sur la carte pour tous, mallette posée à moins de 120 m, [E] pour la ramasser.
local busy = false

local function loadModel(name)
    local h = GetHashKey(name)
    if not IsModelInCdimage(h) then return nil end
    return lib.requestModel(h, 5000) and h or nil
end

local function anim(ped, dict, clip, flag, ms)
    if lib.requestAnimDict(dict, 2000) then TaskPlayAnim(ped, dict, clip, 4.0, -4.0, ms or -1, flag or 0, 0, false, false, false) end
end

--- Texte de cinéma (bas de l'écran) pendant `ms`
local function caption(text, ms)
    local untilT = GetGameTimer() + ms
    CreateThread(function()
        while GetGameTimer() < untilT do
            SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline()
            SetTextColour(236, 230, 255, 235)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.86)
            Wait(0)
        end
    end)
end

--- Pendant la scène : aucune commande (caméra libre seulement)
local function lockControls()
    CreateThread(function()
        while busy do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) -- regarder autour
            Wait(0)
        end
    end)
end

local function register(ents)
    local nets = {}
    for _, e in ipairs(ents) do if e and e ~= 0 and DoesEntityExist(e) then nets[#nets + 1] = NetworkGetNetworkIdFromEntity(e) end end
    lib.callback.await('gs_admin:sceneEnts', false, nets)
end

local function leaveVehicle(ped)
    if cache.vehicle then
        TaskLeaveVehicle(ped, cache.vehicle, 16)
        local t = GetGameTimer() + 2500
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do Wait(100) end
    end
end

--- Point de route entre `minD` et 60 m du joueur (camionnette), ou nil
local function roadNear(pos, minD)
    for i = 1, 25 do
        local ok, node, heading = GetNthClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, i, 1, 3.0, 0)
        if ok then
            local d = #(vec3(node.x, node.y, node.z) - pos)
            if d >= minD and d <= 60.0 then return node, heading end
        end
    end
end

local function blackOut(text)
    caption(text, 3500)
    DoScreenFadeOut(2500)
    local t = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(50) end
end

-- Enlèvement -------------------------------------------------------------------------------------------------------------
local function kidnap(cfg)
    local ped = cache.ped
    leaveVehicle(ped)
    local start = GetEntityCoords(ped)
    local vanH, thugH = loadModel(cfg.van), loadModel(cfg.thug)
    local node, heading = roadNear(start, 20.0)
    if not (vanH and thugH and node) then -- pas de route (intérieur…) : le sac sur la tête directement
        SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
        blackOut('Un sac sur la tête… tout devient noir.')
        return
    end
    local van = CreateVehicle(vanH, node.x, node.y, node.z + 0.5, heading, true, false)
    SetModelAsNoLongerNeeded(vanH)
    SetVehicleOnGroundProperly(van)
    SetVehicleColours(van, 0, 0)
    SetVehicleDoorsLocked(van, 1)
    local driver = CreatePedInsideVehicle(van, 4, thugH, -1, true, false)
    local thug = CreatePedInsideVehicle(van, 4, thugH, 0, true, false)
    SetModelAsNoLongerNeeded(thugH)
    for _, p in ipairs({ driver, thug }) do
        SetBlockingOfNonTemporaryEvents(p, true) SetPedKeepTask(p, true) SetEntityInvincible(p, true)
        SetPedComponentVariation(p, 0, 0, 0, 0)
    end
    register({ van, driver, thug })
    -- la camionnette arrive à hauteur du joueur
    TaskVehicleDriveToCoord(driver, van, start.x, start.y, start.z, 14.0, 0, vanH, 786603, 7.0, true)
    local t = GetGameTimer() + 9000
    while GetGameTimer() < t and #(GetEntityCoords(van) - GetEntityCoords(ped)) > 9.0 do Wait(150) end
    TaskVehicleTempAction(driver, van, 27, 3000)
    Wait(700)
    caption('Une camionnette noire s\'arrête net…', 2500)
    TaskLeaveVehicle(thug, van, 256)
    Wait(1300)
    TaskGoToEntity(thug, ped, 6000, 1.0, 3.0, 1073741824, 0)
    t = GetGameTimer() + 6000
    while GetGameTimer() < t and #(GetEntityCoords(thug) - GetEntityCoords(ped)) > 1.6 do Wait(100) end
    ClearPedTasksImmediately(ped)
    anim(ped, 'random@arrests@busted', 'idle_a', 1, 2500) -- mains sur la tête
    TaskTurnPedToFaceEntity(thug, ped, 1000)
    Wait(800)
    anim(thug, 'mp_arresting', 'a_uncuff', 0, 2000)
    caption('« Monte. Sans faire d\'histoires. »', 2500)
    Wait(2200)
    DoScreenFadeOut(700)
    Wait(800)
    ClearPedTasksImmediately(ped)
    TaskWarpPedIntoVehicle(ped, van, IsVehicleSeatFree(van, 1) and 1 or 2)
    TaskWarpPedIntoVehicle(thug, van, IsVehicleSeatFree(van, 2) and 2 or 0)
    Wait(300)
    SetVehicleDoorsShut(van, false)
    TaskVehicleDriveWander(driver, van, 28.0, 786603)
    DoScreenFadeIn(700)
    Wait(4500)
    blackOut('Un sac sur la tête… tout devient noir.')
end

-- Arrestation par un policier PNJ --------------------------------------------------------------------------------------------
local function arrest(cfg)
    local ped = cache.ped
    leaveVehicle(ped)
    local start = GetEntityCoords(ped)
    local copH = loadModel(cfg.cop)
    if not copH then blackOut('Des menottes claquent… direction le poste.') return end
    -- il arrive de derrière, à 15 m (sinon à côté si le sol n'est pas trouvé)
    local back = start - GetEntityForwardVector(ped) * 15.0
    local found, gz = GetGroundZFor_3dCoord(back.x, back.y, back.z + 4.0, false)
    if not found or math.abs(gz - start.z) > 4.0 then back, gz = start + vec3(4.0, 0.0, 0.0), start.z - 1.0 end
    local cop = CreatePed(6, copH, back.x, back.y, gz, GetHeadingFromVector_2d(start.x - back.x, start.y - back.y), true, false)
    SetModelAsNoLongerNeeded(copH)
    SetBlockingOfNonTemporaryEvents(cop, true) SetPedKeepTask(cop, true) SetEntityInvincible(cop, true)
    register({ cop })
    PlayPedAmbientSpeechNative(cop, 'SHOUT_THREATEN_PED', 'SPEECH_PARAMS_FORCE_SHOUTED')
    caption('« Police ! Plus un geste ! »', 3000)
    TaskGoToEntity(cop, ped, 8000, 0.8, 3.0, 1073741824, 0)
    local t = GetGameTimer() + 8000
    while GetGameTimer() < t and #(GetEntityCoords(cop) - GetEntityCoords(ped)) > 1.8 do Wait(100) end
    -- plaquage
    SetPedToRagdoll(ped, 2200, 2200, 0, false, false, false)
    local dir = GetEntityCoords(ped) - GetEntityCoords(cop)
    ApplyForceToEntity(ped, 1, dir.x * 2.0, dir.y * 2.0, 1.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    Wait(2600)
    -- menottes : le policier derrière le joueur, animation des deux
    local h = GetEntityHeading(ped)
    local behind = GetOffsetFromEntityInWorldCoords(ped, 0.0, -0.6, 0.0)
    SetEntityCoords(cop, behind.x, behind.y, behind.z - 1.0, false, false, false, false)
    SetEntityHeading(cop, h)
    anim(cop, 'mp_arrest_paired', 'cop_p2_back_right', 0, 3600)
    anim(ped, 'mp_arrest_paired', 'crook_p2_back_right', 0, 3600)
    caption('« Tu as le droit de garder le silence. »', 3500)
    Wait(3600)
    anim(ped, 'mp_arresting', 'idle', 49, -1)
    Wait(1200)
    blackOut('Direction le commissariat de Mission Row…')
end

RegisterNetEvent('gs_admin:client:scene', function(kind, cfg)
    if busy or type(cfg) ~= 'table' then return end
    busy = true
    lockControls()
    local ok, err = pcall(kind == 'kidnap' and kidnap or arrest, cfg)
    if not ok then print('[gs_admin] mise en scène : ' .. tostring(err)) end
    if not IsScreenFadedOut() then DoScreenFadeOut(500) Wait(600) end
    lib.callback.await('gs_admin:sceneDone', false) -- expulsion, ou cellule (téléportation par le serveur)
    Wait(1200)
    ClearPedTasksImmediately(cache.ped)
    busy = false
    DoScreenFadeIn(900)
    if kind ~= 'kidnap' then lib.notify({ title = 'Cellule de Mission Row', description = 'Tu as été arrêté. Patiente jusqu\'à la fin de ta peine.', type = 'error', duration = 8000 }) end
end)

-- Chasse au trésor ------------------------------------------------------------------------------------------------------------
local hunt = nil -- { zone, radius, at, prize, untilAt, blip, area, prop }

local function huntClear()
    if not hunt then return end
    if hunt.blip and DoesBlipExist(hunt.blip) then RemoveBlip(hunt.blip) end
    if hunt.area and DoesBlipExist(hunt.area) then RemoveBlip(hunt.area) end
    if hunt.prop and DoesEntityExist(hunt.prop) then DeleteEntity(hunt.prop) end
    hunt = nil
end

RegisterNetEvent('gs_admin:client:huntStart', function(h)
    huntClear()
    hunt = { zone = vec3(h.zone.x, h.zone.y, h.zone.z), radius = h.radius, at = vec3(h.at.x, h.at.y, h.at.z), prize = h.prize,
        untilAt = GetGameTimer() + math.min(h.seconds, 3600) * 1000 }
    hunt.area = AddBlipForRadius(hunt.zone.x, hunt.zone.y, hunt.zone.z, hunt.radius)
    SetBlipColour(hunt.area, 27) SetBlipAlpha(hunt.area, 110)
    hunt.blip = AddBlipForCoord(hunt.zone.x, hunt.zone.y, hunt.zone.z)
    SetBlipSprite(hunt.blip, 617) SetBlipColour(hunt.blip, 27)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Chasse au trésor') EndTextCommandSetBlipName(hunt.blip)
    SetNewWaypoint(hunt.zone.x, hunt.zone.y)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = 'Événement : ' .. (h.label or 'Chasse au trésor'), description = ('%s Prime : %d $.'):format(h.text or '', h.prize),
        type = 'inform', icon = 'gem', position = 'top', duration = 15000 })
    local me = hunt
    CreateThread(function()
        local cfg = Config.Hunt or {}
        while hunt == me and GetGameTimer() < me.untilAt do
            local d = #(GetEntityCoords(cache.ped) - me.at)
            if d < 120.0 and not me.prop then
                local mh = loadModel(cfg.model or 'prop_cash_case_02')
                if mh then
                    local found, gz = GetGroundZFor_3dCoord(me.at.x, me.at.y, me.at.z + 1.0, false)
                    me.prop = CreateObject(mh, me.at.x, me.at.y, (found and gz or me.at.z - 1.0), false, false, false) -- chacun la sienne
                    SetModelAsNoLongerNeeded(mh)
                    PlaceObjectOnGroundProperly(me.prop) FreezeEntityPosition(me.prop, true)
                end
            end
            if d < (cfg.pickup or 3.0) and not IsPedInAnyVehicle(cache.ped, false) then
                SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline() SetTextColour(40, 224, 255, 240)
                BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('[E] Ramasser la mallette') EndTextCommandDisplayText(0.5, 0.88)
                if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                    local ok, msg = lib.callback.await('gs_admin:huntClaim', false)
                    lib.notify({ description = msg, type = ok and 'success' or 'error' })
                end
                Wait(0)
            else
                Wait(d < 30.0 and 0 or 500)
            end
        end
        if hunt == me then huntClear() end
    end)
end)

RegisterNetEvent('gs_admin:client:huntEnd', function(winner)
    if not hunt then return end
    huntClear()
    lib.notify({ title = 'Chasse au trésor', description = ('%s a trouvé la mallette. Bien joué !'):format(winner or 'Quelqu\'un'), type = 'inform', icon = 'gem' })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    huntClear()
    if busy then DoScreenFadeIn(0) end
end)
