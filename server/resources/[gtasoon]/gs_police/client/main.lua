-- gs_police (client) : menu d'intervention F4 (police / EMS en service) et effets sur la cible
-- (menottes, escorte, véhicule, soins, prison). Boucles actives seulement pendant l'effet.
local Bridge = exports.gs_bridge

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function act(name, target, data) return lib.callback.await('gs_police:action', false, name, target, data) end

local function myJob()
    local j = Bridge:GetJob()
    if not j or not j.onduty then return nil end
    if j.name == Config.PoliceJob then return 'police' end
    if j.name == Config.EmsJob then return 'ems' end
end

--- Joueurs à portée, du plus proche au plus loin.
local function nearbyPlayers()
    local me = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - me)
            if d <= Config.Range then list[#list + 1] = { id = GetPlayerServerId(pid), name = GetPlayerName(pid), d = d } end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

local function nearestVehicle(range)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD = 0, range or 8.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - me)
        if d < bestD then best, bestD = v, d end
    end
    return best
end

--- Choisit la cible : directement s'il n'y a qu'une personne, sinon une liste.
local function withTarget(fn)
    local list = nearbyPlayers()
    if #list == 0 then return notify(false, 'Personne à portée.') end
    if #list == 1 then return fn(list[1].id) end
    local options = {}
    for _, p in ipairs(list) do options[#options + 1] = { title = ('[%d] %s'):format(p.id, p.name), description = ('%.1f m'):format(p.d),
        icon = 'user', onSelect = function() fn(p.id) end } end
    lib.registerContext({ id = 'gs_police_target', title = 'Qui ?', options = options })
    lib.showContext('gs_police_target')
end

local function simple(name, progress)
    return function()
        withTarget(function(id)
            if progress and not lib.progressBar({ duration = progress.duration, label = progress.label, canCancel = true,
                anim = progress.anim, disable = { move = true, car = true, combat = true } }) then return end
            notify(act(name, id))
        end)
    end
end

local function vehicleAction(name)
    return function()
        withTarget(function(id)
            local veh = nearestVehicle(8.0)
            if veh == 0 then return notify(false, 'Aucun véhicule proche.') end
            notify(act(name, id, { netId = VehToNet(veh) }))
        end)
    end
end

local function showRecords(id)
    local ok, list = act('records', id)
    if not ok then return notify(false, list) end
    local options = {}
    for _, r in ipairs(list) do
        options[#options + 1] = { title = r.charge, icon = 'scale-balanced', readOnly = true,
            description = ('%s · %s%s · %s'):format(r.date, r.fine > 0 and (r.fine .. ' $ ') or '', r.jail > 0 and (r.jail .. ' min') or '', r.officer) }
    end
    if #options == 0 then options[1] = { title = 'Casier vierge', icon = 'circle-check', readOnly = true } end
    lib.registerContext({ id = 'gs_police_records', title = 'Casier judiciaire', menu = 'gs_police_menu', options = options })
    lib.showContext('gs_police_records')
end

