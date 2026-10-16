-- gs_world (client) : Cayo Perico. L'île du jeu (DLC) est activée seulement quand on s'en approche, puis désactivée :
-- pas de coût en ville, eau / minimap / chemins IA de Los Santos intacts. [API] natives GTA « heist island ».
local I = Config.Island
local Y = Config.Yankton
local loaded = false
GsWorld = GsWorld or {} -- partagé avec client/yankton.lua (même ressource) : vol en cours
--- V12.63 · destination du vol régulier aujourd'hui (North Yankton et Cayo partagent les mêmes coordonnées)
local function mode() return GlobalState.gsIslandMode == 'yankton' and 'yankton' or 'cayo' end

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
        local near = mode() == 'cayo' and #(GetEntityCoords(cache.ped) - I.center) < I.loadRadius -- V12.63 : jamais un jour North Yankton
        if near ~= loaded then setIsland(near) end
        Wait(near and 2000 or 3000)
    end
end)

-- Film du vol : avion local au-dessus de l'océan, caméra qui le suit, puis APPROCHE, ATTERRISSAGE et ROULAGE près du comptoir
-- d'arrivée (V12.33 : avant, l'avion disparaissait en plein vol). [Espace] ou [Retour] pendant la croisière = transfert rapide.
local function flightFilm(toIsland, arrival, opts)
    local c = I.flight.cinematic
    local L = c.landing or {}
    local from, to = toIsland and c.from or c.to, toIsland and c.to or c.from
    opts = opts or {} -- V12.63 · North Yankton : autre cap (opts.to), pas de piste (opts.noLanding), autre titre (opts.label)
    if opts.to then if toIsland then to = opts.to else from = opts.to end end
    local hash = GetHashKey(c.model)
    lib.requestModel(hash, 5000)
    local heading = GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
    local flat = vec3(to.x - from.x, to.y - from.y, 0.0)
    local dir = flat / #flat
    local ground = arrival.z + (L.wheelHeight or 1.2)
    local touch = vec3(arrival.x, arrival.y, ground) - dir * (L.before or 60.0) -- toucher des roues, avant le comptoir
    local stop = touch + dir * (L.roll or 45.0)                                   -- fin du roulage, à côté du comptoir
    local plane = CreateVehicle(hash, from.x, from.y, from.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(plane, false, false)
    SetVehicleEngineOn(plane, true, true, false)
    SetVehicleLandingGear(plane, 3) -- train rentré
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(800)
    local label = opts.label or (toIsland and 'Vol LSIA → Cayo Perico' or 'Vol Cayo Perico → LSIA')
    local phases = {
        { a = from, b = to, ms = c.seconds * 1000, kind = 'cruise', text = label .. ' · [Espace] arriver' },
        { a = to, b = touch, ms = (L.approachSeconds or 4) * 1000, kind = 'approach', text = 'Approche finale' },
        { a = touch, b = stop, ms = (L.rollSeconds or 2.5) * 1000, kind = 'roll', text = 'Atterrissage' },
    }
    if opts.noLanding and toIsland then phases = { phases[1] } end
    local skipped = false
    for _, ph in ipairs(phases) do
        if ph.kind == 'approach' then SetVehicleLandingGear(plane, 0) end -- train sorti pour l'approche
        local start = GetGameTimer()
        -- par frame : seulement pendant le film du vol (une quinzaine de secondes, une fois par trajet)
        while true do
            local k = math.min(1.0, (GetGameTimer() - start) / ph.ms)
            local e = k
            if ph.kind == 'approach' then e = 1 - (1 - k) ^ 2 elseif ph.kind == 'roll' then e = 1 - (1 - k) ^ 3 end -- freinage
            local p = ph.a + (ph.b - ph.a) * e
            SetEntityCoordsNoOffset(plane, p.x, p.y, p.z, false, false, false)
            SetEntityRotation(plane, ph.kind == 'approach' and -4.0 * (1 - k) or 0.0, 0.0, heading, 2, true)
            SetFocusPosAndVel(p.x, p.y, p.z, 0.0, 0.0, 0.0)
            local side = ph.kind == 'cruise' and GetOffsetFromEntityInWorldCoords(plane, -28.0 + 20.0 * k, -30.0, 6.0)
                or GetOffsetFromEntityInWorldCoords(plane, -14.0, -26.0, 5.0)
            SetCamCoord(cam, side.x, side.y, side.z)
            PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true)
            SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 220)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(ph.text)
            EndTextCommandDisplayText(0.5, 0.9)
            if ph.kind == 'cruise' and (IsControlJustPressed(0, 22) or IsControlJustPressed(0, 194)) then skipped = true break end
            if k >= 1.0 then break end
            Wait(0)
        end
        if skipped then break end
    end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    DeleteEntity(plane)
end

