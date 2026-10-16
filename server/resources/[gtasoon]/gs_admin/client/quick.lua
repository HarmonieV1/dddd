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

--- Téléportation au sol en (x, y). `zHint` (intérieur d'une map, sous-sol) : on cherche d'abord le sol à cette hauteur,
--- sinon on arriverait sur le toit du bâtiment ; à défaut, sol le plus haut comme pour le marqueur.
local function teleportTo(x, y, zHint)
    if not grant('tpm') then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(ent, true)
    local z
    if zHint then
        SetEntityCoordsNoOffset(ent, x, y, zHint + 1.0, false, false, false)
        local t = GetGameTimer() + 2500
        repeat RequestCollisionAtCoord(x, y, zHint) Wait(0) until HasCollisionLoadedAroundEntity(ent) or GetGameTimer() > t
        local found, gz = GetGroundZFor_3dCoord(x, y, zHint + 3.0, false)
        if found and math.abs(gz - zHint) < 15.0 then z = gz end
    end
    if not z then
        SetEntityCoordsNoOffset(ent, x, y, 800.0, false, false, false)
        z = groundZ(ent, x, y)
    end
    if z then
        SetEntityCoordsNoOffset(ent, x, y, z + 0.5, false, false, false)
    else
        -- Sol introuvable : téléport du jeu, qui cherche lui-même la terre ferme
        FreezeEntityPosition(ent, false)
        StartPlayerTeleport(PlayerId(), x, y, 100.0, GetEntityHeading(ent), veh ~= 0, true, false)
        local t = GetGameTimer() + 8000
        while IsPlayerTeleportActive() and GetGameTimer() < t do Wait(0) end
    end
    FreezeEntityPosition(ent, false)
    DoScreenFadeIn(250)
    notify(true, 'Téléporté.')
end

local function teleportToMarker()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return notify(false, 'Pose d\'abord un marqueur sur la carte.') end
    local c = GetBlipInfoIdCoord(blip)
    teleportTo(c.x, c.y)
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
    -- V12.59 : délires « sur moi » (demande du backtest), seulement sur MON perso / MA voiture
    { id = 'carspeed', label = 'Super vitesse (voiture conduite)', icon = 'gauge-high' },
    { id = 'carjump', label = 'Voiture sauteuse (Espace en conduisant)', icon = 'car-side' },
    { id = 'rainbow', label = 'Voiture arc-en-ciel', icon = 'palette' },
    { id = 'drunk', label = 'Caméra ivre', icon = 'wine-glass' },
    -- V12.63 (2e série) : sur la voiture que je conduis
    { id = 'carshield', label = 'Voiture indestructible (conduite)', icon = 'shield' },
    { id = 'tyresmoke', label = 'Fumée de pneus arc-en-ciel (conduite)', icon = 'smog' },
}
local fun = {}

