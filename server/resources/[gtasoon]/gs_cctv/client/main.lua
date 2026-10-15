-- gs_cctv (client) : boîtiers de caméra visibles (objets locaux créés à l'approche) ; police : ordinateur du commissariat
-- (recherche par plaque ou par caméra) ; tout le monde : [ox_target] aveugler l'objectif à la bombe de peinture.
local props = {} -- [i] = entité

local function blinded(i)
    for _, k in ipairs(GlobalState.gsCctvBlind or {}) do if k == i then return true end end
    return false
end

--- V11.5 · Accroche : hauteur au sol, puis rayon horizontal dans 16 directions ; le mur / poteau le plus proche
--- reçoit le boîtier (collé à 12 cm), tourné vers l'extérieur. Sans support : posé à `height` au-dessus du sol.
local function mountPoint(cam)
    local M = Config.Mount
    local c = cam.coords
    local z = c.z
    local okG, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 10.0, false)
    if okG then z = math.max(gz + M.minHeight, math.min(gz + M.maxHeight, math.max(c.z, gz + M.height))) end
    local from = vec3(c.x, c.y, z)
    local best, bestD, bestN
    for k = 0, 15 do
        local a = k * (math.pi / 8)
        local dir = vec3(math.cos(a), math.sin(a), 0.0)
        local ray = StartShapeTestRay(from.x, from.y, from.z, from.x + dir.x * M.reach, from.y + dir.y * M.reach, from.z, 1 | 16, 0, 7)
        local _, hit, pos, normal = GetShapeTestResult(ray)
        if hit == 1 then
            local d = #(vec3(pos.x, pos.y, pos.z) - from)
            if not bestD or d < bestD then best, bestD, bestN = vec3(pos.x, pos.y, pos.z), d, vec3(normal.x, normal.y, 0.0) end
        end
    end
    if best and #bestN > 0.01 then
        local n = bestN / #bestN
        local heading = cam.heading or (math.deg(math.atan(-n.x, n.y)) % 360.0) -- regarde dans le sens de la normale (vers la rue)
        return best + n * 0.12, heading, true
    end
    return from, cam.heading or 0.0, false
end

