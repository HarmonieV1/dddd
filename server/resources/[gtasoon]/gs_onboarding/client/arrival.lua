-- gs_onboarding (client) · V11.5 « Arrivée en bus », V12.4 / V12.8 : robuste. Un nouveau personnage n'apparaît plus planté
-- devant la mairie : il descend d'un bus Dashound qui arrive à l'arrêt de la mairie, Max « le Guide » à deux pas. Entités
-- locales (bus, chauffeur), caméra de cinéma, Espace ou Retour arrière pour passer. Une seule fois par personnage (le serveur note).
-- Les deux bugs signalés (« le bus traverse la map », « il ne dépose pas devant la mairie ») avaient deux causes, corrigées :
--  1. le sol n'était pas chargé 400 m plus loin quand le bus était créé (le joueur venait d'apparaître à la mairie) : le bus
--     tombait à travers la carte → le joueur est amené au départ (invisible, figé), on attend la collision, le bus reste figé
--     tant que son propre sol n'est pas là, et un bus bloqué 6 s ou tombé passe directement à la dépose ;
--  2. le perso était posé à `stop.z - 1.0`, soit 1 m SOUS le trottoir : il traversait la map et réapparaissait n'importe où →
--     on attend la sortie réelle du bus, le chargement de la collision, puis on cale sur le sol réel (GetGroundZFor_3dCoord).
-- Bonus : itinéraire GPS tracé vers la position réelle de Max « le Guide » (déplacements du staff compris) + notification.
local A = Config.Arrival

local function model(name)
    local h = GetHashKey(name)
    return lib.requestModel(h, 8000) and h or nil
end

local function cleanup(bus, driver, cam)
    if cam then RenderScriptCams(false, true, 800, true, true) DestroyCam(cam, false) end
    if driver and DoesEntityExist(driver) then DeleteEntity(driver) end
    if bus and DoesEntityExist(bus) then DeleteEntity(bus) end
end

--- Attend que le sol soit chargé autour d'une entité (sinon tout ce qu'on pose tombe à travers la carte). 6 s max.
local function waitGround(entity, x, y, z)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStartSphere(x, y, z, 60.0, 0)
    local t0 = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() - t0 < 6000 do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end
    NewLoadSceneStop()
    return HasCollisionLoadedAroundEntity(entity)
end

--- Pose le personnage sur le trottoir de la mairie, au niveau du sol réel (jamais sous la carte, jamais dans le vide).
local function placeAtStop(ped)
    local sx, sy, sz = A.stop.x, A.stop.y, A.stop.z
    SetEntityCoords(ped, sx, sy, sz, false, false, false, false)
    waitGround(ped, sx, sy, sz)
    local okG, gz = GetGroundZFor_3dCoord(sx, sy, sz + 3.0, false)
    SetEntityCoords(ped, sx, sy, (okG and gz or sz) + 1.0, false, false, false, false) -- l'origine d'un ped est ~1 m au-dessus du sol
    SetEntityHeading(ped, A.stop.w)
    FreezeEntityPosition(ped, false)
end

--- Max « le Guide » est à ~20 m : on trace l'itinéraire, sinon le nouveau ne sait pas où aller. Position lue chez gs_quests
--- (déplacements du staff compris) ; hors de Config ici pour ne pas apparaître deux fois au F11.
local function guideToMax()
    local okG2, max = pcall(function() return exports.gs_bridge:FindPoint('gs_quests:Config.Characters.guide.coords') end)
    local guide = okG2 and max or vec3(-536.9, -218.4, 37.65)
    if guide then
        SetNewWaypoint(guide.x, guide.y)
        lib.notify({ title = 'Bienvenue à Los Santos', description = 'Max « le Guide » t\'attend devant la mairie.', type = 'inform', duration = 8000 })
    end
end

