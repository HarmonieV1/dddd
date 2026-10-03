-- gs_races (client) : organisateur PNJ (inscription, voiture prêtée ou la sienne, placement sur la grille), compte à
-- rebours (véhicule figé), point de passage courant recollé sur la route (marqueur + GPS), chrono. Le serveur valide.
local racing            -- { circuit, index, startedAt, snapped = { [i] = vec3 } }
local blip
local organizer

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function clearRace()
    racing = nil
    if blip then RemoveBlip(blip) blip = nil end
end

--- Point de passage recollé sur la route la plus proche (les points de config sont approximatifs)
local function snapped(i)
    local p = Config.Circuits[racing.circuit].points[i]
    if racing.snapped[i] then return racing.snapped[i] end
    local ok, node = GetClosestVehicleNode(p.x, p.y, p.z, 1, 3.0, 0)
    if ok and #(vec2(node.x, node.y) - vec2(p.x, p.y)) <= Config.SnapTolerance then
        -- recalcul seulement de près (les routes lointaines ne sont pas chargées)
        if #(GetEntityCoords(cache.ped) - node) < 350.0 then racing.snapped[i] = node end
        return node
    end
    return p
end

local function pointBlip(i)
    if blip then RemoveBlip(blip) end
    local p = snapped(i)
    blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(blip, 1) SetBlipColour(blip, 5) SetBlipRoute(blip, true) SetBlipRouteColour(blip, 5)
end

