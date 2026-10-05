-- gs_wanted (client) : détection des tirs / car-jacking, étoiles de chaleur, dispatch police.
-- Aucune boucle par frame hors arme à feu en main ou chaleur > 0.
local heat = 0
local reports = {}

-- Tirs : boucle par frame UNIQUEMENT tant qu'une arme à feu est en main -------------------------
local watchToken = 0

local function watchShots(weapon)
    watchToken = watchToken + 1
    local token = watchToken
    CreateThread(function()
        while cache.weapon == weapon and token == watchToken do
            if IsPedShooting(cache.ped) then
                TriggerServerEvent('gs_wanted:server:shot', IsPedCurrentWeaponSilenced(cache.ped))
                Wait(10000)
            else
                Wait(0)
            end
        end
    end)
end

local function onWeapon(weapon)
    if weapon and GetWeaponDamageType(weapon) == 3 then watchShots(weapon) end -- 3 = balles
end
lib.onCache('weapon', onWeapon)
CreateThread(function() onWeapon(cache.weapon) end) -- arme déjà en main au (re)démarrage

-- Car-jacking : vérif légère 4 fois / seconde
CreateThread(function()
    while true do
        if IsPedJacking(cache.ped) then
            TriggerServerEvent('gs_wanted:server:carjack')
            Wait(20000)
        end
        Wait(250)
    end
end)

-- Étoiles de chaleur (visibles seulement quand on est signalé) ------------------------------------
local drawing = false
local function drawStars()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while heat > 0 do
            local stars = math.ceil(heat / 20)
            SetTextFont(4)
            SetTextScale(0.0, 0.55)
            SetTextColour(255, 46, 136, 230)
            SetTextOutline()
            SetTextRightJustify(true)
            SetTextWrap(0.0, 0.985)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('RECHERCHÉ ' .. ('★'):rep(stars) .. ('☆'):rep(5 - stars))
            EndTextCommandDisplayText(0.985, 0.03)
            Wait(0)
        end
        drawing = false
    end)
end

RegisterNetEvent('gs_wanted:client:heat', function(value)
    heat = value or 0
    TriggerEvent('gs_wanted:client:heatChanged', heat) -- le HUD néon affiche les étoiles
    if heat > 0 and GetResourceState('gs_hud') ~= 'started' then drawStars() end
end)

-- Dispatch police ----------------------------------------------------------------------------------
local function streetOf(c)
    local a, b = GetStreetNameAtCoord(c.x, c.y, c.z)
    local main, cross = GetStreetNameFromHashKey(a), b ~= 0 and GetStreetNameFromHashKey(b) or ''
    return cross ~= '' and ('%s / %s'):format(main, cross) or main
end