--- V12.58 · Peindre l'objectif (Alt sur le boîtier, ou bombe de peinture utilisée dessous)
local function blind(i, box)
    if not lib.progressBar({ duration = Config.Blind.time, label = 'Peinture sur l\'objectif…', canCancel = true,
        anim = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar' }, disable = { move = true, car = true } }) then return end
    -- V12.62 : boîtier du décor = sa position (le serveur vérifie qu'on est à côté ET qu'il est dans la portée de la caméra)
    local ok, msg = lib.callback.await('gs_cctv:blind', false, i, box and { x = box.x, y = box.y, z = box.z } or nil)
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end

--- V12.59 · Caméra RoadLine qui filme un point (la plus proche dans sa portée), ou nil.
local function camFor(pos)
    local best, bestD
    for i, cam in ipairs(Config.Cameras) do
        local d = #(vec2(cam.coords.x, cam.coords.y) - vec2(pos.x, pos.y))
        if d <= Config.Radius and (not bestD or d < bestD) then best, bestD = i, d end
    end
    return best
end

--- V12.59 · Boîtier du décor du jeu le plus proche (≤ useRange), ou nil.
local function worldCam(me)
    local best, bestD
    for _, m in ipairs(Config.WorldProps) do
        local o = GetClosestObjectOfType(me.x, me.y, me.z, Config.Blind.useRange + 2.0, GetHashKey(m), false, false, false)
        if o ~= 0 then
            local c = GetEntityCoords(o)
            local d = #(vec2(c.x, c.y) - vec2(me.x, me.y))
            if d <= Config.Blind.useRange and (not bestD or d < bestD) then best, bestD = o, d end
        end
    end
    return best
end

--- V12.58 · Appelé par la bombe de peinture (gs_gangs) : une caméra juste au-dessus ? On la peint (true).
--- V12.59 : aussi les boîtiers du décor du jeu (reliés à la caméra RoadLine qui filme ce coin).
exports('TryBlind', function()
    local me = GetEntityCoords(cache.ped)
    local best, bestD
    for i, o in pairs(props) do
        if DoesEntityExist(o) and not blinded(i) then
            local c = GetEntityCoords(o)
            local d = #(vec2(c.x, c.y) - vec2(me.x, me.y))
            if d <= Config.Blind.useRange and (not bestD or d < bestD) then best, bestD = i, d end
        end
    end
    if best then
        TaskTurnPedToFaceEntity(cache.ped, props[best], 800)
        blind(best)
        return true
    end
    local o = worldCam(me)
    if not o then return false end
    local i = camFor(GetEntityCoords(o))
    TaskTurnPedToFaceEntity(cache.ped, o, 800)
    if not i then
        lib.notify({ description = 'Cette caméra n\'est reliée à aucun réseau : personne ne regarde ce coin.', type = 'inform' })
        return true
    end
    if blinded(i) then
        lib.notify({ description = 'Cette caméra ne voit déjà plus rien.', type = 'inform' })
        return true
    end
    blind(i, GetEntityCoords(o))
    return true
end)

-- V12.59 · Alt sur un boîtier du décor : même chose qu'avec la bombe
CreateThread(function()
    Wait(2000)
    exports.ox_target:addModel(Config.WorldProps, { {
        name = 'gs_cctv_blind_world', icon = 'fas fa-spray-can', label = 'Peindre l\'objectif (bombe de peinture)', distance = Config.Blind.range,
        onSelect = function(data)
            local i = camFor(GetEntityCoords(data.entity))
            if not i then return lib.notify({ description = 'Cette caméra n\'est reliée à aucun réseau : personne ne regarde ce coin.', type = 'inform' }) end
            if blinded(i) then return lib.notify({ description = 'Cette caméra ne voit déjà plus rien.', type = 'inform' }) end
            blind(i, GetEntityCoords(data.entity))
        end,
    } })
end)

local function spawn(i, cam)
    local hash = GetHashKey(Config.Prop)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 3000) then return end
    local at, heading = mountPoint(cam)
    local o = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(o, heading)
    FreezeEntityPosition(o, true)
    exports.ox_target:addLocalEntity(o, { {
        name = 'gs_cctv_blind', icon = 'fas fa-spray-can', label = 'Aveugler la caméra (bombe de peinture)', distance = Config.Blind.range,
        canInteract = function() return not blinded(i) end,
        onSelect = function() blind(i) end,
    } })
    props[i] = o
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for i, cam in ipairs(Config.Cameras) do
            local d = #(me - cam.coords)
            if d < 90.0 and not props[i] then spawn(i, cam)
            elseif d > 130.0 and props[i] then
                exports.ox_target:removeLocalEntity(props[i]) DeleteEntity(props[i]) props[i] = nil
            end
        end
        Wait(3000)
    end
end)

