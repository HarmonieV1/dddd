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

-- V12.63 · Geste devant un objet : animation (version femme si prévue), puis effet (propre, désaltéré)
local function gesture(o)
    if lib.progressActive() or cache.vehicle then return end
    local female = GetEntityModel(cache.ped) == GetHashKey('mp_f_freemode_01')
    local dict, clip = (female and o.dictF) or o.dict, (female and o.clipF) or o.clip
    if not lib.progressBar({ duration = o.ms or 5000, label = o.label .. '…', canCancel = true,
        anim = { dict = dict, clip = clip, flag = 49 }, disable = { move = true, car = true, combat = true } }) then return end
    if o.clean then cleanUp(cache.ped) end
    lib.notify({ description = o.drink and 'Ça fait du bien.' or 'Propre comme un sou neuf.', type = 'success' })
end
RegisterNetEvent('gs_vie:client:cleaned', function() cleanUp(cache.ped) lib.notify({ description = 'Un secouriste a nettoyé tes plaies.', type = 'success' }) end)

-- V12.63 · Dans la mer (ou un lac) : E pour se rincer, proposé seulement si on a pied, à pied, et sale ou ensanglanté
CreateThread(function()
    local shown = false
    while true do
        local ped = cache.ped
        local can = IsEntityInWater(ped) and not IsPedSwimming(ped) and not cache.vehicle and not lib.progressActive()
        if can ~= shown then
            shown = can
            if can then lib.showTextUI('[E] Se rincer dans l\'eau', { position = 'left-center', icon = 'water' }) else lib.hideTextUI() end
        end
        if can then
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then lib.hideTextUI() shown = false wash('Tu te rinces dans l\'eau…') end
            Wait(0)
        else Wait(1000) end
    end
end)

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
-- V12.63 (backtest : deux options sur les poubelles) : ox_inventory ajoute aussi « Fouiller la benne » (inventaire de
-- stockage) sur les mêmes modèles. On retire toutes les options de ces bennes puis on remet SEULEMENT la nôtre (fouille
-- animée, butin serveur) ; refait quand ox_inventory (re)démarre, et une fois le personnage chargé (il ajoute la sienne tard).
local function binTargets()
    pcall(function() exports.ox_target:removeModel(Config.Dumpster.models) end) -- [API] ox_target (sans nom : toutes les options)
    exports.ox_target:addModel(Config.Dumpster.models, { -- [API] ox_target
        { name = 'gs_vie_bin', icon = 'fa-solid fa-dumpster', label = 'Fouiller la poubelle', distance = 2.0,
          onSelect = function(data) searchBin(data.entity) end },
    })
end
AddEventHandler('onClientResourceStart', function(res) if res == 'ox_inventory' then SetTimeout(3000, binTargets) end end)
AddEventHandler('gs_bridge:client:playerLoaded', function() SetTimeout(5000, binTargets) end)
CreateThread(function()
    binTargets()
    SetTimeout(15000, binTargets) -- filet : ox_inventory a pu ajouter la sienne après nous
    -- V12.63 : gestes selon l'objet (Config.Gestures) ; les modèles qui n'y sont pas gardent « Se laver »
    local covered = {}
    for kind, g in pairs(Config.Gestures or {}) do
        if type(g) == 'table' and g.models then
            for _, m in ipairs(g.models) do covered[m] = true end
            local opts = {}
            for i, o in ipairs(g.options) do
                opts[#opts + 1] = { name = ('gs_vie_%s_%d'):format(kind, i), icon = o.icon, label = o.label, distance = 2.0, onSelect = function() gesture(o) end }
            end
            exports.ox_target:addModel(g.models, opts) -- [API] ox_target
        end
    end
    local rest = {}
    for _, m in ipairs(Config.Wash.models) do if not covered[m] then rest[#rest + 1] = m end end
    if #rest > 0 then
        exports.ox_target:addModel(rest, {
            { name = 'gs_vie_wash', icon = 'fa-solid fa-hands-bubbles', label = 'Se laver', distance = 2.0, onSelect = function() wash() end },
        })
    end
    -- EMS en service : nettoyer les plaies d'un joueur
    exports.ox_target:addGlobalPlayer({ -- [API] ox_target
        { name = 'gs_vie_ems_clean', icon = 'fa-solid fa-kit-medical', label = 'Nettoyer les plaies', distance = 2.0,
          canInteract = function() local ok, j = pcall(function() return exports.gs_bridge:GetJob() end) return ok and j and j.name == Config.Gestures.emsJob and j.onduty end,
          onSelect = function(data)
              if lib.progressActive() then return end
              if not lib.progressBar({ duration = Config.Gestures.emsMs, label = 'Tu nettoies les plaies…', canCancel = true,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, disable = { move = true, car = true, combat = true } }) then return end
              local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
              local ok, msg = lib.callback.await('gs_vie:emsClean', false, target)
              lib.notify({ description = msg, type = ok and 'success' or 'error' })
          end },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if injuredUntil > 0 then ResetPedMovementClipset(cache.ped, 1.0) end
end)