local function drawText(text, x, y, scale)
    SetTextFont(4) SetTextScale(0.0, scale) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('gs_races:client:begin', function(circuit, delayMs, players)
    racing = { circuit = circuit, index = 1, startedAt = GetGameTimer() + delayMs, snapped = {} }
    local veh = cache.vehicle
    if veh then FreezeEntityPosition(veh, true) end
    CreateThread(function()
        while racing and GetGameTimer() < racing.startedAt do
            drawText(tostring(math.ceil((racing.startedAt - GetGameTimer()) / 1000)), 0.5, 0.35, 2.2)
            Wait(0)
        end
        if veh and DoesEntityExist(veh) then FreezeEntityPosition(veh, false) end
        if not racing then return end
        pointBlip(2)
        notify(true, ('GO ! %d pilote%s.'):format(players, players > 1 and 's' or ''))
        local pts = Config.Circuits[racing.circuit].points
        local lastSnap = 0
        while racing do
            if GetGameTimer() > lastSnap then lastSnap = GetGameTimer() + 1000 pointBlip(racing.index + 1) end
            local p = snapped(racing.index + 1)
            local me = GetEntityCoords(cache.ped)
            DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.CheckpointRadius * 1.6, Config.CheckpointRadius * 1.6, 8.0,
                255, 196, 0, 120, false, false, 2, false, nil, nil, false)
            local ms = GetGameTimer() - racing.startedAt
            drawText(('%d:%02d.%d  ·  point %d/%d'):format(ms // 60000, (ms // 1000) % 60, (ms % 1000) // 100, racing.index, #pts - 1), 0.5, 0.9, 0.6)
            if #(me - vec3(p.x, p.y, p.z)) <= Config.CheckpointRadius then
                local ok, idx = lib.callback.await('gs_races:checkpoint', false)
                if ok and idx then racing.index = idx pointBlip(idx + 1) PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
                elseif not ok then Wait(500) end
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('gs_races:client:end', function(msg, ok)
    clearRace()
    PlaySoundFrontend(-1, ok and 'WIN' or 'LOSER', 'HUD_AWARDS', true)
    lib.notify({ title = 'Course', description = msg, type = ok and 'success' or 'error', duration = 9000 })
end)

--- Inscription validée : transfert sur la ligne (écran noir), place sur la grille, puis départ.
local function goToStart(circuitId, mode, ownCar)
    local p1 = Config.Circuits[circuitId].points[1]
    local veh = ownCar and cache.vehicle or nil
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    local ent = veh or cache.ped
    FreezeEntityPosition(ent, true)
    SetEntityCoords(ent, p1.x, p1.y, p1.z + 1.0, false, false, false, false)
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < t do RequestCollisionAtCoord(p1.x, p1.y, p1.z) Wait(0) end
    Wait(500)
    local ok, node, heading = GetClosestVehicleNodeWithHeading(p1.x, p1.y, p1.z, 1, 3.0, 0)
    local base = ok and { x = node.x, y = node.y, z = node.z, w = heading } or { x = p1.x, y = p1.y, z = p1.z, w = 0.0 }
    local okPos, pos = lib.callback.await('gs_races:organize', false, base)
    if okPos and veh then
        SetEntityCoords(veh, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(veh, pos.w)
        SetVehicleOnGroundProperly(veh)
    end
    FreezeEntityPosition(ent, false)
    if okPos and not veh then -- voiture prêtée : le serveur nous met dedans
        local t2 = GetGameTimer() + 5000
        while not cache.vehicle and GetGameTimer() < t2 do Wait(100) end
    end
    DoScreenFadeIn(600)
    if not okPos then return notify(false, pos) end
    notify(lib.callback.await('gs_races:start', false, circuitId, mode))
end

local function vehicleMenu(c, mode)
    local options = {}
    for i, l in ipairs(Config.Loaners) do
        options[#options + 1] = { title = 'Voiture prêtée : ' .. l.label, icon = 'car', description = 'La même pour tous les pilotes, rendue à l\'arrivée',
            onSelect = function()
                local ok, msg = lib.callback.await('gs_races:ticket', false, c.id, mode, i)
                if not ok then return notify(false, msg) end
                goToStart(c.id, mode, false)
            end }
    end
    options[#options + 1] = { title = 'Avec ma voiture', icon = 'car-side', description = 'Sois au volant, à côté de l\'organisateur',
        onSelect = function()
            local ok, msg = lib.callback.await('gs_races:ticket', false, c.id, mode, nil)
            if not ok then return notify(false, msg) end
            goToStart(c.id, mode, true)
        end }
    lib.registerContext({ id = 'gs_races_vehicle', title = c.label .. ' · véhicule', menu = 'gs_races_menu', options = options })
    lib.showContext('gs_races_vehicle')
end

AddEventHandler('gs_races:client:menu', function()
    if racing then
        if lib.alertDialog({ header = 'Abandonner la course ?', content = 'Ta mise ne sera pas remboursée.', centered = true, cancel = true }) == 'confirm' then
            lib.callback.await('gs_races:cancel', false)
            clearRace()
        end
        return
    end
    local data = lib.callback.await('gs_races:list', false)
    if not data then return end
    local options = {}
    for _, c in ipairs(data.circuits) do
        local desc = {}
        for i, r in ipairs(c.top) do desc[#desc + 1] = ('%d. %s %s'):format(i, r.name, r.time) end
        options[#options + 1] = { title = c.label, icon = 'flag-checkered', readOnly = true, description = #desc > 0 and table.concat(desc, ' · ') or 'Aucun temps : sois le premier.' }
        options[#options + 1] = { title = '   Chrono solo', icon = 'stopwatch', arrow = true, onSelect = function() vehicleMenu(c, 'solo') end }
        options[#options + 1] = { title = ('   Course à plusieurs (mise %d $)'):format(data.entry), icon = 'people-group', arrow = true,
            description = c.open and ('Départ dans %d s · %d inscrit(s) · cagnotte %d $'):format(c.open.left, c.open.players, c.open.pot) or 'Ouvre une course : les autres ont 45 s pour te rejoindre.',
            onSelect = function() vehicleMenu(c, 'group') end }
    end
    lib.registerContext({ id = 'gs_races_menu', title = Config.Organizer.label, options = options })
    lib.showContext('gs_races_menu')
end)

-- Organisateur : PNJ créé à l'approche, point [E] et logo
CreateThread(function()
    local o = Config.Organizer
    exports.gs_markers:Add('gs_races:organizer', { coords = vec3(o.coords.x, o.coords.y, o.coords.z), style = 'objective', label = 'Courses de rue',
        event = 'gs_races:client:menu', prompt = 'Parler à l\'organisateur de courses', reach = 2.5, distance = 30.0, snap = true })
    local b = AddBlipForCoord(o.coords.x, o.coords.y, o.coords.z)
    SetBlipSprite(b, Config.Blip.sprite) SetBlipColour(b, Config.Blip.color) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Courses de rue (organisateur)') EndTextCommandSetBlipName(b)
    local hash = GetHashKey(o.model)
    while true do
        local d = #(GetEntityCoords(cache.ped) - vec3(o.coords.x, o.coords.y, o.coords.z))
        if d < 60.0 and not organizer and lib.requestModel(hash, 5000) then
            organizer = CreatePed(4, hash, o.coords.x, o.coords.y, o.coords.z - 1.0, o.coords.w, false, true)
            SetEntityInvincible(organizer, true) FreezeEntityPosition(organizer, true) SetBlockingOfNonTemporaryEvents(organizer, true)
            TaskStartScenarioInPlace(organizer, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        elseif d > 80.0 and organizer then
            DeletePed(organizer) organizer = nil
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearRace()
    if organizer and DoesEntityExist(organizer) then DeletePed(organizer) end
    exports.gs_markers:RemovePrefix('gs_races:')
end)
