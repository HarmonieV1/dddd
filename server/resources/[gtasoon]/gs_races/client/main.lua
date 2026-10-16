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
    local base = ok and { x = node.x, y = node.y, z = node.z, w = heading } or nil
    -- V12.63 (backtest : la course sur mesure ne démarrait pas) : départ posé hors route (parking, place) → la route la plus
    -- proche était trop loin et le serveur répondait « Départ introuvable ». On part alors du point posé, tourné vers le 2e point.
    if not base or #(vec2(base.x, base.y) - vec2(p1.x, p1.y)) > Config.StartRadius then
        local p2 = Config.Circuits[circuitId].points[2] or p1
        base = { x = p1.x, y = p1.y, z = p1.z, w = GetHeadingFromVector_2d(p2.x - p1.x, p2.y - p1.y) }
    end
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
    if not okPos then
        print(('[gs_races] placement refusé (%s) : %s'):format(tostring(circuitId), tostring(pos))) -- F8 : raison exacte
        return notify(false, pos)
    end
    local okS, msgS = lib.callback.await('gs_races:start', false, circuitId, mode)
    if not okS then print(('[gs_races] départ refusé (%s) : %s'):format(tostring(circuitId), tostring(msgS))) end
    notify(okS, msgS)
    if okS then return end
    -- V12.63 (backtest : « parle à l'organisateur », bloqué sur la ligne) : sur la ligne, on peut relancer le départ sans
    -- retourner voir l'organisateur (E), ou annuler (X : la voiture prêtée est rendue). 60 s.
    local untilT = GetGameTimer() + 60000
    lib.showTextUI('[E] Lancer le départ · [X] Annuler', { position = 'bottom-center', icon = 'flag-checkered' })
    while GetGameTimer() < untilT and not racing do
        if IsControlJustReleased(0, 38) and not IsNuiFocused() then
            okS, msgS = lib.callback.await('gs_races:start', false, circuitId, mode)
            notify(okS, msgS)
            if okS then break end
        elseif IsControlJustReleased(0, 73) and not IsNuiFocused() then
            lib.callback.await('gs_races:cancel', false)
            notify(true, 'Course annulée.')
            break
        end
        Wait(0)
    end
    lib.hideTextUI()
end

local function vehicleMenu(c, mode)
    local options = {}
    if c.vehicle then -- V12.63 : véhicule imposé (course sur mesure)
        options[#options + 1] = { title = 'Voiture imposée : ' .. c.vehicle, icon = 'car', description = 'Prêtée par l\'organisateur, la même pour tous',
            onSelect = function()
                local ok, msg = lib.callback.await('gs_races:ticket', false, c.id, mode, 'req')
                if not ok then return notify(false, msg) end
                goToStart(c.id, mode, false)
            end }
        options[#options + 1] = { title = 'Avec ma ' .. c.vehicle, icon = 'car-side', description = 'Sois au volant de ce modèle, à côté de l\'organisateur',
            onSelect = function()
                local ok, msg = lib.callback.await('gs_races:ticket', false, c.id, mode, nil)
                if not ok then return notify(false, msg) end
                goToStart(c.id, mode, true)
            end }
        lib.registerContext({ id = 'gs_races_vehicle', title = c.label .. ' · véhicule imposé', menu = 'gs_races_menu', options = options })
        return lib.showContext('gs_races_vehicle')
    end
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
    if not data then return notify(false, 'L\'organisateur ne répond pas, réessaie dans quelques secondes.') end -- V12.63 : plus de silence
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
        event = 'gs_races:client:menu', prompt = 'Parler à l\'organisateur de courses', reach = 3.5, distance = 30.0, snap = true })
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

