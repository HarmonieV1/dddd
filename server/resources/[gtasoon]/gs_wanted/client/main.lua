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
    -- V10.2 : gs_evidence détecte déjà les tirs (une seule boucle) ; celle-ci ne sert que s'il est arrêté
    if GetResourceState('gs_evidence') == 'started' then return end
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
    if r.desc and #r.desc > 0 then parts[#parts + 1] = (r.crime == 'anonymous_call' and 'Message : ' or 'Suspect : ') .. table.concat(r.desc, ', ') end -- V12.60 : cabines
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
-- V12.63 · Police IA graduée : niveau courant (lu par chaque patrouille à chaque passage : une escalade change tout de suite le
-- comportement de toutes les patrouilles), agents présents (négociation, menaces).
local npcStars = 0
local copPeds = {}   -- [ped] = true
local armed = {}     -- [ped] = niveau pour lequel l'arme a été donnée

--- Arme de l'agent selon le niveau (taser à 1-2 ★, arme à feu ensuite), donnée une fois par niveau
local function ensureWeapon(ped, level)
    if armed[ped] == level then return end
    armed[ped] = level
    local W = Config.NpcPolice.units.weapons[math.min(#Config.NpcPolice.units.weapons, math.max(1, level))]
    if W then
        local h = GetHashKey(W)
        GiveWeaponToPed(ped, h, 120, false, level >= 2)
        if level <= 1 then SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true) end -- 1 ★ : arme rangée
    end
end

local function nearestCop(range)
    local me, best, bestD = GetEntityCoords(cache.ped), nil, range
    for cop in pairs(copPeds) do
        if DoesEntityExist(cop) and not IsEntityDead(cop) then
            local d = #(GetEntityCoords(cop) - me)
            if d < bestD then best, bestD = cop, d end
        else copPeds[cop] = nil end
    end
    return best
end

--- Négociation à 1 ★ ([E] près de l'agent) : se rendre, rançon, otage (si un civil est en joue tout près), refuser
local function negotiateMenu(hostage)
    local N = Config.NpcPolice.negotiate
    local function go(choice, h)
        local ok, msg = lib.callback.await('gs_wanted:negotiate', false, choice, h)
        lib.notify({ title = 'Négociation', description = msg, type = ok and 'success' or 'error', duration = 8000 })
        if ok and choice == 'hostage' and hostage and DoesEntityExist(hostage.ped) then
            ClearPedTasks(hostage.ped)
            TaskSmartFleePed(hostage.ped, cache.ped, 100.0, -1, false, false)
        end
    end
    local opts = {
        { title = 'Me rendre', icon = 'handcuffs', description = ('Amende (à partir de %d $ selon tes délits), l\'affaire est classée'):format(N.surrender.base),
          onSelect = function() go('surrender') end },
        { title = ('Proposer %d $ pour qu\'il me laisse filer'):format(N.ransom), icon = 'money-bill-wave', description = 'Liquide d\'abord, sinon la banque',
          onSelect = function() go('ransom') end },
    }
    if hostage then
        opts[#opts + 1] = { title = 'L\'otage contre ma fuite', icon = 'user-lock', description = 'Le civil que tu tiens en joue est libéré, la police te laisse partir',
            onSelect = function() go('hostage', hostage.net) end }
    end
    opts[#opts + 1] = { title = 'Refuser de discuter', icon = 'hand', iconColor = '#ff4d6d', description = 'Ils durcissent le ton (2 ★)', onSelect = function() go('refuse') end }
    lib.registerContext({ id = 'gs_wanted_nego', title = 'Agent de police · « On peut s\'arranger. »', options = opts })
    lib.showContext('gs_wanted_nego')
end

--- Civil tenu en joue à moins de 6 m (otage possible) : { ped, net } ou nil
local function hostageInSight()
    if not IsPlayerFreeAiming(PlayerId()) then return nil end
    local hit, ped = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not hit or not ped or ped == 0 or not IsEntityAPed(ped) or IsPedAPlayer(ped) or copPeds[ped] or IsPedDeadOrDying(ped, true) then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) > Config.NpcPolice.negotiate.hostageReach then return nil end
    if not NetworkGetEntityIsNetworked(ped) then return nil end
    return { ped = ped, net = NetworkGetNetworkIdFromEntity(ped) }
end

RegisterNetEvent('gs_wanted:client:npcStandDown', function()
    npcStars = 0
    ClearPlayerWantedLevel(PlayerId())
    SetPlayerWantedLevelNow(PlayerId(), false)
end)

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

--- Donne leurs ordres aux agents : sirène, poursuite au volant, combat à pied.
--- V12.59 (backtest 15/10 : « la voiture pop mais ne poursuit pas, il faut passer dans son champ de vision ») : avant, un
--- seul ordre au départ ; à 170 m le jeu attendait qu'ils voient le suspect. Maintenant ils connaissent sa position :
--- au-delà de `track.chase` m, ils foncent vers lui (route), de près ils le prennent en chasse ; à pied, ils descendent et
--- l'interpellent. Au-delà de `track.giveUp` m ou une fois les étoiles perdues, ils lâchent (on peut toujours les semer).
local function setupCop(ped)
    SetPedRelationshipGroupHash(ped, COP)
    SetPedAsCop(ped, true)
    SetPedCombatAttributes(ped, 46, true) -- se bat jusqu'au bout
    SetPedKeepTask(ped, true)
    SetDriverAbility(ped, 1.0) SetDriverAggressiveness(ped, 0.8)
end

--- V12.62 · Hélicoptère de la police IA (poursuite filmée) : il tourne au-dessus du suspect, projecteur allumé la nuit,
--- tant que les étoiles restent. Ordre renouvelé toutes les 5 s (le suspect bouge) ; supprimé par le serveur ensuite.
local function heliUnit(u)
    local H = Config.NpcPolice.heli
    local t = GetGameTimer() + 5000
    while not (NetworkDoesEntityExistWithNetworkId(u.veh) and NetworkDoesEntityExistWithNetworkId(u.peds[1] or -1)) and GetGameTimer() < t do Wait(100) end
    if not NetworkDoesEntityExistWithNetworkId(u.veh) or not NetworkDoesEntityExistWithNetworkId(u.peds[1] or -1) then return end
    local heli, pilot = NetToVeh(u.veh), NetToPed(u.peds[1])
    if not control(heli) or not control(pilot) then return end
    SetPedKeepTask(pilot, true)
    SetBlockingOfNonTemporaryEvents(pilot, true)
    SetVehicleEngineOn(heli, true, true, false)
    SetHeliBladesFullSpeed(heli)
    while DoesEntityExist(heli) and DoesEntityExist(pilot) and not IsEntityDead(pilot) and GetPlayerWantedLevel(PlayerId()) > 0 do
        if NetworkHasControlOfEntity(pilot) then
            -- [native] TaskHeliMission : 9 = tourner autour de la cible, à `height` m au-dessus
            TaskHeliMission(pilot, heli, 0, cache.ped, 0.0, 0.0, 0.0, 9, 30.0, H.radius, -1.0, math.floor(H.height), math.floor(H.height * 0.6), -1.0, 0)
            local hour = GetClockHours()
            SetVehicleSearchlight(heli, hour >= 20 or hour < 6, true)
        end
        Wait(5000)
    end
end

local function command(units)
    local T = Config.NpcPolice.track or { every = 1500, chase = 60.0, giveUp = 450.0, speed = 42.0, onFoot = 35.0 } -- V12.62 : le bon chemin dans la config
    for _, u in ipairs(units) do
        if u.heli then CreateThread(function() heliUnit(u) end) goto continue end
        CreateThread(function()
            local t = GetGameTimer() + 5000
            while not NetworkDoesEntityExistWithNetworkId(u.veh) and GetGameTimer() < t do Wait(100) end
            if not NetworkDoesEntityExistWithNetworkId(u.veh) then return end
            local veh = NetToVeh(u.veh)
            if control(veh) then SetVehicleSiren(veh, true) SetVehicleHasMutedSirens(veh, false) end
            local peds = {}
            for _, nid in ipairs(u.peds) do
                local t2 = GetGameTimer() + 3000
                while not NetworkDoesEntityExistWithNetworkId(nid) and GetGameTimer() < t2 do Wait(100) end
                local ped = NetworkDoesEntityExistWithNetworkId(nid) and NetToPed(nid)
                if ped and control(ped) then setupCop(ped) peds[#peds + 1] = ped copPeds[ped] = true end
            end
            local mode = {} -- [ped] = dernier ordre donné ('drive', 'chase', 'combat') : pas de ré-ordre à chaque passage
            while #peds > 0 and DoesEntityExist(veh) and GetPlayerWantedLevel(PlayerId()) > 0 do
                local me = GetEntityCoords(cache.ped)
                local d = #(GetEntityCoords(veh) - me)
                if d > T.giveUp then break end -- trop loin : semés
                local suspectOnFoot = not cache.vehicle
                local level = math.max(1, npcStars)
                for _, ped in ipairs(peds) do
                    if DoesEntityExist(ped) and not IsEntityDead(ped) and NetworkHasControlOfEntity(ped) then
                        ensureWeapon(ped, level)
                        local pd = #(GetEntityCoords(ped) - me)
                        local isDriver = GetPedInVehicleSeat(veh, -1) == ped
                        local inCar = IsPedInAnyVehicle(ped, false)
                        local want
                        if level <= 1 then
                            -- V12.63 · 1 ★ : ils viennent PARLER. À pied : ils descendent, s'approchent à 5 m et attendent face au
                            -- suspect ([E] Parler à l'agent). En voiture : ils suivent à distance, sans percuter.
                            if suspectOnFoot then
                                if inCar then want = pd < 45.0 and 'exit' or (isDriver and 'drive' or nil)
                                else want = pd > 8.0 and 'approach' or (pd <= 6.0 and 'talk' or mode[ped]) end
                            elseif isDriver then want = d > T.chase and 'drive' or 'follow'
                            elseif not inCar then want = 'enter' end
                        elseif suspectOnFoot and pd < T.onFoot then want = 'combat' -- 2 ★ : au taser ; 3 ★ et plus : arme à feu
                        elseif isDriver then want = d > T.chase and 'drive' or 'chase' -- V12.62 : le conducteur, pas « le 1er contrôlé »
                        elseif not inCar then want = 'combat' end
                        if want == 'drive' then -- position connue : on y va par la route, sirène hurlante (renouvelé : il bouge)
                            TaskVehicleDriveToCoordLongrange(ped, veh, me.x, me.y, me.z, T.speed, 787004, 15.0)
                            mode[ped] = 'drive'
                        elseif want and mode[ped] ~= want then
                            if want == 'chase' then
                                TaskVehicleChase(ped, cache.ped)
                                SetTaskVehicleChaseIdealPursuitDistance(ped, level <= 2 and 12.0 or 0.0)
                            elseif want == 'follow' then
                                TaskVehicleFollow(ped, veh, cache.vehicle or cache.ped, 25.0, 786603, 20)
                            elseif want == 'exit' then
                                TaskLeaveVehicle(ped, veh, 256)
                            elseif want == 'enter' then
                                TaskEnterVehicle(ped, veh, 10000, 0, 1.5, 1, 0)
                            elseif want == 'approach' then
                                TaskGoToEntity(ped, cache.ped, -1, 5.0, 1.6, 1073741824, 0)
                            elseif want == 'talk' then
                                ClearPedTasks(ped)
                                TaskTurnPedToFaceEntity(ped, cache.ped, -1)
                            else
                                TaskCombatPed(ped, cache.ped, 0, 16)
                            end
                            mode[ped] = want
                        end
                    end
                end
                Wait(T.every)
            end
            -- V12.63 : fin (semés, accord, plus d'étoiles) : les agents remontent et repartent au lieu de rester figés
            for _, ped in ipairs(peds) do
                copPeds[ped], armed[ped] = nil, nil
                if DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
                    ClearPedTasks(ped)
                    if GetPedInVehicleSeat(veh, -1) == ped then TaskVehicleDriveWander(ped, veh, 20.0, 786603) else TaskWanderStandard(ped, 10.0, 10) end
                end
            end
        end)
        ::continue::
    end
end

RegisterNetEvent('gs_wanted:client:npcPolice', function(stars)
    stars = math.max(1, math.min(5, tonumber(stars) or 1))
    local pid = PlayerId()
    local escalated = npcStars > 0 and stars > npcStars
    npcStars = math.max(npcStars, stars)
    setStars(true)
    if GetPlayerWantedLevel(pid) < stars then
        SetPlayerWantedLevel(pid, stars, false)
        SetPlayerWantedLevelNow(pid, false)
    end
    local LINES = { [1] = 'Un agent vient te parler : [E] près de lui pour négocier (te rendre, t\'arranger, ou l\'otage contre ta fuite).',
        [2] = 'La police veut t\'interpeller au taser. Sème-les !', [3] = 'La police ouvre le feu. Sème-les !' }
    lib.notify({ title = escalated and 'La police durcit le ton' or 'Police de Los Santos', description = ('%d ★ · %s'):format(stars, LINES[math.min(3, stars)]),
        type = 'error', icon = 'handcuffs', duration = 9000 })
    command(lib.callback.await('gs_wanted:npcUnits', false, stars, roadPositions(math.min(stars, Config.NpcPolice.units.maxUnits))) or {})
    if npcActive then return end
    npcActive = true
    CreateThread(function()
        Wait(5000)
        local nextThreat = 0
        -- V12.63 : pendant la recherche, 2 à 3 fois par seconde (par image seulement à côté d'un agent, pour le [E]) :
        -- menace sur un agent (le viser à 1 ★, le frapper) = escalade ; à 1 ★, négociation avec l'agent le plus proche
        while GetPlayerWantedLevel(PlayerId()) > 0 do
            local wait = 400
            local now = GetGameTimer()
            if npcStars > 0 and npcStars <= 2 and now >= nextThreat then
                for cop in pairs(copPeds) do
                    if DoesEntityExist(cop) and (HasEntityBeenDamagedByEntity(cop, cache.ped, true) or (npcStars == 1 and IsPlayerFreeAimingAtEntity(PlayerId(), cop))) then
                        nextThreat = now + 15000
                        ClearEntityLastDamageEntity(cop)
                        TriggerServerEvent('gs_wanted:server:escalate')
                        break
                    end
                end
            end
            if npcStars == 1 and not cache.vehicle and nearestCop(7.0) then
                wait = 0
                SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline() SetTextColour(40, 224, 255, 240)
                BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName('[E] Parler à l\'agent') EndTextCommandDisplayText(0.5, 0.88)
                if IsControlJustReleased(0, 38) and not IsNuiFocused() then negotiateMenu(hostageInSight()) end
            end
            Wait(wait)
        end
        npcStars = 0
        setStars(false)
        npcActive = false
        TriggerServerEvent('gs_wanted:server:npcClear')
        lib.notify({ description = 'La police a perdu ta trace.', type = 'success' })
    end)
end)

-- V12.43 · Résumé de la tenue pour les témoins (le serveur ne peut pas la lire lui-même) : composants 0 à 11
-- (modèle, texture) + couvre-chef, publié dans le state bag `gsLook` seulement quand il change (vérifié toutes les 3 s).
CreateThread(function()
    local last
    while true do
        local ped = cache.ped
        local c = {}
        for comp = 0, 11 do c[comp + 1] = { GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp) } end
        local hat = GetPedPropIndex(ped, 0)
        local key = json.encode(c) .. hat
        if key ~= last then
            last = key
            LocalPlayer.state:set('gsLook', { c = c, hat = hat }, true)
        end
        Wait(3000)
    end
end)