-- V12.41 · Vue en direct depuis le terminal : caméra de script posée au boîtier, image de vidéosurveillance (filtre,
-- horodatage), on tourne à la souris, zoom à la molette ; le monde autour de la caméra est chargé (SetFocusPosAndVel)
-- puis rendu au joueur à la sortie. Le policier reste devant l'ordinateur (figé), Retour / Échap pour quitter.
local watching = false
local function watch(i)
    if watching then return end
    local ok, cam = lib.callback.await('gs_cctv:view', false, i)
    if not ok then return lib.notify({ description = cam, type = 'error' }) end
    watching = true
    local ped = cache.ped
    local function placeOf(idx, data)
        local at = props[idx] and DoesEntityExist(props[idx]) and GetEntityCoords(props[idx]) or vec3(data.x, data.y, data.z)
        local yaw = props[idx] and DoesEntityExist(props[idx]) and GetEntityHeading(props[idx]) or (Config.Cameras[idx].heading or 0.0)
        return at, yaw
    end
    local at, yaw = placeOf(i, cam)
    local base, pitch, fov = yaw, -20.0, 60.0
    DoScreenFadeOut(300) Wait(300)
    FreezeEntityPosition(ped, true)
    SetFocusPosAndVel(at.x, at.y, at.z, 0.0, 0.0, 0.0)
    local c = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', at.x, at.y, at.z - 0.25, pitch, 0.0, yaw, fov, false, 2)
    SetCamActive(c, true) RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier('scanline_cam_cheap') SetTimecycleModifierStrength(1.0)
    Wait(500) DoScreenFadeIn(300)
    local function help() lib.showTextUI('Vidéosurveillance · ' .. cam.label .. ' · souris : tourner · molette : zoom · ← → : caméra suivante · Retour : quitter', { position = 'top-center', icon = 'video' }) end
    help()
    --- V12.59 (backtest 15/10) : ← / → passent à la caméra en service précédente / suivante, sans quitter la vue
    local nextSwitch = 0
    local function switch(step)
        -- V12.62 : un changement toutes les 0,3 s au plus, et on s'arrête au premier refus qui n'est pas « image noire »
        -- (avant : un « Doucement. » faisait essayer toutes les caméras d'affilée → anti-flood → policier expulsé)
        if GetGameTimer() < nextSwitch then return end
        nextSwitch = GetGameTimer() + 300
        local n = #Config.Cameras
        for k = 1, n - 1 do
            local j = ((i - 1 + step * k) % n) + 1
            if not blinded(j) then
                local okJ, data = lib.callback.await('gs_cctv:view', false, j)
                if not okJ and not (type(data) == 'string' and data:find('^Image noire')) then
                    return lib.notify({ description = data or 'Caméra indisponible.', type = 'error' })
                end
                if okJ then
                    DoScreenFadeOut(120) Wait(120)
                    i, cam = j, data
                    at, yaw = placeOf(j, data)
                    base, pitch = yaw, -20.0
                    SetFocusPosAndVel(at.x, at.y, at.z, 0.0, 0.0, 0.0)
                    SetCamCoord(c, at.x, at.y, at.z - 0.25)
                    help()
                    Wait(150) DoScreenFadeIn(120)
                    return
                end
            end
        end
        lib.notify({ description = 'Aucune autre caméra en service.', type = 'inform' })
    end
    CreateThread(function()
        -- par frame : seulement pendant la vue en direct (caméra tournée et commandes coupées à chaque image)
        while watching do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) -- souris
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true) -- chat, push-to-talk
            yaw = yaw - GetDisabledControlNormal(0, 1) * 6.0
            pitch = math.max(-70.0, math.min(10.0, pitch - GetDisabledControlNormal(0, 2) * 6.0))
            if math.abs(((yaw - base + 180.0) % 360.0) - 180.0) > 75.0 then -- angle mort du boîtier : 150° de champ
                yaw = base + (((yaw - base + 180.0) % 360.0) - 180.0 > 0 and 75.0 or -75.0)
            end
            if IsDisabledControlJustPressed(0, 241) then fov = math.max(15.0, fov - 5.0) end
            if IsDisabledControlJustPressed(0, 242) then fov = math.min(80.0, fov + 5.0) end
            if IsDisabledControlJustPressed(0, 174) then switch(-1) end -- flèche gauche
            if IsDisabledControlJustPressed(0, 175) then switch(1) end  -- flèche droite
            SetCamRot(c, pitch, 0.0, yaw, 2) SetCamFov(c, fov)
            SetTextFont(4) SetTextScale(0.0, 0.42) SetTextColour(255, 255, 255, 210) SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('● REC  %s  %02d:%02d'):format(cam.label:upper(), GetClockHours(), GetClockMinutes()))
            EndTextCommandDisplayText(0.03, 0.05)
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) or IsEntityDead(ped) then watching = false end
            Wait(0)
        end
        DoScreenFadeOut(250) Wait(250)
        lib.hideTextUI()
        ClearTimecycleModifier()
        RenderScriptCams(false, false, 0, true, true) DestroyCam(c, false)
        ClearFocus()
        FreezeEntityPosition(ped, false)
        DoScreenFadeIn(250)
    end)
end

-- Ordinateur du commissariat
local function showResults(list, title)
    local o = {}
    for _, e in ipairs(list) do
        o[#o + 1] = { title = ('%s · %s'):format(e.at, e.cam), icon = 'video', readOnly = true,
            description = ('%s %s · plaque %s · %d km/h'):format(e.model or 'Véhicule', e.color and ('(' .. e.color .. ')') or '', e.plate, e.kmh or 0) }
    end
    if #o == 0 then o[1] = { title = 'Aucun passage enregistré', icon = 'circle-xmark', readOnly = true } end
    lib.registerContext({ id = 'gs_cctv_results', title = title, menu = 'gs_cctv', options = o })
    lib.showContext('gs_cctv_results')
