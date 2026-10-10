-- gs_roadside (client) · V8 « Rencontres de la route ». Après un moment de route hors de la ville, demande au serveur
-- s'il y a une rencontre ; si oui, la scène est posée sur le bas-côté, devant le véhicule. Rien n'est signalé : pas de
-- blip, pas de notification. Le joueur s'arrête… ou pas. Entités locales (scène vécue par le conducteur).
local scene
local function notify(ok, msg, dur) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = dur or 6000 }) end end
local function say(msg) lib.notify({ title = 'Sur la route', description = msg, type = 'inform', icon = 'road', duration = 8000 }) end

local function hash(model)
    local h = GetHashKey(model)
    return lib.requestModel(h, 8000) and h or nil
end

local function track(ent) scene.ents[#scene.ents + 1] = ent return ent end

local function spawnPed(model, c, heading)
    local h = hash(model)
    if not h then return nil end
    local ped = CreatePed(4, h, c.x, c.y, c.z, heading or 0.0, false, true)
    SetModelAsNoLongerNeeded(h)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    return track(ped)
end

local function spawnVeh(model, c, heading)
    local h = hash(model)
    if not h then return nil end
    local veh = CreateVehicle(h, c.x, c.y, c.z, heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(h)
    SetVehicleOnGroundProperly(veh)
    return track(veh)
end

local function playLoop(ped, dict, clip)
    if lib.requestAnimDict(dict, 3000) then TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, 1, 0, false, false, false) end
end

local function pick(list) return list[math.random(1, #list)] end
local function me() return GetEntityCoords(cache.ped) end

local function cleanup(delay)
    local s = scene
    scene = nil
    lib.hideTextUI()
    if s.blip then RemoveBlip(s.blip) end
    SetTimeout(delay or 0, function()
        for _, e in ipairs(s.ents) do if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true) DeleteEntity(e) end end
    end)
end

local function finish(outcome)
    local ok, msg = lib.callback.await('gs_roadside:finish', false, scene.data.token, outcome)
    if msg then notify(ok, msg) end
    return ok
end

--- Trouve un point au bord de la route, devant le véhicule, dans le sens de la marche
local function findSpot()
    local veh = cache.vehicle
    if not veh then return nil end
    local p, fwd = GetEntityCoords(veh), GetEntityForwardVector(veh)
    local t = p + fwd * Config.SpawnAhead
    local ok, node, heading = GetClosestVehicleNodeWithHeading(t.x, t.y, t.z, 1, 3.0, 0)
    if not ok then return nil end
    local rad = math.rad(heading)
    if -math.sin(rad) * fwd.x + math.cos(rad) * fwd.y < 0 then heading = (heading + 180.0) % 360.0 rad = math.rad(heading) end
    local right = vec3(math.cos(rad), math.sin(rad), 0.0)
    local side = node + right * 5.5
    local found, gz = GetGroundZFor_3dCoord(side.x, side.y, side.z + 5.0, false)
    return vec3(side.x, side.y, found and gz or node.z), heading
end

--- Attend que le joueur soit à `radius` m (à pied, ou véhicule arrêté si allowCar) et appuie sur E.
--- false si le joueur s'éloigne trop ou si la scène a expiré.
local function waitInteract(target, radius, prompt, allowCar)
    local shown = false
    while scene do
        local pos = type(target) == 'number' and GetEntityCoords(target) or target
        local d = #(me() - pos)
        if d > 450.0 or GetGameTimer() - scene.t0 > Config.Lifetime * 1000 then break end
        local veh = cache.vehicle
        local ready = d <= radius and (not veh or (allowCar and GetEntitySpeed(veh) < 1.5))
        if ready ~= shown then
            if ready then lib.showTextUI('[E] ' .. prompt, { icon = 'hand' }) else lib.hideTextUI() end
            shown = ready
        end
        if ready and IsControlJustReleased(0, 38) and not IsNuiFocused() then lib.hideTextUI() return true end
        Wait(d < 60.0 and 0 or 500)
    end
    lib.hideTextUI()
    return false
end

local function routeTo(c, label)
    scene.blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(scene.blip, 280) SetBlipColour(scene.blip, 5) SetBlipRoute(scene.blip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(scene.blip)
end

local function ignore() if scene then finish('ignored') cleanup() end end

-- Scènes --------------------------------------------------------------------------------------------------------
local Scenes = {}

Scenes.friend = function(d)
    local ped = spawnPed(d.model or pick(Config.Models.hitchhiker), scene.pos, scene.heading + 90.0)
    if not ped then return ignore() end
    playLoop(ped, 'random@hitch_lift', 'idle_f')
    if not waitInteract(ped, 6.0, 'Saluer', true) then return ignore() end
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, cache.ped, 1500)
    say('« Hé ! C\'est toi qui m\'avais pris en stop l\'autre jour ! Tiens, pour la route. »')
    finish('met')
    TaskWanderStandard(ped, 10.0, 10)
    cleanup(30000)
end

Scenes.hitchhiker = function(d)
    local ped = spawnPed(d.model, scene.pos, scene.heading + 90.0)
    if not ped then return ignore() end
    playLoop(ped, 'random@hitch_lift', 'idle_f')
    if not waitInteract(ped, 12.0, 'Le prendre en stop', true) then return ignore() end
    local veh = cache.vehicle
    if not veh or not IsVehicleSeatFree(veh, 0) then notify(false, 'Pas de place pour lui.') return ignore() end
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, 15000, 0, 1.5, 1, 0)
    local t = GetGameTimer() + 15000
    while not IsPedInVehicle(ped, veh, false) and GetGameTimer() < t do Wait(250) end
    if not IsPedInVehicle(ped, veh, false) then return ignore() end
    local place = Config.Places[d.place]
    say(('« Merci ! Tu peux me déposer à %s ? »'):format(place.label))
    routeTo(place.coords, 'Destination de l\'auto-stoppeur')
    local start, total = me(), #(me() - place.coords)
    scene.t0 = GetGameTimer() -- la scène dure le temps du trajet
    while scene do
        Wait(500)
        if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return ignore() end
        if d.danger and #(me() - start) >= total * 0.45 then
            -- l'auto-stoppeur était un braqueur
            GiveWeaponToPed(ped, GetHashKey('WEAPON_PISTOL'), 12, false, true)
            say('Il sort un pistolet : « Arrête-toi. Tout de suite. Et vide tes poches. »')
            PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
            local deadline = GetGameTimer() + 20000
            while GetGameTimer() < deadline do
                local v = cache.vehicle
                if v and GetEntitySpeed(v) < 1.0 then
                    finish('robbed')
                    TaskLeaveVehicle(ped, v, 0) Wait(1500)
                    TaskSmartFleePed(ped, cache.ped, 300.0, -1, false, false)
                    return cleanup(40000)
                end
                Wait(200)
            end
            say('« T\'es complètement malade ! » Il saute du véhicule en marche.')
            TaskLeaveVehicle(ped, cache.vehicle or 0, 4160)
            finish('escaped')
            return cleanup(30000)
        end
        local v = cache.vehicle
        if not d.danger and #(me() - place.coords) < 40.0 and v and GetEntitySpeed(v) < 1.0 then
            TaskLeaveVehicle(ped, v, 0)
            Wait(1500)
            say('« Merci, t\'es quelqu\'un de bien. Je m\'en souviendrai. »')
            finish('dropped')
            TaskWanderStandard(ped, 10.0, 10)
            return cleanup(30000)
        end
        if GetGameTimer() - scene.t0 > 20 * 60000 then return ignore() end
    end
end

Scenes.breakdown = function(d)
    local car = spawnVeh(pick(Config.Models.car), scene.pos, scene.heading)
    if not car then return ignore() end
    SetVehicleIndicatorLights(car, 0, true) SetVehicleIndicatorLights(car, 1, true)
    SetVehicleDoorOpen(car, 4, false, false)
    SetVehicleEngineHealth(car, 250.0)
    local driver = spawnPed(pick(Config.Models.driver), GetOffsetFromEntityInWorldCoords(car, 0.0, -3.2, 0.0), scene.heading)
    if driver then TaskStartScenarioInPlace(driver, 'WORLD_HUMAN_STAND_MOBILE', 0, true) end
    if d.danger then
        -- fausse panne : un guet-apens quand on s'approche
        while scene and #(me() - scene.pos) > 30.0 do
            if #(me() - scene.pos) > 450.0 or GetGameTimer() - scene.t0 > Config.Lifetime * 1000 then return ignore() end
            Wait(300)
        end
        if not scene then return end
        local _, grp = AddRelationshipGroup('GS_AMBUSH')
        SetRelationshipBetweenGroups(5, grp, GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), grp)
        local enemies = { driver }
        for i = 1, 2 do
            local p = spawnPed(pick(Config.Models.ambush), GetOffsetFromEntityInWorldCoords(car, i == 1 and -2.5 or 2.5, -5.0, 0.0), scene.heading)
            if p then enemies[#enemies + 1] = p end
        end
        for _, p in ipairs(enemies) do
            if p then
                ClearPedTasks(p)
                SetPedRelationshipGroupHash(p, grp)
                GiveWeaponToPed(p, GetHashKey(math.random() < 0.5 and 'WEAPON_PISTOL' or 'WEAPON_BAT'), 60, false, true)
                SetBlockingOfNonTemporaryEvents(p, false)
                TaskCombatPed(p, cache.ped, 0, 16)
            end
        end
        while scene do
            Wait(1000)
            local alive = 0
            for _, p in ipairs(enemies) do if p and DoesEntityExist(p) and not IsPedDeadOrDying(p, true) then alive = alive + 1 end end
            if alive == 0 or #(me() - scene.pos) > 250.0 or IsPedDeadOrDying(cache.ped, true) then
                finish('ambush')
                return cleanup(60000)
            end
        end
        return
    end
    if not waitInteract(car, 4.5, 'Aider à redémarrer (jerrican ou kit de réparation)') then return ignore() end
    if not lib.progressBar({ duration = 7000, label = 'Dépannage…', canCancel = true, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
        disable = { move = true, car = true, combat = true } }) then ClearPedTasks(cache.ped) return ignore() end
    ClearPedTasks(cache.ped)
    if not finish('helped') then return ignore() end
    SetVehicleEngineHealth(car, 1000.0) SetVehicleDoorShut(car, 4, false)
    SetVehicleIndicatorLights(car, 0, false) SetVehicleIndicatorLights(car, 1, false)
    say('« Vous m\'avez sauvé la journée ! »')
    if driver then
        ClearPedTasks(driver)
        TaskEnterVehicle(driver, car, 10000, -1, 1.0, 1, 0)
        SetTimeout(6000, function() if DoesEntityExist(driver) and DoesEntityExist(car) then TaskVehicleDriveWander(driver, car, 20.0, 786603) end end)
    end
    cleanup(60000)
end

Scenes.accident = function()
    local car = spawnVeh(pick(Config.Models.car), scene.pos + vec3(0.0, 0.0, 0.3), scene.heading + 35.0)
    if not car then return ignore() end
    SetVehicleDamage(car, 0.0, 1.0, 0.1, 500.0, 300.0, true)
    SetVehicleEngineHealth(car, 150.0)
    SetVehicleDoorOpen(car, 0, false, false)
    local victim = spawnPed(pick(Config.Models.driver), GetOffsetFromEntityInWorldCoords(car, -2.0, 0.5, 0.0), scene.heading)
    if not victim then return ignore() end
    ApplyPedDamagePack(victim, 'BigHitByVehicle', 0.0, 1.0)
    playLoop(victim, 'combat@damage@writhe', 'writhe_loop')
    if not waitInteract(victim, 2.5, 'Premiers secours (bandage)') then return ignore() end
    if not lib.progressBar({ duration = 8000, label = 'Premiers secours…', canCancel = true,
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' }, disable = { move = true, car = true, combat = true } }) then
        ClearPedTasks(cache.ped) return ignore() end
    ClearPedTasks(cache.ped)
    if not finish('helped') then return ignore() end
    ClearPedTasks(victim)
    TaskStartScenarioInPlace(victim, 'WORLD_HUMAN_PICNIC', 0, true)
    say('« Merci… J\'ai cru que personne ne s\'arrêterait. »')
    cleanup(90000)
end

Scenes.animal = function()
    local a = spawnPed(pick(Config.Models.animal), scene.pos, scene.heading + 90.0)
    if not a then return ignore() end
    SetPedToRagdoll(a, 600000, 600000, 0, false, false, false)
    if not waitInteract(a, 2.5, 'Soigner l\'animal (bandage)') then return ignore() end
    if not lib.progressBar({ duration = 6000, label = 'Soins…', canCancel = true, anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },
        disable = { move = true, car = true, combat = true } }) then ClearPedTasks(cache.ped) return ignore() end
    ClearPedTasks(cache.ped)
    if not finish('helped') then return ignore() end
    ClearPedTasksImmediately(a)
    TaskSmartFleePed(a, cache.ped, 200.0, -1, false, false)
    cleanup(20000)
end

local OWNERS = { 'Dolores M.', 'Kenny R.', 'Martha J.', 'Luis V.', 'Bradley S.', 'Imani T.', 'Gus O.' }

Scenes.wallet = function(d)
    local h = hash('prop_ld_wallet_01')
    if not h then return ignore() end
    local obj = track(CreateObject(h, scene.pos.x, scene.pos.y, scene.pos.z, false, false, false))
    PlaceObjectOnGroundProperly(obj)
    if not waitInteract(obj, 2.0, 'Ramasser') then return ignore() end
    DeleteEntity(obj)
    local place, owner = Config.Places[d.place], pick(OWNERS)
    local choice
    lib.registerContext({ id = 'gs_roadside_wallet', title = 'Portefeuille de ' .. owner, canClose = false, options = {
        { title = 'Le rendre', description = ('Adresse sur le permis : %s'):format(place.label), icon = 'hand-holding-heart', onSelect = function() choice = 'return' end },
        { title = 'Le garder', description = 'Personne n\'en saura rien…', icon = 'sack-dollar', onSelect = function() choice = 'keep' end },
    } })
    lib.showContext('gs_roadside_wallet')
    while not choice do Wait(100) end
    if choice == 'keep' then finish('kept') return cleanup() end
    routeTo(place.coords, 'Adresse du portefeuille')
    scene.t0 = GetGameTimer()
    while scene and #(me() - place.coords) > 40.0 do
        if GetGameTimer() - scene.t0 > 20 * 60000 then return ignore() end
        Wait(1000)
    end
    if not scene then return end
    if not waitInteract(place.coords, 40.0, ('Rendre le portefeuille de %s'):format(owner), true) then return ignore() end
    say(('« Mon portefeuille ! Il reste encore des gens honnêtes. » — %s'):format(owner))
    finish('returned')
    cleanup()
end

Scenes.vendor = function(d)
    local van = spawnVeh(Config.Models.vendor.van, scene.pos, scene.heading)
    if not van then return ignore() end
    SetVehicleDoorOpen(van, 2, false, false) SetVehicleDoorOpen(van, 3, false, false)
    local seller = spawnPed(Config.Models.vendor.ped, GetOffsetFromEntityInWorldCoords(van, 0.0, -4.0, 0.0), scene.heading + 180.0)
    if seller then TaskStartScenarioInPlace(seller, 'WORLD_HUMAN_SMOKING', 0, true) end
    while scene do
        if not waitInteract(seller or van, 3.0, 'Voir la marchandise') then break end
        local options = {}
        for i, art in ipairs(Config.Vendor) do
            local ok, item = pcall(function() return exports.ox_inventory:Items(art.item) end) -- [API] ox_inventory
            options[#options + 1] = { title = (ok and item and item.label or art.item), description = art.price .. ' $ (liquide)', icon = 'cart-shopping',
                onSelect = function() notify(lib.callback.await('gs_roadside:buy', false, d.token, i)) end }
        end
        lib.registerContext({ id = 'gs_roadside_vendor', title = 'Vendeur ambulant', options = options })
        lib.showContext('gs_roadside_vendor')
        Wait(1500)
    end
    if scene then finish('ignored') cleanup() end
end

Scenes.sheriff = function(d)
    local car = spawnVeh(Config.Models.sheriff.car, scene.pos, scene.heading)
    if not car then return ignore() end
    SetVehicleSiren(car, true) SetVehicleHasMutedSirens(car, true)
    local cop = spawnPed(Config.Models.sheriff.ped, GetOffsetFromEntityInWorldCoords(car, -2.2, 4.0, 0.0), scene.heading + 90.0)
    if not cop then return ignore() end
    GiveWeaponToPed(cop, GetHashKey('WEAPON_PISTOL'), 30, false, false)
    playLoop(cop, 'amb@world_human_car_park_attendant@male@base', 'base')
    local wasClose, fast = false, false
    while scene do
        local dd = #(me() - GetEntityCoords(cop))
        local veh = cache.vehicle
        if dd < 25.0 then
            wasClose = true
            if veh and GetEntitySpeed(veh) > 8.0 then fast = true end
        end
        if dd < 20.0 and veh and GetEntitySpeed(veh) < 1.0 then
            if waitInteract(cop, 20.0, 'Présenter ses papiers', true) then
                ClearPedTasks(cop)
                TaskTurnPedToFaceEntity(cop, cache.ped, 1500)
                lib.progressBar({ duration = 4000, label = 'Contrôle des papiers…', canCancel = false, disable = { move = true, car = true } })
                finish('checked')
                return cleanup(20000)
            end
        end
        if wasClose and fast and dd > 60.0 then
            say('Le shérif hurle dans ton rétro : « Arrêtez-vous immédiatement ! »')
            finish('fled')
            return cleanup(30000)
        end
        if dd > 450.0 or GetGameTimer() - scene.t0 > Config.Lifetime * 1000 then return ignore() end
        Wait(dd < 80.0 and 100 or 600)
    end
end

-- V8 · Halloween : l'auto-stoppeur fantôme (il disparaît en route)
Scenes.ghost = function(d)
    local ped = spawnPed(d.model, scene.pos, scene.heading + 90.0)
    if not ped then return ignore() end
    SetPedConfigFlag(ped, 208, true)
    playLoop(ped, 'random@hitch_lift', 'idle_f')
    if not waitInteract(ped, 12.0, 'Le prendre en stop', true) then return ignore() end
    local veh = cache.vehicle
    if not veh or not IsVehicleSeatFree(veh, 0) then return ignore() end
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, 15000, 0, 1.0, 1, 0)
    local t = GetGameTimer() + 15000
    while not IsPedInVehicle(ped, veh, false) and GetGameTimer() < t do Wait(250) end
    if not IsPedInVehicle(ped, veh, false) then return ignore() end
    say('« … Roule. Je te dirai quand t\'arrêter. »')
    Wait(math.random(25000, 45000))
    AnimpostfxPlay('DeathFailOut', 1500, false)
    PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    say('Le siège passager est vide. Il ne reste qu\'une odeur de terre mouillée… et quelques billets.')
    finish('vanished')
    cleanup()
end

local function start(d)
    local pos, heading = findSpot()
    if not pos then return lib.callback.await('gs_roadside:finish', false, d.token, 'ignored') end
    scene = { data = d, pos = pos, heading = heading, ents = {}, t0 = GetGameTimer() }
    local fn = Scenes[d.kind]
    if not fn then return ignore() end
    CreateThread(function()
        local ok, err = pcall(fn, d)
        if not ok then print(('[gs_roadside] %s : %s'):format(d.kind, tostring(err))) if scene then ignore() end end
    end)
end

-- Boucle : temps de route hors de la ville (au volant, en roulant), puis tirage côté serveur
CreateThread(function()
    local rural = 0
    while true do
        Wait(5000)
        local veh = cache.vehicle
        if not scene and veh and GetPedInVehicleSeat(veh, -1) == cache.ped and GetEntitySpeed(veh) >= Config.MinSpeed then
            local class, c = GetVehicleClass(veh), GetEntityCoords(veh)
            if class < 14 and class ~= 18 and Config.IsRural(c.x, c.y) and GetPlayerWantedLevel(PlayerId()) == 0 then
                rural = rural + 5
                if rural >= Config.RollEvery then
                    rural = 0
                    local d = lib.callback.await('gs_roadside:roll', false)
                    if d then start(d) end
                end
            end
        end
    end
end)

-- Collection (carnet de route)
local function collection()
    local seen = lib.callback.await('gs_roadside:collection', false) or {}
    local options, n = {}, 0
    for _, c in ipairs(Config.Collection) do
        local got = seen[c[1]]
        if got then n = n + 1 end
        options[#options + 1] = { title = got and c[2] or '???', icon = got and 'road' or 'lock', iconColor = got and '#4fd8ff' or '#6b6380',
            description = got and ('Vécue %d fois'):format(got) or 'Pas encore croisée', readOnly = true }
    end
    table.insert(options, 1, { title = ('Rencontres de la route : %d / %d'):format(n, #Config.Collection), icon = 'route', readOnly = true,
        progress = math.floor(n / #Config.Collection * 100), colorScheme = 'violet' })
    lib.registerContext({ id = 'gs_roadside_collection', title = 'Carnet de route', options = options })
    lib.showContext('gs_roadside_collection')
end
RegisterCommand('rencontres', collection, false)
exports('OpenCollection', collection)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and scene then cleanup() end
end)
