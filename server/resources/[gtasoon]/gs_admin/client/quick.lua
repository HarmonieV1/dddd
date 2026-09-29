-- gs_admin (client) : menu staff rapide (F11, flèches + Entrée). Chaque pouvoir est d'abord accordé par le serveur
-- (niveau + mode staff + journal), puis appliqué ici. Couper le mode staff coupe tous les pouvoirs.
local Bridge = exports.gs_bridge
local powers = { noclip = false, invisible = false, godmode = false, names = false }
local animal = nil          -- modèle animal actif
local spectating = nil      -- { target, back = vec3 }
local info = nil            -- dernier retour de gs_admin:quick

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function act(name, target, data) return lib.callback.await('gs_admin:action', false, name, target, data) end

--- Demande l'accord du serveur pour un pouvoir. Retourne true si accordé.
local function grant(power, data)
    data = data or {}
    data.power = power
    local ok, msg = act('power', nil, data)
    if not ok then notify(false, msg) end
    return ok
end

-- Pouvoirs -------------------------------------------------------------------------------------------------

local function applyVisibility()
    local ped = PlayerPedId()
    local hidden = powers.invisible or powers.noclip or spectating ~= nil
    SetEntityVisible(ped, not hidden, false)
    if hidden then SetEntityAlpha(ped, 120, false) else ResetEntityAlpha(ped) end
end

local function applyGodmode()
    SetEntityInvincible(PlayerPedId(), powers.godmode or powers.noclip)
    SetPlayerInvincible(PlayerId(), powers.godmode or powers.noclip)
end

local NOCLIP_DISABLED = { 30, 31, 32, 33, 34, 35, 21, 22, 36, 44, 38, 24, 25, 257, 263, 140, 141, 142, 143, 75 }

local function noclipLoop()
    CreateThread(function()
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local ent = veh ~= 0 and veh or ped
        SetEntityCollision(ent, false, false)
        FreezeEntityPosition(ent, true)
        lib.showTextUI('VOL LIBRE  ·  [ZQSD] bouger  ·  [Espace/Ctrl] monter/descendre  ·  [Shift] vite  ·  [Alt] lent', { position = 'top-center' })
        while powers.noclip do
            for _, c in ipairs(NOCLIP_DISABLED) do DisableControlAction(0, c, true) end
            local speed = (IsDisabledControlPressed(0, 21) and 4.0) or (IsDisabledControlPressed(0, 19) and 0.15) or 1.0
            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local fwd = vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
            local right = vec3(math.cos(yaw), math.sin(yaw), 0.0)
            local p = GetEntityCoords(ent)
            local move = vec3(0.0, 0.0, 0.0)
            if IsDisabledControlPressed(0, 32) then move = move + fwd end
            if IsDisabledControlPressed(0, 33) then move = move - fwd end
            if IsDisabledControlPressed(0, 35) then move = move + right end
            if IsDisabledControlPressed(0, 34) then move = move - right end
            if IsDisabledControlPressed(0, 22) then move = move + vec3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, 36) then move = move - vec3(0.0, 0.0, 1.0) end
            p = p + move * speed
            SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, true, true, true)
            SetEntityHeading(ent, rot.z)
            Wait(0)
        end
        lib.hideTextUI()
        FreezeEntityPosition(ent, false)
        SetEntityCollision(ent, true, true)
        applyVisibility()
        applyGodmode()
    end)
end

local function setNoclip(on)
    if on and not grant('noclip') then return end
    if not on then act('power', nil, { power = 'noclip', on = false }) end
    powers.noclip = on
    applyVisibility()
    applyGodmode()
    if on then noclipLoop() end
end

local function namesLoop()
    CreateThread(function()
        while powers.names do
            local me = GetEntityCoords(PlayerPedId())
            for _, pid in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(pid)
                local c = GetEntityCoords(ped)
                if pid ~= PlayerId() and #(me - c) < 60.0 then
                    local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.1)
                    if onScreen then
                        SetTextFont(4) SetTextScale(0.0, 0.32) SetTextCentre(true) SetTextOutline()
                        SetTextColour(40, 224, 255, 230)
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName(('[%d] %s'):format(GetPlayerServerId(pid), GetPlayerName(pid)))
                        EndTextCommandDisplayText(x, y)
                    end
                end
            end
            Wait(0)
        end
    end)
end

