-- gs_vie (client) · V12.57 Vie quotidienne. Aucune boucle permanente hors véhicule avec passager PNJ :
--  - Alt sur une benne : « Fouiller la poubelle » (butin décidé par le serveur) ;
--  - Alt sur un lavabo / une douche / une fontaine, ou /laver dans l'eau : sang, saleté et traces effacés ;
--  - relevé après une grosse blessure (à terre ou mort) : démarche blessée 10 min, soignée par un bandage ou des
--    antidouleurs (gardée si on se reconnecte) ;
--  - conducteur avec un PNJ passager : il raconte de temps en temps une vraie rumeur de la ville.

-- 123 · Poubelles -------------------------------------------------------------------------------------------------
local function searchBin(ent)
    if lib.progressActive() then return end
    if not lib.progressBar({ duration = Config.Dumpster.duration, label = 'Tu fouilles la poubelle…', canCancel = true,
        anim = { scenario = 'PROP_HUMAN_BUM_BIN' }, disable = { move = true, car = true, combat = true } }) then return end
    local ok, msg, item, n = lib.callback.await('gs_vie:dumpster', false, GetEntityCoords(ent))
    if item then msg = ('%s (%d × %s)'):format(msg, n, exports.ox_inventory:Items(item) and exports.ox_inventory:Items(item).label or item) end
    lib.notify({ description = msg, type = ok and (item and 'success' or 'inform') or 'error' })
end

-- 125 · Se laver --------------------------------------------------------------------------------------------------
local function cleanUp(ped)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedEnvDirt(ped)
end

local function wash(label)
    if lib.progressActive() then return end
    if not lib.progressBar({ duration = Config.Wash.duration, label = label or 'Tu te laves…', canCancel = true,
        anim = { dict = 'missheist_agency3aig_23', clip = 'urinal_sink_loop', flag = 49 },
        disable = { move = true, car = true, combat = true } }) then return end
    cleanUp(cache.ped)
    lib.notify({ description = 'Propre comme un sou neuf.', type = 'success' })
end

RegisterCommand('laver', function()
    if not (IsEntityInWater(cache.ped) or IsPedSwimming(cache.ped)) then
        return lib.notify({ description = 'Il faut de l\'eau : un lavabo, une douche, une fontaine (Alt) ou la mer.', type = 'error' })
    end
    wash('Tu te rinces dans l\'eau…')
end, false)

-- 118 (allégé) · Démarche blessée ---------------------------------------------------------------------------------
local injuredUntil = 0 -- heure réseau (secondes)
local function clipset()
    return GetEntityModel(cache.ped) == GetHashKey('mp_f_freemode_01') and Config.Injured.clipset.f or Config.Injured.clipset.m
end

local function applyWalk()
    local set = clipset()
    lib.requestAnimSet(set, 3000)
    SetPedMovementClipset(cache.ped, set, 1.0)
    RemoveAnimSet(set)
end

local function cure(msg)
    if injuredUntil == 0 then return end
    injuredUntil = 0
    DeleteResourceKvp('gs_vie_injured')
    ResetPedMovementClipset(cache.ped, 1.0)
    if msg then lib.notify({ description = msg, type = 'success' }) end
end

local function injure(seconds)
    local first = injuredUntil == 0
    injuredUntil = GetCloudTimeAsInt() + seconds
    SetResourceKvpInt('gs_vie_injured', injuredUntil)
    applyWalk()
    if not first then return end
    lib.notify({ description = 'Tu boites après cette blessure. Un bandage ou des antidouleurs t\'aideront.', type = 'inform', duration = 8000 })
    CreateThread(function() -- tant que la blessure dure : remet la démarche si autre chose l'a changée (1 fois / 5 s)
        while injuredUntil > 0 do
            if GetCloudTimeAsInt() >= injuredUntil then cure('Tu ne boites plus.') break end
            if GetPedMovementClipset(cache.ped) ~= joaat(clipset()) and not IsPedInAnyVehicle(cache.ped, false) then applyWalk() end
            Wait(5000)
        end
    end)
end

RegisterNetEvent('gs_vie:client:cured', function() cure('La douleur passe : tu marches normalement.') end)

-- qbx_medical : 1 vivant, 2 à terre, 3 mort. Relevé après 2 ou 3 → blessé. [API] state bag qbx_medical
local lastState = 1
AddStateBagChangeHandler('qbx_medical:deathState', ('player:%d'):format(cache.serverId), function(_, _, value)
    value = value or 1
    if lastState >= 2 and value == 1 then SetTimeout(2000, function() injure(Config.Injured.minutes * 60) end) end
    lastState = value
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function() -- [API] qbx_core · blessure gardée à la reconnexion
    local untilT = GetResourceKvpInt('gs_vie_injured')
    local left = untilT - GetCloudTimeAsInt()
    if left > 5 then SetTimeout(3000, function() injure(left) end) else DeleteResourceKvp('gs_vie_injured') end
end)

-- 120 · Passagers bavards -----------------------------------------------------------------------------------------
local function npcPassenger(veh)
    for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and not IsPedAPlayer(p) and not IsPedDeadOrDying(p, true) then return p end
    end
end

lib.onCache('vehicle', function(veh)
    if not veh then return end
    CreateThread(function()
        local nextTalk = GetGameTimer() + math.random(Config.Passengers.every[1], Config.Passengers.every[2]) * 1000
        while cache.vehicle == veh do
            Wait(Config.Passengers.check)
            if cache.vehicle ~= veh then break end
            if GetGameTimer() >= nextTalk and GetPedInVehicleSeat(veh, -1) == cache.ped then
                nextTalk = GetGameTimer() + math.random(Config.Passengers.every[1], Config.Passengers.every[2]) * 1000
                local p = npcPassenger(veh)
                if p and math.random() < Config.Passengers.chance then
                    local text = lib.callback.await('gs_vie:rumor', false)
                    if text and cache.vehicle == veh then
                        PlayPedAmbientSpeechNative(p, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE')
                        lib.notify({ title = 'Passager', description = ('« %s »'):format(text), type = 'inform', icon = 'comment', duration = 10000 })
                    end
                end
            end
        end
    end)
end)

-- Cibles ox_target ------------------------------------------------------------------------------------------------
CreateThread(function()
    exports.ox_target:addModel(Config.Dumpster.models, { -- [API] ox_target
        { name = 'gs_vie_bin', icon = 'fa-solid fa-dumpster', label = 'Fouiller la poubelle', distance = 2.0,
          onSelect = function(data) searchBin(data.entity) end },
    })
    exports.ox_target:addModel(Config.Wash.models, {
        { name = 'gs_vie_wash', icon = 'fa-solid fa-hands-bubbles', label = 'Se laver', distance = 2.0, onSelect = function() wash() end },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if injuredUntil > 0 then ResetPedMovementClipset(cache.ped, 1.0) end
end)