-- V12.62 (relecture) : on ne touche à un réglage du jeu que quand SON effet change (avant : chaque bascule remettait tout à zéro,
-- ce qui coupait par exemple l'ivresse d'un vrai verre (gs_economy) ou la vitesse d'une voiture modifiée ailleurs)
local applied = {}
local function changed(id) local now = fun[id] == true if applied[id] == now then return false end applied[id] = now return true end
local function applyFun()
    local pid = PlayerId()
    if changed('fastrun') then SetRunSprintMultiplierForPlayer(pid, fun.fastrun and 1.49 or 1.0) end
    if changed('fastswim') then SetSwimMultiplierForPlayer(pid, fun.fastswim and 1.49 or 1.0) end
    if changed('lowgravity') then SetGravityLevel(fun.lowgravity and 1 or 0) end
    if changed('nightvision') then SetNightvision(fun.nightvision == true) end
    if changed('thermal') then SetSeethrough(fun.thermal == true) end
    if changed('drunk') then if fun.drunk then ShakeGameplayCam('DRUNK_SHAKE', 1.0) else StopGameplayCamShaking(true) end end -- V12.59
    if changed('carspeed') and not fun.carspeed and cache.vehicle then ModifyVehicleTopSpeed(cache.vehicle, 0.0) end -- V12.59 : vitesse d'origine
end
for _, id in ipairs({ 'fastrun', 'fastswim', 'lowgravity', 'nightvision', 'thermal', 'drunk', 'carspeed' }) do applied[id] = false end

local funLoopOn = false
local function looping() return fun.superjump or fun.stamina or fun.carspeed or fun.carjump or fun.rainbow or fun.carshield or fun.tyresmoke end
local function funLoop()
    if funLoopOn then return end
    funLoopOn = true
    CreateThread(function()
        local hue, boosted, nextColor = 0, nil, 0
        local shielded, nextSmoke = nil, 0
        local SMOKE = { { 255, 46, 154 }, { 176, 72, 255 }, { 79, 216, 255 }, { 90, 255, 140 }, { 255, 210, 63 } }
        -- par frame : seulement tant qu'un effet « sur moi » à entretenir est actif (mode staff)
        while looping() do
            local pid = PlayerId()
            if fun.superjump then SetSuperJumpThisFrame(pid) end
            if fun.stamina then RestorePlayerStamina(pid, 1.0) end
            local veh = cache.vehicle
            if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then -- V12.59 : seulement la voiture que JE conduis
                if fun.carspeed then
                    if boosted ~= veh then ModifyVehicleTopSpeed(veh, 60.0) boosted = veh end
                    SetVehicleCheatPowerIncrease(veh, 4.0)
                end
                if fun.carjump and IsControlJustPressed(0, 22) and IsVehicleOnAllWheels(veh) then
                    ApplyForceToEntity(veh, 1, 0.0, 0.0, 9.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                end
                if fun.carshield and shielded ~= veh then -- V12.63 : indestructible tant que l'effet est actif
                    shielded = veh
                    SetEntityInvincible(veh, true) SetVehicleCanBeVisiblyDamaged(veh, false) SetVehicleTyresCanBurst(veh, false)
                end
                if fun.tyresmoke and GetGameTimer() >= nextSmoke then -- V12.63 : fumée de pneus qui change de couleur
                    nextSmoke = GetGameTimer() + 400
                    ToggleVehicleMod(veh, 20, true)
                    local c = SMOKE[(math.floor(GetGameTimer() / 400) % #SMOKE) + 1]
                    SetVehicleTyreSmokeColor(veh, c[1], c[2], c[3])
                end
                if fun.rainbow and GetGameTimer() >= nextColor then
                    nextColor = GetGameTimer() + 80
                    hue = (hue + 4) % 360
                    local h, r, g, b = hue / 60, 0, 0, 0
                    local x = math.floor(255 * (1 - math.abs(h % 2 - 1)))
                    if h < 1 then r, g = 255, x elseif h < 2 then r, g = x, 255 elseif h < 3 then g, b = 255, x
                    elseif h < 4 then g, b = x, 255 elseif h < 5 then r, b = x, 255 else r, b = 255, x end
                    SetVehicleCustomPrimaryColour(veh, r, g, b) SetVehicleCustomSecondaryColour(veh, r, g, b)
                end
            end
            if shielded and (not fun.carshield or shielded ~= veh) then
                if DoesEntityExist(shielded) then SetEntityInvincible(shielded, false) SetVehicleCanBeVisiblyDamaged(shielded, true) SetVehicleTyresCanBurst(shielded, true) end
                shielded = nil
            end
            if boosted and (not fun.carspeed or boosted ~= veh) then
                if DoesEntityExist(boosted) then ModifyVehicleTopSpeed(boosted, 0.0) end
                boosted = nil
            end
            Wait(0)
        end
        if boosted and DoesEntityExist(boosted) then ModifyVehicleTopSpeed(boosted, 0.0) end
        if shielded and DoesEntityExist(shielded) then SetEntityInvincible(shielded, false) SetVehicleCanBeVisiblyDamaged(shielded, true) SetVehicleTyresCanBurst(shielded, true) end
        funLoopOn = false
    end)
end

local function setFun(id, on)
    if on and not grant(id) then return end
    if not on then act('power', nil, { power = id, on = false }) end
    fun[id] = on or nil
    applyFun()
    if looping() then funLoop() end
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

-- V12.10 · blips des mappings (staff, locaux, le temps d'un tour de la carte)
local mapBlips = {}
local function clearMapBlips()
    for _, b in ipairs(mapBlips) do RemoveBlip(b) end
    mapBlips = {}
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

-- V11.5 · Items par catégorie, avec l'image de chaque objet (celle de l'inventaire) : plus besoin de connaître les noms.
local ITEM_CATEGORIES = {
    { id = 'weapons', label = 'Armes', icon = 'gun', match = function(it) return it.name:find('^WEAPON_') ~= nil end },
    { id = 'ammo', label = 'Munitions', icon = 'bullseye', match = function(it) return it.name:find('^ammo%-') ~= nil end },
    { id = 'attach', label = 'Accessoires d\'armes', icon = 'crosshairs', match = function(it) return it.name:find('^at_') ~= nil end },
    { id = 'food', label = 'Nourriture et boissons', icon = 'utensils', match = function(it) return it.food == true end },
    { id = 'cards', label = 'Cartes et permis', icon = 'id-card', match = function(it) return it.name:find('license') or it.name:find('id_card') or it.name:find('pass$') end },
    { id = 'roadline', label = 'Objets RoadLine', icon = 'star', match = function(it) return it.name:find('^gs_') ~= nil end },
    { id = 'other', label = 'Autres objets', icon = 'box', match = function() return true end },
}
local function itemImage(it)
    local file = it.image or (it.name .. '.png')
    return 'nui://ox_inventory/web/images/' .. file
end

local function itemsMenu(target)
    local list = lib.callback.await('gs_admin:items', false)
    if not list then return notify(false, 'Réservé au super-admin et au fondateur.') end
    local founder = info.level >= 5
    local choices = {}
    for _, it in ipairs(list) do choices[#choices + 1] = { value = it.name, label = ('%s (%s)'):format(it.label, it.name) } end
    --- Quantité (et motif pour un super-admin) → r[1] quantité, r[2] motif
    local function askCount(title, it)
        local fields = { { type = 'number', label = 'Quantité', default = 1, min = 1, max = Config.Give.maxItems, required = true } }
        -- super-admin : motif obligatoire (journal + webhook) ; le fondateur seul s'en passe
        if not founder then fields[2] = { type = 'input', label = 'Motif (journalisé)', required = true, max = 200 } end
        local r = input(('%s · %s'):format(title, it.label), fields)
        return r and r[1], r and r[2]
    end
    --- Recherche libre (ancien fonctionnement) → item, quantité, motif
    local function askSearch(title)
        local fields = {
            { type = 'select', label = 'Item', options = choices, searchable = true, required = true },
            { type = 'number', label = 'Quantité', default = 1, min = 1, max = Config.Give.maxItems, required = true },
        }
        if not founder then fields[3] = { type = 'input', label = 'Motif (journalisé)', required = true, max = 200 } end
        local r = input(title, fields)
        return r and r[1], r and r[2], r and r[3]
    end
    local ACTIONS = {
        give = { title = 'Donner à ' .. target.name, icon = 'plus', action = 'giveitem', target = target.id },
        remove = { title = 'Retirer à ' .. target.name, icon = 'minus', action = 'removeitem', target = target.id },
        drop = { title = 'Poser au sol, ici', icon = 'box', action = 'dropitem' },
    }
    local function run(a, item, count, reason)
        notify(act(a.action, a.target, { item = item, amount = count, reason = reason }))
    end
    local function categoryMenu(a, cat)
        local o = {}
        for _, it in ipairs(list) do
            if cat.match(it) and not it._taken then
                o[#o + 1] = { title = it.label, description = it.name, image = itemImage(it), onSelect = function()
                    local count, reason = askCount(a.title, it)
                    if count then run(a, it.name, count, reason) end
                end }
            end
        end
        if #o == 0 then o[1] = { title = 'Rien dans cette catégorie', readOnly = true } end
        show('gs_staff_items_cat', ('%s · %s'):format(a.title, cat.label), o, 'gs_staff_items_' .. a.action)
    end
    local function actionMenu(a)
        -- chaque item va dans la 1re catégorie qui le reconnaît (le compte sert d'aperçu)
        for _, it in ipairs(list) do it._taken = nil end
        local o = { { title = 'Rechercher (nom)', icon = 'magnifying-glass', description = 'Taper un nom, comme avant', onSelect = function()
            local item, count, reason = askSearch(a.title)
            if item then run(a, item, count, reason) end
        end } }
        for _, cat in ipairs(ITEM_CATEGORIES) do
            local n = 0
            for _, it in ipairs(list) do if not it._taken and cat.match(it) then it._taken = true n = n + 1 end end
            if n > 0 then
                o[#o + 1] = { title = cat.label, icon = cat.icon, arrow = true, description = ('%d objet(s)'):format(n), onSelect = function()
                    for _, it in ipairs(list) do it._taken = nil end
                    for _, c in ipairs(ITEM_CATEGORIES) do
                        if c == cat then break end
                        for _, it in ipairs(list) do if not it._taken and c.match(it) then it._taken = true end end
                    end
                    categoryMenu(a, cat)
                end }
            end
        end
        show('gs_staff_items_' .. a.action, a.title, o, 'gs_staff_items')
    end
    local options = { { title = ACTIONS.give.title, icon = ACTIONS.give.icon, arrow = true, onSelect = function() actionMenu(ACTIONS.give) end } }
    if not founder then return show('gs_staff_items', 'Items (super-admin)', options, 'gs_staff_quick') end
    show('gs_staff_items', 'Items (fondateur)', {
        options[1],
        { title = ACTIONS.remove.title, icon = ACTIONS.remove.icon, arrow = true, onSelect = function() actionMenu(ACTIONS.remove) end },
        { title = ACTIONS.drop.title, icon = ACTIONS.drop.icon, arrow = true, onSelect = function() actionMenu(ACTIONS.drop) end },
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

-- V12.37 · Placement libre (aperçu + réglages au clavier : export Place de gs_markers) et PNJ / objets posés par le staff -------
local PLACE_HELP = table.concat({
    '[Flèches / pavé 8 5 4 6] déplacer de 10 cm  ·  [PgUp/PgDn] hauteur 5 cm',
    '[Q/E] tourner de 5°  ·  [Maj] pas × 5  ·  [Tab] viser à la souris',
    '[G] au sol  ·  [F] coller au mur / plafond visé',
    '[Entrée] valider  ·  [Retour] annuler',
}, '  \n')

--- Aperçu + réglages ; retourne la pose { x, y, z, heading } ou nil (annulé, ou impossible : déjà notifié).
local function freePlace(opts)
    lib.showTextUI(PLACE_HELP, { position = 'right-center' })
    local pose, err = exports.gs_markers:Place(opts)
    lib.hideTextUI()
    if not pose and err then notify(false, err) end
    return pose
end

-- Modèles de PNJ du jeu par catégorie (noms exacts de GTA V) ; n'importe quel autre modèle reste possible en le tapant.
local PED_MODELS = {
    { label = 'Civils', icon = 'user', items = {
        { model = 'a_m_y_business_01', label = 'Homme d\'affaires' }, { model = 'a_f_y_business_02', label = 'Femme d\'affaires' },
        { model = 'a_m_m_business_01', label = 'Cadre (âge mûr)' }, { model = 'a_f_m_business_02', label = 'Cadre (femme)' },
        { model = 'a_f_y_business_04', label = 'Secrétaire' }, { model = 'a_m_y_hipster_01', label = 'Hipster' }, { model = 'a_f_y_hipster_01', label = 'Hipster (femme)' },
        { model = 'a_m_y_beach_01', label = 'Plagiste' }, { model = 'a_f_y_tourist_01', label = 'Touriste' }, { model = 'a_m_y_skater_01', label = 'Skateur' },
        { model = 'a_m_m_farmer_01', label = 'Fermier' }, { model = 'a_m_y_golfer_01', label = 'Golfeur' }, { model = 'a_f_y_fitness_01', label = 'Sportive' },
        { model = 'a_m_y_runner_01', label = 'Joggeur' }, { model = 'a_m_o_genstreet_01', label = 'Homme âgé' }, { model = 'a_f_o_genstreet_01', label = 'Femme âgée' },
        { model = 'a_m_m_eastsa_02', label = 'Habitant (quartier est)' }, { model = 'a_f_y_soucent_01', label = 'Habitante (sud)' }, { model = 'a_m_m_tramp_01', label = 'Sans-abri' },
    } },
    { label = 'Police et sécurité', icon = 'shield-halved', items = {
        { model = 's_m_y_cop_01', label = 'Policier' }, { model = 's_f_y_cop_01', label = 'Policière' }, { model = 's_m_y_sheriff_01', label = 'Shérif' },
        { model = 's_f_y_sheriff_01', label = 'Shérif (femme)' }, { model = 's_m_y_hwaycop_01', label = 'Motard de la route' }, { model = 's_m_y_swat_01', label = 'SWAT' },
        { model = 's_m_m_fiboffice_01', label = 'Agent FIB' }, { model = 's_m_m_security_01', label = 'Agent de sécurité' }, { model = 's_m_m_highsec_01', label = 'Agent de sécurité (costume)' },
        { model = 's_m_m_prisguard_01', label = 'Gardien de prison' }, { model = 's_m_y_ranger_01', label = 'Garde forestier' }, { model = 's_f_y_ranger_01', label = 'Garde forestière' },
        { model = 's_m_m_bouncer_01', label = 'Videur' },
    } },
    { label = 'Médical et secours', icon = 'briefcase-medical', items = {
        { model = 's_m_m_paramedic_01', label = 'Ambulancier' }, { model = 's_m_m_doctor_01', label = 'Médecin' }, { model = 's_f_y_scrubs_01', label = 'Infirmière' },
        { model = 's_m_y_fireman_01', label = 'Pompier' }, { model = 's_m_m_lifeguard_01', label = 'Maître-nageur' }, { model = 's_f_y_baywatch_01', label = 'Sauveteuse' },
    } },
    { label = 'Mécanos et ouvriers', icon = 'wrench', items = {
        { model = 's_m_m_autoshop_01', label = 'Mécano (patron)' }, { model = 's_m_m_autoshop_02', label = 'Mécano' }, { model = 's_m_y_xmech_01', label = 'Mécano (jeune)' },
        { model = 's_m_y_xmech_02', label = 'Mécano (tatoué)' }, { model = 's_m_y_construct_01', label = 'Ouvrier' }, { model = 's_m_y_construct_02', label = 'Ouvrier (casque)' },
        { model = 's_m_m_trucker_01', label = 'Routier' }, { model = 's_m_y_garbage', label = 'Éboueur' }, { model = 's_m_m_gardener_01', label = 'Jardinier' },
        { model = 's_m_m_dockwork_01', label = 'Docker' }, { model = 's_m_m_postal_01', label = 'Facteur' }, { model = 's_m_m_gentransport', label = 'Chauffeur de bus' },
        { model = 's_m_m_pilot_01', label = 'Pilote' }, { model = 's_m_y_valet_01', label = 'Voiturier' },
    } },
    { label = 'Vendeurs et accueil', icon = 'store', items = {
        { model = 'mp_m_shopkeep_01', label = 'Commerçant' }, { model = 's_f_y_shop_low', label = 'Vendeuse' }, { model = 's_f_y_shop_mid', label = 'Vendeuse (prêt-à-porter)' },
        { model = 's_f_m_shop_high', label = 'Vendeuse (boutique chic)' }, { model = 's_m_y_shop_mask', label = 'Vendeur (station)' }, { model = 's_m_y_ammucity_01', label = 'Armurier' },
        { model = 's_m_m_ammucountry', label = 'Armurier (campagne)' }, { model = 'u_m_m_bankman', label = 'Banquier' }, { model = 's_m_m_strvend_01', label = 'Vendeur de rue' },
        { model = 's_m_y_barman_01', label = 'Barman' }, { model = 's_f_y_bartender_01', label = 'Barmaid' }, { model = 's_m_y_waiter_01', label = 'Serveur' },
        { model = 's_m_y_chef_01', label = 'Chef cuisinier' }, { model = 's_m_m_linecook', label = 'Cuisinier' }, { model = 's_f_y_casino_01', label = 'Croupière' },
        { model = 's_m_y_casino_01', label = 'Croupier' },
    } },
    { label = 'Gangs et rue', icon = 'people-group', items = {
        { model = 'g_m_y_ballasout_01', label = 'Ballas' }, { model = 'g_m_y_ballaorig_01', label = 'Ballas (original)' }, { model = 'g_f_y_ballas_01', label = 'Ballas (femme)' },
        { model = 'g_m_y_famca_01', label = 'Families' }, { model = 'g_m_y_famdnf_01', label = 'Families (Forum)' }, { model = 'g_f_y_families_01', label = 'Families (femme)' },
        { model = 'g_m_y_mexgoon_01', label = 'Vagos' }, { model = 'g_f_y_vagos_01', label = 'Vagos (femme)' }, { model = 'g_m_y_lost_01', label = 'Lost MC' },
        { model = 'g_f_y_lost_01', label = 'Lost MC (femme)' }, { model = 'g_m_m_armboss_01', label = 'Chef arménien' }, { model = 'g_m_m_chigoon_01', label = 'Triade' },
        { model = 'g_m_y_korean_01', label = 'Kkangpae' }, { model = 'g_m_y_salvagoon_01', label = 'Marabunta' }, { model = 'g_m_y_pologoon_01', label = 'Mafia polonaise' },
        { model = 'a_m_y_stbla_01', label = 'Jeune de la rue' },
    } },
}

-- Scénarios d'attente (noms exacts du jeu) ; nil = debout, immobile.
local SCENARIOS = {
    { value = 'WORLD_HUMAN_CLIPBOARD', label = 'Bloc-notes (accueil)' }, { value = 'WORLD_HUMAN_STAND_IMPATIENT', label = 'Attente impatiente' },
    { value = 'WORLD_HUMAN_GUARD_STAND', label = 'Garde debout' }, { value = 'WORLD_HUMAN_COP_IDLES', label = 'Policier en faction' },
    { value = 'WORLD_HUMAN_SECURITY_SHINE_TORCH', label = 'Vigile à la lampe' }, { value = 'WORLD_HUMAN_SMOKING', label = 'Fume une cigarette' },
    { value = 'WORLD_HUMAN_LEANING', label = 'Adossé au mur' }, { value = 'WORLD_HUMAN_STAND_MOBILE', label = 'Au téléphone' },
    { value = 'WORLD_HUMAN_AA_COFFEE', label = 'Boit un café' }, { value = 'WORLD_HUMAN_DRINKING', label = 'Boit une canette' },
    { value = 'WORLD_HUMAN_HANG_OUT_STREET', label = 'Traîne dans la rue' }, { value = 'WORLD_HUMAN_WELDING', label = 'Soude' },
    { value = 'WORLD_HUMAN_HAMMERING', label = 'Martèle' }, { value = 'WORLD_HUMAN_JANITOR', label = 'Balaie' },
    { value = 'WORLD_HUMAN_MAID_CLEAN', label = 'Nettoie' }, { value = 'WORLD_HUMAN_GARDENER_PLANT', label = 'Jardine' },
    { value = 'WORLD_HUMAN_MUSICIAN', label = 'Musicien' }, { value = 'WORLD_HUMAN_TOURIST_MAP', label = 'Lit un plan' },
    { value = 'WORLD_HUMAN_BINOCULARS', label = 'Jumelles' }, { value = 'WORLD_HUMAN_SUNBATHE', label = 'Bronze (allongé)' },
    { value = 'WORLD_HUMAN_YOGA', label = 'Yoga' }, { value = 'WORLD_HUMAN_SIT_UPS', label = 'Abdos' },
}

local STAFF_ROLES = { duty = 'Accueil', boss = 'Direction', garage = 'Garage' }

--- Cible lisible : 'job:police:duty' → « LSPD · Accueil », 'gang:ballas' → « Gang Ballas », 'libre' → « Décor libre ».
local function targetLabel(t)
    if not t or t == 'libre' then return 'Décor libre' end
    local job, kind, idx = t:match('^job:([%w_]+):(%a+)(%d*)$')
    if job then
        local label = job
        for _, j in ipairs(info.jobs or {}) do if j.name == job then label = j.label end end
        return ('%s · %s%s'):format(label, STAFF_ROLES[kind] or kind, idx ~= '' and (' ' .. idx) or '')
    end
    local gang = t:match('^gang:([%w_]+)$')
    if gang then
        for _, g in ipairs(info.gangs or {}) do if g.name == gang then return 'Gang ' .. g.label end end
        return 'Gang ' .. gang
    end
    return t
end

--- Choix de la cible : décor libre, un point de métier (accueil / direction / garage) ou un gang ; `cb(target)`.
local function pickTarget(title, cb)
    local o = {
        { title = 'Décor libre', icon = 'tree', description = 'Sans interaction : ambiance seulement', onSelect = function() cb('libre') end },
    }
    for _, j in ipairs(info.jobs or {}) do
        local roles = {}
        for _, pt in ipairs(j.points or {}) do
            if STAFF_ROLES[pt.kind] then
                roles[#roles + 1] = { title = pt.label, icon = 'briefcase', description = ('%s · le PNJ portera l\'interaction de ce point'):format(STAFF_ROLES[pt.kind]),
                    onSelect = function() cb(('job:%s:%s%s'):format(j.name, pt.kind, pt.idx > 1 and pt.idx or '')) end }
            end
        end
        if #roles > 0 then
            o[#o + 1] = { title = 'Métier · ' .. j.label, icon = 'briefcase', arrow = true, description = ('%d point(s) : accueil, direction, garage'):format(#roles),
                onSelect = function() show('gs_staff_sp_role', j.label .. ' · quel point ?', roles, 'gs_staff_sp_target') end }
        end
    end
    for _, g in ipairs(info.gangs or {}) do
        o[#o + 1] = { title = 'Gang · ' .. g.label, icon = 'people-group', description = 'Garde la planque : les membres lui parlent pour l\'ouvrir',
            onSelect = function() cb('gang:' .. g.name) end }
    end
    show('gs_staff_sp_target', title, o, 'gs_staff_sp')
end

--- Choix du modèle de PNJ (catégories, ou nom libre) ; `cb(model)`.
local function pickPedModel(cb)
    local cats = {}
    for i, c in ipairs(PED_MODELS) do
        cats[#cats + 1] = { title = c.label, icon = c.icon, arrow = true, description = ('%d modèles'):format(#c.items), onSelect = function()
            local items = {}
            for _, it in ipairs(c.items) do items[#items + 1] = { title = it.label, description = it.model, icon = 'user', onSelect = function() cb(it.model) end } end
            show('gs_staff_sp_pedcat_' .. i, c.label, items, 'gs_staff_sp_ped')
        end }
    end
    cats[#cats + 1] = { title = 'Autre modèle (nom)', icon = 'keyboard', description = 'ex : s_m_y_cop_01', onSelect = function()
        local r = input('Nom du modèle de PNJ', { { type = 'input', label = 'ex : s_m_y_cop_01', required = true, max = 64 } })
        if r then cb((r[1]:gsub('%s', ''))) end
    end }
    show('gs_staff_sp_ped', 'Quel PNJ ?', cats, 'gs_staff_sp')
end

--- Choix du scénario d'attente ; `cb(scenario | nil)`.
local function pickScenario(cb)
    local o = { { title = 'Aucun (debout, immobile)', icon = 'person', onSelect = function() cb(nil) end } }
    for _, s in ipairs(SCENARIOS) do
        o[#o + 1] = { title = s.label, description = s.value, icon = 'person-walking', onSelect = function() cb(s.value) end }
    end
    show('gs_staff_sp_scen', 'Que fait-il en attendant ?', o, 'gs_staff_sp')
end

local function addStaffPed()
    pickTarget('Nouveau PNJ : relié à quoi ?', function(target)
        pickPedModel(function(model)
            pickScenario(function(scenario)
                local pose = freePlace({ kind = 'ped', model = model, scenario = scenario })
                if pose then notify(act('addstaffped', nil, { kind = 'ped', target = target, model = model, scenario = scenario, pose = pose })) end
            end)
        end)
    end)
end

local function addStaffProp()
    local catalog = lib.callback.await('gs_admin:staffCatalog', false)
    if not catalog then return notify(false, 'Catalogue indisponible.') end
    pickTarget('Nouvel objet : relié à quoi ?', function(target)
        local function placeProp(model)
            local pose = freePlace({ kind = 'prop', model = model })
            if pose then notify(act('addstaffped', nil, { kind = 'prop', target = target, model = model, pose = pose })) end
        end
        local cats = {}
        for i, c in ipairs(catalog) do
            cats[#cats + 1] = { title = c.label, icon = c.icon or 'cube', arrow = true, description = ('%d objets'):format(#c.items), onSelect = function()
                local items = {}
                for _, it in ipairs(c.items) do items[#items + 1] = { title = it.label, description = it.model, icon = 'cube', onSelect = function() placeProp(it.model) end } end
                show('gs_staff_sp_cat_' .. i, c.label, items, 'gs_staff_sp_catalog')
            end }
        end
        cats[#cats + 1] = { title = 'Autre modèle (nom)', icon = 'keyboard', description = 'ex : prop_bench_01a', onSelect = function()
            local r = input('Nom du modèle', { { type = 'input', label = 'ex : prop_bench_01a', required = true, max = 64 } })
            if r then placeProp((r[1]:gsub('%s', ''))) end
        end }
        show('gs_staff_sp_catalog', 'Catalogue d\'objets', cats, 'gs_staff_sp')
    end)
end

local function confirmRemoveStaff(e)
    local what = e.kind == 'ped' and 'PNJ' or 'Objet'
    if lib.alertDialog({ header = ('Retirer %s #%d ?'):format(what, e.id), centered = true, cancel = true,
        content = ('%s · %s\n\nIl disparaît pour tout le monde ; le PNJ de la config, s\'il y en avait un, revient.'):format(e.model, targetLabel(e.target)) }) == 'confirm' then
        notify(act('delstaffped', nil, { id = e.id }))
    end
end

--- V12.63 · Déplacer / tourner une entrée (placement libre depuis sa position actuelle ; F = coller au mur)
local function moveStaff(e)
    local pose = freePlace({ kind = e.kind, model = e.model, scenario = e.scenario, x = e.x, y = e.y, z = e.z, heading = e.heading })
    if pose then notify(act('movestaffped', nil, { id = e.id, pose = pose })) end
end

local function staffEntryMenu(e, parent)
    show('gs_staff_sp_entry', ('%s #%d · %s'):format(e.kind == 'ped' and 'PNJ' or 'Objet', e.id, e.model), {
        { title = 'Déplacer / tourner', icon = 'arrows-up-down-left-right', description = 'Placement libre ; [F] le colle au mur visé', onSelect = function() moveStaff(e) end },
        { title = 'Retirer', icon = 'trash', iconColor = '#ff4d6d', onSelect = function() confirmRemoveStaff(e) end },
    }, parent)
end

local function aimedStaff()
    local hit, entity = lib.raycast.cam(8 | 16, 4, 30.0) -- [API] ox_lib : PNJ et objets
    local id = hit and entity ~= 0 and exports.gs_markers:StaffEntryOf(entity) or nil
    if not id then return nil end
    for _, e in ipairs(GlobalState.gsStaffPeds or {}) do if e.id == id then return e end end
end

local function removeAimedStaff()
    local hit, entity = lib.raycast.cam(8 | 16, 4, 30.0) -- [API] ox_lib : PNJ et objets
    local id = hit and entity ~= 0 and exports.gs_markers:StaffEntryOf(entity) or nil
    if not id then return notify(false, 'Vise un PNJ ou un objet posé par le staff.') end
    for _, e in ipairs(GlobalState.gsStaffPeds or {}) do
        if e.id == id then return confirmRemoveStaff(e) end
    end
    notify(false, 'Entrée introuvable (déjà retirée ?).')
end

local function staffPedsList()
    local me = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, e in ipairs(GlobalState.gsStaffPeds or {}) do list[#list + 1] = { e = e, dist = #(me - vec3(e.x, e.y, e.z)) } end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local _, claimed = exports.gs_markers:UnclaimedStaff()
    local o = {}
    for i = 1, math.min(#list, 30) do
        local e = list[i].e
        local state = e.kind ~= 'ped' and 'objet' or (claimed[e.id] and 'porte l\'interaction du point' or 'ambiance, sans interaction')
        o[#o + 1] = { title = ('%s #%d · %s'):format(e.kind == 'ped' and 'PNJ' or 'Objet', e.id, e.model), icon = e.kind == 'ped' and 'user' or 'cube', arrow = true,
            description = ('%s · %s · à %d m · par %s'):format(targetLabel(e.target), state, math.floor(list[i].dist), e.by or '?'),
            onSelect = function() staffEntryMenu(e, 'gs_staff_sp_list') end } -- V12.63 : déplacer ou retirer
    end
    if #o == 0 then o[1] = { title = 'Aucun PNJ ni objet posé par le staff', readOnly = true } end
    show('gs_staff_sp_list', ('PNJ et objets posés (%d) · déplacer ou retirer'):format(#list), o, 'gs_staff_sp')
end

local function staffPedsMenu()
    show('gs_staff_sp', 'PNJ et objets posés par le staff', {
        { title = 'Ajouter un PNJ', icon = 'user-plus', arrow = true, onSelect = addStaffPed,
          description = 'Relié à un métier (accueil, direction, garage), à un gang ou décor libre ; modèle, scénario, puis placement libre' },
        { title = 'Ajouter un objet', icon = 'cube', arrow = true, onSelect = addStaffProp,
          description = 'Catalogue (celui du Mapping) ou nom de modèle, relié à un métier / gang / libre, puis placement libre' },
        { title = 'Déplacer celui que je vise', icon = 'arrows-up-down-left-right', description = 'Vise un PNJ ou un objet posé par le staff ; [F] le colle au mur',
          onSelect = function() local e = aimedStaff() if e then moveStaff(e) else notify(false, 'Vise un PNJ ou un objet posé par le staff.') end end },
        { title = 'Retirer celui que je vise', icon = 'crosshairs', description = 'Vise un PNJ ou un objet posé par le staff', onSelect = removeAimedStaff },
        { title = 'Liste (les plus proches)', icon = 'list', arrow = true, onSelect = staffPedsList,
          description = ('%d posé(s) sur %d · retirer depuis la liste'):format(#(GlobalState.gsStaffPeds or {}), 200) },
    }, 'gs_staff_world')
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
    -- V12.59 : n'importe quel ped humain du jeu (~700) par son nom de modèle (liste : docs.fivem.net/docs/game-references/ped-models)
    options[#options + 1] = { title = 'Autre perso (nom du modèle)', icon = 'keyboard', description = 'Ex. a_m_y_hipster_02, s_f_y_cop_01, ig_josh',
        onSelect = function()
            local r = input('Autre perso GTA', { { type = 'input', label = 'Nom du modèle', required = true, max = 40 } })
            if r and r[1] then setAnimal((r[1]:gsub('%s', '')):lower()) end
        end }
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

-- V12.63 · Effets d'un instant (feux d'artifice, confettis, fumée) : particules réseau à ma position
local BURSTS = {
    { id = 'fireworks', label = 'Feux d\'artifice', icon = 'burst', asset = 'scr_indep_fireworks', fx = 'scr_indep_firework_starburst', n = 4, height = 18.0, scale = 1.6 },
    { id = 'confetti', label = 'Pluie de confettis', icon = 'champagne-glasses', asset = 'scr_xs_celebration', fx = 'scr_xs_confetti_burst', n = 2, height = 2.5, scale = 1.4 },
    { id = 'smoke', label = 'Apparition dans la fumée', icon = 'cloud', asset = 'scr_rcbarry2', fx = 'scr_clown_appears', n = 1, height = 0.0, scale = 1.2 },
    -- V12.63 (2e série)
    { id = 'teleportfx', label = 'Téléportation « alien »', icon = 'bolt', asset = 'scr_rcbarry1', fx = 'scr_alien_teleport', n = 1, height = 0.0, scale = 1.0 },
    { id = 'vanish', label = 'Désintégration (puis invisible 10 s)', icon = 'ghost', asset = 'scr_rcbarry1', fx = 'scr_alien_disintegrate', n = 1, height = 0.0, scale = 1.0, hide = 10000 },
    { id = 'boom', label = 'Souffle lumineux (sans dégâts)', icon = 'sun', asset = 'scr_trevor1', fx = 'scr_trev1_trailer_boosh', n = 1, height = 0.5, scale = 1.0 },
}
local function burst(f)
    if not lib.requestNamedPtfxAsset(f.asset, 3000) then return notify(false, 'Effet indisponible sur ce build du jeu.') end
    CreateThread(function()
        for i = 1, f.n do
            local c = GetEntityCoords(cache.ped)
            local dx, dy = (i == 1) and 0.0 or math.random(-6, 6) + 0.0, (i == 1) and 0.0 or math.random(-6, 6) + 0.0
            UseParticleFxAssetNextCall(f.asset)
            StartNetworkedParticleFxNonLoopedAtCoord(f.fx, c.x + dx, c.y + dy, c.z + f.height, 0.0, 0.0, 0.0, f.scale, false, false, false)
            Wait(450)
        end
        RemoveNamedPtfxAsset(f.asset)
        if f.hide then -- désintégration : invisible quelques secondes (réapparition automatique)
            SetEntityVisible(cache.ped, false, false)
            Wait(f.hide)
            SetEntityVisible(cache.ped, not powers.invisible, false)
        end
    end)
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
    -- V12.63 : effets d'un instant à ma position (particules réseau : les joueurs autour les voient)
    for _, f in ipairs(BURSTS) do
        if info.level >= (Config.Powers[f.id] or 99) then
            options[#options + 1] = { title = f.label, icon = f.icon, iconColor = '#b048ff', description = 'Un instant, à ta position, vu par les joueurs autour',
                onSelect = function() if grant(f.id) then burst(f) end funMenu() end }
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

--- V12.63 · Événements rangés par usage : rassemblements (annonce + GPS pour tous), chasse au trésor, bonus serveur,
--- météo et saisons, police et faits divers, rumeurs, effets sur moi. Le serveur revérifie rang et mode staff.
local function eventsMenu()
    local function launch(id, ev, extra)
        if lib.alertDialog({ header = ev.label, content = ev.text .. '\n\nTout le monde reçoit l\'annonce et le GPS.', centered = true, cancel = true }) == 'confirm' then
            local data = extra or {}
            data.kind = id
            notify(act('event', nil, data))
        end
    end
    -- Rassemblements
    local gather = {}
    for id, ev in pairs(Config.Events) do
        if not ev.hunt then
            gather[#gather + 1] = { title = ev.label, icon = ev.icon, description = ('%d min · %s%s'):format(ev.minutes, ev.at and 'lieu fixe' or 'à ta position',
                ev.fx == 'melee' and (' · armes rangées dans %d m'):format(math.floor(ev.radius)) or ''), onSelect = function() launch(id, ev) end }
        end
    end
    table.sort(gather, function(a, b) return a.title < b.title end)
    local options = {
        { title = 'Rassemblements', icon = 'people-group', arrow = true, description = 'Auto, club, concert, marché de nuit, défilé, foot, billard, laser game, boxe, emploi, course, road trip, plage',
          onSelect = function() show('gs_staff_gather', 'Rassemblements', gather, 'gs_staff_events') end },
    }
    local hev = Config.Events.hunt
    if hev then
        options[#options + 1] = { title = hev.label, icon = hev.icon, description = ('Cache une mallette ICI : zone de %d m pour tous, prime au premier qui la trouve'):format(math.floor(hev.radius)),
            onSelect = function()
                local H = Config.Hunt or {}
                local r = input(hev.label, { { type = 'number', label = 'Prime (en banque)', description = ('Au-delà de %d $ : super-admin'):format(H.prize or 1500),
                    default = H.prize or 1500, min = 100, max = H.maxPrize or 5000, required = true } })
                if r then launch('hunt', hev, { prize = math.floor(tonumber(r[1]) or 0) }) end
            end }
    end
    -- Bonus de serveur (gs_events)
    local bonus = {}
    for _, b in ipairs({ { 'double_xp', 'Soirée double XP', 'star' }, { 'lucky', 'Soirée chanceuse', 'clover' } }) do
        bonus[#bonus + 1] = { title = b[2], icon = b[3], description = 'Pour tout le serveur, durée au choix', onSelect = function()
            local r = input(b[2], { { type = 'number', label = 'Durée (minutes)', default = 60, min = 5, max = 240, required = true } })
            if r then ExecuteCommand(('gsevent start %s %d'):format(b[1], r[1])) end
        end }
    end
    bonus[#bonus + 1] = { title = 'Arrêter le bonus en cours', icon = 'stop', onSelect = function() ExecuteCommand('gsevent stop') end }
    options[#options + 1] = { title = 'Bonus serveur', icon = 'star', arrow = true, description = 'Double XP, soirée chanceuse',
        onSelect = function() show('gs_staff_bonus', 'Bonus serveur', bonus, 'gs_staff_events') end }
    if info.level >= 3 then
        options[#options + 1] = { title = 'Météo et saisons', icon = 'cloud-bolt', arrow = true,
            description = 'Neige, tempête, canicule, brouillard ; Halloween', onSelect = function()
                show('gs_staff_weather', 'Météo et saisons', {
                    { title = 'Neige sur Los Santos', icon = 'snowflake', description = 'Ville enneigée, traces de pas et de pneus (30 à 45 min)',
                      onSelect = function() ExecuteCommand('meteoevent snow') end },
                    { title = 'Tempête tropicale', icon = 'cloud-bolt', description = 'Routes du comté fermées, arbres et véhicules à dégager',
                      onSelect = function() ExecuteCommand('meteoevent storm') end },
                    { title = 'Canicule', icon = 'temperature-high', onSelect = function() ExecuteCommand('meteoevent heatwave') end },
                    { title = 'Brouillard épais', icon = 'smog', onSelect = function() ExecuteCommand('meteoevent fog') end },
                    { title = 'Arrêter l\'événement météo', icon = 'sun', onSelect = function() ExecuteCommand('meteoevent stop') end },
                    { title = 'Halloween : activer', icon = 'ghost', description = 'Citrouilles sur la route (automatique du 24 oct. au 1er nov.)', onSelect = function() ExecuteCommand('halloween on') end },
                    { title = 'Halloween : désactiver', icon = 'ban', onSelect = function() ExecuteCommand('halloween off') end },
                    { title = 'Halloween : automatique (selon la date)', icon = 'calendar', onSelect = function() ExecuteCommand('halloween auto') end },
                }, 'gs_staff_events')
            end }
        options[#options + 1] = { title = 'Police : fait divers PNJ', icon = 'magnifying-glass', arrow = true, -- V10
            description = 'Cambriolage, corps retrouvé, délit de fuite, vandalisme : la police en service est prévenue', onSelect = function()
                show('gs_staff_fd', 'Fait divers PNJ', {
                    { title = 'Au hasard', icon = 'dice', onSelect = function() ExecuteCommand('faitdivers') end },
                    { title = 'Cambriolage', icon = 'house-crack', onSelect = function() ExecuteCommand('faitdivers burglary') end },
                    { title = 'Corps retrouvé', icon = 'skull', onSelect = function() ExecuteCommand('faitdivers body') end },
                    { title = 'Délit de fuite', icon = 'car-burst', onSelect = function() ExecuteCommand('faitdivers hitrun') end },
                    { title = 'Vandalisme', icon = 'spray-can', onSelect = function() ExecuteCommand('faitdivers vandalism') end },
                }, 'gs_staff_events')
            end }
    end
    -- V10.2 : rumeurs écrites par les joueurs (rien n'est public avant validation)
    options[#options + 1] = { title = 'Rumeurs des joueurs', icon = 'comment-dots', arrow = true, description = 'Valider (le barman la raconte) ou écarter',
        onSelect = function()
            local list = lib.callback.await('gs_rumors:pending', false)
            if not list then return notify(false, 'Indisponible.') end
            local o = {}
            for _, r in ipairs(list) do
                o[#o + 1] = { title = r.text, icon = 'comment-dots', description = ('%s · %s · il y a %d min'):format(r.by, r.teller, r.mins), arrow = true,
                    onSelect = function()
                        show('gs_staff_rumor', 'Rumeur n°' .. r.id, {
                            { title = 'Valider (les barmans la racontent)', icon = 'check', onSelect = function() notify(lib.callback.await('gs_rumors:decide', false, r.id, true, false)) end },
                            { title = 'Valider + brève Weazel', icon = 'newspaper', onSelect = function() notify(lib.callback.await('gs_rumors:decide', false, r.id, true, true)) end },
                            { title = 'Écarter', icon = 'xmark', onSelect = function() notify(lib.callback.await('gs_rumors:decide', false, r.id, false)) end },
                        }, 'gs_staff_rumors')
                    end }
            end
            if #o == 0 then o[1] = { title = 'Aucune rumeur en attente', readOnly = true } end
            show('gs_staff_rumors', 'Rumeurs des joueurs', o, 'gs_staff_events')
        end }
    options[#options + 1] = { title = 'Effets sur moi (animation d\'événement)', icon = 'wand-magic-sparkles', arrow = true,
        description = 'Feux d\'artifice, confettis, téléportation, désintégration, voiture indestructible, fumée de pneus, super vitesse…', onSelect = funMenu }
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
    add(1, { title = 'Coincé : ramener au dernier endroit sûr', icon = 'arrow-up', description = 'Sous la carte, dans un mur… (V12.63)',
        onSelect = function() notify(act('unstuck', p.id)) end })
    add(2, { title = 'Figer / libérer', icon = 'snowflake', onSelect = function() notify(act('freeze', p.id)) end })
    -- V12.63 · Modération avancée : surveillance (admin et plus) — le staff est prévenu à chacune de ses arrivées
    if p.watched then
        add(3, { title = 'Lever la surveillance', icon = 'eye-slash', iconColor = '#ffb020', onSelect = function()
            local ok, msg = act('unwatch', p.id)
            notify(ok, msg)
            if ok then p.watched = nil playerMenu(p) end
        end })
    else
        add(3, { title = 'Mettre sous surveillance', icon = 'eye', description = 'Le staff en service est prévenu à chacune de ses arrivées (invisible pour lui)',
            onSelect = function()
                local r = lib.inputDialog('Surveiller ' .. p.name, { { type = 'input', label = 'Motif (staff uniquement)', required = true, max = 200 } })
                if not r then return end
                local ok, msg = act('watch', p.id, { reason = r[1] })
                notify(ok, msg)
                if ok then p.watched = true playerMenu(p) end
            end })
    end
    add(3, { title = 'Effacer sa recherche (étoiles)', icon = 'star', description = 'Chaleur remise à zéro (gs_wanted)',
        onSelect = function() ExecuteCommand('effacerrecherche ' .. p.id) notify(true, 'Recherche effacée.') end })
    add(3, { title = 'Lui mettre un métier', icon = 'briefcase', arrow = true, onSelect = function() jobsMenu(p) end })
    add(3, { title = 'Mort RP : tombe au cimetière', icon = 'cross', description = 'Tombe + épitaphe + avis de décès (le personnage n\'est pas supprimé)', -- V12.60
        onSelect = function()
            if GetResourceState('gs_cimetiere') ~= 'started' then return notify(false, 'gs_cimetiere n\'est pas démarré.') end
            exports.gs_cimetiere:PlayerDeath(p.id, p.name)
        end })
    add(3, { title = 'Le mettre dans un gang', icon = 'people-group', arrow = true, onSelect = function() gangsMenu(p) end })
    -- V12.63 · Mises en scène (admin et plus) : sanction appliquée par le serveur à la fin de la scène
    add(Config.Scenes and Config.Scenes.level or 3, { title = 'Mises en scène', icon = 'clapperboard', arrow = true,
        description = 'Enlèvement en camionnette (expulsion), arrestation par un policier PNJ (cellule)', onSelect = function()
            show('gs_staff_scenes', 'Mises en scène · ' .. p.name, {
                { title = 'Enlèvement en camionnette', icon = 'van-shuttle', iconColor = '#ff4d6d',
                  description = 'Une camionnette l\'embarque, écran noir, puis EXPULSION (motif publié comme une expulsion)', onSelect = function()
                    local r = lib.inputDialog('Enlèvement : ' .. p.name, { { type = 'input', label = 'Motif de l\'expulsion (publié)', required = true, max = 200 } })
                    if not r then return end
                    if lib.alertDialog({ header = 'Enlever ' .. p.name .. ' ?', content = ('Il sera **expulsé** à la fin de la scène.\n**Motif** : %s'):format(r[1]), centered = true, cancel = true }) ~= 'confirm' then return end
                    notify(act('kidnap', p.id, { reason = r[1] }))
                end },
                { title = 'Arrestation par un policier PNJ', icon = 'handcuffs', iconColor = '#5aa0ff',
                  description = 'Plaqué, menotté, puis en cellule à Mission Row (isolement)', onSelect = function()
                    local r = lib.inputDialog('Arrestation : ' .. p.name, {
                        { type = 'number', label = 'Minutes de cellule', default = (Config.Scenes and Config.Scenes.arrest.minutes) or 5, min = 1, max = Config.Jail.maxMinutes, required = true },
                        { type = 'input', label = 'Motif (publié)', required = true, max = 200 },
                    })
                    if not r then return end
                    notify(act('npcarrest', p.id, { minutes = math.floor(tonumber(r[1]) or 5), reason = r[2] }))
                end },
            }, 'gs_staff_player')
        end })
    add(4, { title = 'Argent', icon = 'money-bill', arrow = true, onSelect = function() moneyMenu(p) end })
    add(4, { title = 'Items', icon = 'box-open', arrow = true, onSelect = function() itemsMenu(p) end })
    -- V12.4 · Bannissement RoadLine (super-admin) : posé ici, LEVÉ depuis « Bannissements » (même hors ligne)
    add(4, { title = 'Bannir', icon = 'gavel', iconColor = '#ff4d6d', description = 'Durée en jours (0 = définitif), motif obligatoire',
        onSelect = function()
            local r = lib.inputDialog('Bannir ' .. p.name, {
                { type = 'number', label = 'Durée en jours', description = '0 = définitif', required = true, min = 0, max = 3650, default = 3 },
                { type = 'input', label = 'Motif', description = 'Visible par le joueur et dans #sanctions', required = true, max = 200 },
            })
            if not r then return end
            local days = math.floor(tonumber(r[1]) or 0)
            if lib.alertDialog({ header = 'Bannir ' .. p.name,
                content = ('**Durée** : %s\n**Motif** : %s\n\nLe joueur est déconnecté immédiatement et ne pourra plus se reconnecter.')
                    :format(days == 0 and 'DÉFINITIF' or (days .. ' jour(s)'), r[2]), centered = true, cancel = true }) ~= 'confirm' then return end
            notify(act('ban', p.id, { days = days, reason = r[2] }))
        end })
    if info.ranks and p.id ~= info.me then
        add(5, { title = 'Rang staff (fondateur)', icon = 'user-shield', arrow = true, onSelect = function() rankMenu(p) end })
    end
    if info.vips then
        -- V11.5 : VIP = un deuxième personnage (comme le staff), rien d'autre
        local vip = p.license and info.vips[p.license] == true
        add(5, { title = ('VIP (2 personnages) : %s'):format(vip and 'OUI' or 'NON'), icon = 'crown', iconColor = vip and ON or OFF,
            description = vip and 'Retirer le statut VIP' or 'Accorder un deuxième personnage', onSelect = function()
                local ok, msg = act('setvip', p.id, { on = not vip })
                notify(ok, msg)
                if ok then info.vips[p.license] = (not vip) or nil playerMenu(p) end
            end })
    end
    show('gs_staff_player', ('[%d] %s'):format(p.id, p.name), options, 'gs_staff_players')
end

--- V12.4 · Bannissements RoadLine (super-admin) : la liste des bannis actifs, une recherche par pseudo ou licence,
--- et la levée du bannissement — même sur un joueur hors ligne, ce que txAdmin ne permet pas depuis le jeu.
local function bansMenu(search)
    local list = lib.callback.await('gs_admin:bans', false, search)
    if type(list) ~= 'table' then return notify(false, 'Liste indisponible (super-admin requis).') end
    local options = { { title = 'Rechercher', icon = 'magnifying-glass',
        description = search and ('Filtre actuel : « %s »'):format(search) or 'Par pseudo ou par licence', onSelect = function()
            local r = lib.inputDialog('Chercher un banni', { { type = 'input', label = 'Pseudo ou licence', max = 64 } })
            bansMenu(r and r[1] ~= '' and r[1] or nil)
        end } }
    for i = 1, #list do
        local b = list[i]
        local when = b.when or (b.until_ts == 0 and 'définitif' or 'à durée') -- V12.35 : texte formaté par le serveur (pas de os.date côté client)
        options[#options + 1] = { title = b.name, icon = 'user-lock', iconColor = '#ff4d6d', arrow = true,
            description = ('%s · %s · par %s'):format(when, b.reason or '—', b.staff or '?'),
            onSelect = function()
                if lib.alertDialog({ header = 'Débannir ' .. b.name,
                    content = ('**Motif du ban** : %s\n**Posé par** : %s\n**Fin** : %s\n\nIl pourra se reconnecter immédiatement.')
                        :format(b.reason or '—', b.staff or '?', when), centered = true, cancel = true }) ~= 'confirm' then return end
                local ok, msg = act('unban', nil, { license = b.license })
                notify(ok, msg)
                if ok then bansMenu(search) end
            end }
    end
    if #list == 0 then
        options[#options + 1] = { title = search and 'Aucun banni trouvé' or 'Aucun bannissement actif', icon = 'circle-check', readOnly = true }
    end
    show('gs_staff_bans', 'Bannissements', options, 'gs_staff_quick')
end

--- V12.63 · Modération avancée (admin, super-admin, fondateur) : arrivées fermées, joueurs surveillés, départs récents → ban
--- hors ligne. Le serveur renvoie seulement ce que le rang permet et revérifie chaque action.
local function since(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec < 60 then return sec .. ' s' end
    if sec < 3600 then return (sec // 60) .. ' min' end
    return ('%d h %02d'):format(sec // 3600, (sec % 3600) // 60)
end

local function moderationMenu()
    local st = lib.callback.await('gs_admin:moderation', false)
    if type(st) ~= 'table' then return notify(false, 'Modération avancée : admin minimum.') end
    local o = {}
    if st.locked then
        o[#o + 1] = { title = ('Arrivées FERMÉES · encore %s'):format(since(st.locked.left)), icon = 'door-closed', iconColor = '#ff4d6d',
            description = ('%s · par %s%s'):format(st.locked.reason or '—', st.locked.staff or '?', st.canLock and ' · cliquer pour rouvrir' or ''),
            readOnly = not st.canLock, onSelect = st.canLock and function()
                notify(act('lockdown', nil, { minutes = 0 }))
                moderationMenu()
            end or nil }
    elseif st.canLock then
        o[#o + 1] = { title = 'Fermer les arrivées', icon = 'door-open', description = 'Raid, attaque : plus personne n\'entre sauf le staff (rouvre seul)',
            onSelect = function()
                local r = lib.inputDialog('Fermer les arrivées', {
                    { type = 'number', label = 'Durée (minutes)', required = true, min = 1, max = 60, default = 15 },
                    { type = 'input', label = 'Motif (affiché à ceux qui tentent d\'entrer)', required = true, max = 120, default = 'maintenance de modération' },
                })
                if not r then return end
                notify(act('lockdown', nil, { minutes = math.floor(tonumber(r[1]) or 15), reason = r[2] }))
                moderationMenu()
            end }
    else
        o[#o + 1] = { title = 'Arrivées ouvertes', icon = 'door-open', readOnly = true, description = 'Fermeture : super-admin et fondateur' }
    end
    -- Surveillés
    local w = st.watch or {}
    local wo = {}
    for _, e in ipairs(w) do
        wo[#wo + 1] = { title = ('%s%s'):format(e.name or '?', e.online and (' · en ville [' .. e.online .. ']') or ''), icon = 'eye',
            iconColor = e.online and ON or nil, description = ('%s · par %s · cliquer pour lever'):format(e.reason or '—', e.staff or '?'),
            onSelect = function()
                if lib.alertDialog({ header = 'Lever la surveillance', content = ('**%s**\n%s'):format(e.name or '?', e.reason or ''), centered = true, cancel = true }) ~= 'confirm' then return end
                notify(act('unwatch', nil, { license = e.license }))
                moderationMenu()
            end }
    end
    if #wo == 0 then wo[1] = { title = 'Personne sous surveillance', icon = 'circle-check', readOnly = true, description = 'Fiche d\'un joueur → Mettre sous surveillance' } end
    o[#o + 1] = { title = ('Joueurs surveillés (%d)'):format(#w), icon = 'eye', arrow = true, onSelect = function() show('gs_staff_watch', 'Joueurs surveillés', wo, 'gs_staff_mod') end }
    -- Départs récents → ban hors ligne
    local dep = st.departed or {}
    local dpo = {}
    for _, d in ipairs(dep) do
        dpo[#dpo + 1] = { title = ('%s (%s)'):format(d.name or '?', d.account or '?'), icon = d.banned and 'user-lock' or 'person-walking-arrow-right',
            iconColor = d.banned and '#ff4d6d' or nil, readOnly = d.banned or not st.canOfflineBan,
            description = ('parti il y a %s · %s · resté %s%s'):format(since(d.ago), d.reason ~= '' and d.reason or '—', since(d.session),
                d.banned and ' · BANNI' or (st.canOfflineBan and ' · cliquer pour bannir' or '')),
            onSelect = (not d.banned and st.canOfflineBan) and function()
                local r = lib.inputDialog('Bannir hors ligne : ' .. (d.name or '?'), {
                    { type = 'number', label = 'Durée en jours', description = '0 = définitif', required = true, min = 0, max = 3650, default = 3 },
                    { type = 'input', label = 'Motif', description = 'Visible dans #sanctions et à sa prochaine tentative', required = true, max = 200 },
                })
                if not r then return end
                local days = math.floor(tonumber(r[1]) or 0)
                if lib.alertDialog({ header = 'Bannir ' .. (d.name or '?'), content = ('**Durée** : %s\n**Motif** : %s'):format(days == 0 and 'DÉFINITIF' or (days .. ' jour(s)'), r[2]),
                    centered = true, cancel = true }) ~= 'confirm' then return end
                notify(act('offlineban', nil, { license = d.license, days = days, reason = r[2] }))
                moderationMenu()
            end or nil }
    end
    if #dpo == 0 then dpo[1] = { title = 'Aucun départ depuis le démarrage', icon = 'circle-check', readOnly = true } end
    o[#o + 1] = { title = ('Partis récemment (%d)'):format(#dep), icon = 'person-walking-arrow-right', arrow = true,
        description = st.canOfflineBan and 'Le rage-quit après un RDM : bannir hors ligne' or 'Ban hors ligne : super-admin et fondateur',
        onSelect = function() show('gs_staff_departed', 'Partis récemment', dpo, 'gs_staff_mod') end }
    show('gs_staff_mod', 'Modération avancée', o, 'gs_staff_quick')
end

--- V10.2 : distance d'un joueur (nil s'il est trop loin pour être chargé)
local function distanceTo(id)
    local pl = GetPlayerFromServerId(id)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    if ped == 0 then return nil end
    return #(GetEntityCoords(ped) - GetEntityCoords(cache.ped))
end

--- Joueur juste devant moi (visé ou le plus proche à moins de 6 m)
local function facingPlayer()
    local best, bestD
    for _, p in ipairs(info.players) do
        if p.id ~= info.me then
            local d = distanceTo(p.id)
            if d and d <= 6.0 and (not bestD or d < bestD) then best, bestD = p, d end
        end
    end
    return best
end

local function playersMenu(filter)
    local list = {}
    for _, p in ipairs(info.players) do
        local f = filter and filter:lower()
        if not f or tostring(p.id) == f or p.name:lower():find(f, 1, true) then
            list[#list + 1] = { p = p, d = distanceTo(p.id) }
        end
    end
    -- les plus proches d'abord (ceux hors de portée à la fin, par identifiant)
    table.sort(list, function(a, b)
        if a.d and b.d then return a.d < b.d end
        if a.d or b.d then return a.d ~= nil end
        return a.p.id < b.p.id
    end)
    local options = { { title = 'Rechercher (nom ou ID)', icon = 'magnifying-glass', onSelect = function()
        local r = input('Rechercher un joueur', { { type = 'input', label = 'Nom ou identifiant', required = true } })
        if r then playersMenu(r[1]) end
    end } }
    for _, e in ipairs(list) do
        options[#options + 1] = { title = ('[%d] %s%s'):format(e.p.id, e.p.name, e.p.watched and ' 👁' or ''), icon = 'user', arrow = true,
            description = e.d and ('à %d m'):format(math.floor(e.d)) or 'loin', onSelect = function() playerMenu(e.p) end }
    end
    if #list == 0 then options[#options + 1] = { title = filter and 'Aucun joueur trouvé' or 'Aucun joueur', readOnly = true } end
    show('gs_staff_players', filter and ('Recherche « %s »'):format(filter) or ('Joueurs (%d)'):format(#info.players), options, 'gs_staff_quick')
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

    local function spawnModel(model)
        local hash = GetHashKey(model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return notify(false, 'Modèle inconnu : ' .. model) end
        notify(act('spawnveh', nil, { model = model, vtype = vehicleType(hash) }))
    end
    -- V11.5 · Catalogue Qbox par catégorie (nom lisible, marque, prix) : plus besoin de connaître le nom de spawn.
    local VEH_CATEGORIES = { compacts = 'Citadines', sedans = 'Berlines', suvs = 'SUV', coupes = 'Coupés', muscle = 'Muscle cars',
        sportsclassics = 'Sportives classiques', sports = 'Sportives', super = 'Supercars', motorcycles = 'Motos', offroad = 'Tout-terrain',
        industrial = 'Industriels', utility = 'Utilitaires', vans = 'Camionnettes', cycles = 'Vélos', boats = 'Bateaux', helicopters = 'Hélicoptères',
        planes = 'Avions', service = 'Service', emergency = 'Urgences', military = 'Militaires', commercial = 'Poids lourds', trains = 'Trains', roadtrip = '★ Imports RoadLine' }
    local function catalogMenu()
        local ok, all = pcall(function() return exports.qbx_core:GetVehiclesByName() end) -- [API] qbx_core
        if not ok or type(all) ~= 'table' then return notify(false, 'Catalogue indisponible.') end
        local byCat = {}
        for model, v in pairs(all) do
            local c = v.category or 'other'
            byCat[c] = byCat[c] or {}
            byCat[c][#byCat[c] + 1] = { model = model, name = v.name or model, brand = v.brand or '', price = v.price or 0 }
        end
        local cats = {}
        for c, l in pairs(byCat) do
            table.sort(l, function(x, y) return (x.brand .. x.name) < (y.brand .. y.name) end)
            cats[#cats + 1] = { id = c, label = VEH_CATEGORIES[c] or c, n = #l }
        end
        table.sort(cats, function(x, y) return x.label < y.label end)
        local o = {}
        for _, c in ipairs(cats) do
            o[#o + 1] = { title = c.label, icon = 'car-side', arrow = true, description = ('%d modèle(s)'):format(c.n), onSelect = function()
                local l = {}
                for _, v in ipairs(byCat[c.id]) do
                    l[#l + 1] = { title = ('%s %s'):format(v.brand, v.name), description = ('%s · %s $'):format(v.model, lib.math.groupdigits(v.price)),
                        icon = 'car', onSelect = function() spawnModel(v.model) end }
                end
                show('gs_staff_veh_cat', c.label, l, 'gs_staff_veh_catalog')
            end }
        end
        show('gs_staff_veh_catalog', 'Catalogue des véhicules', o, 'gs_staff_veh')
    end
    local function vehMenu()
        local o = {}
        local function a(minLvl, opt) if lvl >= minLvl then o[#o + 1] = opt end end
        a(3, { title = 'Catalogue par catégorie', icon = 'list', arrow = true, description = 'Berlines, sportives, motos… (nom, marque, prix)', onSelect = catalogMenu })
        a(3, { title = 'Faire apparaître un véhicule (nom de spawn)', icon = 'car', onSelect = function()
            local r = input('Véhicule', { { type = 'input', label = 'Modèle (ex : sultan, faggio, buzzard)', required = true } })
            if not r then return end
            spawnModel(r[1]:gsub('%s', ''):lower())
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

    -- V12.15 · Une map : y aller, ou la retirer (super-admin / fondateur). V12.36 : le retrait supprime vraiment (avant : ressource
    -- seulement arrêtée, ligne commentée, dossier gardé → réinstallée par IMPORTER-MODS) : arrêt + dossier effacé + mods-retires.txt
    -- + ligne enlevée de cfg/addons.cfg (server/maps.js, comme RETIRED_MAPS au démarrage) ; l'archive reste dans mods-a-trier.
    local mappingsMenu
    local function mapActions(m, p)
        local opts = {}
        if p then opts[#opts + 1] = { title = 'Y aller', icon = 'location-arrow', description = ('%.0f, %.0f, %.0f'):format(p.x, p.y, p.z),
            onSelect = function() teleportTo(p.x, p.y, p.z) end } end
        opts[#opts + 1] = { title = 'Retirer cette map', icon = 'trash', iconColor = '#ff6b6b',
            description = 'Arrêtée, dossier supprimé du disque, notée dans mods-retires.txt (jamais réimportée), ligne enlevée de cfg/addons.cfg',
            onSelect = function()
                local c = lib.alertDialog({ header = 'Retirer ' .. m.label .. ' ?', centered = true, cancel = true,
                    content = ('La map **%s** (%s) sera arrêtée, son dossier supprimé du disque, son nom inscrit dans mods-retires.txt et sa ligne enlevée de cfg/addons.cfg.\nSon archive reste dans mods-a-trier : pour la remettre, enlever son nom de mods-retires.txt puis relancer IMPORTER-MODS.\n\nÀ faire sur le serveur du PC, puis METTRE-A-JOUR-OVH.'):format(m.label, m.name) })
                if c ~= 'confirm' then return end
                notify(lib.callback.await('gs_admin:disableMap', false, m.name))
                clearMapBlips()
                mappingsMenu()
            end }
        if m.activity then
            opts[#opts + 1] = { title = m.activity.script and ('Activité : %s'):format(m.activity.what) or ('Activité : %s — décor seul'):format(m.activity.what),
                icon = m.activity.script and 'gamepad' or 'ban', iconColor = m.activity.script and '#5aff8c' or '#ffb020', disabled = true,
                description = m.activity.script and ('Script démarré : %s'):format(m.activity.script)
                    or 'Le jeu est un script vendu à part par l\'auteur (pas de point pour jouer sans lui) : dans C:\\GTASOON\\mods-tri\\scripts-a-verifier' }
        end
        opts[#opts + 1] = { title = m.name, icon = 'file', disabled = true, description = 'Nom de la ressource (cfg/addons.cfg)' }
        show('gs_staff_map_one', m.label, opts, 'gs_staff_maps')
    end

    -- V12.30 · Contrôle « chez moi » : la map est démarrée sur le serveur, mais ses modèles arrivent-ils jusqu'au joueur, et
    -- se chargent-ils ? (un bâtiment invisible ne laisse aucune erreur dans la console). Modèles = ceux de la map posés par
    -- ses .ymap (server/maps.js). Quelques-uns sont chargés pour de vrai puis relâchés.
    local function checkMaps(maps)
        local res = {}
        for _, m in ipairs(maps) do
            local c = { name = m.name, label = m.label, total = #(m.models or {}), present = 0, tried = 0, loaded = 0, sample = {} }
            for _, h in ipairs(m.models or {}) do
                if IsModelInCdimage(h) then
                    c.present = c.present + 1
                    if #c.sample < 4 then c.sample[#c.sample + 1] = h; RequestModel(h) end
                end
            end
            res[#res + 1] = c
        end
        local deadline = GetGameTimer() + 12000
        repeat
            local waiting = false
            for _, c in ipairs(res) do for _, h in ipairs(c.sample) do if not HasModelLoaded(h) then waiting = true end end end
            if not waiting then break end
            Wait(250)
        until GetGameTimer() > deadline
        for _, c in ipairs(res) do
            for _, h in ipairs(c.sample) do
                c.tried = c.tried + 1
                if HasModelLoaded(h) then c.loaded = c.loaded + 1 end
                SetModelAsNoLongerNeeded(h)
            end
            c.sample = nil
            if c.total == 0 then
                c.v, c.msg = 'na', 'non testable d\'ici (ses objets ne portent pas le nom de ses fichiers) : « Y aller » pour vérifier sur place'
            elseif c.present == 0 then
                c.v, c.msg = 'missing', ('aucun de ses %d modèles n\'arrive chez le joueur : fichiers absents de la ressource ou cache FiveM (VIDER-CACHE-FIVEM)'):format(c.total)
            elseif c.loaded < c.tried then
                c.v, c.msg = 'unreadable', ('modèles reçus mais impossibles à charger (%d/%d) : licence Cfx de la map (achetée avec un autre compte que celui de la clé du serveur) ou fichier abîmé → bâtiment invisible'):format(c.loaded, c.tried)
            elseif c.present < c.total then
                c.v, c.msg = 'partial', ('%d modèles sur %d reçus : pack incomplet, des morceaux du bâtiment manquent'):format(c.present, c.total)
            else
                c.v, c.msg = 'ok', ('bâtiment chargé (%d modèles)'):format(c.total)
            end
        end
        return res
    end

    local function checkMenu(maps)
        notify(true, 'Contrôle des maps en cours (quelques secondes)…')
        local res = checkMaps(maps)
        lib.callback.await('gs_admin:mapCheckReport', false, res) -- recopié dans la console du serveur
        local byName = {}
        for _, m in ipairs(maps) do byName[m.name] = m end
        local ICON = { ok = { 'circle-check', '#5aff8c' }, na = { 'circle-question', '#ffb020' }, missing = { 'circle-xmark', '#ff6b6b' }, partial = { 'triangle-exclamation', '#ff6b6b' }, unreadable = { 'lock', '#ff6b6b' } }
        local o, bad = {}, 0
        table.sort(res, function(a, b) return (a.v == 'ok' and 1 or 0) < (b.v == 'ok' and 1 or 0) end)
        for _, c in ipairs(res) do
            if c.v ~= 'ok' and c.v ~= 'na' then bad = bad + 1 end
            local m, desc = byName[c.name], c.msg
            if m and m.activity and not m.activity.script then desc = desc .. (' · activité (%s) : script pas installé, décor seul'):format(m.activity.what) end
            local p = m and m.places and m.places[1]
            o[#o + 1] = { title = c.label, icon = ICON[c.v][1], iconColor = ICON[c.v][2], description = desc, arrow = p ~= nil,
                disabled = p == nil, onSelect = p and function() mapActions(m, p) end or nil }
        end
        notify(bad == 0, bad == 0 and 'Toutes les maps testables sont chargées chez toi.' or ('%d map(s) invisible(s) chez toi : détail dans la liste et dans la console du serveur.'):format(bad))
        show('gs_staff_maps_check', ('Contrôle chez moi (%d)'):format(#res), o, 'gs_staff_maps')
    end

    -- V12.10 · Mappings installés : où est chaque map ajoutée (lu dans ses fichiers), y aller, la voir sur la carte
    function mappingsMenu(r)
        r = r or lib.callback.await('gs_admin:mappings', false)
        if not r then return end
        local o = {}
        if r.error then o[#o + 1] = { title = 'Lecture des maps impossible', icon = 'triangle-exclamation', disabled = true, description = r.error } end
        -- V12.63 · QG de gang : variantes d'une même map (…_vagos / …_ballas…), une seule chargée chez tous les joueurs
        o[#o + 1] = { title = 'QG de gang : changer les couleurs', icon = 'people-group', arrow = true,
            description = 'Ex. QG Patoche en Vagos → Ballas (variantes .ymap de la map)', onSelect = function()
                local groups, order, files = {}, {}, {}
                for _, m in ipairs(r.maps) do
                    for _, v in ipairs(m.gangVariants or {}) do
                        if not groups[v.group] then groups[v.group] = { label = m.label, gangs = {}, x = v.x, y = v.y, z = v.z } order[#order + 1] = v.group end
                        groups[v.group].gangs[v.gang] = true
                    end
                    if m.ymapFiles then files[#files + 1] = { label = m.label, list = m.ymapFiles } end
                end
                local chosen = GlobalState.gsMapGangs or {}
                local g = {}
                for _, key in ipairs(order) do
                    local grp = groups[key]
                    local cur = chosen[key] and chosen[key].gang or 'comme installé'
                    g[#g + 1] = { title = ('%s · %s'):format(grp.label, key:gsub('#', '…')), icon = 'house-flag', arrow = true,
                        description = ('Actuel : %s · %.0f, %.0f'):format(cur, grp.x, grp.y), onSelect = function()
                            local c = { { title = 'Comme installé (toutes les variantes)', icon = 'rotate-left', onSelect = function()
                                notify(act('mapgang', nil, { group = key })) end } }
                            for gang in pairs(grp.gangs) do
                                c[#c + 1] = { title = 'Aux couleurs : ' .. gang, icon = 'flag', onSelect = function()
                                    notify(act('mapgang', nil, { group = key, gang = gang })) end }
                            end
                            show('gs_staff_mapgang', grp.label, c, 'gs_staff_mapgangs')
                        end }
                end
                if #g == 0 then
                    g[1] = { title = 'Aucune variante de gang trouvée dans les fichiers', icon = 'circle-info', readOnly = true,
                        description = 'Les variantes sont peut-être des « entity sets » : envoyer le PDF du pack au développeur' }
                end
                for _, f in ipairs(files) do -- diagnostic : fichiers .ymap des packs de gang
                    g[#g + 1] = { title = 'Fichiers de ' .. f.label, icon = 'file', arrow = true, description = ('%d fichier(s) .ymap'):format(#f.list), onSelect = function()
                        local l = {}
                        for _, n in ipairs(f.list) do l[#l + 1] = { title = n, icon = 'file', readOnly = true } end
                        show('gs_staff_mapfiles', f.label, l, 'gs_staff_mapgangs')
                    end }
                end
                show('gs_staff_mapgangs', 'QG de gang', g, 'gs_staff_maps')
            end }
        o[#o + 1] = { title = 'Supprimer définitivement toutes les maps', icon = 'dumpster-fire', iconColor = '#ff4d6d',
            description = 'Efface leurs dossiers, leurs lignes de addons.cfg et leurs archives : elles ne reviendront jamais. Vêtements non touchés',
            onSelect = function()
                local r2 = input('Suppression définitive', { { type = 'input', label = 'Tape SUPPRIMER pour confirmer (irréversible)', required = true } })
                if not r2 or r2[1] ~= 'SUPPRIMER' then return notify(false, 'Annulé : rien n\'a été supprimé.') end
                notify(lib.callback.await('gs_admin:deleteAllMaps', false, 'SUPPRIMER'))
                clearMapBlips()
            end }
        if #r.maps > 0 then
            o[#o + 1] = { title = 'Retirer TOUTES les maps', icon = 'trash-can', iconColor = '#ff6b6b',
                description = 'Arrêtées et plus chargées (lignes commentées dans cfg/addons.cfg, réversible). Vêtements non touchés',
                onSelect = function()
                    local c = lib.alertDialog({ header = ('Retirer les %d maps ?'):format(#r.maps), centered = true, cancel = true,
                        content = 'Toutes les maps ajoutées seront arrêtées et ne seront plus chargées.\n\nÀ faire sur le serveur du PC, puis METTRE-A-JOUR-OVH.' })
                    if c ~= 'confirm' then return end
                    notify(lib.callback.await('gs_admin:disableAllMaps', false))
                    clearMapBlips()
                end }
        end
        if #r.maps > 0 then
            o[#o + 1] = { title = 'Contrôler les maps chez moi', icon = 'stethoscope', iconColor = '#5ab4ff', arrow = true,
                description = 'Bâtiment visible ou pas, sans bouger : modèles reçus, chargés, licence, activité. Résultat aussi dans la console du serveur',
                onSelect = function() checkMenu(r.maps) end }
        end
        o[#o + 1] = { title = #mapBlips > 0 and 'Masquer leurs blips' or 'Afficher leurs blips sur ma carte', icon = 'location-dot',
            description = 'Visibles par toi seul, le temps de faire le tour', onSelect = function()
                if #mapBlips > 0 then clearMapBlips() else
                    for _, m in ipairs(r.maps) do
                        for _, p in ipairs(m.places) do
                            local b = AddBlipForCoord(p.x, p.y, p.z)
                            SetBlipSprite(b, 472) SetBlipColour(b, 27) SetBlipScale(b, 0.85)
                            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(m.label) EndTextCommandSetBlipName(b)
                            mapBlips[#mapBlips + 1] = b
                        end
                    end
                end
                mappingsMenu(r) -- même liste, sans redemander au serveur
            end }
        if #r.conflicts > 0 then
            local c, open = {}, 0
            for _, x in ipairs(r.conflicts) do
                if x.resolved then
                    c[#c + 1] = { title = x.file .. ' (résolu)', icon = 'circle-check', iconColor = '#5aff8c', disabled = true,
                        description = table.concat(x.resources, ' + ') .. ' : versions fusionnées par ' .. x.resolved }
                else
                    open = open + 1
                    c[#c + 1] = { title = x.file, icon = 'triangle-exclamation', iconColor = '#ff6b6b', disabled = true,
                        description = 'Remplacé par ' .. table.concat(x.resources, ' ET ') .. ' : une seule des deux s\'affichera correctement' }
                end
            end
            o[#o + 1] = { title = open > 0 and ('%d conflit(s) entre maps'):format(open) or 'Conflits entre maps : tous résolus',
                icon = open > 0 and 'triangle-exclamation' or 'circle-check', iconColor = open > 0 and '#ff6b6b' or '#5aff8c', arrow = true,
                description = open > 0 and 'Deux maps remplacent le même fichier du jeu : fusionner (Claude) ou en garder une' or 'Fusionnés par la ressource gsa_zz_fusion',
                onSelect = function() show('gs_staff_maps_conf', 'Conflits entre maps', c, 'gs_staff_maps') end }
        end
        for _, m in ipairs(r.maps) do
            for _, h in ipairs(m.heavy or {}) do
                o[#o + 1] = { title = ('%s : modèle trop lourd'):format(m.label), icon = 'weight-hanging', iconColor = '#ffb020', disabled = true,
                    description = ('%s prend %.1f Mo en mémoire (limite FiveM : 48 Mo) : textures ou murs qui peuvent ne pas s\'afficher'):format(h.file, h.mb) }
            end
            if #m.places == 0 then
                local why = ' · emplacement introuvable'
                if m.ymaps == 0 then
                    why = (m.assets or 0) > 0 and ' · habillage d\'objets du jeu (ex. toutes les agences Fleeca), pas de lieu propre'
                        or ' · aucun fichier de map : vide ou incomplète, à supprimer'
                end
                o[#o + 1] = { title = m.label, icon = 'circle-question', disabled = true, description = m.name .. why }
            end
            for i, p in ipairs(m.places) do
                local code = GetNameOfZone(p.x, p.y, p.z)
                local zone = GetLabelText(code)
                if not zone or zone == 'NULL' or zone == '' then zone = (code and code ~= '' and code ~= 'NULL') and code or 'Hors quartier' end
                o[#o + 1] = { title = m.label .. (#m.places > 1 and (' · lieu %d'):format(i) or ''), icon = 'map-pin', arrow = true,
                    description = ('%s · %.0f, %.0f, %.0f'):format(zone, p.x, p.y, p.z), onSelect = function() mapActions(m, p) end }
            end
            if #m.places == 0 then
                o[#o].onSelect = function() mapActions(m, nil) end
                o[#o].disabled, o[#o].arrow = false, true
            end
        end
        show('gs_staff_maps', ('Mappings installés (%d)'):format(#r.maps), o, 'gs_staff_world')
    end

    local function worldMenu()
        local o = {}
        local function a(minLvl, opt) if lvl >= minLvl then o[#o + 1] = opt end end
        a(4, { title = 'Lieux publics (boutique, parking)', icon = 'shop', arrow = true, description = 'Poser une boutique de vêtements ou un parking ici',
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
        a(4, { title = 'Déplacer / retirer un point (récolte, gangs, magasins…)', icon = 'location-crosshairs', arrow = true,
            description = 'Point mal placé ? Mets-toi au bon endroit et choisis-le. Super-admin : retirer du jeu', onSelect = function() TriggerEvent('gs_bridge:client:pointsMenu') end })
        a(4, { title = 'Points de métier (placer ici)', icon = 'briefcase', arrow = true,
            description = 'Service, coffre, armurerie, direction, garage', onSelect = pointsMenu })
        -- V12.37 : PNJ et objets posés par le staff, reliés à un métier / un gang (cohérence du mapping), placement libre
        a(4, { title = 'PNJ et objets posés par le staff', icon = 'user-plus', arrow = true,
            description = 'Ajouter un PNJ ou un objet relié à un métier / un gang (ou libre), aperçu et réglages, retirer', onSelect = staffPedsMenu })
        a(4, { title = 'Gangs (création, QG, garage)', icon = 'people-group', arrow = true, onSelect = gangAdminMenu })
        a(4, { title = 'Mapping : objets du décor', icon = 'cube', arrow = true, description = 'Catalogue par catégorie, placer, modifier, retirer de la map (/builder)',
            onSelect = function() exports.gs_builder:Open('gs_staff_world') end })
        -- V12.40 · portes verrouillées par métier / gang (ox_doorlock, éditeur en jeu) : prison, commissariat, mappings…
        a(3, { title = 'Portes verrouillées (métiers, gangs)', icon = 'door-closed', arrow = true,
            description = 'Viser une porte (même d\'un mapping) et la réserver à la police, aux EMS, à un gang…',
            onSelect = function()
                local c = lib.alertDialog({ header = 'Portes verrouillées', centered = true, cancel = true, size = 'lg', labels = { confirm = 'Ouvrir l\'éditeur' },
                    content = table.concat({
                        '1. **Créer** : vise la porte (ou les 2 battants : « Porte double »), donne un nom clair (« Prison · sas 1 »).',
                        '2. **Groupes** : métier ou gang + grade minimum. Réglages conseillés :',
                        '   · Prison / cellules : `police` 0 + `sheriff` 0 · Commissariat (accueil exclu) : `police` 0',
                        '   · Hôpital (bloc, pharmacie) : `ambulance` 0 · Garage Benny\'s (atelier) : `mechanic` 0',
                        '   · Concession (bureau) : `cardealer` 1 · QG de gang : le gang (ex. `ballas` 0)',
                        '3. **Verrouillée par défaut** pour la prison et les cellules ; « Fermeture auto » 5 s pour les sas.',
                        '4. En jeu : [E] près de la porte pour ouvrir / fermer si tu as le métier (en service conseillé).',
                        'Les portes sont enregistrées en base (ox_doorlock) : rien à refaire aux mises à jour.',
                    }, '\n') })
                if c == 'confirm' then ExecuteCommand('doorlock') end
            end })
        -- V12.60 · Blips en double (backtest 15/10) : tous les blips de MA carte (nos ressources, maps importées, scripts tiers),
        -- regroupés quand la même icône revient à moins de 40 m. Clic = téléportation pour voir sur place lequel garder.
        a(3, { title = 'Blips en double sur la carte', icon = 'clone', arrow = true, description = 'Même icône deux fois au même endroit (nos lieux + maps + scripts)',
            onSelect = function()
                local all = {}
                for sprite = 1, 900 do
                    local b = GetFirstBlipInfoId(sprite)
                    while DoesBlipExist(b) do
                        local c = GetBlipInfoIdCoord(b)
                        if GetBlipInfoIdType(b) == 4 and (c.x ~= 0.0 or c.y ~= 0.0) then all[#all + 1] = { sprite = sprite, c = c } end -- 4 = blip posé sur une position
                        b = GetNextBlipInfoId(sprite)
                    end
                end
                local o, used = {}, {}
                for i, p in ipairs(all) do
                    if not used[i] then
                        local n = 1
                        for j = i + 1, #all do
                            if not used[j] and all[j].sprite == p.sprite and #(vec2(all[j].c.x, all[j].c.y) - vec2(p.c.x, p.c.y)) < 40.0 then used[j] = true n = n + 1 end
                        end
                        if n > 1 then
                            local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(p.c.x, p.c.y, p.c.z))
                            o[#o + 1] = { title = ('Icône %d · %d blips au même endroit'):format(p.sprite, n), icon = 'clone', iconColor = '#ffb347',
                                description = (street ~= '' and street or 'lieu sans nom') .. ' · clic : y aller', onSelect = function() teleportTo(p.c.x, p.c.y, p.c.z) end }
                        end
                    end
                end
                if #o == 0 then o[1] = { title = ('Aucun doublon (%d blips contrôlés)'):format(#all), icon = 'check', readOnly = true } end
                show('gs_staff_blipdup', 'Blips en double', o, 'gs_staff_world')
            end })
        -- V12.60 · cimetière (gs_cimetiere) : tombes, épitaphes, avis de décès
        a(3, { title = 'Cimetière', icon = 'cross', arrow = true, description = 'Poser une tombe (carré ou ici), y aller, retirer',
            onSelect = function()
                if GetResourceState('gs_cimetiere') ~= 'started' then return notify(false, 'gs_cimetiere n\'est pas démarré.') end
                exports.gs_cimetiere:OpenStaffMenu()
            end })
        -- V12.40 · courses de rue sur mesure (gs_races) : points posés sur place, éphémères ou permanentes
        a(3, { title = 'Courses de rue sur mesure', icon = 'flag-checkered', arrow = true, description = 'Créer une course (points posés là où tu es), durée de vie, supprimer',
            onSelect = function()
                if GetResourceState('gs_races') ~= 'started' then return notify(false, 'gs_races n\'est pas démarré.') end
                exports.gs_races:OpenEditor()
            end })
        -- V12.40 · véhicules d'exposition des concessions (gs_showroom) : poser, départ des essais, changer, retirer
        a(3, { title = 'Concessions : véhicules d\'exposition', icon = 'car', arrow = true, description = 'Exposer un véhicule ici, départ des essais, changer le modèle, retirer',
            onSelect = function()
                if GetResourceState('gs_showroom') ~= 'started' then return notify(false, 'gs_showroom n\'est pas démarré.') end
                exports.gs_showroom:OpenStaffMenu()
            end })
        -- V12.63 · Journée North Yankton (n° 191) : Cayo Perico et North Yankton à tour de rôle, ou une destination forcée
        a(4, { title = 'Destination du vol de l\'île (Cayo / North Yankton)', icon = 'plane-departure', arrow = true,
            description = 'Un jour sur deux, ou forcer une destination (les joueurs sur place sont rapatriés)',
            onSelect = function()
                if GetResourceState('gs_world') ~= 'started' then return notify(false, 'gs_world n\'est pas démarré.') end
                local i = lib.callback.await('gs_world:islandInfo', false)
                if not i then return notify(false, 'Réservé au staff.') end
                local name = { cayo = 'Cayo Perico', yankton = 'North Yankton' }
                local function set(c) notify(lib.callback.await('gs_world:setIslandMode', false, c)) end
                show('gs_staff_island', 'Vol de l\'île', {
                    { title = ('Aujourd\'hui : %s'):format(name[i.mode]), icon = 'plane', readOnly = true,
                      description = i.choice == 'auto' and ('Alternance · demain : %s'):format(name[i.tomorrow]) or 'Destination forcée par le staff' },
                    { title = 'Alternance (un jour sur deux)', icon = 'arrows-rotate', onSelect = function() set('auto') end },
                    { title = 'Cayo Perico tous les jours', icon = 'umbrella-beach', onSelect = function() set('cayo') end },
                    { title = 'North Yankton tous les jours', icon = 'snowflake', onSelect = function() set('yankton') end },
                }, 'gs_staff_world')
            end })
        a(4, { title = 'Mappings installés', icon = 'map', arrow = true, description = 'Où est chaque map ajoutée : y aller, la voir sur la carte, conflits',
            onSelect = function() mappingsMenu() end })
        a(4, { title = 'Copier mes coordonnées', icon = 'crosshairs', description = 'vec4 dans le presse-papiers', onSelect = function()
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
        local near = facingPlayer()
        if near then
            add(1, { title = ('Joueur en face : [%d] %s'):format(near.id, near.name), icon = 'user-check', iconColor = ON, arrow = true,
                description = 'Ses actions en un clic', onSelect = function() playerMenu(near) end })
        end
        add(1, { title = 'Joueurs', icon = 'users', arrow = true, description = 'Triés par distance, recherche par nom ou ID', onSelect = function() playersMenu() end })
        add(1, { title = 'Moi', icon = 'user-gear', arrow = true, description = 'Vol libre, invisible, TP, peds et animaux…', onSelect = meMenu })
        -- V12.60 · Lives : écrans des joueurs dans des fenêtres déplaçables (gs_lives, screenshot-basic)
        add(2, { title = 'Lives (écrans des joueurs)', icon = 'tv', description = 'Regarder un ou plusieurs joueurs dans des fenêtres · aussi /lives', onSelect = function()
            if GetResourceState('gs_lives') ~= 'started' then return notify(false, 'gs_lives n\'est pas démarré.') end
            lib.hideContext()
            exports.gs_lives:Open()
        end })
        add(2, { title = 'Véhicules', icon = 'car', arrow = true, description = 'Faire apparaître, mods, réparer, supprimer', onSelect = vehMenu })
        -- V12.14 : Monde et lieux réservé aux super-admins et au fondateur (serveur : actions et callbacks au niveau 4)
        add(4, { title = 'Monde et lieux', icon = 'map-location-dot', arrow = true, description = 'Lieux publics, points, gangs, décor', onSelect = worldMenu })
        add(3, { title = 'Événements', icon = 'champagne-glasses', arrow = true, description = 'Événements en un clic, bonus serveur, effets', onSelect = eventsMenu })
        add(1, { title = 'Anti-triche', icon = 'user-shield', arrow = true, description = 'Dernières alertes (aucune sanction automatique)', onSelect = function()
            local list = lib.callback.await('gs_admin:acAlerts', false) or {}
            local o = {}
            for i = 1, math.min(#list, 30) do
                local a = list[i]
                o[#o + 1] = { title = ('%s [%d] · %s'):format(a.name, a.src, a.kind), icon = 'triangle-exclamation', iconColor = '#ff8a3d',
                    description = ('%s · il y a %d min'):format(a.detail or '', math.max(0, GetCloudTimeAsInt() - a.at) // 60),
                    onSelect = function() notify(act('goto', a.src)) end }
            end
            if #o == 0 then o[1] = { title = 'Aucune alerte', icon = 'circle-check', readOnly = true } end
            show('gs_staff_ac', 'Anti-triche', o, 'gs_staff_quick')
        end })
        -- V12.4 · Bannissements : lever un bannissement sans quitter le jeu, même sur un joueur hors ligne
        add(4, { title = 'Bannissements', icon = 'gavel', arrow = true, description = 'Voir les bannis, chercher, débannir', onSelect = bansMenu })
        add(3, { title = 'Modération avancée', icon = 'shield-halved', arrow = true, description = 'Surveillés, partis récemment (ban hors ligne), fermer les arrivées', onSelect = moderationMenu })
        add(3, { title = 'Statistiques de rétention', icon = 'chart-line', arrow = true, description = 'Nouveaux joueurs, retours J+1 / 7 jours, abandon, sessions', onSelect = function()
            local r = GetResourceState('gs_stats') == 'started' and lib.callback.await('gs_stats:retention', false)
            if not r then return notify(false, 'Statistiques indisponibles.') end
            local function p(v) return v and (v .. ' %') or '—' end
            local o = {
                { title = ('Nouveaux joueurs (7 j) : %d'):format(r.new7), icon = 'user-plus', readOnly = true },
                { title = ('Reviennent le lendemain : %s'):format(p(r.d1.pct)), description = ('%d sur %d'):format(r.d1.back, r.d1.of), icon = 'rotate-left', readOnly = true },
                { title = ('Reviennent dans la semaine : %s'):format(p(r.d7.pct)), description = ('%d sur %d'):format(r.d7.back, r.d7.of), icon = 'calendar-week', readOnly = true },
                { title = ('Abandon à la 1re session (< 15 min) : %s'):format(p(r.drop.pct)), description = 'À faire baisser : accueil, première heure', icon = 'door-open', readOnly = true },
                { title = ('Session moyenne : %d min'):format(r.avg), icon = 'clock', readOnly = true },
            }
            for _, d in ipairs(r.daily) do
                o[#o + 1] = { title = ('%s · %d joueurs'):format(d.label, d.players), description = ('%d nouveaux · pic %d en même temps'):format(d.new, d.peak), icon = 'calendar', readOnly = true }
            end
            show('gs_staff_stats', 'Rétention', o, 'gs_staff_quick')
        end })
    end
    add(1, { title = 'Panel complet (F10)', icon = 'table-columns', onSelect = function() ExecuteCommand('admin') end })
    show('gs_staff_quick', ('Staff · %s · RoadLine %s'):format(info.levelName or '', GetConvar('gs_version', '?')), options)
end

-- Déplacer / retirer un point (toutes ressources) : les plus proches (300 m), filtre par ressource.
-- V11.6 : « Retirer du jeu » (super-admin, réversible) en plus de déplacer / remettre à l'origine.
local POINT_RES = { gs_harvest = 'Récolte', gs_jobs = 'Métiers', gs_gangs = 'Gangs', gs_economy = 'Magasins', gs_bank = 'Banques', gs_drugs = 'Drogue',
    gs_heists = 'Braquages', gs_rental = 'Locations', gs_gigs = 'Petits boulots', gs_races = 'Courses', gs_blackmarket = 'Marché noir', gs_police = 'Police',
    gs_hideouts = 'Planques', gs_casino = 'Casino', gs_driving = 'Auto-école', gs_cctv = 'Caméras', gs_nightcity = 'Ville de nuit', gs_world = 'Monde',
    gs_quests = 'Quêtes (personnages, cabine)', gs_interiors = 'Portes d\'intérieurs', gs_auction = 'Fourrière', gs_onboarding = 'Arrivée' }
local function pointsAllMenu(filter)
    local me = GetEntityCoords(PlayerPedId())
    local all = exports.gs_bridge:NearbyPoints(me, 300.0)
    local list, byRes = {}, {}
    for _, p in ipairs(all) do
        byRes[p.res] = (byRes[p.res] or 0) + 1
        if not filter or p.res == filter then list[#list + 1] = p end
    end
    local options = {}
    if not filter then
        options[1] = { title = 'Filtrer par ressource', icon = 'filter', arrow = true, description = 'Récolte, métiers, gangs, magasins…', onSelect = function()
            local o = {}
            for res, n in pairs(byRes) do o[#o + 1] = { title = POINT_RES[res] or res, description = ('%s · %d point(s)'):format(res, n), icon = 'folder',
                onSelect = function() pointsAllMenu(res) end } end
            table.sort(o, function(a, b) return a.title < b.title end)
            show('gs_staff_points_filter', 'Filtrer par ressource', o, 'gs_staff_points_all')
        end }
    end
    for i = 1, math.min(#list, 30) do
        local p = list[i]
        local state = p.off and ' · RETIRÉ' or (p.moved and ' · déjà déplacé' or '')
        options[#options + 1] = { title = p.label, icon = p.off and 'ban' or (p.moved and 'location-dot' or 'location-crosshairs'),
            iconColor = p.off and '#ff4d6d' or (p.moved and ON or nil),
            description = ('%s · à %d m%s'):format(POINT_RES[p.res] or p.res, math.floor(p.dist), state), arrow = true,
            onSelect = function()
                local o = {
                    { title = 'Placer ce point ici (ma position)', icon = 'location-crosshairs', disabled = p.off, onSelect = function()
                        if lib.alertDialog({ header = p.label, content = 'Le point est posé à tes pieds, orienté comme toi.\n\n' .. p.res
                            .. ' est relancé quelques secondes (les joueurs en train de l\'utiliser devront recommencer).', centered = true, cancel = true }) == 'confirm' then
                            notify(act('movepoint', nil, { key = p.key }))
                        end
                    end },
                    -- V12.37 · placement libre : aperçu du point (anneau + cap), réglages au clavier, même sauvegarde et même vérification
                    { title = 'Placement libre (aperçu, hauteur, orientation)', icon = 'arrows-up-down-left-right', disabled = p.off,
                        description = 'Flèches 10 cm · PgUp/PgDn 5 cm · Q/E 5° · Maj ×5 · G au sol · Tab viser · Entrée / Retour', onSelect = function()
                            local ped = PlayerPedId()
                            local me = GetEntityCoords(ped)
                            local cur = exports.gs_bridge:FindPoint(p.key)
                            local start = (cur and #(me - cur) <= 50.0) and cur or me -- l'aperçu part du point s'il est proche (régler sa hauteur), sinon de moi
                            local pose = freePlace({ kind = 'point', x = start.x, y = start.y, z = start.z, heading = GetEntityHeading(ped) })
                            if not pose then return end
                            if lib.alertDialog({ header = p.label, content = ('Le point est posé à l\'endroit de l\'aperçu (hauteur %.2f, cap %d°).\n\n%s est relancé quelques secondes (les joueurs en train de l\'utiliser devront recommencer).'):format(pose.z, math.floor(pose.heading), p.res),
                                centered = true, cancel = true }) == 'confirm' then
                                notify(act('movepoint', nil, { key = p.key, pose = pose }))
                            end
                        end },
                    { title = 'Remettre la position d\'origine', icon = 'rotate-left', disabled = not p.moved,
                        onSelect = function() notify(act('resetpoint', nil, { key = p.key })) end },
                }
                if info.level >= 4 then
                    if p.off then
                        o[#o + 1] = { title = 'Réactiver ce point', icon = 'circle-check', iconColor = ON, onSelect = function() notify(act('enablepoint', nil, { key = p.key })) end }
                    else
                        o[#o + 1] = { title = 'Retirer ce point du jeu', icon = 'ban', iconColor = '#ff4d6d', description = 'Réversible : il réapparaît ici avec « Réactiver »',
                            onSelect = function()
                                if lib.alertDialog({ header = p.label, content = 'Le point disparaît pour tout le monde (marqueur, logo, interaction). ' .. p.res
                                    .. ' est relancé quelques secondes.', centered = true, cancel = true }) == 'confirm' then
                                    notify(act('disablepoint', nil, { key = p.key }))
                                end
                            end }
                    end
                end
                show('gs_staff_point', p.label, o, 'gs_staff_points_all')
            end }
    end
    if #list == 0 then options[#options + 1] = { title = 'Aucun point à moins de 300 m', readOnly = true } end
    show('gs_staff_points_all', filter and ('Points · ' .. (POINT_RES[filter] or filter)) or 'Déplacer / retirer un point', options, 'gs_staff_world')
end
AddEventHandler('gs_bridge:client:pointsMenu', function() pointsAllMenu(nil) end)

--- Ouvre le menu principal (données rafraîchies depuis le serveur).
function openQuick()
    info = lib.callback.await('gs_admin:quick', false)
    if not info then return notify(false, 'Accès réservé au staff.') end
    mainMenu()
end

-- Nom neuf en V7 : la touche par défaut (F11) s'applique à tous, même à ceux qui avaient l'ancienne (Suppr)
RegisterCommand('gs_staffmenu_v7', function()
    if lib.getOpenContextMenu() then return lib.hideContext() end -- même touche = fermer
    if IsNuiFocused() then return end -- V11.5 : jamais pendant une saisie ou une autre interface
    openQuick('main')
end, false)
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
    RegisterCommand('staff_' .. id, function() if ctrlHeld() and not IsNuiFocused() then sc.run() end end, false)
    RegisterKeyMapping('staff_' .. id, sc.label, 'keyboard', Config.Shortcuts[id])
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then powersOff() clearMapBlips() end
end)