local function setAnimal(model)
    if model and not grant('animal', { model = model }) then return end
    if not model then
        act('power', nil, { power = 'animal', on = false })
        animal = nil
        Bridge:RestoreAppearance()
        return
    end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return notify(false, 'Modèle absent de ce build du jeu.') end
    lib.requestModel(hash, 10000)
    SetPlayerModel(PlayerId(), hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(hash)
    animal = model
    applyVisibility()
    applyGodmode()
end

local function groundZ(x, y)
    for z = 1000.0, 0.0, -25.0 do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
        local found, gz = GetGroundZFor_3dCoord(x, y, z, false)
        if found then return gz end
    end
end

local function teleportToMarker()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return notify(false, 'Pose d\'abord un marqueur sur la carte.') end
    if not grant('tpm') then return end
    local c = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(ent, true)
    SetEntityCoordsNoOffset(ent, c.x, c.y, 500.0, false, false, false)
    local z = groundZ(c.x, c.y)
    SetEntityCoordsNoOffset(ent, c.x, c.y, (z or 100.0) + 1.0, false, false, false)
    FreezeEntityPosition(ent, false)
    DoScreenFadeIn(250)
    notify(true, z and 'Téléporté.' or 'Téléporté (sol introuvable, attention à la chute).')
end

-- Spectate ----------------------------------------------------------------------------------------------------

local function stopSpectate()
    if not spectating then return end
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    local back = spectating.back
    spectating = nil
    SetEntityCoordsNoOffset(ped, back.x, back.y, back.z, false, false, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    applyVisibility()
    lib.hideTextUI()
end

RegisterNetEvent('gs_admin:client:spectate', function(target, coords)
    if spectating then stopSpectate() end
    local ped = PlayerPedId()
    spectating = { target = target, back = GetEntityCoords(ped) }
    applyVisibility()
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z - 15.0, false, false, false) -- sous la cible, le temps qu'elle charge
    local deadline = GetGameTimer() + 6000
    local player = GetPlayerFromServerId(target)
    while (player == -1 or not DoesEntityExist(GetPlayerPed(player))) and GetGameTimer() < deadline do
        Wait(100)
        player = GetPlayerFromServerId(target)
    end
    if player == -1 then stopSpectate() return notify(false, 'Joueur introuvable (trop loin ?).') end
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    lib.showTextUI(('SPECTATE [%d]  ·  [Retour] arrêter'):format(target), { position = 'top-center' })
    CreateThread(function()
        while spectating do
            if IsControlJustPressed(0, 194) then stopSpectate() break end
            local p = GetPlayerFromServerId(spectating.target)
            if p == -1 then stopSpectate() notify(false, 'Le joueur est parti.') break end
            local tc = GetEntityCoords(GetPlayerPed(p))
            SetEntityCoordsNoOffset(PlayerPedId(), tc.x, tc.y, tc.z - 15.0, false, false, false) -- suit la cible (streaming)
            Wait(0)
        end
    end)
end)

--- Coupe tout (fin du mode staff, arrêt de la ressource).
local function powersOff()
    powers.noclip, powers.invisible, powers.godmode, powers.names = false, false, false, false
    stopSpectate()
    if animal then animal = nil Bridge:RestoreAppearance() end
    applyVisibility()
    applyGodmode()
end
RegisterNetEvent('gs_admin:client:powersOff', powersOff)

-- Menus ---------------------------------------------------------------------------------------------------------

local openQuick

local function input(title, fields)
    local r = lib.inputDialog(title, fields)
    return r
end

local function nearestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local c = GetEntityCoords(ped)
    local best, bestD = 0, Config.Vehicle.maxDeleteDistance
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - c)
        if d < bestD then best, bestD = v, d end
    end
    return best
end

local function vehicleType(hash)
    if IsThisModelABike(hash) or IsThisModelABicycle(hash) or IsThisModelAQuadbike(hash) then return 'bike' end
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABoat(hash) or IsThisModelAJetski(hash) then return 'boat' end
    return 'automobile'
end

