-- gs_admin (client) : menu staff rapide (F11, cliquable à la souris). Chaque pouvoir est d'abord accordé par le serveur
-- (niveau + mode staff + journal), puis appliqué ici. Couper le mode staff coupe tous les pouvoirs.
local Bridge = exports.gs_bridge
local powers = { noclip = false, invisible = false, godmode = false, names = false }
local animal = nil          -- modèle animal actif
local spectating = nil      -- { target, back = vec3 }
local info = nil            -- dernier retour de gs_admin:quick

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function act(name, target, data)
    local ok, msg = lib.callback.await('gs_admin:action', false, name, target, data)
    -- Action refusée car le mode staff est coupé : on l'active (journalisé côté serveur) et on réessaie une fois.
    if not ok and type(msg) == 'string' and msg:find('mode staff', 1, true) and lib.callback.await('gs_admin:toggleDuty', false) then
        lib.notify({ description = 'Mode staff activé', type = 'inform' })
        ok, msg = lib.callback.await('gs_admin:action', false, name, target, data)
    end
    return ok, msg
end

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

--- Noms et ID (modération / spectate) : [ID] nom, vie, « parle » en rouge quand il parle, jusqu'à 150 m.
--- La liste des joueurs proches est recalculée toutes les 500 ms ; l'affichage seul tourne à chaque image.
local function namesLoop()
    CreateThread(function()
        local near, nextScan = {}, 0
        while powers.names do
            local now = GetGameTimer()
            local me = GetFinalRenderedCamCoord()
            if now > nextScan then
                nextScan, near = now + 500, {}
                for _, pid in ipairs(GetActivePlayers()) do
                    local ped = GetPlayerPed(pid)
                    if pid ~= PlayerId() and #(me - GetEntityCoords(ped)) < 150.0 then
                        near[#near + 1] = { pid = pid, ped = ped, label = ('[%d] %s'):format(GetPlayerServerId(pid), GetPlayerName(pid)) }
                    end
                end
            end
            -- par frame : seulement tant que « Noms et ID » est actif (mode staff)
            for _, n in ipairs(near) do
                local c = GetEntityCoords(n.ped)
                local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.1)
                if onScreen then
                    local talking = NetworkIsPlayerTalking(n.pid)
                    local hp = math.max(0, GetEntityHealth(n.ped) - 100)
                    SetTextFont(4) SetTextScale(0.0, 0.34) SetTextCentre(true) SetTextOutline()
                    if talking then SetTextColour(255, 80, 110, 240) else SetTextColour(40, 224, 255, 230) end
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(('%s  ·  %d PV%s'):format(n.label, hp, talking and '  ·  parle' or ''))
                    EndTextCommandDisplayText(x, y)
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
    if not animal then Bridge:SaveAppearance() end -- pour retrouver exactement son perso ensuite
    lib.requestModel(hash, 10000)
    SetPlayerModel(PlayerId(), hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(hash)
    animal = model
    applyVisibility()
    applyGodmode()
end

--- Sol sous (x, y) : on attend que la collision du coin soit chargée (jusqu'à ~3 s), sinon nil.
--- (Avant : un seul passage sans attendre → sol pas encore chargé → arrivée dans le ciel.)
local function groundZ(ent, x, y)
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        for h = 1000.0, -50.0, -50.0 do
            RequestCollisionAtCoord(x, y, h)
            local found, gz = GetGroundZFor_3dCoord(x, y, h, false)
            if found then
                SetEntityCoordsNoOffset(ent, x, y, gz + 2.0, false, false, false)
                RequestCollisionAtCoord(x, y, gz)
                local t = GetGameTimer() + 1000
                while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < t do Wait(0) end
                local again, gz2 = GetGroundZFor_3dCoord(x, y, gz + 2.0, false)
                return again and gz2 or gz
            end
        end
        Wait(100)
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
    SetEntityCoordsNoOffset(ent, c.x, c.y, 800.0, false, false, false)
    local z = groundZ(ent, c.x, c.y)
    if z then
        SetEntityCoordsNoOffset(ent, c.x, c.y, z + 0.5, false, false, false)
    else
        -- Sol introuvable : téléport du jeu, qui cherche lui-même la terre ferme
        FreezeEntityPosition(ent, false)
        StartPlayerTeleport(PlayerId(), c.x, c.y, 100.0, GetEntityHeading(ent), veh ~= 0, true, false)
        local t = GetGameTimer() + 8000
        while IsPlayerTeleportActive() and GetGameTimer() < t do Wait(0) end
    end
    FreezeEntityPosition(ent, false)
    DoScreenFadeIn(250)
    notify(true, 'Téléporté.')
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
    if not powers.names then powers.names = true namesLoop() end -- noms et ID visibles pendant le spectate
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

-- Section Fun (staff et événements) : effets sur soi uniquement ----------------------------------------------------
local FUN = {
    { id = 'fastrun', label = 'Course rapide', icon = 'person-running' },
    { id = 'superjump', label = 'Super saut', icon = 'arrow-up' },
    { id = 'stamina', label = 'Endurance infinie', icon = 'battery-full' },
    { id = 'fastswim', label = 'Nage rapide', icon = 'person-swimming' },
    { id = 'lowgravity', label = 'Gravité lunaire', icon = 'moon' },
    { id = 'nightvision', label = 'Vision nocturne', icon = 'eye' },
    { id = 'thermal', label = 'Vision thermique', icon = 'temperature-high' },
}
local fun = {}

local function applyFun()
    local pid = PlayerId()
    SetRunSprintMultiplierForPlayer(pid, fun.fastrun and 1.49 or 1.0)
    SetSwimMultiplierForPlayer(pid, fun.fastswim and 1.49 or 1.0)
    SetGravityLevel(fun.lowgravity and 1 or 0)
    SetNightvision(fun.nightvision == true)
    SetSeethrough(fun.thermal == true)
end

local funLoopOn = false
local function funLoop()
    if funLoopOn then return end
    funLoopOn = true
    CreateThread(function()
        -- par frame : seulement tant que super saut ou endurance infinie sont actifs (mode staff)
        while fun.superjump or fun.stamina do
            if fun.superjump then SetSuperJumpThisFrame(PlayerId()) end
            if fun.stamina then RestorePlayerStamina(PlayerId(), 1.0) end
            Wait(0)
        end
        funLoopOn = false
    end)
end

local function setFun(id, on)
    if on and not grant(id) then return end
    if not on then act('power', nil, { power = id, on = false }) end
    fun[id] = on or nil
    applyFun()
    if fun.superjump or fun.stamina then funLoop() end
end

--- Coupe tout (fin du mode staff, arrêt de la ressource).
local function powersOff()
    powers.noclip, powers.invisible, powers.godmode, powers.names = false, false, false, false
    fun = {}
    applyFun()
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

-- Véhicules importés (IMPORTER-MODS) + véhicules de service ajoutés : retrouvés sans connaître leur nom de spawn.
local function addonVehiclesMenu()
    local list = lib.callback.await('gs_admin:addonVehicles', false)
    if not list then return end
    local options = {}
    for _, v in ipairs(list) do
        local hash = GetHashKey(v.model)
        local here = IsModelInCdimage(hash)
        options[#options + 1] = { title = v.name, icon = here and 'car' or 'triangle-exclamation', disabled = not here,
            description = ('spawn : %s%s%s'):format(v.model, v.price and (' · %d $'):format(v.price) or '', here and '' or ' · mod non installé'),
            onSelect = function() notify(act('spawnveh', nil, { model = v.model, vtype = vehicleType(hash) })) end }
    end
    local installed = 0
    for _, o in ipairs(options) do if not o.disabled then installed = installed + 1 end end
    if installed == 0 then
        table.insert(options, 1, { title = 'Aucun mod de véhicule installé sur ce serveur', icon = 'circle-info', disabled = true,
            description = 'Mets les fichiers du Drive (dossier GTA) dans C:\\GTASOON\\mods-a-trier puis lance IMPORTER-MODS.bat' })
    end
    lib.registerContext({ id = 'gs_staff_addonveh', title = 'Véhicules ajoutés (' .. #list .. ')', menu = 'gs_staff_quick', options = options })
    lib.showContext('gs_staff_addonveh')
end

-- Menus cliquables (souris) : chaque option porte sa propre action, aucune correspondance par position.
local ON, OFF = '#5aff8c', '#6b6380'

local function show(id, title, options, parent)
    lib.registerContext({ id = id, title = title, menu = parent, options = options })
    lib.showContext(id)
end

local function gradeMenu(parent, title, grades, apply)
    local options = {}
    for _, g in ipairs(grades) do
        options[#options + 1] = { title = g.label, icon = 'user-tie', onSelect = function() apply(g.grade) end }
    end
    show('gs_staff_grade', title, options, parent)
end

local function jobsMenu(target)
    local options = {}
    for _, j in ipairs(info.jobs) do
        options[#options + 1] = { title = j.label, icon = 'briefcase', arrow = true, onSelect = function()
            gradeMenu('gs_staff_jobs', j.label .. ' · grade', j.grades, function(grade)
                notify(act('setjob', target.id, { job = j.name, grade = grade }))
            end)
        end }
    end
    if #options == 0 then options[1] = { title = 'Aucun métier', readOnly = true } end
    show('gs_staff_jobs', 'Métier · ' .. target.name, options, 'gs_staff_quick')
end

local GANG_GRADES = { { grade = 0, label = 'Recrue' }, { grade = 1, label = 'Membre' }, { grade = 2, label = 'Bras droit' }, { grade = 3, label = 'Chef' } }

local function gangsMenu(target)
    local options = { { title = 'Retirer de son gang', icon = 'user-minus', iconColor = '#ff2e88', onSelect = function()
        notify(act('setgang', target.id, { gang = 'none' }))
    end } }
    for _, g in ipairs(info.gangs) do
        options[#options + 1] = { title = g.label, icon = 'people-group', arrow = true, onSelect = function()
            gradeMenu('gs_staff_gangs', g.label .. ' · grade', GANG_GRADES, function(grade)
                notify(act('setgang', target.id, { gang = g.name, grade = grade }))
            end)
        end }
    end
    if #info.gangs == 0 then options[#options + 1] = { title = 'Aucun gang en base (redémarre : gangs par défaut créés)', readOnly = true } end
    show('gs_staff_gangs', 'Gang · ' .. target.name, options, 'gs_staff_quick')
end

local function itemsMenu(target)
    local list = lib.callback.await('gs_admin:items', false)
    if not list then return notify(false, 'Réservé au super-admin et au fondateur.') end
    local founder = info.level >= 5
    local choices = {}
    for _, it in ipairs(list) do choices[#choices + 1] = { value = it.name, label = ('%s (%s)'):format(it.label, it.name) } end
    local function ask(title)
        local fields = {
            { type = 'select', label = 'Item', options = choices, searchable = true, required = true },
            { type = 'number', label = 'Quantité', default = 1, min = 1, max = Config.Give.maxItems, required = true },
        }
        -- super-admin : motif obligatoire (journal + webhook) ; le fondateur seul s'en passe
        if not founder then fields[3] = { type = 'input', label = 'Motif (journalisé)', required = true, max = 200 } end
        local r = input(title, fields)
        return r and r[1], r and r[2], r and r[3]
    end
    local options = {
        { title = 'Donner à ' .. target.name, icon = 'plus', onSelect = function()
            local item, count, reason = ask('Donner')
            if item then notify(act('giveitem', target.id, { item = item, amount = count, reason = reason })) end
        end },
    }
    if not founder then return show('gs_staff_items', 'Items (super-admin)', options, 'gs_staff_quick') end
    show('gs_staff_items', 'Items (fondateur)', {
        options[1],
        { title = 'Retirer à ' .. target.name, icon = 'minus', onSelect = function()
            local item, count = ask('Retirer')
            if item then notify(act('removeitem', target.id, { item = item, amount = count })) end
        end },
        { title = 'Poser au sol, ici', icon = 'box', onSelect = function()
            local item, count = ask('Poser au sol')
            if item then notify(act('dropitem', nil, { item = item, amount = count })) end
        end },
    }, 'gs_staff_quick')
end

local function moneyMenu(target)
    local function ask(give)
        local r = input(give and 'Donner de l\'argent' or 'Retirer de l\'argent', {
            { type = 'select', label = 'Compte', required = true, default = 'cash', options = { { value = 'cash', label = 'Liquide' }, { value = 'bank', label = 'Banque' } } },
            { type = 'number', label = 'Montant', min = 1, max = Config.Give.maxMoney, required = true },
            { type = 'input', label = 'Motif (journalisé)', required = true, max = 200 },
        })
        if r then notify(act(give and 'givemoney' or 'removemoney', target.id, { account = r[1], amount = r[2], reason = r[3] })) end
    end
    show('gs_staff_money', 'Argent · ' .. target.name, {
        { title = 'Donner', icon = 'plus', onSelect = function() ask(true) end },
        { title = 'Retirer', icon = 'minus', onSelect = function() ask(false) end },
    }, 'gs_staff_player')
end

local function pointsMenu()
    local options = {}
    for _, j in ipairs(info.jobs) do
        if #(j.points or {}) > 0 then
            options[#options + 1] = { title = j.label, icon = 'briefcase', arrow = true, onSelect = function()
                local pts = {}
                for _, pt in ipairs(j.points) do
                    pts[#pts + 1] = { title = pt.label, icon = 'location-crosshairs',
                        description = pt.kind == 'garage_spawn' and 'Place-toi (ou ton véhicule) là où les véhicules doivent sortir'
                            or 'Déplacé exactement à ta position',
                        onSelect = function() notify(act('jobpoint', nil, { job = j.name, kind = pt.kind, idx = pt.idx })) end }
                end
                show('gs_staff_points_job', j.label, pts, 'gs_staff_points')
            end }
        end
    end
    show('gs_staff_points', 'Points de métier (placer ici)', options, 'gs_staff_quick')
end

local GANG_COLORS = {
    { value = 1, label = 'Rouge' }, { value = 3, label = 'Bleu' }, { value = 25, label = 'Vert' }, { value = 27, label = 'Violet' },
    { value = 46, label = 'Jaune' }, { value = 47, label = 'Orange' }, { value = 40, label = 'Gris' }, { value = 48, label = 'Rose' },
}
local PAINTS = {
    { value = 0, label = 'Noir' }, { value = 27, label = 'Rouge' }, { value = 53, label = 'Vert' }, { value = 70, label = 'Bleu' },
    { value = 88, label = 'Jaune' }, { value = 145, label = 'Violet' }, { value = 135, label = 'Rose' }, { value = 111, label = 'Blanc' },
}

local function gangAdminMenu()
    local function pickGang(title, cb2)
        local opts = {}
        for _, g in ipairs(info.gangs) do opts[#opts + 1] = { value = g.name, label = g.label } end
        if #opts == 0 then return notify(false, 'Aucun gang.') end
        local r = input(title, { { type = 'select', label = 'Gang', options = opts, required = true } })
        if r then cb2(r[1]) end
    end
    show('gs_staff_gangadmin', 'Gangs (création, QG, garage)', {
        { title = 'Créer un gang', icon = 'plus', description = 'Identifiant, nom affiché, couleur', onSelect = function()
            local r = input('Nouveau gang', {
                { type = 'input', label = 'Identifiant (ex : aztecas)', required = true, max = 30 },
                { type = 'input', label = 'Nom affiché (ex : Varrios Los Aztecas)', required = true, max = 50 },
                { type = 'select', label = 'Couleur', options = GANG_COLORS, required = true },
            })
            if r then notify(act('creategang', nil, { name = r[1], label = r[2], color = r[3] })) end
        end },
        { title = 'Placer la planque / QG ici', icon = 'house-flag', onSelect = function()
            pickGang('Planque', function(gang) notify(act('gangplace', nil, { gang = gang, kind = 'stash' })) end)
        end },
        { title = 'Placer le garage ici', icon = 'warehouse', description = 'Place-toi (ou ton véhicule) à la sortie', onSelect = function()
            local opts = {}
            for _, g in ipairs(info.gangs) do opts[#opts + 1] = { value = g.name, label = g.label } end
            local r = input('Garage', { { type = 'select', label = 'Gang', options = opts, required = true },
                { type = 'select', label = 'Couleur des véhicules', options = PAINTS, required = true } })
            if r then notify(act('gangplace', nil, { gang = r[1], kind = 'garage', paint = r[2] })) end
        end },
    }, 'gs_staff_quick')
end

local function animalsMenu()
    local options = {}
    if animal then options[1] = { title = 'Reprendre forme humaine', icon = 'person', iconColor = ON, onSelect = function() setAnimal(nil) end } end
    for _, a in ipairs(Config.Animals) do
        options[#options + 1] = { title = a.label, icon = 'paw', iconColor = animal == a.model and ON or nil,
            onSelect = function() setAnimal(a.model) end }
    end
    show('gs_staff_animals', 'Animaux', options, 'gs_staff_me')
end

local function pedsMenu()
    local options = {}
    if animal then options[1] = { title = 'Reprendre mon perso', icon = 'person', iconColor = ON, onSelect = function() setAnimal(nil) end } end
    for _, a in ipairs(Config.Peds) do
        options[#options + 1] = { title = a.label, icon = 'user-secret', iconColor = animal == a.model and ON or nil,
            onSelect = function() setAnimal(a.model) end }
    end
    show('gs_staff_peds', 'Persos GTA (peds)', options, 'gs_staff_me')
end

--- Rang staff d'un joueur (fondateur seulement ; le serveur revérifie).
local function rankMenu(p)
    local options = { { title = 'Joueur (retirer du staff)', icon = 'user', iconColor = '#ff2e88', onSelect = function()
        notify(act('setrank', p.id, { rank = 0 }))
    end } }
    for r = 1, 4 do
        options[#options + 1] = { title = info.ranks[r], icon = 'user-shield', onSelect = function()
            if lib.alertDialog({ header = ('%s → %s'):format(p.name, info.ranks[r]), content = 'Effet immédiat, enregistré en base.', centered = true, cancel = true }) == 'confirm' then
                notify(act('setrank', p.id, { rank = r }))
            end
        end }
    end
    show('gs_staff_rank', 'Rang staff · ' .. p.name, options, 'gs_staff_player')
end

local function funMenu()
    local options = {}
    for _, f in ipairs(FUN) do
        if info.level >= (Config.Powers[f.id] or 99) then
            local on = fun[f.id] == true
            options[#options + 1] = { title = ('%s : %s'):format(f.label, on and 'ON' or 'OFF'), icon = f.icon, iconColor = on and ON or OFF,
                onSelect = function() setFun(f.id, not on) funMenu() end }
        end
    end
    options[#options + 1] = { title = 'Tout couper', icon = 'power-off', onSelect = function()
        for id in pairs(fun) do act('power', nil, { power = id, on = false }) end
        fun = {}
        applyFun()
        funMenu()
    end }
    show('gs_staff_fun', 'Effets sur moi', options, 'gs_staff_events')
end

local function eventsMenu()
    local options = {}
    for id, ev in pairs(Config.Events) do
        options[#options + 1] = { title = ev.label, icon = ev.icon, description = ('%d min · centré sur toi%s'):format(ev.minutes, ev.radius > 0 and (' · %d m'):format(math.floor(ev.radius)) or ''),
            onSelect = function()
                if lib.alertDialog({ header = ev.label, content = ev.text .. '\n\nTout le monde reçoit l\'annonce et le GPS vers ta position.', centered = true, cancel = true }) == 'confirm' then
                    notify(act('event', nil, { kind = id }))
                end
            end }
    end
    table.sort(options, function(a, b) return a.title < b.title end)
    -- Bonus de serveur (gs_events) : même menu, plus de catégorie en double
    for _, b in ipairs({ { 'double_xp', 'Soirée double XP (bonus serveur)', 'star' }, { 'lucky', 'Soirée chanceuse (bonus serveur)', 'clover' } }) do
        options[#options + 1] = { title = b[2], icon = b[3], description = 'Pour tout le serveur, durée au choix', onSelect = function()
            local r = input(b[2], { { type = 'number', label = 'Durée (minutes)', default = 60, min = 5, max = 240, required = true } })
            if r then ExecuteCommand(('gsevent start %s %d'):format(b[1], r[1])) end
        end }
    end
    options[#options + 1] = { title = 'Arrêter le bonus serveur en cours', icon = 'stop', onSelect = function() ExecuteCommand('gsevent stop') end }
    options[#options + 1] = { title = 'Effets sur moi (animation d\'événement)', icon = 'wand-magic-sparkles', arrow = true,
        description = 'Course rapide, super saut, gravité lunaire…', onSelect = funMenu }
    show('gs_staff_events', 'Événements', options, 'gs_staff_quick')
end

local function playerMenu(p)
    local lvl = info.level
    local options = {}
    local function add(minLvl, opt) if lvl >= minLvl then options[#options + 1] = opt end end
    add(1, { title = 'Aller à lui', icon = 'location-arrow', onSelect = function() notify(act('goto', p.id)) end })
    add(2, { title = 'L\'amener à moi', icon = 'hand', onSelect = function() notify(act('bring', p.id)) end })
    add(2, { title = 'Spectate', icon = 'eye', onSelect = function() local ok, msg = act('spectate', p.id) if not ok then notify(false, msg) end end })
    add(2, { title = 'Soigner', icon = 'heart', onSelect = function() notify(act('heal', p.id)) end })
    add(2, { title = 'Réanimer', icon = 'heart-pulse', onSelect = function() notify(act('revive', p.id)) end })
    add(2, { title = 'Figer / libérer', icon = 'snowflake', onSelect = function() notify(act('freeze', p.id)) end })
    add(3, { title = 'Lui mettre un métier', icon = 'briefcase', arrow = true, onSelect = function() jobsMenu(p) end })
    add(3, { title = 'Le mettre dans un gang', icon = 'people-group', arrow = true, onSelect = function() gangsMenu(p) end })
    add(4, { title = 'Argent', icon = 'money-bill', arrow = true, onSelect = function() moneyMenu(p) end })
    add(4, { title = 'Items', icon = 'box-open', arrow = true, onSelect = function() itemsMenu(p) end })
    if info.ranks and p.id ~= info.me then
        add(5, { title = 'Rang staff (fondateur)', icon = 'user-shield', arrow = true, onSelect = function() rankMenu(p) end })
    end
    show('gs_staff_player', ('[%d] %s'):format(p.id, p.name), options, 'gs_staff_players')
end

local function playersMenu()
    local options = {}
    for _, p in ipairs(info.players) do
        options[#options + 1] = { title = ('[%d] %s'):format(p.id, p.name), icon = 'user', arrow = true, onSelect = function() playerMenu(p) end }
    end
    if #options == 0 then options[1] = { title = 'Aucun joueur', readOnly = true } end
    show('gs_staff_players', ('Joueurs (%d)'):format(#info.players), options, 'gs_staff_quick')
end

local function mainMenu()
    local lvl = info.level
    local options = {}
    local function add(minLvl, opt) if lvl >= minLvl then options[#options + 1] = opt end end
    --- Interrupteur : état affiché dans le titre et la couleur, menu rouvert après le changement.
    local function toggle(list, menuFn, minLvl, label, icon, on, fn)
        if lvl < minLvl then return end
        list[#list + 1] = { title = ('%s : %s'):format(label, on and 'ON' or 'OFF'), icon = icon, iconColor = on and ON or OFF,
            onSelect = function() fn(not on) menuFn() end }
    end

    -- Moi : pouvoirs, déplacements, apparence
    local function meMenu()
        local o = {}
        local function a(minLvl, opt) if lvl >= minLvl then o[#o + 1] = opt end end
        toggle(o, meMenu, Config.Powers.names, 'Noms et ID des joueurs', 'id-badge', powers.names, function(on)
            if on and not grant('names') then return end
            powers.names = on
            if on then namesLoop() end
        end)
        toggle(o, meMenu, Config.Powers.noclip, 'Vol libre', 'feather', powers.noclip, function(on) setNoclip(on) end)
        toggle(o, meMenu, Config.Powers.invisible, 'Invisible', 'ghost', powers.invisible, function(on)
            if on and not grant('invisible') then return end
            if not on then act('power', nil, { power = 'invisible', on = false }) end
            powers.invisible = on
            applyVisibility()
        end)
        toggle(o, meMenu, Config.Powers.godmode, 'Invincible', 'shield', powers.godmode, function(on)
            if on and not grant('godmode') then return end
            if not on then act('power', nil, { power = 'godmode', on = false }) end
            powers.godmode = on
            applyGodmode()
        end)
        a(Config.Powers.tpm, { title = 'Téléportation au marqueur', icon = 'map-pin', description = 'Pose d\'abord un point sur la carte (ou Ctrl + Y)', onSelect = teleportToMarker })
        a(2, { title = 'Me soigner et réanimer', icon = 'heart', onSelect = function() notify(act('revive', info.me)) end })
        a(Config.Powers.animal, { title = 'Persos GTA (peds)', icon = 'user-secret', arrow = true, onSelect = pedsMenu })
        a(Config.Powers.animal, { title = 'Animaux', icon = 'paw', arrow = true, onSelect = animalsMenu })
        if animal then a(1, { title = 'Reprendre mon perso', icon = 'person', iconColor = ON, onSelect = function() setAnimal(nil) meMenu() end }) end
        a(3, { title = 'Me mettre un métier', icon = 'briefcase', arrow = true, onSelect = function() jobsMenu({ id = info.me, name = 'moi' }) end })
        a(3, { title = 'Me mettre dans un gang', icon = 'people-group', arrow = true, onSelect = function() gangsMenu({ id = info.me, name = 'moi' }) end })
        a(4, { title = 'Argent', icon = 'money-bill', arrow = true, onSelect = function() moneyMenu({ id = info.me, name = 'moi' }) end })
        a(4, { title = 'Items', icon = 'box-open', arrow = true, onSelect = function() itemsMenu({ id = info.me, name = 'moi' }) end })
        show('gs_staff_me', 'Moi', o, 'gs_staff_quick')
    end

    local function vehMenu()
        local o = {}
        local function a(minLvl, opt) if lvl >= minLvl then o[#o + 1] = opt end end
        a(3, { title = 'Faire apparaître un véhicule', icon = 'car', onSelect = function()
            local r = input('Véhicule', { { type = 'input', label = 'Modèle (ex : sultan, faggio, buzzard)', required = true } })
            if not r then return end
            local model = r[1]:gsub('%s', ''):lower()
            local hash = GetHashKey(model)
            if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return notify(false, 'Modèle inconnu : ' .. model) end
            notify(act('spawnveh', nil, { model = model, vtype = vehicleType(hash) }))
        end })
        a(3, { title = 'Véhicules ajoutés (mods)', icon = 'car-side', arrow = true, description = 'Nom, prix, spawn en un clic', onSelect = addonVehiclesMenu })
        a(2, { title = 'Réparer mon véhicule', icon = 'wrench', onSelect = function() notify(act('fixveh', info.me)) end })
        a(2, { title = 'Supprimer le véhicule proche', icon = 'trash', onSelect = function()
            local veh = nearestVehicle()
            if veh == 0 or not NetworkGetEntityIsNetworked(veh) then return notify(false, 'Aucun véhicule proche.') end
            notify(act('delveh', nil, { netId = VehToNet(veh) }))
        end })
        show('gs_staff_veh', 'Véhicules', o, 'gs_staff_quick')
    end

    local function worldMenu()
        local o = {}
        local function a(minLvl, opt) if lvl >= minLvl then o[#o + 1] = opt end end
        a(3, { title = 'Lieux publics (boutique, parking)', icon = 'shop', arrow = true, description = 'Poser une boutique de vêtements ou un parking ici',
            onSelect = function()
                local function place(kind, prompt)
                    local r = input(prompt, { { type = 'input', label = 'Nom affiché', required = true, max = 40 } })
                    if r then notify(lib.callback.await('gs_places:create', false, kind, r[1])) end
                end
                show('gs_staff_places', 'Lieux publics', {
                    { title = 'Boutique de vêtements ici', icon = 'shirt', description = 'Point « Essayer des vêtements » + blip, à ta position',
                      onSelect = function() place('clothing', 'Boutique de vêtements') end },
                    { title = 'Parking public ici (au volant)', icon = 'square-parking', description = 'Les voitures sortiront à cet endroit',
                      onSelect = function() place('parking', 'Parking public') end },
                    { title = 'Retirer le lieu le plus proche', icon = 'trash', onSelect = function() notify(lib.callback.await('gs_places:delete', false)) end },
                }, 'gs_staff_world')
            end })
        a(3, { title = 'Déplacer un point (métiers, récolte, magasins…)', icon = 'location-crosshairs', arrow = true,
            description = 'Point mal placé ? Mets-toi au bon endroit et choisis-le', onSelect = function() TriggerEvent('gs_bridge:client:pointsMenu') end })
        a(3, { title = 'Points de métier (placer ici)', icon = 'briefcase', arrow = true,
            description = 'Service, coffre, armurerie, direction, garage', onSelect = pointsMenu })
        a(3, { title = 'Gangs (création, QG, garage)', icon = 'people-group', arrow = true, onSelect = gangAdminMenu })
        a(4, { title = 'Objets du décor (placer / retirer)', icon = 'cube', description = 'Bancs, poubelles, barrières… (/builder)', onSelect = function() ExecuteCommand('builder') end })
        a(1, { title = 'Copier mes coordonnées', icon = 'crosshairs', description = 'vec4 dans le presse-papiers', onSelect = function()
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            lib.setClipboard(('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped)))
            notify(true, 'Coordonnées copiées.')
        end })
        show('gs_staff_world', 'Monde et lieux', o, 'gs_staff_quick')
    end

    toggle(options, mainMenu, 1, 'Mode staff', 'shield-halved', info.onDuty, function()
        local state = lib.callback.await('gs_admin:toggleDuty', false)
        if state == nil then return end
        notify(true, state and 'Mode staff : ON' or 'Mode staff : OFF')
        if not state then powersOff() end
        info.onDuty = state
    end)
    if info.onDuty then
        add(1, { title = 'Joueurs', icon = 'users', arrow = true, description = 'Aller à, amener, spectate, soigner, argent…', onSelect = playersMenu })
        add(1, { title = 'Moi', icon = 'user-gear', arrow = true, description = 'Vol libre, invisible, TP, peds et animaux…', onSelect = meMenu })
        add(2, { title = 'Véhicules', icon = 'car', arrow = true, description = 'Faire apparaître, mods, réparer, supprimer', onSelect = vehMenu })
        add(1, { title = 'Monde et lieux', icon = 'map-location-dot', arrow = true, description = 'Lieux publics, points, gangs, décor', onSelect = worldMenu })
        add(3, { title = 'Événements', icon = 'champagne-glasses', arrow = true, description = 'Événements en un clic, bonus serveur, effets', onSelect = eventsMenu })
    end
    add(1, { title = 'Panel complet (F10)', icon = 'table-columns', onSelect = function() ExecuteCommand('admin') end })
    show('gs_staff_quick', ('Staff · %s'):format(info.levelName or ''), options)
end

-- Déplacer un point (toutes ressources) : les 25 points les plus proches (200 m), du plus proche au plus loin.
AddEventHandler('gs_bridge:client:pointsMenu', function()
    local list = exports.gs_bridge:NearbyPoints(GetEntityCoords(PlayerPedId()), 200.0)
    local options = {}
    for i = 1, math.min(#list, 25) do
        local p = list[i]
        options[#options + 1] = { title = p.label, icon = p.moved and 'location-dot' or 'location-crosshairs', iconColor = p.moved and ON or nil,
            description = ('%s · à %d m%s'):format(p.res, math.floor(p.dist), p.moved and ' · déjà déplacé' or ''), arrow = true,
            onSelect = function()
                show('gs_staff_point', p.label, {
                    { title = 'Placer ce point ici (ma position)', icon = 'location-crosshairs', onSelect = function()
                        if lib.alertDialog({ header = p.label, content = 'Le point est posé à tes pieds, orienté comme toi.\n\n' .. p.res
                            .. ' est relancé quelques secondes (les joueurs en train de l\'utiliser devront recommencer).', centered = true, cancel = true }) == 'confirm' then
                            notify(act('movepoint', nil, { key = p.key }))
                        end
                    end },
                    { title = 'Remettre la position d\'origine', icon = 'rotate-left', disabled = not p.moved,
                        onSelect = function() notify(act('resetpoint', nil, { key = p.key })) end },
                }, 'gs_staff_points_all')
            end }
    end
    if #options == 0 then options[1] = { title = 'Aucun point déplaçable à moins de 200 m', readOnly = true } end
    show('gs_staff_points_all', 'Déplacer un point', options, 'gs_staff_world')
end)

--- Ouvre le menu principal (données rafraîchies depuis le serveur).
function openQuick()
    info = lib.callback.await('gs_admin:quick', false)
    if not info then return notify(false, 'Accès réservé au staff.') end
    mainMenu()
end

-- Nom neuf en V7 : la touche par défaut (F11) s'applique à tous, même à ceux qui avaient l'ancienne (Suppr)
RegisterCommand('gs_staffmenu_v7', function() openQuick('main') end, false)
RegisterKeyMapping('gs_staffmenu_v7', 'Menu staff rapide', 'keyboard', Config.QuickKey)

-- Raccourcis du mode staff : Ctrl gauche maintenu + touche (le serveur vérifie niveau et mode staff).
local function ctrlHeld() return IsControlPressed(0, 36) or IsDisabledControlPressed(0, 36) end
local SHORTCUTS = {
    tpm = { label = 'Staff : TP au marqueur (Ctrl +)', run = teleportToMarker },
    noclip = { label = 'Staff : vol libre (Ctrl +)', run = function() setNoclip(not powers.noclip) end },
    names = { label = 'Staff : noms et ID (Ctrl +)', run = function()
        if not powers.names and not grant('names') then return end
        powers.names = not powers.names
        if powers.names then namesLoop() end
    end },
}
for id, sc in pairs(SHORTCUTS) do
    RegisterCommand('staff_' .. id, function() if ctrlHeld() then sc.run() end end, false)
    RegisterKeyMapping('staff_' .. id, sc.label, 'keyboard', Config.Shortcuts[id])
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then powersOff() end
end)