--- V12.33 · Le joueur ne reprend la main que le sol chargé sous ses pieds, posé au niveau réel du sol (avant : 1,5 s d'attente
--- aveugle à l'arrivée, le monde pas encore chargé autour de lui, et il traversait la carte).
local function settleAt(arrival)
    local ped = cache.ped
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(arrival.x, arrival.y, arrival.z)
    NewLoadSceneStartSphere(arrival.x, arrival.y, arrival.z, 80.0, 0)
    local t = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do
        RequestCollisionAtCoord(arrival.x, arrival.y, arrival.z)
        Wait(50)
    end
    NewLoadSceneStop()
    local ok, gz = GetGroundZFor_3dCoord(arrival.x, arrival.y, arrival.z + 5.0, false)
    SetEntityCoords(ped, arrival.x, arrival.y, (ok and gz or arrival.z) + 1.0, false, false, false, false)
    SetEntityHeading(ped, arrival.w)
    FreezeEntityPosition(ped, false)
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

-- Vols réguliers LS ↔ île (V12.63 : l'île du jour, Cayo Perico ou North Yankton)
local function flightOf(m)
    local ny = m == 'yankton'
    return { island = ny and Y.flight.island or I.flight.island, price = ny and (Y.flight.price or 0) or I.flight.price,
        mainlandLabel = ny and Y.flight.mainlandLabel or I.flight.mainland.label, name = ny and 'North Yankton' or 'Cayo Perico' }
end

AddEventHandler('gs_world:client:fly', function(side)
    local f = I.flight
    local m = mode()
    local fl = flightOf(m)
    local alert = lib.alertDialog({ header = side == 'mainland' and fl.mainlandLabel or fl.island.label, centered = true, cancel = true,
        content = fl.price > 0 and ('Billet : %d $ (liquide ou argent sale). On y va ?'):format(fl.price) or 'Vol gratuit. On y va ?' })
    if alert ~= 'confirm' then return end
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(cache.ped, true) -- V12.33 : figé le temps du film (le serveur nous a déjà posés à l'arrivée, monde pas encore chargé)
    GsWorld.flying = true
    local ok, msg, served = lib.callback.await('gs_world:fly', false, side)
    if ok and served and served ~= m then m, fl = served, flightOf(served) end -- destination changée entre-temps
    local dest = side == 'mainland' and fl.island.arrival or f.mainland.arrival
    if ok and m == 'yankton' and side == 'mainland' then TriggerEvent('gs_world:client:yanktonPreload') end
    if ok and f.cinematic and f.cinematic.enabled then
        if m == 'yankton' then
            flightFilm(side == 'mainland', dest, { to = Y.flight.cinematicTo, noLanding = true,
                label = side == 'mainland' and 'Vol LSIA → North Yankton' or 'Vol North Yankton → LSIA' })
        else
            flightFilm(side == 'mainland', dest) -- l'île se charge pendant le film
        end
    end
    if ok then settleAt(dest) else FreezeEntityPosition(cache.ped, false) end
    GsWorld.flying = false
    DoScreenFadeIn(800)
    if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end
    if ok then TriggerEvent('gs_world:client:landed', side, m) end
end)

-- V12.63 · Changement de destination par le staff pendant qu'on est sur l'île : rapatrié à l'aéroport (sol chargé avant)
RegisterNetEvent('gs_world:client:evacuate', function(text)
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end
    GsWorld.flying = true
    settleAt(I.flight.mainland.arrival)
    GsWorld.flying = false
    DoScreenFadeIn(800)
    lib.notify({ title = 'Vol régulier', description = text, type = 'inform', icon = 'plane-arrival', duration = 12000 })
end)

-- Comptoirs et blips (V12.63 : refaits quand la destination change)
local flightBlips = {}
local function refreshFlights(m)
    for _, side in ipairs({ 'mainland', 'island' }) do exports.gs_markers:Remove('gs_world:fly:' .. side) end
    for _, b in ipairs(flightBlips) do RemoveBlip(b) end
    flightBlips = {}
    local fl = flightOf(m)
    for _, side in ipairs({ 'mainland', 'island' }) do
        local s = side == 'mainland' and I.flight.mainland or fl.island
        local label = side == 'mainland' and fl.mainlandLabel or s.label
        exports.gs_markers:Add('gs_world:fly:' .. side, { coords = s.counter, style = 'entry', label = label,
            event = 'gs_world:client:fly', args = { side }, prompt = label, distance = 20.0, snap = true, reach = 2.2 })
        local b = AddBlipForCoord(s.counter.x, s.counter.y, s.counter.z)
        SetBlipSprite(b, 307) SetBlipColour(b, 5) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, side == 'mainland')
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(side == 'mainland' and ('Vols pour ' .. fl.name) or 'Vol retour pour Los Santos') EndTextCommandSetBlipName(b)
        flightBlips[#flightBlips + 1] = b
    end
end
CreateThread(function() refreshFlights(mode()) end)
AddStateBagChangeHandler('gsIslandMode', 'global', function(_, _, value)
    SetTimeout(0, function() refreshFlights(value == 'yankton' and 'yankton' or 'cayo') end)
end)

-- Arrivée sur l'île : où reprendre l'avion
AddEventHandler('gs_world:client:landed', function(side, m)
    if side == 'mainland' then
        lib.notify({ title = m == 'yankton' and 'North Yankton' or 'Cayo Perico', description = 'Vol retour : comptoir à l\'arrivée (logo avion), quand tu veux.', type = 'inform', duration = 9000 })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if party.on then partyStop() end
    if loaded then setIsland(false) end
    exports.gs_markers:RemovePrefix('gs_world:')
end)
