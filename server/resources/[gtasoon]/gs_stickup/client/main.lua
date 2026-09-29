-- gs_stickup (client) : vise un PNJ avec une arme, [E] pour le braquer. La peur monte avec l'arme pointée et la voix
-- (chuchoter < parler < CRIER, portée pma-voice sur ²). À 100 %, il te tend l'argent. Arme baissée : il s'enfuit.
local UNARMED = GetHashKey('WEAPON_UNARMED')
local zones = {}        -- [id] = { kind, label, coords }
local tellers = {}      -- [id] = ped (créés localement près des agences)
local robbed = {}       -- [ped] = true (on ne braque pas deux fois la même personne)
local active = false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function tellerOf(ped)
    for id, h in pairs(tellers) do if h == ped then return id end end
end

--- Type de victime : guichetier, caissier (près d'un comptoir) ou passant.
local function classify(ped)
    local tid = tellerOf(ped)
    if tid then return 'teller', tid end
    local c = GetEntityCoords(ped)
    for id, z in pairs(zones) do
        if z.kind == 'register' and #(c - vec3(z.coords.x, z.coords.y, z.coords.z)) < Config.Kinds.register.radius then return 'register', id end
    end
    return 'street'
end

local function eligible(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsEntityAPed(ped) or IsPedAPlayer(ped) then return false end
    if IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, false) or robbed[ped] then return false end
    local t = GetPedType(ped)
    if t == 6 or t == 27 or t == 28 then return false end -- policiers, SWAT, animaux
    return #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) <= Config.AimRange
end

local function text(str, y)
    SetTextFont(4) SetTextScale(0.0, 0.5) SetTextCentre(true) SetTextOutline() SetTextColour(255, 196, 0, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(str) EndTextCommandDisplayText(0.5, y or 0.84)
end

local function voiceRate()
    if not NetworkIsPlayerTalking(PlayerId()) then return 0, nil end
    local prox = LocalPlayer.state.proximity
    local idx = prox and prox.index or 2
    return Config.Fear.voice[idx] or Config.Fear.voice[2], idx
end

local function control(ped)
    if NetworkGetEntityIsNetworked(ped) then
        NetworkRequestControlOfEntity(ped)
        local t = GetGameTimer() + 800
        while not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do Wait(0) end
    end
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
end

local function release(ped, flee)
    if not DoesEntityExist(ped) then return end
    SetBlockingOfNonTemporaryEvents(ped, false)
    ClearPedTasks(ped)
    if flee then TaskSmartFleePed(ped, cache.ped, 120.0, -1, false, false) end
end

local function handover(ped, kindName)
    if kindName == 'street' then
        lib.requestAnimDict('mp_common', 2000)
        TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 0, 0, false, false, false)
        TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_b', 8.0, -8.0, 2000, 48, 0, false, false, false)
        Wait(2000)
    else
        lib.requestAnimDict('mp_am_hold_up', 2000)
        TaskPlayAnim(ped, 'mp_am_hold_up', 'holdup_victim_20s', 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(5500) -- ouvre la caisse et tend le sac
    end
end

local function robbery(ped, kindName, zoneId)
    local kind = Config.Kinds[kindName]
    local ok, msg = lib.callback.await('gs_stickup:begin', false, kindName, zoneId)
    if not ok then return notify(false, msg) end
    active, robbed[ped] = true, true
    control(ped)
    TaskHandsUp(ped, -1, cache.ped, -1, true)
    local fear, lastAim, last = 0.0, GetGameTimer(), GetGameTimer()
    -- par frame : seulement pendant un braquage en cours (jauge de peur + contrôle de la visée)
    while active do
        local now = GetGameTimer()
        local dt = (now - last) / 1000
        last = now
        local aiming = IsPlayerFreeAimingAtEntity(PlayerId(), ped) and #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) <= Config.AimRange + 2.0
        local vr, idx = voiceRate()
        if aiming then
            lastAim = now
            fear = fear + (Config.Fear.aim + vr) * kind.fearScale * dt
        else
            fear = math.max(0, fear - Config.Fear.decay * dt)
        end
        if IsPedDeadOrDying(ped, true) or IsPedDeadOrDying(cache.ped, true) or now - lastAim > Config.LostAimTime then
            active = false
            TriggerServerEvent('gs_stickup:server:cancel')
            release(ped, true)
            return notify(false, 'Il s\'est enfui… et il appelle la police.')
        end
        local hint = idx == 3 and 'tu cries : il panique !' or idx == 1 and 'tu chuchotes : crie (²) pour l\'intimider' or vr > 0 and 'parle plus fort (²) !' or 'parle-lui (N), crie pour aller plus vite'
        text(('%s · PEUR %d %%'):format(kind.label:upper(), math.min(100, math.floor(fear))), 0.82)
        text(hint, 0.86)
        if fear >= 100 then break end
        Wait(0)
    end
    handover(ped, kindName)
    local done, res = lib.callback.await('gs_stickup:finish', false)
    active = false
    release(ped, true)
    notify(done, res)
end

-- Détection : 4 fois par seconde, seulement avec une arme en main ; boucle rapide seulement en visant une cible possible.
CreateThread(function()
    zones = lib.callback.await('gs_stickup:zones', false) or {}
    while true do
        Wait(250)
        if not active and not cache.vehicle and GetSelectedPedWeapon(cache.ped) ~= UNARMED and IsPlayerFreeAiming(PlayerId()) then
            local hit, ped = GetEntityPlayerIsFreeAimingAt(PlayerId())
            -- par frame : seulement tant qu'on vise un PNJ braquable (affiche [E])
            while hit and eligible(ped) and IsPlayerFreeAimingAtEntity(PlayerId(), ped) and not active do
                local kindName = classify(ped)
                text(('[E] %s'):format(kindName == 'street' and 'Racketter' or kindName == 'register' and 'Braquer la caisse' or 'Braquer le guichet'), 0.86)
                if IsControlJustReleased(0, 38) then
                    local k, zid = classify(ped)
                    robbery(ped, k, zid)
                    break
                end
                Wait(0)
            end
        end
    end
end)

-- Guichetiers des agences : créés localement à moins de 50 m.
CreateThread(function()
    local hash = GetHashKey(Config.TellerModel)
    while true do
        local pos = GetEntityCoords(cache.ped)
        for _, t in ipairs(Config.Tellers) do
            local c = t.coords
            local d = #(pos - vec3(c.x, c.y, c.z))
            if d < 50.0 and not tellers[t.id] then
                lib.requestModel(hash, 5000)
                local p = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
                SetEntityInvincible(p, true)
                SetBlockingOfNonTemporaryEvents(p, true)
                TaskStartScenarioInPlace(p, 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
                tellers[t.id] = p
            elseif d > 70.0 and tellers[t.id] then
                DeletePed(tellers[t.id])
                robbed[tellers[t.id]] = nil
                tellers[t.id] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(tellers) do if DoesEntityExist(p) then DeletePed(p) end end
end)