local function describe(r)
    if r.detector then return ('n°%d · %s · ±%d m · %s'):format(r.id or 0, streetOf(r.coords), r.radius, 'détection automatique, pas de description') end
    local street = streetOf(r.coords)
    local who = r.witnesses == -1 and 'constaté par un agent'
        or (r.witnesses == 0 and 'appel anonyme' or ('%d témoin(s)'):format(r.witnesses))
    local parts = { ('%s · ±%d m'):format(street, r.radius), who }
    if r.camera then parts[#parts + 1] = 'Caméra : ' .. r.camera end
    if r.model then
        local name = GetLabelText(GetDisplayNameFromVehicleModel(r.model))
        parts[#parts + 1] = ('%s %s'):format(name, r.plate or '')
    end
    -- La ville se souvient : description brute des témoins
    if r.desc and #r.desc > 0 then parts[#parts + 1] = 'Suspect : ' .. table.concat(r.desc, ', ') end
    if r.named then parts[#parts + 1] = ('Un témoin pense reconnaître %s'):format(r.named) end
    if r.linked then parts[#parts + 1] = ('Même %s que le signalement n°%d'):format(r.linkedBy or 'description', r.linked) end
    return ('n°%d · '):format(r.id or 0) .. table.concat(parts, ' · ')
end

RegisterNetEvent('gs_wanted:client:dispatch', function(r)
    table.insert(reports, 1, r)
    reports[11] = nil
    lib.notify({ title = ('Central : %s · %s'):format(r.label, streetOf(r.coords)), description = describe(r), type = 'warning', icon = 'tower-broadcast', duration = 10000 })
    if not IsWaypointActive() then SetNewWaypoint(r.coords.x, r.coords.y) end -- GPS posé si aucun itinéraire en cours
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)

    local area = AddBlipForRadius(r.coords.x, r.coords.y, r.coords.z, r.radius + 0.0)
    SetBlipColour(area, 1)
    SetBlipAlpha(area, 90)
    local blip = AddBlipForCoord(r.coords.x, r.coords.y, r.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(r.label)
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.Dispatch.blipSeconds * 1000, function()
        RemoveBlip(area)
        RemoveBlip(blip)
    end)
end)

RegisterCommand('dispatch', function()
    local list = lib.callback.await('gs_wanted:history', false) or {}
    local options = {}
    for _, r in ipairs(list) do
        options[#options + 1] = {
            title = r.label, description = describe(r), icon = 'location-crosshairs',
            onSelect = function() SetNewWaypoint(r.coords.x, r.coords.y) end,
        }
    end
    if #options == 0 then options[1] = { title = 'Aucun signalement récent', readOnly = true } end
    lib.registerContext({ id = 'gs_dispatch', title = 'Central LSPD', options = options })
    lib.showContext('gs_dispatch')
end, false)

-- Police IA (aucun policier joueur en service) : étoiles du jeu + patrouilles créées par le serveur ---------------
-- (le « dispatch » du jeu reste coupé : avec la protection des entités du serveur il créait des voitures vides)
local npcActive = false
local COP = GetHashKey('COP')

local function setStars(on)
    for i = 1, 15 do EnableDispatchService(i, false) end
    SetMaxWantedLevel(on and 5 or 0)
end

--- Positions de route à ~170 m autour du joueur (le serveur crée les voitures là, hors de vue)
local function roadPositions(n)
    local me = GetEntityCoords(cache.ped)
    local out = {}
    local base = math.random() * math.pi * 2
    for i = 1, n + 2 do
        local a = base + (i / (n + 2)) * math.pi * 2
        local p = me + vec3(math.cos(a), math.sin(a), 0.0) * Config.NpcPolice.units.spawnDistance
        local ok, node, heading = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
        if ok then out[#out + 1] = { x = node.x, y = node.y, z = node.z + 0.5, w = heading } end
    end
    return out
end

local function control(ent)
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < t do NetworkRequestControlOfEntity(ent) Wait(50) end
    return NetworkHasControlOfEntity(ent)
end

--- Donne leurs ordres aux agents : sirène, poursuite au volant, combat à pied
local function command(units)
    for _, u in ipairs(units) do
        CreateThread(function()
            local t = GetGameTimer() + 5000
            while not NetworkDoesEntityExistWithNetworkId(u.veh) and GetGameTimer() < t do Wait(100) end
            if not NetworkDoesEntityExistWithNetworkId(u.veh) then return end
            local veh = NetToVeh(u.veh)
            if control(veh) then SetVehicleSiren(veh, true) SetVehicleHasMutedSirens(veh, false) end
            for i, nid in ipairs(u.peds) do
                local t2 = GetGameTimer() + 3000
                while not NetworkDoesEntityExistWithNetworkId(nid) and GetGameTimer() < t2 do Wait(100) end
                local ped = NetworkDoesEntityExistWithNetworkId(nid) and NetToPed(nid)
                if ped and control(ped) then
                    SetPedRelationshipGroupHash(ped, COP)
                    SetPedAsCop(ped, true)
                    SetPedCombatAttributes(ped, 46, true) -- se bat jusqu'au bout
                    SetPedKeepTask(ped, true)
                    if i == 1 then
                        TaskVehicleChase(ped, cache.ped)
                        SetTaskVehicleChaseIdealPursuitDistance(ped, 0.0)
                    else
                        TaskCombatPed(ped, cache.ped, 0, 16)
                    end
                end
            end
        end)
    end
end

RegisterNetEvent('gs_wanted:client:npcPolice', function(stars)
    stars = math.max(1, math.min(5, tonumber(stars) or 1))
    local pid = PlayerId()
    setStars(true)
    if GetPlayerWantedLevel(pid) < stars then
        SetPlayerWantedLevel(pid, stars, false)
        SetPlayerWantedLevelNow(pid, false)
    end
    lib.notify({ title = 'Police de Los Santos', description = ('Tu es recherché (%d ★). Sème-les !'):format(stars), type = 'error', icon = 'handcuffs' })
    command(lib.callback.await('gs_wanted:npcUnits', false, stars, roadPositions(math.min(stars, Config.NpcPolice.units.maxUnits))) or {})
    if npcActive then return end
    npcActive = true
    CreateThread(function()
        Wait(5000)
        while GetPlayerWantedLevel(PlayerId()) > 0 do Wait(2000) end
        setStars(false)
        npcActive = false
        TriggerServerEvent('gs_wanted:server:npcClear')
        lib.notify({ description = 'La police a perdu ta trace.', type = 'success' })
    end)
end)
