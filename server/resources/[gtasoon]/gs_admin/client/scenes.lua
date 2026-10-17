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
--- V12.65 · Relâché dans le désert : en sous-vêtements (tenue changée chez le joueur seulement ; sa tenue enregistrée revient
--- à la reconnexion ou à la garde-robe), chapeau / lunettes / sac retirés
local function strip(ped)
    local male = GetEntityModel(ped) == GetHashKey('mp_m_freemode_01')
    SetPedComponentVariation(ped, 11, 15, 0, 0) -- haut
    SetPedComponentVariation(ped, 8, 15, 0, 0)  -- dessous
    SetPedComponentVariation(ped, 3, 15, 0, 0)  -- bras nus
    SetPedComponentVariation(ped, 4, male and 21 or 15, 0, 0) -- caleçon / culotte
    SetPedComponentVariation(ped, 6, male and 34 or 35, 0, 0) -- pieds nus
    SetPedComponentVariation(ped, 5, 0, 0, 0) SetPedComponentVariation(ped, 9, 0, 0, 0) SetPedComponentVariation(ped, 7, 0, 0, 0)
    ClearPedProp(ped, 0) ClearPedProp(ped, 1)
end

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
        if cfg.strip then strip(ped) end -- V12.65 : relâché dans le désert, en sous-vêtements
        SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false) -- jeté dehors
        ApplyForceToEntityCenterOfMass(ped, 1, -math.cos(hr) * 6.0, -math.sin(hr) * 6.0, 1.5, false, false, true, false)
        DoScreenFadeIn(600)
        caption(cfg.desert and 'On te jette en plein désert… sans un sou, et sans tes vêtements.' or 'On te jette sur le bord de la route, le sac sur la tête…', 3500)
        Wait(1200)
        if DoesEntityExist(van) then
            SetVehicleDoorsShut(van, false)
            if DoesEntityExist(driver) then TaskVehicleDriveWander(driver, van, 30.0, 786603) end
        end
        Wait(3000)
        if cfg.desert then return end -- V12.65 : pas d'expulsion, il reste là (sans écran noir)
        blackOut('La camionnette disparaît au loin…')
    else
        SetEntityCoordsNoOffset(ped, start.x, start.y, start.z, false, false, false)
        if cfg.desert then if cfg.strip then strip(ped) end return end
    end
    FreezeEntityPosition(ped, true)
    Wait(300)
end

