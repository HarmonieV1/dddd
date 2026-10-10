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
        onSelect = function()
            if not lib.progressBar({ duration = Config.Blind.time, label = 'Peinture sur l\'objectif…', canCancel = true,
                anim = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar' }, disable = { move = true, car = true } }) then return end
            local ok, msg = lib.callback.await('gs_cctv:blind', false, i)
            lib.notify({ description = msg, type = ok and 'success' or 'error' })
        end,
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
            description = c.active and ('%d passage(s) récent(s)'):format(c.count) or 'Hors service (objectif peint)', onSelect = function()
                local ok, list = lib.callback.await('gs_cctv:search', false, '', i)
                if not ok then return lib.notify({ description = list, type = 'error' }) end
                showResults(list, c.label)
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
    for i, o in pairs(props) do if DoesEntityExist(o) then DeleteEntity(o) end props[i] = nil end
    exports.gs_markers:RemovePrefix('gs_cctv:')
end)