local function policeOptions()
    return {
        { title = 'Menotter / démenotter', icon = 'handcuffs', onSelect = simple('cuff', { duration = 2500, label = 'Menottage…',
            anim = { dict = 'mp_arresting', clip = 'a_uncuff' } }) },
        { title = 'Escorter / lâcher', icon = 'person-walking-arrow-right', onSelect = simple('escort') },
        { title = 'Mettre dans le véhicule', icon = 'car-side', onSelect = vehicleAction('putin') },
        { title = 'Sortir du véhicule', icon = 'person-walking-arrow-loop-left', onSelect = simple('takeout') },
        { title = 'Fouiller', icon = 'magnifying-glass', onSelect = function()
            withTarget(function(id)
                local ok, msg = act('search', id)
                if not ok then return notify(false, msg) end
                exports.ox_inventory:openNearbyInventory() -- [API] ox_inventory
            end)
        end },
        { title = 'Casier judiciaire', icon = 'folder-open', onSelect = function() withTarget(showRecords) end },
        { title = 'Ajouter au casier / amende', icon = 'file-pen', onSelect = function()
            withTarget(function(id)
                local r = lib.inputDialog('Casier', {
                    { type = 'input', label = 'Infraction', required = true, max = 120 },
                    { type = 'number', label = 'Amende (0 = aucune, facture via F6)', default = 0, min = 0, max = 100000 },
                })
                if r then notify(act('record', id, { charge = r[1], fine = r[2] })) end
            end)
        end },
        { title = 'Incarcérer', icon = 'building-shield', onSelect = function()
            withTarget(function(id)
                local r = lib.inputDialog('Prison', {
                    { type = 'number', label = 'Minutes', default = 10, min = 1, max = Config.Jail.maxMinutes, required = true },
                    { type = 'input', label = 'Motif', required = true, max = 120 },
                })
                if r then notify(act('jail', id, { minutes = r[1], reason = r[2] })) end
            end)
        end },
        { title = 'Soigner (bandage)', icon = 'bandage', onSelect = simple('heal', { duration = Config.Heal.duration, label = 'Soins…',
            anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a' } }) },
        { title = 'Fourrière (véhicule proche)', icon = 'truck-pickup', onSelect = function()
            local veh = nearestVehicle(Config.Impound.range)
            if veh == 0 then return notify(false, 'Aucun véhicule proche.') end
            if not lib.progressBar({ duration = Config.Impound.duration, label = 'Appel de la fourrière…', canCancel = true,
                anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' }, disable = { move = true, car = true } }) then return end
            notify(act('impound', nil, { netId = VehToNet(veh) }))
        end },
        { title = 'Objets de voirie', icon = 'road-barrier', arrow = true, onSelect = function() GSPolice.objectsMenu() end },
        { title = ('Radar de vitesse : %s'):format(GSPolice.radar and 'ON' or 'OFF'), icon = 'gauge-high',
            onSelect = function() GSPolice.toggleRadar() end },
    }
end

local function emsOptions()
    return {
        { title = 'Réanimer', icon = 'heart-pulse', onSelect = simple('revive', { duration = Config.Revive.duration, label = 'Réanimation…',
            anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' } }) },
        { title = 'Soigner (bandage)', icon = 'bandage', onSelect = simple('heal', { duration = Config.Heal.duration, label = 'Soins…',
            anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a' } }) },
        { title = 'Porter / lâcher le patient', icon = 'person-walking-arrow-right', onSelect = simple('escort') },
        { title = 'Mettre dans l\'ambulance', icon = 'truck-medical', onSelect = vehicleAction('putin') },
        { title = 'Sortir du véhicule', icon = 'person-walking-arrow-loop-left', onSelect = simple('takeout') },
    }
end

GSPolice = GSPolice or {}

function GSPolice.openMenu()
    local job = myJob()
    if not job then return notify(false, 'Réservé à la police et aux EMS en service.') end
    lib.registerContext({ id = 'gs_police_menu', title = job == 'police' and 'Intervention LSPD' or 'Intervention EMS',
        options = job == 'police' and policeOptions() or emsOptions() })
    lib.showContext('gs_police_menu')
end

RegisterCommand('intervention', function() GSPolice.openMenu() end, false)
RegisterKeyMapping('intervention', 'Menu intervention (police / EMS)', 'keyboard', Config.Key)

-- Effets sur la cible ----------------------------------------------------------------------------------------------

local CUFF_BLOCK = { 21, 22, 23, 24, 25, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264 }

CreateThread(function()
    local wasCuffed, attachedTo = false, nil
    while true do
        local st = LocalPlayer.state
        local ped = PlayerPedId()
        -- Menottes
        if st.gsCuffed and not wasCuffed then
            wasCuffed = true
            SetEnableHandcuffs(ped, true)
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            CreateThread(function()
                lib.requestAnimDict('mp_arresting', 2000)
                while LocalPlayer.state.gsCuffed do
                    local p = PlayerPedId()
                    for _, c in ipairs(CUFF_BLOCK) do DisableControlAction(0, c, true) end
                    if not IsEntityPlayingAnim(p, 'mp_arresting', 'idle', 3) and not IsPedInAnyVehicle(p, false) then
                        TaskPlayAnim(p, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                    end
                    Wait(0)
                end
            end)
        elseif not st.gsCuffed and wasCuffed then
            wasCuffed = false
            SetEnableHandcuffs(ped, false)
            ClearPedTasks(ped)
        end
        -- Escorte
        local by = st.gsEscortedBy
        if by and attachedTo ~= by then
            local pid = GetPlayerFromServerId(by)
            if pid ~= -1 then
                AttachEntityToEntity(ped, GetPlayerPed(pid), 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                attachedTo = by
            end
        elseif not by and attachedTo then
            DetachEntity(ped, true, false)
            attachedTo = nil
        end
        Wait((wasCuffed or attachedTo) and 200 or 500)
    end
end)

RegisterNetEvent('gs_police:client:putIn', function(netId)
    local veh = NetToVeh(netId)
    if veh == 0 then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    for _, seat in ipairs({ 2, 1, 0 }) do
        if IsVehicleSeatFree(veh, seat) then return TaskWarpPedIntoVehicle(ped, veh, seat) end
    end
end)

RegisterNetEvent('gs_police:client:takeOut', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) end
end)

RegisterNetEvent('gs_police:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

-- Prison : compte à rebours ----------------------------------------------------------------------------------------
local jailEnd = 0
RegisterNetEvent('gs_police:client:jail', function(seconds, reason)
    local was = jailEnd > GetGameTimer()
    jailEnd = GetGameTimer() + (seconds or 0) * 1000
    if not seconds or seconds <= 0 or was then return end
    lib.notify({ title = 'Prison de Bolingbroke', description = 'Motif : ' .. (reason or '—'), type = 'error', duration = 10000 })
    CreateThread(function()
        while GetGameTimer() < jailEnd do
            local left = math.ceil((jailEnd - GetGameTimer()) / 1000)
            SetTextFont(4) SetTextScale(0.0, 0.5) SetTextColour(255, 46, 136, 230) SetTextOutline() SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('PRISON · %d:%02d'):format(left // 60, left % 60))
            EndTextCommandDisplayText(0.5, 0.05)
            Wait(0)
        end
    end)
end)