-- V12.63 (backtest : « ça marque parler à l'organisateur et ça lance rien », au volant à moins de 15 m) : le [E] des points
-- (gs_markers) ne marche qu'à pied à 2,5 m, alors que « Avec ma voiture » demande d'être au volant → impossible. Au volant,
-- dans le rayon d'inscription, [E] ouvre ici le même menu (klaxon coupé pendant ce temps).
CreateThread(function()
    local o = Config.Organizer
    local reach = ((Config.Custom and Config.Custom.organizerReach) or 15.0) - 1.0
    while true do
        local wait = 1000
        local veh = cache.vehicle
        if veh and not racing and GetPedInVehicleSeat(veh, -1) == cache.ped then
            local p = GetEntityCoords(cache.ped)
            local d = #(vec2(p.x, p.y) - vec2(o.coords.x, o.coords.y))
            if d < reach and math.abs(p.z - o.coords.z) < 8.0 then
                wait = 0
                DisableControlAction(0, 86, true)
                SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline()
                SetTextColour(40, 224, 255, 240)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName('[E] Parler à l\'organisateur de courses')
                EndTextCommandDisplayText(0.5, 0.88)
                if (IsDisabledControlJustReleased(0, 86) or IsControlJustReleased(0, 38)) and not IsNuiFocused() then
                    TriggerEvent('gs_races:client:menu')
                    wait = 500
                end
            elseif d < 60.0 then
                wait = 250
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearRace()
    if organizer and DoesEntityExist(organizer) then DeletePed(organizer) end
    exports.gs_markers:RemovePrefix('gs_races:')
end)

-- V12.40 · Courses créées par le staff : ajoutées à Config.Circuits (même affichage, mêmes contrôles que les circuits livrés)
local function mergeCustom(list)
    for k, c in pairs(Config.Circuits) do if c.custom and not (list and list[k]) then Config.Circuits[k] = nil end end
    for k, c in pairs(list or {}) do
        local pts = {}
        for i, p in ipairs(c.points or {}) do pts[i] = vec3(p.x, p.y, p.z) end
        Config.Circuits[k] = { label = c.label, points = pts, custom = true, vehicle = c.vehicle }
    end
end
AddStateBagChangeHandler('gsRaceCustom', 'global', function(_, _, value) mergeCustom(value) end)
CreateThread(function() Wait(1500) mergeCustom(GlobalState.gsRaceCustom) end)

-- Éditeur staff (F11 → Monde et lieux → Courses de rue sur mesure) : brouillon, points posés sur place, enregistrement
local draftBlips = {}
local function clearDraftBlips() for _, b in ipairs(draftBlips) do RemoveBlip(b) end draftBlips = {} end
local function note(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local editor
editor = function()
    local ok, races, draft = lib.callback.await('gs_races:editor', false, 'list')
    if not ok then return note(false, races) end
    local o = {}
    if draft then
        o[#o + 1] = { title = ('Brouillon : %s (%d point%s)'):format(draft.label, draft.points, draft.points > 1 and 's' or ''), readOnly = true, icon = 'pen',
            description = draft.hours > 0 and ('Éphémère : %d h après enregistrement'):format(draft.hours) or 'Permanente' }
        o[#o + 1] = { title = 'Poser un point ICI', icon = 'location-dot', description = 'Dans l\'ordre : 1er = départ, dernier = arrivée', onSelect = function()
            local p = GetEntityCoords(cache.ped)
            local ok2, msg = lib.callback.await('gs_races:editor', false, 'point')
            note(ok2, msg)
            if ok2 then
                local b = AddBlipForCoord(p.x, p.y, p.z)
                SetBlipSprite(b, 1) SetBlipColour(b, 5) ShowNumberOnBlip(b, #draftBlips + 1)
                draftBlips[#draftBlips + 1] = b
            end
            editor()
        end }
        o[#o + 1] = { title = 'Véhicule imposé : ' .. (draft.vehicle or 'libre'), icon = 'car', description = 'Nom du modèle (ex. sultan, elegy2) ; vide = chacun prend le sien',
            onSelect = function()
                local r = lib.inputDialog('Véhicule imposé', { { type = 'input', label = 'Modèle (vide = libre)', default = draft.vehicle or '', max = 30 } })
                if r then note(lib.callback.await('gs_races:editor', false, 'vehicle', { model = r[1] or '' })) end
                editor()
            end }
        o[#o + 1] = { title = 'Retirer le dernier point', icon = 'rotate-left', onSelect = function()
            local ok2, msg = lib.callback.await('gs_races:editor', false, 'undo')
            note(ok2, msg)
            if ok2 and #draftBlips > 0 then RemoveBlip(draftBlips[#draftBlips]) draftBlips[#draftBlips] = nil end
            editor()
        end }
        o[#o + 1] = { title = 'Enregistrer la course', icon = 'floppy-disk', iconColor = '#5aff8c', onSelect = function()
            local ok2, msg = lib.callback.await('gs_races:editor', false, 'save')
            note(ok2, msg)
            if ok2 then clearDraftBlips() end
            editor()
        end }
        o[#o + 1] = { title = 'Abandonner le brouillon', icon = 'xmark', iconColor = '#ff6b6b', onSelect = function()
            note(lib.callback.await('gs_races:editor', false, 'cancel'))
            clearDraftBlips()
            editor()
        end }
    else
        o[#o + 1] = { title = 'Nouvelle course', icon = 'plus', description = 'Nom, puis durée de vie (heures, 0 = permanente)', onSelect = function()
            local r = lib.inputDialog('Nouvelle course de rue', {
                { type = 'input', label = 'Nom de la course', required = true, min = 3, max = 40 },
                { type = 'number', label = ('Durée de vie en heures (0 = permanente, max %d)'):format(Config.Custom.maxHours), default = 0, min = 0, max = Config.Custom.maxHours },
            })
            if r then note(lib.callback.await('gs_races:editor', false, 'new', { label = r[1], hours = r[2] })) clearDraftBlips() end
            editor()
        end }
    end
    for _, r in ipairs(races) do
        o[#o + 1] = { title = r.label, icon = 'flag-checkered', arrow = true,
            description = ('%d points · %s · %s · par %s'):format(r.points, r.expiresAt and 'éphémère' or 'permanente', r.vehicle and ('véhicule : ' .. r.vehicle) or 'véhicule libre', r.author ~= '' and r.author or '?'),
            onSelect = function() -- V12.63 : changer le véhicule imposé, ou supprimer
                lib.registerContext({ id = 'gs_races_editor_one', title = r.label, menu = 'gs_races_editor', options = {
                    { title = 'Changer le véhicule imposé', icon = 'car', description = 'Actuel : ' .. (r.vehicle or 'libre'), onSelect = function()
                        local i = lib.inputDialog('Véhicule imposé · ' .. r.label, { { type = 'input', label = 'Modèle (vide = libre)', default = r.vehicle or '', max = 30 } })
                        if i then note(lib.callback.await('gs_races:editor', false, 'setvehicle', { id = r.id, model = i[1] or '' })) end
                        editor()
                    end },
                    { title = 'Supprimer la course', icon = 'trash', iconColor = '#ff6b6b', onSelect = function()
                        local c = lib.alertDialog({ header = 'Supprimer « ' .. r.label .. ' » ?', centered = true, cancel = true,
                            content = 'Elle disparaît de chez l\'organisateur (les temps enregistrés restent en base).' })
                        if c == 'confirm' then note(lib.callback.await('gs_races:editor', false, 'delete', { id = r.id })) end
                        editor()
                    end },
                } })
                lib.showContext('gs_races_editor_one')
            end }
    end
    lib.registerContext({ id = 'gs_races_editor', title = 'Courses de rue sur mesure', options = o })
    lib.showContext('gs_races_editor')
end
exports('OpenEditor', function() editor() end)
