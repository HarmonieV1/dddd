-- gs_bank (client) · V12.64 · Piratage de distributeur : [Alt] sur un distributeur avec le boîtier en poche.
-- 1. on branche le boîtier (animation au distributeur, clé USB en main, étincelles) ; 2. mini-jeu sur la tablette
-- (touches au bon moment) ; 3. réussi : les billets sortent (animation, liasse en main) ; raté : bips et alarme.
-- Tout le reste (butin, alarme, caméra, usure du boîtier) est décidé par le serveur.
local H = Config.Hack
local busy = false
local hasAt, hasItem = 0, false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 6000 }) end end

--- Boîtier en poche ? (relu au plus toutes les 2 s : ox_target interroge souvent)
local function hasHacker()
    if GetGameTimer() - hasAt > 2000 then
        hasAt = GetGameTimer()
        local ok, n = pcall(function() return exports.ox_inventory:Search('count', H.item) end) -- [API] ox_inventory
        hasItem = ok and (tonumber(n) or 0) > 0
    end
    return hasItem
end

local function sparks(c)
    CreateThread(function()
        if not lib.requestNamedPtfxAsset('core', 2000) then return end
        for _ = 1, 3 do
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('ent_brk_sparking_wires', c.x, c.y, c.z + 1.0, 0.0, 0.0, 0.0, 0.6, false, false, false)
            Wait(700)
        end
        RemoveNamedPtfxAsset('core')
    end)
end

--- Mini-jeu sur la tablette (animation + accessoire), rend true si réussi
local function tabletGame(skill, keys)
    local ped = cache.ped
    local dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
    local tablet
    if lib.requestAnimDict(dict, 2000) then TaskPlayAnim(ped, dict, 'base', 3.0, 3.0, -1, 49, 0, false, false, false) end
    if lib.requestModel(GetHashKey('prop_cs_tablet'), 2000) then
        local c = GetEntityCoords(ped)
        tablet = CreateObject(GetHashKey('prop_cs_tablet'), c.x, c.y, c.z + 0.2, true, true, false)
        AttachEntityToEntity(tablet, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(GetHashKey('prop_cs_tablet'))
    end
    local ok = lib.skillCheck(skill, keys) -- [API] ox_lib
    StopAnimTask(ped, dict, 'base', 1.0)
    RemoveAnimDict(dict)
    if tablet and DoesEntityExist(tablet) then DeleteEntity(tablet) end
    return ok == true
end

local function hack(entity)
    if busy then return end
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    local c = GetEntityCoords(entity)
    local coords = { x = c.x, y = c.y, z = c.z }
    local ok, res = lib.callback.await('gs_bank:hackBegin', false, coords)
    if not ok then return notify(false, res) end
    busy = true
    TaskTurnPedToFaceCoord(cache.ped, c.x, c.y, c.z, 800)
    Wait(800)
    sparks(c)
    local plugged = lib.progressBar({ -- [API] ox_lib
        duration = res.install, label = 'Branchement du boîtier sur le lecteur de carte…', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_atm@male@idle_a', clip = 'idle_b' },
        prop = { model = GetHashKey('hei_prop_hst_usb_drive'), bone = 28422, pos = vec3(0.04, 0.0, 0.0), rot = vec3(0.0, 0.0, 90.0) },
    })
    if not plugged then busy = false return TriggerServerEvent('gs_bank:server:hackCancel') end
    local won = tabletGame(res.skill, res.keys)
    local good, drain, alarm = lib.callback.await('gs_bank:hackResult', false, won)
    if not good then
        busy = false
        if alarm then
            PlaySoundFrontend(-1, 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
            for _ = 1, 3 do PlaySoundFromCoord(-1, 'Beep_Red', c.x, c.y, c.z + 1.0, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 25, false) Wait(350) end
        end
        return notify(false, drain)
    end
    PlaySoundFrontend(-1, 'Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
    local done = lib.progressBar({
        duration = drain, label = 'Le distributeur crache les billets…', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_atm@male@idle_a', clip = 'idle_a' },
        prop = { model = GetHashKey('prop_anim_cash_pile_01'), bone = 18905, pos = vec3(0.12, 0.03, 0.02), rot = vec3(-90.0, 0.0, 0.0) },
    })
    busy = false
    if not done then return TriggerServerEvent('gs_bank:server:hackCancel') end
    local okF, msg = lib.callback.await('gs_bank:hackFinish', false)
    hasAt = 0 -- le boîtier a peut-être grillé : relire l'inventaire
    notify(okF, msg)
end

CreateThread(function()
    exports.ox_target:addModel(Config.AtmModels, { { -- [API] ox_target
        name = 'gs_bank:hack', icon = 'fa-solid fa-microchip', label = 'Pirater le distributeur', distance = 1.6,
        canInteract = function() return not busy and hasHacker() end,
        onSelect = function(data) hack(data.entity) end,
    } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then pcall(function() exports.ox_target:removeModel(Config.AtmModels, 'gs_bank:hack') end) end
end)
