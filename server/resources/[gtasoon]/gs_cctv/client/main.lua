-- gs_cctv (client) : boîtiers de caméra visibles (objets locaux créés à l'approche) ; police : ordinateur du commissariat
-- (recherche par plaque ou par caméra) ; tout le monde : [ox_target] aveugler l'objectif à la bombe de peinture.
local props = {} -- [i] = entité

local function blinded(i)
    for _, k in ipairs(GlobalState.gsCctvBlind or {}) do if k == i then return true end end
    return false
end

local function spawn(i, cam)
    local hash = GetHashKey(Config.Prop)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 3000) then return end
    local o = CreateObject(hash, cam.coords.x, cam.coords.y, cam.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
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