--- Joue l'arrivée puis appelle `done()`. Robuste : tout échec (modèle, nœud de route, sol) passe directement à `done`.
function GSArrival(done)
    if not A or not A.enabled then return done() end
    local ped = PlayerPedId()
    local okN, stopNode, stopHeading = GetClosestVehicleNodeWithHeading(A.stop.x, A.stop.y, A.stop.z, 1, 3.0, 0)
    local okS, startNode = GetClosestVehicleNode(A.from.x, A.from.y, A.from.z, 1, 3.0, 0)
    local busModel, driverModel = model(A.bus), model(A.driver)
    if not okN or not okS or not busModel or not driverModel then return done() end

    DoScreenFadeOut(300)
    Wait(400)
    -- 1. Le joueur (invisible, figé) est amené au départ : c'est lui qui fait charger le monde autour du bus
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCoords(ped, startNode.x, startNode.y, startNode.z + 1.0, false, false, false, false)
    if not waitGround(ped, startNode.x, startNode.y, startNode.z) then
        -- sol jamais chargé : on renonce proprement, le perso est posé à la mairie
        SetEntityVisible(ped, true, false)
        placeAtStop(ped)
        DoScreenFadeIn(500)
        guideToMax()
        return done()
    end
    local heading = GetHeadingFromVector_2d(stopNode.x - startNode.x, stopNode.y - startNode.y)
    local bus = CreateVehicle(busModel, startNode.x, startNode.y, startNode.z + 0.5, heading, false, false)
    SetModelAsNoLongerNeeded(busModel)
    SetEntityLoadCollisionFlag(bus, true)
    FreezeEntityPosition(bus, true) -- figé tant que son propre sol n'est pas là
    SetVehicleOnGroundProperly(bus)
    SetVehicleDoorsLocked(bus, 4)
    SetVehicleEngineOn(bus, true, true, false)
    local driver = CreatePedInsideVehicle(bus, 4, driverModel, -1, false, false)
    SetModelAsNoLongerNeeded(driverModel)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedKeepTask(driver, true)
    SetDriverAbility(driver, 1.0) SetDriverAggressiveness(driver, 0.0)
    SetPedIntoVehicle(ped, bus, A.seat)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    waitGround(bus, startNode.x, startNode.y, startNode.z)
    SetVehicleOnGroundProperly(bus)
    FreezeEntityPosition(bus, false)
    -- 2. Conduite jusqu'à l'arrêt en suivant les routes (786603 : conduite normale, feux et trafic respectés)
    TaskVehicleDriveToCoordLongrange(driver, bus, stopNode.x, stopNode.y, stopNode.z, A.speed, 786603, 6.0)

    -- Caméra : plan large depuis le trottoir, puis suit le bus
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Wait(300)
    DoScreenFadeIn(600)
    lib.showTextUI('Arrivée à Los Santos · [Espace] passer', { position = 'bottom-center' })

    local t0, skipped = GetGameTimer(), false
    local lastPos, lastMove = GetEntityCoords(bus), GetGameTimer()
    local floorZ = math.min(startNode.z, stopNode.z) - 25.0
    -- par frame : caméra qui suit le bus, ~28 s une seule fois par personnage (sortie au point d'arrêt, au délai, à Espace,
    -- si le bus est bloqué 6 s ou s'il est tombé sous la route)
    while true do
        local bc = GetEntityCoords(bus)
        local fwd = GetEntityForwardVector(bus)
        local right = vec3(fwd.y, -fwd.x, 0.0)
        local camPos = bc - fwd * 6.0 + right * 5.5 + vec3(0.0, 0.0, 2.6)
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(cam, bus, 0.0, 0.0, 1.0, true)
        DisableAllControlActions(0)
        if IsDisabledControlJustReleased(0, 22) or IsDisabledControlJustReleased(0, 177) then skipped = true break end
        local d = #(vec3(bc.x, bc.y, bc.z) - vec3(stopNode.x, stopNode.y, stopNode.z))
        if d < 9.0 or GetGameTimer() - t0 > A.seconds * 1000 then break end
        if #(bc - lastPos) > 0.5 then lastPos, lastMove = bc, GetGameTimer() end
        if GetGameTimer() - lastMove > 6000 and GetGameTimer() - t0 > 4000 then skipped = true break end -- bloqué
        if bc.z < floorZ then skipped = true break end                                                   -- tombé
        Wait(0)
    end
    lib.hideTextUI()

    -- 3. Descente : le bus s'arrête, le perso en sort côté trottoir ; le bus repart tout seul puis disparaît
    DoScreenFadeOut(300)
    Wait(350)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    if skipped then
        SetEntityCoords(bus, stopNode.x, stopNode.y, stopNode.z, false, false, false, false)
        SetEntityHeading(bus, stopHeading)
        SetVehicleOnGroundProperly(bus)
    end
    TaskVehicleTempAction(driver, bus, 27, 2000)
    Wait(300)
    TaskLeaveVehicle(ped, bus, 0)
    -- On attend d'être VRAIMENT sorti : téléporter un perso encore assis ne marche pas (il repartait avec le bus)
    local tl = GetGameTimer()
    while IsPedInAnyVehicle(ped, true) and GetGameTimer() - tl < 2500 do Wait(50) end
    if IsPedInAnyVehicle(ped, true) then ClearPedTasksImmediately(ped) Wait(100) end -- dernier recours : on le sort de force
    placeAtStop(ped)
    DoScreenFadeIn(500)
    guideToMax()
    SetTimeout(A.leaveAfter * 1000, function()
        if DoesEntityExist(driver) and DoesEntityExist(bus) then
            SetVehicleDoorsShut(bus, false)
            TaskVehicleDriveWander(driver, bus, 15.0, 786603)
        end
        SetTimeout(25000, function() cleanup(bus, driver, nil) end)
    end)
    done()
end