-- V12.65 · Interrogatoire (proposition n° 292) : salle d'interrogatoire de Mission Row, un inspecteur PNJ pose ses questions,
-- le joueur répond (ou se tait) ; les réponses partent au staff qui a lancé la scène. Puis la cellule.
local function interrogate(I)
    local ped = cache.ped
    blackOut('Direction la salle d\'interrogatoire de Mission Row…')
    local r = I.room
    SetEntityCoordsNoOffset(ped, r.x, r.y, r.z, false, false, false)
    SetEntityHeading(ped, r.w)
    RequestCollisionAtCoord(r.x, r.y, r.z)
    local t = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(100) end
    local h = loadModel(I.inspector)
    local inspector
    if h then
        local face = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.6, 0.0)
        inspector = CreatePed(6, h, face.x, face.y, r.z - 1.0, (r.w + 180.0) % 360.0, true, false)
        SetModelAsNoLongerNeeded(h)
        if DoesEntityExist(inspector) then
            SetBlockingOfNonTemporaryEvents(inspector, true) SetPedKeepTask(inspector, true) SetEntityInvincible(inspector, true)
            register({ inspector })
            TaskStartScenarioInPlace(inspector, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        end
    end
    anim(ped, 'mp_arresting', 'idle', 49, -1)
    DoScreenFadeIn(800)
    caption('« Assieds-toi. On a quelques questions. »', 3000)
    Wait(3000)
    for i, q in ipairs(I.questions) do caption(('Inspecteur : « %s »'):format(q), 3200) Wait(3300) end
    local fields = {}
    for i, q in ipairs(I.questions) do fields[i] = { type = 'input', label = q, description = 'Laisse vide pour garder le silence', max = 200 } end
    local closed = false
    SetTimeout((I.answerSeconds or 30) * 1000, function() if not closed then pcall(lib.closeInputDialog) end end)
    local answers = lib.inputDialog('Interrogatoire', fields) or {}
    closed = true
    TriggerServerEvent('gs_admin:server:interrogation', answers)
    caption('« C\'est noté. On verra ce qu\'en dit le juge. »', 2500)
    Wait(2500)
    blackOut('Direction la cellule…')
end

-- V12.65 · Transfert en fourgon vers Bolingbroke (proposition n° 294) : le détenu est assis à l'arrière, portes verrouillées ;
-- si le fourgon est arrêté (moteur détruit, conducteur à terre), le serveur vérifie et le libère. Sinon : isolement à l'arrivée.
local function transfer(cfg)
    local ped = cache.ped
    leaveVehicle(ped)
    blackOut('Des policiers te conduisent au fourgon de transfert…')
    local vanH, copH = loadModel(cfg.van), loadModel(cfg.cop)
    if not (vanH and copH) then return end
    local f = cfg.from
    SetEntityCoordsNoOffset(ped, f.x + 3.0, f.y, f.z, false, false, false)
    RequestCollisionAtCoord(f.x, f.y, f.z)
    local t = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(100) end
    local van = CreateVehicle(vanH, f.x, f.y, f.z, f.w, true, false)
    SetModelAsNoLongerNeeded(vanH)
    if not DoesEntityExist(van) then return end
    SetVehicleOnGroundProperly(van)
    local driver = CreatePedInsideVehicle(van, 6, copH, -1, true, false)
    local escort = CreatePedInsideVehicle(van, 6, copH, 0, true, false)
    SetModelAsNoLongerNeeded(copH)
    register({ van, driver, escort }) -- l'ordre compte : fourgon, conducteur (vérifiés par le serveur)
    SetBlockingOfNonTemporaryEvents(driver, true) SetPedKeepTask(driver, true)
    GiveWeaponToPed(escort, GetHashKey('WEAPON_PISTOL'), 60, false, true)
    TaskWarpPedIntoVehicle(ped, van, IsVehicleSeatFree(van, 1) and 1 or 2)
    SetVehicleDoorsLocked(van, 4)
    SetVehicleSiren(van, true)
    SetVehicleEngineOn(van, true, true, false)
    Wait(500)
    TaskVehicleDriveToCoordLongrange(driver, van, cfg.to.x, cfg.to.y, cfg.to.z, 24.0, 786603, 25.0)
    DoScreenFadeIn(800)
    caption('Transfert vers la prison de Bolingbroke…', 4000)
    local deadline = GetGameTimer() + (cfg.seconds or 400) * 1000
    while GetGameTimer() < deadline do
        local broken = not DoesEntityExist(van) or GetVehicleEngineHealth(van) <= (cfg.engineFail or 300.0)
        local downed = not DoesEntityExist(driver) or IsEntityDead(driver)
        if broken or downed then
            if lib.callback.await('gs_admin:transferFreed', false) then
                if DoesEntityExist(van) then SetVehicleDoorsLocked(van, 1) end
                caption('Le fourgon est arrêté : les portes s\'ouvrent… fuis !', 5000)
                return 'freed'
            end
        end
        if DoesEntityExist(van) and #(GetEntityCoords(van) - cfg.to) < 40.0 then break end
        Wait(500)
    end
    blackOut('Arrivée à Bolingbroke…')
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
    if cfg.interrogate and cfg.interrogation then return interrogate(cfg.interrogation) end -- V12.65
    blackOut('Direction le commissariat de Mission Row…')
end

RegisterNetEvent('gs_admin:client:scene', function(kind, cfg)
    if busy or type(cfg) ~= 'table' then return end
    busy = true
    lockControls()
    local fn = ({ kidnap = kidnap, desert = kidnap, arrest = arrest, transfer = transfer })[kind] or arrest -- V12.65
    local ok, res = pcall(fn, cfg)
    if not ok then print('[gs_admin] mise en scène : ' .. tostring(res)) end
    if res == 'freed' then busy = false return end -- évadé du fourgon : la scène s'arrête là (vérifié par le serveur)
    if kind ~= 'desert' and not IsScreenFadedOut() then DoScreenFadeOut(500) Wait(600) end
    lib.callback.await('gs_admin:sceneDone', false) -- expulsion, cellule, isolement (téléportation par le serveur) ou désert
    FreezeEntityPosition(cache.ped, false)
    if kind ~= 'desert' then Wait(1200) ClearPedTasksImmediately(cache.ped) end
    busy = false
    DoScreenFadeIn(900)
    if kind == 'arrest' then lib.notify({ title = 'Cellule de Mission Row', description = 'Tu as été arrêté. Patiente jusqu\'à la fin de ta peine.', type = 'error', duration = 8000 })
    elseif kind == 'transfer' then lib.notify({ title = 'Bolingbroke', description = 'Transfert terminé : isolement à la prison.', type = 'error', duration = 8000 }) end
end)

-- V12.65 · Mises en scène d'AMBIANCE (sans sanction, admin et plus) : pimenter une scène RP au lieu de la couper.
-- Jouées chez le joueur visé, entités réseau (tout le monde les voit), supprimées ici à la fin ET par le serveur.
local staging = false

local function cleanStage(ents)
    for _, e in ipairs(ents) do if e and DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true) DeleteEntity(e) end end
    lib.callback.await('gs_admin:stageDone', false)
