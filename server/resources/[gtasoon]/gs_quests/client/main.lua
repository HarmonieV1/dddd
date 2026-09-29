-- gs_quests (client) : personnages (PNJ locaux + losange vert), objectifs (blip, marqueur, texte, chrono),
-- paquets cachés, menu Progression (F5), annonces façon « vieux GTA » (NIVEAU SUPÉRIEUR / MISSION RÉUSSIE).
local Markers = exports.gs_markers
local state = nil
local peds = {}          -- [charId] = handle
local objective = { blips = {}, zones = {}, markers = {} }
local packageProps = {}  -- [index] = handle
local lastAdvance = 0

local QuestById = {}
for _, q in ipairs(Quests) do QuestById[q.id] = q end

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

-- Annonce plein écran (scaleform du jeu) ------------------------------------------------------------------------
local function shard(title, subtitle, sound)
    CreateThread(function()
        local sf = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
        local timeout = GetGameTimer() + 2000
        while not HasScaleformMovieLoaded(sf) and GetGameTimer() < timeout do Wait(0) end
        if not HasScaleformMovieLoaded(sf) then return end
        BeginScaleformMovieMethod(sf, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
        ScaleformMovieMethodAddParamTextureNameString(title)
        ScaleformMovieMethodAddParamTextureNameString(subtitle or '')
        ScaleformMovieMethodAddParamInt(5)
        EndScaleformMovieMethod()
        if sound then PlaySoundFrontend(-1, sound[1], sound[2], false) end
        local stop = GetGameTimer() + 4500
        while GetGameTimer() < stop do
            DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0)
            Wait(0)
        end
        SetScaleformMovieAsNoLongerNeeded(sf)
    end)
end

RegisterNetEvent('gs_quests:client:xp', function(d)
    lib.notify({ title = ('+%d XP'):format(d.gained), description = d.reason, type = 'success', icon = 'star' })
    if d.levelUp then
        shard(('NIVEAU %d'):format(d.level), d.reward and ('Bonus : %d $ en banque'):format(d.reward) or '', { 'RANK_UP', 'HUD_AWARDS' })
    end
    if state then state.xp, state.level, state.floor, state.nextXp = d.xp, d.level, d.floor, d.nextXp end
end)

-- Personnages ---------------------------------------------------------------------------------------------------

local refresh

local function activeStep()
    if not state or not state.active then return nil end
    local q = QuestById[state.active.id]
    return q.steps[state.active.step], q
end

local function advance(point)
    if GetGameTimer() - lastAdvance < 1500 then return end
    lastAdvance = GetGameTimer()
    local ok, msg = lib.callback.await('gs_quests:advance', false, point)
    notify(ok, msg)
    refresh()
end

local function talk(charId)
    refresh()
    if not state then return notify(false, 'Ta progression charge encore, réessaie dans quelques secondes.') end
    local ch = Characters[charId]
    local step = activeStep()
    if step and (step.type == 'talk' or step.type == 'deliver') and step.character == charId then return advance() end
    if state.active then
        local q = QuestById[state.active.id]
        if q.giver == charId then
            return lib.alertDialog({ header = ch.name, content = ('« On a dit : %s. »'):format(step.label:lower()), centered = true })
        end
    end
    for _, info in ipairs(state.quests) do
        local q = QuestById[info.id]
        if q.giver == charId and not info.done then
            if not info.available then
                return lib.alertDialog({ header = ch.name, content = ('« Pas maintenant. »\n\n*%s*'):format(info.why or ''), centered = true })
            end
            local answer = lib.alertDialog({
                header = ('%s · %s'):format(ch.name, q.title),
                content = ('« %s »\n\n**Récompense :** %d XP%s'):format(q.intro, q.reward.xp or 0, q.reward.cash and (' · ' .. q.reward.cash .. ' $') or ''),
                centered = true, cancel = true, labels = { confirm = 'J\'accepte', cancel = 'Plus tard' },
            })
            if answer ~= 'confirm' then return end
            local ok, msg = lib.callback.await('gs_quests:start', false, q.id)
            if ok then shard(msg, q.steps[1].label, { 'Event_Start_Text', 'GTAO_FM_Events_Soundset' }) else notify(false, msg) end
            return refresh()
        end
    end
    lib.alertDialog({ header = ch.name, content = '« Rien pour toi aujourd\'hui. Repasse plus tard. »', centered = true })