local function playerMenu(p)
    local lvl = info.level
    local options, actions = {}, {}
    local function add(label, icon, minLvl, fn)
        if lvl >= minLvl then options[#options + 1] = { label = label, icon = icon } actions[#options] = fn end
    end
    add('Aller à lui', 'location-arrow', 1, function() notify(act('goto', p.id)) end)
    add('L\'amener à moi', 'hand', 2, function() notify(act('bring', p.id)) end)
    add('Spectate', 'eye', 2, function() local ok, msg = act('spectate', p.id) if not ok then notify(false, msg) end end)
    add('Soigner', 'heart', 2, function() notify(act('heal', p.id)) end)
    add('Réanimer', 'heart-pulse', 2, function() notify(act('revive', p.id)) end)
    add('Figer / libérer', 'snowflake', 2, function() notify(act('freeze', p.id)) end)
    add('Lui mettre un métier', 'briefcase', 3, function() openQuick('jobs', p) end)
    add('Le mettre dans un gang', 'people-group', 3, function() openQuick('gangs', p) end)
    add('Items (fondateur)', 'box-open', 4, function() openQuick('items', p) end)
    lib.registerMenu({ id = 'gs_staff_player', title = ('[%d] %s'):format(p.id, p.name), position = 'top-right',
        options = options, onClose = function() openQuick('players') end },
        function(i) if actions[i] then actions[i]() end end)
    lib.showMenu('gs_staff_player')
end

local function jobsMenu(target)
    local options = {}
    for _, j in ipairs(info.jobs) do
        local labels = {}
        for _, g in ipairs(j.grades) do labels[#labels + 1] = ('%d · %s'):format(g.grade, g.label) end
        options[#options + 1] = { label = j.label, values = labels, args = j, description = 'Gauche/droite : grade · Entrée : valider' }
    end
    if #options == 0 then options[1] = { label = 'Aucun métier' } end
    lib.registerMenu({ id = 'gs_staff_jobs', title = 'Métier · ' .. target.name, position = 'top-right', options = options,
        onClose = function() openQuick('main') end },
        function(_, scroll, j)
            if not j then return end
            notify(act('setjob', target.id, { job = j.name, grade = j.grades[scroll or 1].grade }))
        end)
    lib.showMenu('gs_staff_jobs')
end

local function gangsMenu(target)
    local options = { { label = 'Retirer de son gang', args = { name = 'none' } } }
    for _, g in ipairs(info.gangs) do
        options[#options + 1] = { label = g.label, values = { '0 · Recrue', '1 · Membre', '2 · Bras droit', '3 · Chef' }, args = g }
    end
    lib.registerMenu({ id = 'gs_staff_gangs', title = 'Gang · ' .. target.name, position = 'top-right', options = options,
        onClose = function() openQuick('main') end },
        function(_, scroll, g)
            if not g then return end
            notify(act('setgang', target.id, { gang = g.name, grade = (scroll or 1) - 1 }))
        end)
    lib.showMenu('gs_staff_gangs')
end

local function itemsMenu(target)
    local list = lib.callback.await('gs_admin:items', false)
    if not list then return notify(false, 'Réservé au fondateur.') end
    local choices = {}
    for _, it in ipairs(list) do choices[#choices + 1] = { value = it.name, label = ('%s (%s)'):format(it.label, it.name) } end
    local function ask(title)
        local r = input(title, {
            { type = 'select', label = 'Item', options = choices, searchable = true, required = true },
            { type = 'number', label = 'Quantité', default = 1, min = 1, max = Config.Give.maxItems, required = true },
        })
        return r and r[1], r and r[2]
    end
    local options = {
        { label = 'Donner à ' .. target.name, icon = 'plus' },
        { label = 'Retirer à ' .. target.name, icon = 'minus' },
        { label = 'Poser au sol, ici', icon = 'box' },
    }
    lib.registerMenu({ id = 'gs_staff_items', title = 'Items (fondateur)', position = 'top-right', options = options,
        onClose = function() openQuick('main') end },
        function(i)
            local item, count = ask(options[i].label)
            if not item then return end
            if i == 1 then notify(act('giveitem', target.id, { item = item, amount = count }))
            elseif i == 2 then notify(act('removeitem', target.id, { item = item, amount = count }))
            else notify(act('dropitem', nil, { item = item, amount = count })) end
        end)
    lib.showMenu('gs_staff_items')
end

local function playersMenu()
    local options = {}
    for _, p in ipairs(info.players) do options[#options + 1] = { label = ('[%d] %s'):format(p.id, p.name), args = p } end
    if #options == 0 then options[1] = { label = 'Aucun joueur' } end
    lib.registerMenu({ id = 'gs_staff_players', title = ('Joueurs (%d)'):format(#info.players), position = 'top-right',
        options = options, onClose = function() openQuick('main') end },
        function(_, _, p) if p then playerMenu(p) end end)
    lib.showMenu('gs_staff_players')
end

local function mainMenu()
    local lvl = info.level
    local me = { id = info.me, name = 'moi' }
    local options, actions = {}, {}
    local function add(opt, minLvl, fn)
        if lvl >= minLvl then options[#options + 1] = opt actions[#options] = fn end
    end
    local function toggle(label, icon, key, minLvl, fn)
        add({ label = label, icon = icon, checked = powers[key] }, minLvl, fn)
    end

    add({ label = 'Mode staff', icon = 'shield-halved', checked = info.onDuty,
        description = 'Tickets + pouvoirs. Tout se coupe en le désactivant.' }, 1, function(checked)
        local state = lib.callback.await('gs_admin:toggleDuty', false)
        if state == nil then return end
        info.onDuty = state
        notify(true, state and 'Mode staff : ON' or 'Mode staff : OFF')
        if not state then powersOff() end
    end)
    if info.onDuty then
        add({ label = 'Joueurs', icon = 'users', description = 'Aller à, amener, spectate, soigner, métier…' }, 1, function() playersMenu() end)
        toggle('Noms et ID des joueurs', 'id-badge', 'names', Config.Powers.names, function(on)
            if on and not grant('names') then return end
            powers.names = on
            if on then namesLoop() end
        end)
        toggle('Vol libre', 'feather', 'noclip', Config.Powers.noclip, function(on) setNoclip(on) end)
        toggle('Invisible', 'ghost', 'invisible', Config.Powers.invisible, function(on)
            if on and not grant('invisible') then return end
            if not on then act('power', nil, { power = 'invisible', on = false }) end
            powers.invisible = on
            applyVisibility()
        end)
        toggle('Invincible', 'shield', 'godmode', Config.Powers.godmode, function(on)
            if on and not grant('godmode') then return end
            if not on then act('power', nil, { power = 'godmode', on = false }) end
            powers.godmode = on
            applyGodmode()
        end)
        add({ label = 'Téléportation au marqueur', icon = 'map-pin' }, Config.Powers.tpm, teleportToMarker)
        local animals = { 'Forme humaine' }
        for _, a in ipairs(Config.Animals) do animals[#animals + 1] = a.label end
        add({ label = 'Se transformer', icon = 'paw', values = animals, defaultIndex = 1,
            description = 'Gauche/droite : choisir · Entrée : appliquer' }, Config.Powers.animal, function(_, scroll)
            if not scroll or scroll == 1 then setAnimal(nil) else setAnimal(Config.Animals[scroll - 1].model) end
        end)
        add({ label = 'Me soigner', icon = 'heart' }, 2, function() notify(act('revive', info.me)) end)
        add({ label = 'Réparer mon véhicule', icon = 'wrench' }, 2, function() notify(act('fixveh', info.me)) end)
        add({ label = 'Faire apparaître un véhicule', icon = 'car' }, 3, function()
            local r = input('Véhicule', { { type = 'input', label = 'Modèle (ex : sultan, faggio, buzzard)', required = true } })
            if not r then return end
            local model = r[1]:gsub('%s', ''):lower()
            local hash = GetHashKey(model)
            if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return notify(false, 'Modèle inconnu : ' .. model) end
            notify(act('spawnveh', nil, { model = model, vtype = vehicleType(hash) }))
        end)
        add({ label = 'Supprimer le véhicule proche', icon = 'trash' }, 2, function()
            local veh = nearestVehicle()
            if veh == 0 or not NetworkGetEntityIsNetworked(veh) then return notify(false, 'Aucun véhicule proche.') end
            notify(act('delveh', nil, { netId = VehToNet(veh) }))
        end)
        add({ label = 'Me mettre un métier', icon = 'briefcase' }, 3, function() jobsMenu(me) end)
        add({ label = 'Me mettre dans un gang', icon = 'people-group' }, 3, function() gangsMenu(me) end)
        add({ label = 'Items (fondateur)', icon = 'box-open' }, 4, function() itemsMenu(me) end)
        add({ label = 'Copier mes coordonnées', icon = 'crosshairs', description = 'vec4 dans le presse-papiers (calage des configs)' }, 1, function()
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            lib.setClipboard(('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped)))
            notify(true, 'Coordonnées copiées.')
        end)
    end
    add({ label = 'Panel complet (F10)', icon = 'table-columns' }, 1, function() ExecuteCommand('admin') end)

    lib.registerMenu({
        id = 'gs_staff_quick', title = ('Staff · %s'):format(info.levelName or ''), position = 'top-right', options = options,
        onCheck = function(i, checked) if actions[i] then actions[i](checked) openQuick('main') end end,
    }, function(i, scroll) if actions[i] then actions[i](nil, scroll) end end)
    lib.showMenu('gs_staff_quick')
end

--- Ouvre un menu (données rafraîchies depuis le serveur).
function openQuick(which, target)
    info = lib.callback.await('gs_admin:quick', false)
    if not info then return notify(false, 'Accès réservé au staff.') end
    if which == 'players' then return playersMenu() end
    if which == 'jobs' then return jobsMenu(target) end
    if which == 'gangs' then return gangsMenu(target) end
    if which == 'items' then return itemsMenu(target) end
    mainMenu()
end

RegisterCommand('staffmenu', function() openQuick('main') end, false)
RegisterKeyMapping('staffmenu', 'Menu staff rapide', 'keyboard', Config.QuickKey)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then powersOff() end
end)