end

local Stage = {}

--- Hélico de la police : tourne au-dessus du joueur, projecteur la nuit, puis repart
function Stage.heli(cfg)
    local me = GetEntityCoords(cache.ped)
    local h, ph = loadModel(cfg.model), loadModel(cfg.pilot)
    if not (h and ph) then return {} end
    local a = math.random() * 2 * math.pi
    local heli = CreateVehicle(h, me.x + math.cos(a) * 220.0, me.y + math.sin(a) * 220.0, me.z + cfg.height + 30.0, 0.0, true, false)
    if not DoesEntityExist(heli) then return {} end
    local pilot = CreatePedInsideVehicle(heli, 6, ph, -1, true, false)
    SetModelAsNoLongerNeeded(h) SetModelAsNoLongerNeeded(ph)
    register({ heli, pilot })
    SetVehicleEngineOn(heli, true, true, false) SetHeliBladesFullSpeed(heli)
    SetBlockingOfNonTemporaryEvents(pilot, true) SetPedKeepTask(pilot, true)
    local untilT = GetGameTimer() + cfg.seconds * 1000
    while GetGameTimer() < untilT and DoesEntityExist(heli) and DoesEntityExist(pilot) do
        TaskHeliMission(pilot, heli, 0, cache.ped, 0.0, 0.0, 0.0, 9, 30.0, cfg.radius, -1.0, math.floor(cfg.height), math.floor(cfg.height * 0.6), -1.0, 0)
        local hour = GetClockHours()
        SetVehicleSearchlight(heli, hour >= 20 or hour < 6, true)
        Wait(5000)
    end
    if DoesEntityExist(heli) and DoesEntityExist(pilot) then -- repart au loin
        SetVehicleSearchlight(heli, false, false)
        local far = GetOffsetFromEntityInWorldCoords(heli, 0.0, 900.0, 60.0)
        TaskHeliMission(pilot, heli, 0, 0, far.x, far.y, far.z, 4, 40.0, 10.0, -1.0, 120, 80, -1.0, 0)
        Wait(15000)
    end
    return { heli, pilot }
end

