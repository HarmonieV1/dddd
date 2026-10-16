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
-- V12.63 (backtest : « il vole de travers jusqu'au PNJ ») : tout le vol suit UN SEUL axe, du départ vers l'arrivée, l'avion
-- regarde toujours où il va ; la croisière descend en douceur jusqu'au début de la finale, la finale arrive dans l'axe avec un
-- arrondi (nez qui se relève), puis toucher et roulage dans le même axe. Vitesses raccordées d'une phase à l'autre (plus d'à-coup),
-- assiette tirée de la pente réelle, sol de la piste lu par le jeu quand il est chargé.

--- Distance parcourue au temps u (0 → 1) d'un segment de longueur D en T s, vitesse v0 au départ et v1 à l'arrivée (Hermite)
local function travel(u, D, T, v0, v1)
    local u2, u3 = u * u, u * u * u
    return (u3 - 2 * u2 + u) * T * v0 + (-2 * u3 + 3 * u2) * D + (u3 - u2) * T * v1
end
local function smooth(x) x = math.max(0.0, math.min(1.0, x)) return x * x * (3 - 2 * x) end
local function groundAt(x, y, near)
    local ok, gz = GetGroundZFor_3dCoord(x, y, near + 40.0, false)
    if ok and math.abs(gz - near) < 12.0 then return gz end -- sol plausible (piste, route) ; sinon on garde l'altitude prévue
    return nil
end

local function flightFilm(toIsland, arrival, opts)
    local c = I.flight.cinematic
    local L = c.landing or {}
    local from, to = toIsland and c.from or c.to, toIsland and c.to or c.from
    opts = opts or {} -- V12.63 · North Yankton : autre cap (opts.to), pas de piste (opts.noLanding), autre titre (opts.label)
    if opts.to then if toIsland then to = opts.to else from = opts.to end end
    local landing = not (opts.noLanding and toIsland)
    local hash = GetHashKey(c.model)
    lib.requestModel(hash, 5000)
    -- axe d'atterrissage : la piste de destination (V12.63), sinon l'axe départ → arrivée ; sans piste : vers le cap de croisière
    local rw = landing and c.runways and c.runways[toIsland and 'island' or 'mainland'] or nil
    local aim = landing and vec3(arrival.x, arrival.y, from.z) or to
    local fx, fy = aim.x - from.x, aim.y - from.y
    if rw then
        -- une piste s'utilise dans les deux sens : on atterrit dans celui qui suit l'arrivée de l'avion (pas de demi-tour final)
        local A, B = rw.toucher, rw.arret
        if (B.x - A.x) * (A.x - from.x) + (B.y - A.y) * (A.y - from.y) < 0 then A, B = B, A end
        rw = { toucher = A, arret = B }
        fx, fy = B.x - A.x, B.y - A.y
    end
    local flen = math.sqrt(fx * fx + fy * fy)
    if flen < 1.0 then fx, fy, flen = 1.0, 0.0, 1.0 end
    local dir = vec3(fx / flen, fy / flen, 0.0)
    local heading = GetHeadingFromVector_2d(dir.x, dir.y)
    local wheel = L.wheelHeight or 1.2
    local refZ = rw and rw.toucher.z or arrival.z -- sol attendu au toucher des roues
    local touchZ = refZ + wheel
    local touch = rw and vec3(rw.toucher.x, rw.toucher.y, 0.0) or (vec3(arrival.x, arrival.y, 0.0) - dir * (L.before or 110.0))
    local rollLen = rw and math.min(400.0, flen) or (L.roll or 90.0)
    local stop = touch + dir * rollLen
    local final = touch - dir * (L.finalDistance or 650.0)
    -- croisière en courbe (V12.63) : de la position de départ jusqu'au début de la finale, en arrivant DANS l'axe de la piste
    -- (courbe de Bézier, mesurée en longueur : vitesse régulière, cap = tangente, inclinaison dans le virage)
    local curve
    if landing then
        local ox, oy = final.x - from.x, final.y - from.y
        local L3 = math.sqrt(ox * ox + oy * oy) / 3
        local P0, P3 = vec3(from.x, from.y, 0.0), vec3(final.x, final.y, 0.0)
        local P1 = P0 + vec3(ox, oy, 0.0) / math.max(1.0, L3 * 3) * L3
        local P2 = P3 - dir * L3
        local pts, acc = {}, { 0.0 }
        for i = 0, 200 do
            local t = i / 200
            local a, b, cc, d = (1 - t) ^ 3, 3 * (1 - t) ^ 2 * t, 3 * (1 - t) * t * t, t ^ 3
            pts[i + 1] = P0 * a + P1 * b + P2 * cc + P3 * d
            if i > 0 then acc[i + 1] = acc[i] + #(pts[i + 1] - pts[i]) end
        end
        curve = { pts = pts, acc = acc, len = acc[#acc] }
        function curve.at(sd)
            local A = curve.acc
            local lo, hi = 1, #A
            while hi - lo > 1 do local mid = (lo + hi) // 2 if A[mid] <= sd then lo = mid else hi = mid end end
            local seg = math.max(1e-6, A[hi] - A[lo])
            local k = math.max(0.0, math.min(1.0, (sd - A[lo]) / seg))
            local p = curve.pts[lo] + (curve.pts[hi] - curve.pts[lo]) * k
            local tg = curve.pts[hi] - curve.pts[lo]
            return p.x, p.y, GetHeadingFromVector_2d(tg.x, tg.y)
        end
    end
    local finalH = L.finalHeight or 70.0
    local vTouch = L.touchSpeed or 60.0
    local plane = CreateVehicle(hash, from.x, from.y, from.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(plane, false, false)
    SetVehicleEngineOn(plane, true, true, false)
    SetVehicleLandingGear(plane, 3) -- train rentré
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(800)
    local label = opts.label or (toIsland and 'Vol LSIA → Cayo Perico' or 'Vol Cayo Perico → LSIA')
    -- phases : a → b (au sol, x/y), durée T, vitesses de raccord v0 → v1, altitude z(f) avec f = part du segment parcourue
    local phases
    if landing then
        local Dc, Da, Dr = curve.len, (L.finalDistance or 650.0), rollLen
        local Tc, Ta = c.seconds, (L.approachSeconds or 5)
        local vA = math.max(vTouch, 2 * Da / Ta - vTouch)  -- vitesse en début de finale (moyenne Da/Ta, fin à vTouch)
        local Tr = math.max(1.5, 2 * Dr / vTouch)          -- roulage : freinage régulier jusqu'à l'arrêt
        phases = {
            { kind = 'cruise', a = from, b = final, D = Dc, T = Tc, v0 = Dc / Tc, v1 = math.min(vA, 3 * Dc / Tc), text = label .. ' · [Espace] arriver',
              z = function(f) return from.z + ((touchZ + finalH) - from.z) * smooth((f - 0.45) / 0.55) end },
            { kind = 'approach', a = final, b = touch, D = Da, T = Ta, v0 = vA, v1 = vTouch, text = 'Approche finale',
              z = function(f) return touchZ + finalH * (1 - f) ^ 1.6 end },             -- pente qui s'adoucit : l'arrondi
            { kind = 'roll', a = touch, b = stop, D = Dr, T = Tr, v0 = vTouch, v1 = 0.0, text = 'Atterrissage',
              z = function() return touchZ end },
        }
    else
        local Dc = flen
        phases = { { kind = 'cruise', a = from, b = to, D = Dc, T = c.seconds, v0 = Dc / c.seconds, v1 = Dc / c.seconds, text = label .. ' · [Espace] arriver',
            z = function(f) return from.z + (to.z - from.z) * smooth(f) end } }
    end
    local skipped, pitch, last, bank, lastHdg = false, 0.0, nil, 0.0, nil
    local camFrom = vec3(-8.0, -30.0, 6.0)
    local clock = GetGameTimer() -- horloges enchaînées : une phase reprend là où la précédente s'est arrêtée (aucune image figée)
    for _, ph in ipairs(phases) do
        if ph.kind == 'approach' then SetVehicleLandingGear(plane, 0) end -- train sorti pour l'approche
        local start, probeAt = clock, 0
        clock = clock + ph.T * 1000
        -- par frame : seulement pendant le film du vol (une vingtaine de secondes, une fois par trajet)
        while true do
            local now = GetGameTimer()
            local u = math.min(1.0, (now - start) / (ph.T * 1000))
            local s = math.max(0.0, math.min(ph.D, travel(u, ph.D, ph.T, ph.v0, ph.v1)))
            local f = ph.D > 0 and s / ph.D or 1.0
            if ph.kind ~= 'cruise' and now >= probeAt then -- sol de la piste, dès que le jeu l'a chargé (sinon altitude prévue)
                probeAt = now + 400
                local g = groundAt(touch.x, touch.y, refZ)
                if g then touchZ = touchZ + ((g + wheel) - touchZ) * 0.5 end
            end
            local x, y = ph.a.x + dir.x * s, ph.a.y + dir.y * s
            local hdg = heading
            if ph.kind == 'cruise' and curve then x, y, hdg = curve.at(s) end
            local z = ph.z(f)
            if ph.kind == 'roll' then local g = groundAt(x, y, touchZ - wheel) if g then z = g + wheel end end
            -- assiette : pente réelle de la trajectoire (+ arrondi en fin de finale), lissée
            local target = 0.0
            if last then
                local ds = math.sqrt((x - last.x) ^ 2 + (y - last.y) ^ 2)
                if ds > 0.01 then target = math.deg(math.atan(z - last.z, ds)) end
            end
            if ph.kind == 'approach' then target = target + 7.0 * smooth((f - 0.7) / 0.3) elseif ph.kind == 'roll' then target = 2.0 * (1 - f) end
            target = math.max(-6.0, math.min(9.0, target))
            pitch = pitch + (target - pitch) * 0.08
            -- inclinaison dans le virage : proportionnelle à la vitesse de rotation du cap, lissée, 25° au plus
            local dh = lastHdg and ((hdg - lastHdg + 540.0) % 360.0 - 180.0) or 0.0
            bank = bank + (math.max(-25.0, math.min(25.0, -dh * 18.0)) - bank) * 0.06
            lastHdg = hdg
            last = vec3(x, y, z)
            SetEntityCoordsNoOffset(plane, x, y, z, false, false, false)
            SetEntityRotation(plane, pitch, bank, hdg, 2, true)
            SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
            local off
            if ph.kind == 'cruise' then
                off = vec3(-28.0 + 20.0 * u, -30.0, 6.0)
                camFrom = off
            else
                local k = smooth((now - start) / 1500) -- la caméra glisse vers sa place d'atterrissage, sans saut
                off = camFrom + (vec3(-14.0, -26.0, 5.0) - camFrom) * k
            end
            local side = GetOffsetFromEntityInWorldCoords(plane, off.x, off.y, off.z)
            SetCamCoord(cam, side.x, side.y, side.z)
            PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true)
            SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 220)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(ph.text)
            EndTextCommandDisplayText(0.5, 0.9)
            if ph.kind == 'cruise' and (IsControlJustPressed(0, 22) or IsControlJustPressed(0, 194)) then skipped = true break end
            if u >= 1.0 then break end
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
        lib.notify({ title = m == 'yankton' and 'North Yankton' or 'Cayo Perico', type = 'inform', duration = 10000,
            description = m == 'yankton' and 'Vol retour au comptoir de l\'arrivée. Ici, personne ne te connaît : ta recherche retombe plus vite. Location de 4x4 et café à Ludendorff. GTA n\'a pas de grande carte de North Yankton (Échap) : la minimap suffit.'
                or 'Vol retour : comptoir à l\'arrivée (logo avion), quand tu veux.' })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if party.on then partyStop() end
    if loaded then setIsland(false) end
    exports.gs_markers:RemovePrefix('gs_world:')
end)
