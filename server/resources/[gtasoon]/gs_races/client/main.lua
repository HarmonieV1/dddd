-- gs_races (client) : ligne de départ ([E] → menu), compte à rebours (véhicule figé), point de passage courant (marqueur + GPS),
-- chrono affiché. Le serveur valide chaque point ; ici on ne fait qu'annoncer « j'y suis » quand on est dans le rayon.
local racing            -- { circuit, index, startedAt }
local blip

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function clearRace()
    racing = nil
    if blip then RemoveBlip(blip) blip = nil end
end

local function pointBlip(i)
    if blip then RemoveBlip(blip) end
    local p = Config.Circuits[racing.circuit].points[i]
    blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(blip, 1) SetBlipColour(blip, 5) SetBlipRoute(blip, true) SetBlipRouteColour(blip, 5)
end

local function drawText(text, x, y, scale)
    SetTextFont(4) SetTextScale(0.0, scale) SetTextCentre(true) SetTextOutline() SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('gs_races:client:begin', function(circuit, delayMs, players)
    racing = { circuit = circuit, index = 1, startedAt = GetGameTimer() + delayMs }
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
        while racing do
            local p = pts[racing.index + 1]
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
        options[#options + 1] = { title = '   Chrono solo', icon = 'stopwatch', onSelect = function() notify(lib.callback.await('gs_races:start', false, c.id, 'solo')) end }
        options[#options + 1] = { title = ('   Course (mise %d $)'):format(data.entry), icon = 'people-group',
            description = c.open and ('Départ dans %d s · %d inscrit(s) · cagnotte %d $'):format(c.open.left, c.open.players, c.open.pot) or 'Ouvre une course : les autres ont 45 s pour te rejoindre.',
            onSelect = function() notify(lib.callback.await('gs_races:start', false, c.id, 'group')) end }
    end
    lib.registerContext({ id = 'gs_races_menu', title = 'Courses de rue', options = options })
    lib.showContext('gs_races_menu')
end)

CreateThread(function()
    for id, c in pairs(Config.Circuits) do
        local p = c.points[1]
        exports.gs_markers:Add('gs_races:' .. id, { coords = p, style = 'objective', label = c.label, event = 'gs_races:client:menu',
            prompt = 'Courses de rue · ' .. c.label, reach = Config.StartRadius, distance = 40.0 })
        local b = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(b, Config.Blip.sprite) SetBlipColour(b, Config.Blip.color) SetBlipScale(b, 0.75) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Course : ' .. c.label) EndTextCommandSetBlipName(b)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearRace()
    exports.gs_markers:RemovePrefix('gs_races:')
end)