--- Foule de curieux : des passants s'arrêtent, filment, commentent, puis s'en vont
function Stage.crowd(cfg)
    local me = GetEntityCoords(cache.ped)
    local peds = {}
    for i = 1, cfg.count do
        local h = loadModel(cfg.models[math.random(#cfg.models)])
        if h then
            local a = (i / cfg.count) * 2 * math.pi + math.random() * 0.4
            local d = 6.0 + math.random() * 3.0
            local x, y = me.x + math.cos(a) * d, me.y + math.sin(a) * d
            local p = CreatePed(4, h, x, y, groundAt(vec3(x, y, me.z), me.z - 1.0), 0.0, true, false)
            SetModelAsNoLongerNeeded(h)
            if DoesEntityExist(p) then
                SetBlockingOfNonTemporaryEvents(p, true)
                TaskTurnPedToFaceEntity(p, cache.ped, 1200)
                peds[#peds + 1] = p
            end
        end
    end
    register(peds)
    Wait(1300)
    local scen = { 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_HANG_OUT_STREET' }
    for i, p in ipairs(peds) do if DoesEntityExist(p) then TaskStartScenarioInPlace(p, scen[(i - 1) % #scen + 1], 0, true) end end
    local lines = { '« Vous avez vu ça ?! »', '« Filme, filme ! »', '« J\'appelle les flics, moi… »', '« C\'est pas lui qu\'on a vu aux infos ? »', '« Allez, on se pousse pas, on regarde ! »' }
    local untilT = GetGameTimer() + cfg.seconds * 1000
    while GetGameTimer() < untilT do
        local p = peds[math.random(#peds)]
        if p and DoesEntityExist(p) then PlayPedAmbientSpeechNative(p, 'GENERIC_SHOCKED_MED', 'SPEECH_PARAMS_FORCE') end
        caption(lines[math.random(#lines)], 2500)
        Wait(5000 + math.random(2000))
    end
    for _, p in ipairs(peds) do if DoesEntityExist(p) then ClearPedTasks(p) TaskWanderStandard(p, 10.0, 10) end end
    Wait(15000)
    return peds
end

--- Appel masqué : le téléphone sonne, une voix dit le texte écrit par le staff
function Stage.call(cfg, text)
    local ped = cache.ped
    for _ = 1, 3 do PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', true) Wait(1500) end
    local phone
    if not cache.vehicle and lib.requestAnimDict('cellphone@', 2000) then
        TaskPlayAnim(ped, 'cellphone@', 'cellphone_call_listen_base', 3.0, 3.0, -1, 49, 0, false, false, false)
        local h = loadModel('prop_npc_phone_02')
        if h then
            local c = GetEntityCoords(ped)
            phone = CreateObject(h, c.x, c.y, c.z + 0.2, false, false, false)
            AttachEntityToEntity(phone, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(h)
        end
    end
    lib.notify({ title = '📞 Numéro masqué', description = text, type = 'inform', icon = 'phone', duration = 15000 })
    caption(('Une voix : « %s »'):format(text), 8000)
    Wait(math.max(6000, (cfg.seconds or 12) * 1000 - 4500))
    StopAnimTask(ped, 'cellphone@', 'cellphone_call_listen_base', 1.0)
    if phone and DoesEntityExist(phone) then DeleteEntity(phone) end
    lib.notify({ title = '📞 Appel terminé', description = 'L\'appelant a raccroché.', type = 'inform', duration = 4000 })
    return {}
end

--- Chien errant : il aboie et colle le joueur
function Stage.stray(cfg)
    local h = loadModel(cfg.model)
    if not h then return {} end
    local c = GetOffsetFromEntityInWorldCoords(cache.ped, 6.0, -6.0, 0.0)
    local dog = CreatePed(28, h, c.x, c.y, groundAt(c, c.z - 1.0), 0.0, true, false)
    SetModelAsNoLongerNeeded(h)
    if not DoesEntityExist(dog) then return {} end
    SetBlockingOfNonTemporaryEvents(dog, true)
    register({ dog })
    caption('Un chien errant te repère… et ne te lâche plus.', 3000)
    local untilT = GetGameTimer() + cfg.seconds * 1000
    while GetGameTimer() < untilT and DoesEntityExist(dog) do
        local d = #(GetEntityCoords(dog) - GetEntityCoords(cache.ped))
        if d < 3.0 and math.random() < 0.5 then
            TaskStartScenarioInPlace(dog, 'WORLD_DOG_BARKING_RETRIEVER', 0, true) -- aboie (son du jeu)
            Wait(3500)
        end
        TaskFollowToOffsetOfEntity(dog, cache.ped, 0.6, -1.2, 0.0, 3.0, -1, 1.0, true)
        Wait(2500)
    end
    if DoesEntityExist(dog) then ClearPedTasks(dog) TaskWanderStandard(dog, 10.0, 10) Wait(10000) end
    return { dog }
end

--- Alcoolo collant : il titube, suit le joueur, bouteille à la main, et raconte sa vie
function Stage.drunk(cfg)
    local h = loadModel(cfg.model)
    if not h then return {} end
    local c = GetOffsetFromEntityInWorldCoords(cache.ped, -5.0, -5.0, 0.0)
    local bum = CreatePed(4, h, c.x, c.y, groundAt(c, c.z - 1.0), 0.0, true, false)
    SetModelAsNoLongerNeeded(h)
    if not DoesEntityExist(bum) then return {} end
    SetBlockingOfNonTemporaryEvents(bum, true)
    if lib.requestAnimSet('move_m@drunk@verydrunk', 2000) then SetPedMovementClipset(bum, 'move_m@drunk@verydrunk', 1.0) end
    local bh = loadModel('prop_cs_beer_bot_01')
    local bottle
    if bh then
        bottle = CreateObject(bh, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(bottle, bum, GetPedBoneIndex(bum, 57005), 0.12, 0.0, -0.05, -70.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(bh)
    end
    register({ bum, bottle })
    local untilT = GetGameTimer() + cfg.seconds * 1000
    while GetGameTimer() < untilT and DoesEntityExist(bum) do
        TaskFollowToOffsetOfEntity(bum, cache.ped, 0.8, -1.0, 0.0, 1.2, -1, 1.2, true)
        if #(GetEntityCoords(bum) - GetEntityCoords(cache.ped)) < 6.0 then
            PlayPedAmbientSpeechNative(bum, 'GENERIC_DRUNK_HIGH', 'SPEECH_PARAMS_FORCE')
            caption(('Un ivrogne : %s'):format(cfg.lines[math.random(#cfg.lines)]), 3000)
        end
        Wait(6000 + math.random(3000))
    end
    if DoesEntityExist(bum) then ClearPedTasks(bum) TaskWanderStandard(bum, 10.0, 10) Wait(10000) end
    return { bum, bottle }
end

RegisterNetEvent('gs_admin:client:stage', function(kind, cfg, text)
    if staging or busy or type(cfg) ~= 'table' or not Stage[kind] then return end
    staging = true
    local ok, ents = pcall(Stage[kind], cfg, text)
    if not ok then print('[gs_admin] mise en scène d\'ambiance : ' .. tostring(ents)) ents = {} end
    cleanStage(ents or {})
    staging = false
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
