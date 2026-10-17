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

local function blackOut(text)
    caption(text, 3500)
    DoScreenFadeOut(2500)
    local t = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(50) end
end

--- Sol sous un point (ou la hauteur du joueur si le sol n'est pas chargé)
local function groundAt(c, fallbackZ)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 3.0, false)
    return (found and math.abs(gz - fallbackZ) < 4.0) and gz or fallbackZ
end

--- Amène `who` à côté de `ped` : à pied s'il y arrive en `ms`, sinon placé directement (jamais bloqué par l'IA)
local function reach(who, ped, ms, run)
    TaskGoToEntity(who, ped, ms, 1.0, run and 3.0 or 2.0, 1073741824, 0)
    local t = GetGameTimer() + ms
    while GetGameTimer() < t and #(GetEntityCoords(who) - GetEntityCoords(ped)) > 1.8 do Wait(100) end
    if #(GetEntityCoords(who) - GetEntityCoords(ped)) > 1.8 then
        local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.1, 0.0)
        SetEntityCoords(who, c.x, c.y, c.z - 1.0, false, false, false, false)
    end
    ClearPedTasks(who)
    TaskTurnPedToFaceEntity(who, ped, 800)
    Wait(800)
end

-- Enlèvement -------------------------------------------------------------------------------------------------------------
-- V12.63 (backtest : scène buguée) : plus de conduite IA jusqu'au joueur. La camionnette apparaît sur la route la plus
-- proche (sinon juste à côté), un inconnu en descend à pied, le joueur lève les mains, fondu, il est assis à l'arrière,
-- la camionnette repart (balade simple de l'IA), écran noir.
--- V12.64 · point où la camionnette jette le joueur : au hasard parmi ceux à plus de `minDistance` m de l'enlèvement
local function pickDrop(cfg, from)
    local far = {}
    for _, d in ipairs(cfg.drops or {}) do
        if #(vec3(d.x, d.y, d.z) - from) >= (cfg.minDistance or 800.0) then far[#far + 1] = d end
    end
    if #far == 0 then return nil end
    return far[math.random(#far)]
end

local function kidnap(cfg)
    local ped = cache.ped
    leaveVehicle(ped)
    local start = GetEntityCoords(ped)
    local vanH, thugH = loadModel(cfg.van), loadModel(cfg.thug)
    if not (vanH and thugH) then
        SetPedToRagdoll(ped, 2000, 2000, 0, false, false, false)
        blackOut('Un sac sur la tête… tout devient noir.')
        return
    end
    local okN, node, heading = GetClosestVehicleNodeWithHeading(start.x, start.y, start.z, 1, 3.0, 0)
    local at, h
    if okN and #(vec3(node.x, node.y, node.z) - start) <= 25.0 then
        at, h = vec3(node.x, node.y, node.z), heading
    else
        local side = GetOffsetFromEntityInWorldCoords(ped, 4.0, 0.0, 0.0)
        at, h = vec3(side.x, side.y, groundAt(side, start.z - 1.0)), GetEntityHeading(ped)
    end
    local van = CreateVehicle(vanH, at.x, at.y, at.z + 0.3, h, true, false)
    SetModelAsNoLongerNeeded(vanH)
    if not DoesEntityExist(van) then blackOut('Un sac sur la tête… tout devient noir.') return end
    SetVehicleOnGroundProperly(van)
    SetVehicleColours(van, 0, 0)
    SetVehicleEngineOn(van, true, true, false)
    local driver = CreatePedInsideVehicle(van, 4, thugH, -1, true, false)
    local door = GetOffsetFromEntityInWorldCoords(van, 1.6, -1.0, 0.0)
    local thug = CreatePed(4, thugH, door.x, door.y, groundAt(door, at.z), h, true, false)
    SetModelAsNoLongerNeeded(thugH)
    for _, p in ipairs({ driver, thug }) do
        if DoesEntityExist(p) then SetBlockingOfNonTemporaryEvents(p, true) SetPedKeepTask(p, true) SetEntityInvincible(p, true) end
    end
    register({ van, driver, thug })
    caption('Une camionnette noire s\'arrête net…', 2500)
    SetVehicleDoorOpen(van, 2, false, false) SetVehicleDoorOpen(van, 3, false, false)
    Wait(800)
    if DoesEntityExist(thug) then reach(thug, ped, 5000, true) end
    ClearPedTasksImmediately(ped)
    TaskTurnPedToFaceEntity(ped, thug, 600)
    Wait(600)
    anim(ped, 'random@arrests@busted', 'idle_a', 1, -1) -- mains sur la tête
    if DoesEntityExist(thug) then anim(thug, 'mp_arresting', 'a_uncuff', 0, 2500) end
    caption('« Monte. Sans faire d\'histoires. »', 2500)
    Wait(2500)
    DoScreenFadeOut(600)
    Wait(700)
    ClearPedTasksImmediately(ped)
    if DoesEntityExist(van) and DoesEntityExist(driver) then
        SetVehicleDoorsShut(van, true)
        TaskWarpPedIntoVehicle(ped, van, IsVehicleSeatFree(van, 2) and 2 or 1)
        if DoesEntityExist(thug) then TaskWarpPedIntoVehicle(thug, van, 0) end
        Wait(400)
        TaskVehicleDriveWander(driver, van, 22.0, 786603)
        DoScreenFadeIn(600)
        Wait(4500)
    end
    blackOut('Un sac sur la tête… tout devient noir.')
    -- V12.64 (fondateur : « qu'ils jettent bien le joueur plus loin ») : la camionnette le jette au bord d'une route isolée, loin
    -- de l'enlèvement ; il s'y reconnectera. Le joueur sort aussi de la camionnette AVANT l'expulsion (crash de FiveM à la
    -- fermeture constaté quand la camionnette était supprimée avec lui dedans).
    local drop = pickDrop(cfg, start)
    ClearPedTasksImmediately(ped)
    if drop then
        SetEntityCoordsNoOffset(ped, drop.x, drop.y, drop.z + 1.0, false, false, false)
        RequestCollisionAtCoord(drop.x, drop.y, drop.z)
        local t = GetGameTimer() + 6000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(100) end
        local found, gz = GetGroundZFor_3dCoord(drop.x, drop.y, drop.z + 50.0, false)
        local z = found and gz or drop.z
        local hr = math.rad(drop.w or 0.0)
        if DoesEntityExist(van) then -- la camionnette s'arrête à côté de lui, porte ouverte
            SetEntityCoordsNoOffset(van, drop.x + math.cos(hr) * 3.2, drop.y + math.sin(hr) * 3.2, z + 0.5, false, false, false)
            SetEntityHeading(van, drop.w or 0.0)
            SetVehicleOnGroundProperly(van)
            SetVehicleDoorOpen(van, 2, false, false) SetVehicleDoorOpen(van, 3, false, false)
        end
        SetEntityCoordsNoOffset(ped, drop.x, drop.y, z, false, false, false)
        SetEntityHeading(ped, (drop.w or 0.0) + 90.0)
        SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false) -- jeté dehors
        ApplyForceToEntityCenterOfMass(ped, 1, -math.cos(hr) * 6.0, -math.sin(hr) * 6.0, 1.5, false, false, true, false)
        DoScreenFadeIn(600)
        caption('On te jette sur le bord de la route, le sac sur la tête…', 3500)
        Wait(1200)
        if DoesEntityExist(van) then
            SetVehicleDoorsShut(van, false)
            if DoesEntityExist(driver) then TaskVehicleDriveWander(driver, van, 30.0, 786603) end
        end
        Wait(3000)
        blackOut('La camionnette disparaît au loin…')
    else
        SetEntityCoordsNoOffset(ped, start.x, start.y, start.z, false, false, false)
    end
    FreezeEntityPosition(ped, true)
    Wait(300)
end

-- Arrestation par un policier PNJ --------------------------------------------------------------------------------------------
-- V12.63 (backtest : scène buguée) : le policier part de 8 m derrière ; s'il n'arrive pas (obstacle), il est placé derrière le
-- joueur. Plaquage (chute), menottes (animation à deux), puis fondu → cellule.
local function arrest(cfg)
    local ped = cache.ped
    leaveVehicle(ped)
    local start = GetEntityCoords(ped)
    local copH = loadModel(cfg.cop)
    if not copH then blackOut('Des menottes claquent… direction le poste.') return end
    local back = GetOffsetFromEntityInWorldCoords(ped, 0.0, -8.0, 0.0)
    local cop = CreatePed(6, copH, back.x, back.y, groundAt(back, start.z - 1.0), GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(copH)
    if not DoesEntityExist(cop) then blackOut('Des menottes claquent… direction le poste.') return end
    SetBlockingOfNonTemporaryEvents(cop, true) SetPedKeepTask(cop, true) SetEntityInvincible(cop, true)
    register({ cop })
    PlayPedAmbientSpeechNative(cop, 'SHOUT_THREATEN_PED', 'SPEECH_PARAMS_FORCE_SHOUTED')
    caption('« Police ! Plus un geste ! »', 3000)
    reach(cop, ped, 6000, true)
    -- plaquage
    SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
    Wait(1600)
    local t = GetGameTimer() + 3000
    while IsPedRagdoll(ped) and GetGameTimer() < t do Wait(100) end
    -- menottes : le policier derrière le joueur, animation des deux
    ClearPedTasksImmediately(ped)
    local behind = GetOffsetFromEntityInWorldCoords(ped, 0.0, -0.75, 0.0)
    SetEntityCoords(cop, behind.x, behind.y, behind.z - 1.0, false, false, false, false)
    SetEntityHeading(cop, GetEntityHeading(ped))
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
    FreezeEntityPosition(cache.ped, false)
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
