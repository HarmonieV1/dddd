-- gs_memoire (client) · V12. 1) Quand on passe près d'un lieu chargé, un passant (PNJ du jeu, le plus proche) lâche une
-- phrase au-dessus de sa tête ; sinon une notification discrète. 2) La nuit, les « échos » : silhouettes translucides,
-- locales, qui rejouent le genre d'événement dominant (signature RoadLine : la ville se souvient, et parfois elle le montre).
local told = {}       -- [id] = GetGameTimer() du dernier rappel
local echoes = {}     -- [id] = { peds = {}, until }
local bubble          -- { ped, text, until }

local function places() return GlobalState.gsMemoire or {} end

local function lineFor(p)
    local list = Config.Lines[p.kind] or Config.Lines.generic
    local l = list[math.random(#list)]
    if p.text and p.text ~= '' and math.random() < 0.5 then l = p.text end
    return l
end

--- PNJ (pas un joueur, pas en véhicule, vivant) le plus proche du joueur
local function nearbyPed()
    local me = GetEntityCoords(cache.ped)
    local best, bestD
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped and not IsPedAPlayer(ped) and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) and IsPedHuman(ped) then
            local d = #(GetEntityCoords(ped) - me)
            if d < Config.Talk.pedRange and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    return best
end

local function say(ped, text)
    bubble = { ped = ped, text = '« ' .. text .. ' »', untilAt = GetGameTimer() + 7000 }
    PlayAmbientSpeech1(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE')
    CreateThread(function()
        -- par frame : seulement pendant les 7 s de la bulle d'un passant
        while bubble and GetGameTimer() < bubble.untilAt do
            if not DoesEntityExist(bubble.ped) then break end
            local c = GetPedBoneCoords(bubble.ped, 31086, 0.0, 0.0, 0.0)
            local on, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 0.5)
            if on then
                SetTextFont(4) SetTextScale(0.0, 0.36) SetTextCentre(true) SetTextOutline() SetTextColour(255, 214, 120, 235)
                BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(bubble.text) EndTextCommandDisplayText(x, y)
            end
            Wait(0)
        end
        bubble = nil
    end)
end

local function isNight()
    local h = GetClockHours()
    local n = Config.Echo.night
    return h >= n.from or h < n.to
end

local function spawnEcho(p)
    local def = Config.Echoes[p.kind] or Config.Echoes.generic
    local peds = {}
    for i, model in ipairs(def.peds) do
        local hash = GetHashKey(model)
        if lib.requestModel(hash, 4000) then
            local a = (i - 1) * 2.1
            local x, y = p.x + math.cos(a) * 1.3, p.y + math.sin(a) * 1.3
            local _, gz = GetGroundZFor_3dCoord(x, y, p.z + 5.0, false)
            local ped = CreatePed(4, hash, x, y, gz or p.z, math.deg(a) + 180.0, false, false)
            SetModelAsNoLongerNeeded(hash)
            SetEntityAlpha(ped, Config.Echo.alpha, false)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityCollision(ped, false, false)
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, def.scenario, 0, true)
            peds[#peds + 1] = ped
        end
    end
    echoes[p.id] = { peds = peds, untilAt = GetGameTimer() + Config.Echo.seconds * 1000, text = def.text, shown = false }
end

local function killEcho(id)
    for _, ped in ipairs(echoes[id] and echoes[id].peds or {}) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    echoes[id] = nil
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local now = GetGameTimer()
        local night = isNight()
        local active = 0
        for _ in pairs(echoes) do active = active + 1 end
        for _, p in ipairs(places()) do
            local d = #(me - vec3(p.x, p.y, p.z))
            -- 1) le passant qui parle
            if d < Config.Talk.reach and (not told[p.id] or now - told[p.id] > Config.Talk.cooldown * 1000) then
                told[p.id] = now
                local ped = nearbyPed()
                if ped then say(ped, lineFor(p))
                else lib.notify({ title = 'La ville se souvient', description = lineFor(p), icon = 'landmark', duration = 7000 }) end
            end
            -- 2) les échos de la nuit
            local e = echoes[p.id]
            if e then
                if d > Config.Echo.range + 20.0 or now > e.untilAt or not night then killEcho(p.id)
                elseif not e.shown and d < 18.0 then
                    e.shown = true
                    lib.notify({ title = 'Un écho', description = e.text, icon = 'ghost', duration = 8000 })
                end
            elseif night and p.n >= Config.EchoAt and d < Config.Echo.range and active < Config.Echo.max and math.random() < 0.35 then
                spawnEcho(p)
                active = active + 1
            end
        end
        Wait(3000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(echoes) do killEcho(id) end
    bubble = nil
end)