end

AddEventHandler('gs_cctv:client:terminal', function()
    local cams = lib.callback.await('gs_cctv:cameras', false)
    if not cams or #cams == 0 then return lib.notify({ description = 'Réservé à la police en service.', type = 'error' }) end
    local o = { { title = 'Rechercher une plaque', icon = 'magnifying-glass', description = 'Même un morceau (ex. 4X2)', onSelect = function()
        local r = lib.inputDialog('Vidéosurveillance', { { type = 'input', label = 'Plaque (ou morceau)', required = true, max = 8 } })
        if not r then return end
        local ok, list = lib.callback.await('gs_cctv:search', false, r[1])
        if not ok then return lib.notify({ description = list, type = 'error' }) end
        showResults(list, 'Plaque « ' .. r[1]:upper() .. ' »')
    end } }
    -- V12 · Remonter la source des brouillages / piratages (opérations de gang)
    o[#o + 1] = { title = 'Remonter la source (brouillage, scanner piraté)', icon = 'satellite-dish', description = 'Le gang responsable apparaît après 5 min d\'analyse', onSelect = function()
        local ok, list = lib.callback.await('gs_cctv:traces', false)
        if not ok then return lib.notify({ description = list, type = 'error' }) end
        local t = {}
        for _, e in ipairs(list) do
            t[#t + 1] = { title = ('%s · %s'):format(e.at, e.kind == 'jam' and 'Brouillage de caméras' or 'Scanner police piraté'), icon = e.gang and 'user-secret' or 'hourglass-half', readOnly = true,
                description = e.gang and ('Source : %s%s'):format(e.gang, e.zone and (' · ' .. e.zone) or '') or ('Analyse en cours : %d min'):format(e.left or 0) }
        end
        if #t == 0 then t[1] = { title = 'Aucune opération récente', icon = 'circle-xmark', readOnly = true } end
        lib.registerContext({ id = 'gs_cctv_traces', title = 'Sources', menu = 'gs_cctv', options = t })
        lib.showContext('gs_cctv_traces')
    end }
    for i, c in ipairs(cams) do
        o[#o + 1] = { title = c.label, icon = c.active and 'video' or 'video-slash', iconColor = (not c.active) and '#ff5470' or nil,
            description = c.active and ('%d passage(s) récent(s)'):format(c.count) or 'Hors service (objectif peint)', arrow = true, onSelect = function()
                lib.registerContext({ id = 'gs_cctv_cam', title = c.label, menu = 'gs_cctv', options = {
                    { title = 'Voir en direct', icon = 'tv', disabled = not c.active, description = 'Souris : tourner · molette : zoom · ← → : autre caméra · Retour : quitter',
                        onSelect = function() watch(i) end },
                    { title = 'Passages enregistrés', icon = 'list', onSelect = function()
                        local ok, list = lib.callback.await('gs_cctv:search', false, '', i)
                        if not ok then return lib.notify({ description = list, type = 'error' }) end
                        showResults(list, c.label)
                    end },
                } })
                lib.showContext('gs_cctv_cam')
            end }
    end
    lib.registerContext({ id = 'gs_cctv', title = 'Vidéosurveillance de la ville', options = o })
    lib.showContext('gs_cctv')
end)

CreateThread(function()
    for i, t in ipairs(Config.Terminals) do
        exports.gs_markers:Add('gs_cctv:terminal' .. i, { coords = t, style = 'job', label = 'Vidéosurveillance', event = 'gs_cctv:client:terminal',
            prompt = 'Consulter les caméras de la ville', distance = 10.0 })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if watching then watching = false ClearTimecycleModifier() RenderScriptCams(false, false, 0, true, true) ClearFocus() FreezeEntityPosition(cache.ped, false) end
    for i, o in pairs(props) do if DoesEntityExist(o) then DeleteEntity(o) end props[i] = nil end
    exports.gs_markers:RemovePrefix('gs_cctv:')
end)
