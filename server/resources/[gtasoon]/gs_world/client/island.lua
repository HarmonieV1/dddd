-- gs_world (client) : Cayo Perico. L'île du jeu (DLC) est activée seulement quand on s'en approche, puis désactivée :
-- pas de coût en ville, eau / minimap / chemins IA de Los Santos intacts. [API] natives GTA « heist island ».
local I = Config.Island
local loaded = false

local function setIsland(on)
    loaded = on
    SetIslandHopperEnabled('HeistIsland', on)
    SetToggleMinimapHeistIsland(on)
    SetAiGlobalPathNodesType(on and 1 or 0)
    LoadGlobalWaterFile(on and 1 or 0)
    SetDeepOceanScaler(on and 0.0 or 1.0)
    SetScenarioGroupEnabled('Heist_Island_Peds', on)
    SetAudioFlag('PlayerOnDLCHeist4Island', on)
    SetAmbientZoneListStatePersistent('AZL_DLC_Hei4_Island_Zones', on, on)
    SetAmbientZoneListStatePersistent('AZL_DLC_Hei4_Island_Disabled_Zones', not on, not on)
end

CreateThread(function()
    while true do
        local near = #(GetEntityCoords(cache.ped) - I.center) < I.loadRadius
        if near ~= loaded then setIsland(near) end
        Wait(near and 2000 or 3000)
    end
end)

-- Film du vol : avion local au-dessus de l'océan, caméra qui le suit ; [Espace] ou [Retour] = transfert rapide.
local function flightFilm(toIsland)
    local c = I.flight.cinematic
    local from, to = toIsland and c.from or c.to, toIsland and c.to or c.from
    local hash = GetHashKey(c.model)
    lib.requestModel(hash, 5000)
    local heading = GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
    local plane = CreateVehicle(hash, from.x, from.y, from.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(plane, false, false)
    SetVehicleEngineOn(plane, true, true, false)
    SetVehicleLandingGear(plane, 3) -- train rentré
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(800)
    local start, total = GetGameTimer(), c.seconds * 1000
    -- par frame : seulement pendant le film du vol (quelques secondes)
    while true do
        local k = math.min(1.0, (GetGameTimer() - start) / total)
        local p = from + (to - from) * k
        SetEntityCoordsNoOffset(plane, p.x, p.y, p.z, false, false, false)
        SetEntityHeading(plane, heading)
        SetFocusPosAndVel(p.x, p.y, p.z, 0.0, 0.0, 0.0)
        local side = GetOffsetFromEntityInWorldCoords(plane, -28.0 + 20.0 * k, -30.0, 6.0)
        SetCamCoord(cam, side.x, side.y, side.z)
        PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true)
        SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 220)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(toIsland and 'Vol LSIA → Cayo Perico · [Espace] arriver' or 'Vol Cayo Perico → LSIA · [Espace] arriver')
        EndTextCommandDisplayText(0.5, 0.9)
        if k >= 1.0 or IsControlJustPressed(0, 22) or IsControlJustPressed(0, 194) then break end
        Wait(0)
    end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    DeleteEntity(plane)
    local t = GetGameTimer() + 1500 -- dernier chargement autour du joueur
    while GetGameTimer() < t do Wait(100) end
end

-- Soirée plage (GlobalState.gsCayoParty posé par le staff) : décor, danseurs et musique créés localement, seulement
-- pour les joueurs proches de la plage ; tout est retiré à la fin ou quand on s'éloigne.
local party = { on = false, entities = {} }

local function partyStop()
    for _, e in ipairs(party.entities) do if DoesEntityExist(e) then DeleteEntity(e) end end
    for _, em in ipairs(I.party.emitters) do SetStaticEmitterEnabled(em, false) end
    party.entities, party.on = {}, false
end

local function partyStart()
    party.on = true
    local P = I.party
    for _, pr in ipairs(P.props) do
        local h = GetHashKey(pr.model)
        if IsModelInCdimage(h) then
            lib.requestModel(h, 5000)
            local o = CreateObjectNoOffset(h, pr.pos.x, pr.pos.y, pr.pos.z, false, false, false)
            SetEntityHeading(o, pr.pos.w)
            PlaceObjectOnGroundProperly(o)
            FreezeEntityPosition(o, true)
            party.entities[#party.entities + 1] = o
        end
    end
    for i = 1, P.dancers.count do
        local h = GetHashKey(P.dancers.models[(i - 1) % #P.dancers.models + 1])
        lib.requestModel(h, 5000)
        local a = math.random() * 2 * math.pi
        local r = math.random() * P.dancers.area
        local ped = CreatePed(4, h, P.spot.x + math.cos(a) * r, P.spot.y - 6.0 + math.sin(a) * r, P.spot.z - 1.0, math.random(0, 359) + 0.0, false, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_PARTYING', 0, true)
        party.entities[#party.entities + 1] = ped
    end
    for _, em in ipairs(P.emitters) do SetStaticEmitterEnabled(em, true) end
end

CreateThread(function()
    while true do
        local g = GlobalState.gsCayoParty
        local want = g ~= nil and loaded and #(GetEntityCoords(cache.ped) - I.party.spot) < I.party.radius
        if want and not party.on then partyStart() elseif not want and party.on then partyStop() end
        Wait(3000)
    end
end)

-- Vols réguliers LS ↔ île
AddEventHandler('gs_world:client:fly', function(side)
    local f = I.flight
    local alert = lib.alertDialog({ header = f[side].label, content = f.price > 0 and ('Billet : %d $ (banque). On y va ?'):format(f.price) or 'Vol gratuit. On y va ?', centered = true, cancel = true })
    if alert ~= 'confirm' then return end
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end
    local ok, msg = lib.callback.await('gs_world:fly', false, side)
    if ok and f.cinematic and f.cinematic.enabled then
        flightFilm(side == 'mainland')   -- l'île se charge pendant le film
    elseif ok then
        -- laisser l'île se charger (ou se décharger) avant de rendre l'image
        local t = GetGameTimer() + 4000
        while GetGameTimer() < t do Wait(100) end
    end
    DoScreenFadeIn(800)
    if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end
    if ok then TriggerEvent('gs_world:client:landed', side) end
end)

CreateThread(function()
    for _, side in ipairs({ 'mainland', 'island' }) do
        local s = I.flight[side]
        exports.gs_markers:Add('gs_world:fly:' .. side, { coords = s.counter, style = 'entry', label = s.label,
            event = 'gs_world:client:fly', args = { side }, prompt = s.label, distance = 20.0, snap = true, reach = 2.2 })
        local b = AddBlipForCoord(s.counter.x, s.counter.y, s.counter.z)
        SetBlipSprite(b, 307) SetBlipColour(b, 5) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, side == 'mainland')
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(side == 'mainland' and 'Vols pour Cayo Perico' or 'Vol retour pour Los Santos') EndTextCommandSetBlipName(b)
    end
end)

-- Arrivée sur l'île : où reprendre l'avion
AddEventHandler('gs_world:client:landed', function(side)
    if side == 'mainland' then
        lib.notify({ title = 'Cayo Perico', description = 'Vol retour : comptoir à côté de la piste (logo avion), quand tu veux.', type = 'inform', duration = 9000 })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if party.on then partyStop() end
    if loaded then setIsland(false) end
    exports.gs_markers:RemovePrefix('gs_world:')
end)