end

local function spawnPed(id, ch)
    local hash = GetHashKey(ch.model)
    if not IsModelInCdimage(hash) then hash = GetHashKey('a_m_m_business_01') end
    lib.requestModel(hash, 5000)
    local c = ch.coords
    -- Posé au sol quelle que soit la façon dont la coord a été relevée (pieds ou bassin)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    local ped = CreatePed(4, hash, c.x, c.y, found and gz or (c.z - 1.0), c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    peds[id] = ped
end

local function despawnPed(id)
    if peds[id] then
        DeleteEntity(peds[id])
        peds[id] = nil
    end
end

--- Losange vert au-dessus des personnages qui ont quelque chose pour toi.
local function updateCharacterMarkers()
    Markers:RemovePrefix('gs_quests:char:')
    if not state then return end
    local wanted = {}
    local step = activeStep()
    if step and step.character then wanted[step.character] = true end
    if not state.active then
        for _, info in ipairs(state.quests) do
            if info.available then wanted[QuestById[info.id].giver] = true end
        end
    end
    for id in pairs(wanted) do
        local c = Characters[id].coords
        Markers:Add('gs_quests:char:' .. id, { coords = vec3(c.x, c.y, c.z), style = 'quest', label = Characters[id].name, ring = false, distance = 60.0 })
    end
end

-- Objectifs -------------------------------------------------------------------------------------------------------

local function clearObjective()
    for _, b in ipairs(objective.blips) do RemoveBlip(b) end
    for _, z in ipairs(objective.zones) do exports.ox_target:removeZone(z) end
    Markers:RemovePrefix('gs_quests:obj:')
    objective = { blips = {}, zones = {} }
end

local function blipAt(c, label, route)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, 1)
    SetBlipColour(b, 5)
    SetBlipScale(b, 0.85)
    if route then SetBlipRoute(b, true) SetBlipRouteColour(b, 5) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    objective.blips[#objective.blips + 1] = b
end

local function setupObjective()
    clearObjective()
    local step = activeStep()
    if not step then return end
    if step.character then
        blipAt(Characters[step.character].coords, Characters[step.character].name, true)
    elseif step.coords then
        blipAt(step.coords, step.label, true)
        Markers:Add('gs_quests:obj:goal', { coords = step.coords, style = 'objective', label = step.label })
    elseif step.type == 'collect' then
        for i, c in ipairs(step.points) do
            if not state.active.collected[i] and not state.active.collected[tostring(i)] then
                blipAt(c, step.label, false)
                Markers:Add('gs_quests:obj:' .. i, { coords = c, style = 'objective', label = 'Ramasser' })
                objective.zones[#objective.zones + 1] = exports.ox_target:addSphereZone({ coords = c, radius = 1.2, options = { {
                    name = 'gs_quest_collect_' .. i, icon = 'fa-solid fa-hand', label = 'Ramasser',
                    onSelect = function() advance(i) end,
                } } })
            end
        end
    end
end

function refresh()
    state = lib.callback.await('gs_quests:state', false)
    if state and state.active then state.active.deadlineAt = state.active.deadline and (GetGameTimer() + state.active.deadline * 1000) or nil end
    setupObjective()
    updateCharacterMarkers()
end

