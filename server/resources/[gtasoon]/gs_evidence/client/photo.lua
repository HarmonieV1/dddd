-- gs_evidence (client) · V9 « Appareil photo argentique » : prendre une photo (objet), la regarder, l'accrocher au mur,
-- la verser au labo (police). Image réelle si l'hébergement des photos est configuré (gs_phone / screenshot-basic).
local C = Config.Camera
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function call(action, a) return lib.callback.await('gs_evidence:photo', false, action, a) end

local function show(md)
    local content = (md.description or '') .. (md.image and ('\n\n![photo](' .. md.image .. ')') or '')
    lib.alertDialog({ header = md.label or 'Photo', content = content, centered = true, size = 'lg' })
end

exports('camera', function()
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    if not lib.progressBar({ duration = 1500, label = 'Clic-clac…', canCancel = true, anim = { scenario = 'WORLD_HUMAN_PAPARAZZI' },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
    local url
    if GetResourceState('gs_phone') == 'started' then
        local ok, u = pcall(function() return exports.gs_phone:TakePhoto() end)
        url = ok and u or nil
    end
    ClearPedTasks(cache.ped)
    notify(call('take', url))
end)

exports('photo', function(_, slot)
    local md = slot and slot.metadata
    if type(md) ~= 'table' or not md.photo then return notify(false, 'Photo voilée.') end
    lib.registerContext({ id = 'gs_photo', title = md.label or 'Photo', options = {
        { title = 'Regarder', icon = 'image', onSelect = function() show(md) end },
        { title = 'Accrocher au mur ici', icon = 'thumbtack', description = 'Chez toi, au QG, dans ton commerce…', onSelect = function() notify(call('hang', md)) end },
        { title = 'Verser au labo (police)', icon = 'microscope', description = 'Au labo du commissariat', onSelect = function()
            local ok, d = call('analyze', md.photo)
            if not ok then return notify(false, d) end
            local options = {}
            for _, l in ipairs(d) do options[#options + 1] = { title = l, icon = 'user', readOnly = true } end
            lib.registerContext({ id = 'gs_photo_lab', title = 'Analyse de la photo', options = options })
            lib.showContext('gs_photo_lab')
        end },
    } })
    lib.showContext('gs_photo')
end)

-- Photos accrochées : visibles de près, [E] pour regarder (l'auteur peut la décrocher)
AddEventHandler('gs_evidence:client:wall', function(i)
    local w = (GlobalState.gsWallPhotos or {})[i]
    if not w then return end
    lib.registerContext({ id = 'gs_photo_wall', title = w.label or 'Photo', options = {
        { title = 'Regarder', icon = 'image', onSelect = function() show({ label = w.label, description = w.text, image = w.image }) end },
        { title = 'Décrocher (si c\'est la tienne)', icon = 'hand', onSelect = function() notify(call('unhang', i)) end },
    } })
    lib.showContext('gs_photo_wall')
end)

local known = {}
AddStateBagChangeHandler('gsWallPhotos', 'global', function(_, _, list)
    for i in pairs(known) do exports.gs_markers:Remove('gs_photo:' .. i) end
    known = {}
    for _, w in ipairs(list or {}) do
        known[w.i] = true
        exports.gs_markers:Add('gs_photo:' .. w.i, { coords = vec3(w.x, w.y, w.z), style = 'hidden', event = 'gs_evidence:client:wall', args = { w.i },
            prompt = 'Regarder la photo accrochée', reach = 1.5 })
    end
end)
CreateThread(function()
    Wait(3000)
    for _, w in ipairs(GlobalState.gsWallPhotos or {}) do
        known[w.i] = true
        exports.gs_markers:Add('gs_photo:' .. w.i, { coords = vec3(w.x, w.y, w.z), style = 'hidden', event = 'gs_evidence:client:wall', args = { w.i },
            prompt = 'Regarder la photo accrochée', reach = 1.5 })
    end
end)
