-- gs_onboarding (client) · V11.5 « Arrivée en bus ». Un nouveau personnage n'apparaît plus planté devant la mairie :
-- il descend d'un bus Dashound qui arrive à l'arrêt de la mairie, Max « le Guide » à deux pas. Entités locales (bus,
-- chauffeur), caméra de cinéma, Espace ou Retour arrière pour passer. Une seule fois par personnage (le serveur note).
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

--- Joue l'arrivée puis appelle `done()`. Robuste : tout échec (modèle, nœud de route) passe directement à `done`.
function GSArrival(done)
    if not A or not A.enabled then return done() end
    local ped = PlayerPedId()
    local okN, stopNode, stopHeading = GetClosestVehicleNodeWithHeading(A.stop.x, A.stop.y, A.stop.z, 1, 3.0, 0)
    local okS, startNode = GetClosestVehicleNode(A.from.x, A.from.y, A.from.z, 1, 3.0, 0)
    local busModel, driverModel = model(A.bus), model(A.driver)
    if not okN or not okS or not busModel or not driverModel then return done() end

    DoScreenFadeOut(300)
    Wait(400)
    RequestCollisionAtCoord(startNode.x, startNode.y, startNode.z)
    local bus = CreateVehicle(busModel, startNode.x, startNode.y, startNode.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(busModel)
    SetVehicleOnGroundProperly(bus)
    SetEntityHeading(bus, GetHeadingFromVector_2d(stopNode.x - startNode.x, stopNode.y - startNode.y))
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
    -- Conduite jusqu'à l'arrêt : vitesse de bus, s'arrête au point
    TaskVehicleDriveToCoordLongrange(driver, bus, stopNode.x, stopNode.y, stopNode.z, A.speed, 786603, 6.0)

    -- Caméra : plan large depuis le trottoir, puis suit le bus
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Wait(300)
    DoScreenFadeIn(600)
    lib.showTextUI('Arrivée à Los Santos · [Espace] passer', { position = 'bottom-center' })

    local t0 = GetGameTimer()
    local skipped = false
    -- par frame : caméra qui suit le bus, ~25 s une seule fois par personnage (sortie au point d'arrêt, au délai ou à Espace)
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
        Wait(0)
    end
    lib.hideTextUI()

    -- Descente : le bus s'arrête, le perso en sort côté trottoir ; le bus repart tout seul puis disparaît
    DoScreenFadeOut(300)
    Wait(350)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    if skipped then SetEntityCoords(bus, stopNode.x, stopNode.y, stopNode.z, false, false, false, false) SetEntityHeading(bus, stopHeading) end
    TaskVehicleTempAction(driver, bus, 27, 2000)
    Wait(300)
    TaskLeaveVehicle(ped, bus, 0)
    Wait(1500)
    SetEntityCoords(ped, A.stop.x, A.stop.y, A.stop.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, A.stop.w)
    DoScreenFadeIn(500)
    SetTimeout(A.leaveAfter * 1000, function()
        if DoesEntityExist(driver) and DoesEntityExist(bus) then
            SetVehicleDoorsShut(bus, false)
            TaskVehicleDriveWander(driver, bus, 15.0, 786603)
        end
        SetTimeout(25000, function() cleanup(bus, driver, nil) end)
    end)
    done()
end