RegisterNetEvent('gs_quests:client:refresh', function() refresh() end)
AddEventHandler('gs_quests:client:talk', function(id) talk(id) end)
RegisterNetEvent('gs_quests:client:daily', function(label)
    lib.notify({ title = 'Défi du jour réussi', description = label, type = 'success', icon = 'calendar-check', duration = 7000 })
end)
RegisterNetEvent('gs_quests:client:badge', function(label, desc)
    shard('BADGE DÉBLOQUÉ', ('%s · %s'):format(label, desc), { 'RANK_UP', 'HUD_AWARDS' })
end)
RegisterNetEvent('gs_quests:client:completed', function(id)
    shard('MISSION RÉUSSIE', QuestById[id] and QuestById[id].title or '', { 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS' })
    refresh()
end)

-- Boucle légère : arrivée aux points, streaming des PNJ et des paquets (toutes les 500 ms) ---------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local me = GetEntityCoords(ped)
        for id, ch in pairs(Characters) do
            if ch.model then
                local d = #(me - vec3(ch.coords.x, ch.coords.y, ch.coords.z))
                if d < 60.0 and not peds[id] then spawnPed(id, ch) elseif d > 80.0 and peds[id] then despawnPed(id) end
            end
        end
        local step = activeStep()
        if step and step.coords and (step.type == 'goto' or step.type == 'drive' or step.type == 'deliver') then
            local inVeh = GetVehiclePedIsIn(ped, false) ~= 0
            local ready = (step.type ~= 'drive' or inVeh)
                and (step.type ~= 'deliver' or exports.gs_bridge:GetItemCount(step.item) >= step.count)
            if ready and #(me - step.coords) < (step.radius or 4.0) then advance() end
        end
        if state and state.active and state.active.deadlineAt and GetGameTimer() > state.active.deadlineAt then
            state.active.deadlineAt = nil
            advance() -- le serveur constate le retard et fait échouer la quête
        end
        if state then
            local found = {}
            for _, i in ipairs(state.packages) do found[i] = true end
            for i, c in ipairs(Config.Packages.points) do
                local d = #(me - c)
                if not found[i] and d < Config.Packages.spawnDistance and not packageProps[i] then
                    local hash = GetHashKey('prop_cs_cardbox_01')
                    lib.requestModel(hash, 5000)
                    local obj = CreateObject(hash, c.x, c.y, c.z - 0.95, false, false, false)
                    SetModelAsNoLongerNeeded(hash)
                    FreezeEntityPosition(obj, true)
                    exports.ox_target:addLocalEntity(obj, { {
                        name = 'gs_package_' .. i, icon = 'fa-solid fa-box', label = 'Ramasser le paquet',
                        onSelect = function()
                            local ok, msg = lib.callback.await('gs_quests:package', false, i)
                            notify(ok, msg)
                            if ok then
                                exports.ox_target:removeLocalEntity(obj)
                                DeleteEntity(obj)
                                packageProps[i] = false
                                refresh()
                            end
                        end,
                    } })
                    packageProps[i] = obj
                elseif packageProps[i] and (found[i] or d > Config.Packages.spawnDistance + 20.0) then
                    exports.ox_target:removeLocalEntity(packageProps[i])
                    DeleteEntity(packageProps[i])
                    packageProps[i] = nil
                end
            end
        end
        Wait(500)
    end
end)

-- Texte d'objectif + chrono (seulement pendant une quête) --------------------------------------------------------------
CreateThread(function()
    while true do
        local step, q = activeStep()
        if not step then
            Wait(1000)
        else
            local text = ('~g~◆~s~ %s~n~~c~%s'):format(step.label, q.title)
            local a = state.active
            if a.deadlineAt then
                local left = math.max(0, math.ceil((a.deadlineAt - GetGameTimer()) / 1000))
                text = text .. ('~n~%s%d:%02d'):format(left <= 30 and '~r~' or '~y~', left // 60, left % 60)
            end
            SetTextFont(4) SetTextScale(0.0, 0.42) SetTextOutline() SetTextJustification(1)
            SetTextColour(255, 255, 255, 235)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.015, 0.30)
            Wait(0)
        end
    end
end)

-- Menu Progression ------------------------------------------------------------------------------------------------------
local function openMenu()
    refresh()
    if not state then return end
    local pct = state.nextXp and math.floor((state.xp - state.floor) / (state.nextXp - state.floor) * 100) or 100
    local options = {
        { title = ('Niveau %d · %s'):format(state.level, state.title), icon = 'star', progress = pct, colorScheme = 'teal',
          description = state.nextXp and ('%d / %d XP'):format(state.xp - state.floor, state.nextXp - state.floor) or 'Niveau maximum' },
        { title = ('Série : %d jour(s) d\'affilée'):format(state.streak), icon = 'fire', iconColor = '#ff8a3d', readOnly = true,
          description = 'Connecte-toi chaque jour : plus d\'XP, et un bonus tous les 7 jours' },
    }
    for _, d in ipairs(state.daily) do
        options[#options + 1] = {
            title = (d.done and '✔ ' or '') .. d.label, icon = 'calendar-check', iconColor = d.done and '#5aff8c' or '#28e0ff',
            progress = math.floor(d.n / d.goal * 100), colorScheme = d.done and 'green' or 'cyan', readOnly = true,
            description = ('Défi du jour · %d / %d · %d XP'):format(d.n, d.goal, Config.Daily.xp),
        }
    end
    local unlocked, badgeOptions = 0, {}
    for _, b in ipairs(state.badges) do
        if b.unlocked then unlocked = unlocked + 1 end
        badgeOptions[#badgeOptions + 1] = { title = b.label, description = b.desc, readOnly = true,
            icon = b.unlocked and 'medal' or 'lock', iconColor = b.unlocked and '#ffd23f' or '#6b6380' }
    end
    lib.registerContext({ id = 'gs_badges', title = 'Badges', menu = 'gs_progress', options = badgeOptions })
    options[#options + 1] = { title = ('Badges : %d / %d'):format(unlocked, #state.badges), icon = 'medal', iconColor = '#ffd23f', menu = 'gs_badges' }
    local step, q = activeStep()
    if step then
        options[#options + 1] = { title = 'En cours : ' .. q.title, description = step.label, icon = 'location-dot', iconColor = '#5aff8c' }
        options[#options + 1] = { title = 'Abandonner la quête', icon = 'xmark', iconColor = '#ff2e88', onSelect = function()
            if lib.alertDialog({ header = 'Abandonner ' .. q.title, content = 'Tu pourras la reprendre auprès du personnage.', centered = true, cancel = true }) == 'confirm' then
                lib.callback.await('gs_quests:abandon', false)
                refresh()
            end
        end }
    end
    for _, info in ipairs(state.quests) do
        local qq = QuestById[info.id]
        if info.done or info.available then
            local giver = Characters[qq.giver]
            options[#options + 1] = {
                title = qq.title, icon = info.done and 'circle-check' or 'circle', iconColor = info.done and '#5aff8c' or '#28e0ff',
                description = info.done and 'Terminée' or ('Disponible auprès de ' .. giver.name),
                onSelect = not info.done and function() SetNewWaypoint(giver.coords.x, giver.coords.y) end or nil,
            }
        end
    end
    options[#options + 1] = { title = ('Paquets cachés : %d / %d'):format(state.packagesFound, state.packagesTotal), icon = 'box', readOnly = true }
    lib.registerContext({ id = 'gs_progress', title = 'Progression', options = options })
    lib.showContext('gs_progress')
end

RegisterCommand('progression', openMenu, false)
RegisterKeyMapping('progression', 'Progression et quêtes', 'keyboard', Config.Key)

-- Interaction avec les personnages : une zone ox_target fixe par personnage (marche même si le PNJ n'a pas
-- encore chargé ou s'il est mal posé) ; la cabine de la Voix n'a pas de PNJ.
CreateThread(function()
    for id, ch in pairs(Characters) do
        Markers:Add('gs_quests:talk:' .. id, { coords = vec3(ch.coords.x, ch.coords.y, ch.coords.z), style = 'hidden', ring = false,
            distance = 6.0, reach = 2.5, event = 'gs_quests:client:talk', args = { id },
            prompt = ch.model and ('Parler à ' .. ch.name) or 'Décrocher le téléphone' })
        exports.ox_target:addSphereZone({ coords = vec3(ch.coords.x, ch.coords.y, ch.coords.z + 0.3), radius = 1.6, options = { {
            name = 'gs_quest_' .. id, icon = ch.model and 'fa-solid fa-comment' or 'fa-solid fa-phone',
            label = ch.model and ('Parler à ' .. ch.name) or 'Décrocher', distance = 3.0,
            onSelect = function() talk(id) end,
        } } })
    end
    if LocalPlayer.state.isLoggedIn then refresh() end -- [API] Qbox : redémarrage de la ressource en jeu
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do despawnPed(id) end
    for _, obj in pairs(packageProps) do if obj then DeleteEntity(obj) end end
    clearObjective()
    Markers:RemovePrefix('gs_quests:')
end)
