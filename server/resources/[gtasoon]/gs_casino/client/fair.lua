-- gs_casino (client) · V12.62 « Jetons de fête foraine » : guichet (salle de jeu) et caisse du casino.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function call(...) return lib.callback.await('gs_casino:fair', false, ...) end

local function ask(title, max)
    local r = lib.inputDialog(title, { { type = 'number', label = 'Combien ?', min = 1, max = max, default = 10, required = true } })
    return r and tonumber(r[1]) or nil
end

local function open()
    local ok, d = call('info')
    if not ok then return notify(false, d) end
    local options = {
        { title = ('Tu as %d jeton%s'):format(d.count, d.count > 1 and 's' or ''), icon = 'coins', readOnly = true,
            description = 'Une seule monnaie pour les jeux de la ville.' },
        { title = ('Acheter des jetons (%d $ pièce)'):format(d.price), icon = 'cart-plus', onSelect = function()
            local n = ask('Acheter des jetons', Config.Fair.maxPerAction)
            if n then notify(call('buy', n)) end
        end },
        { title = ('Revendre des jetons (%d $ pièce)'):format(d.buyBack), icon = 'hand-holding-dollar', onSelect = function()
            local n = ask('Revendre des jetons', Config.Fair.maxPerAction)
            if n then notify(call('sell', n)) end
        end },
    }
    if d.at == 'casino' then
        options[#options + 1] = { title = ('Ticket à gratter contre %d jetons'):format(d.scratchFor), icon = 'ticket', onSelect = function() notify(call('scratch')) end }
    end
    for _, e in ipairs(d.exchange or {}) do
        options[#options + 1] = { title = 'Jetons → ' .. e.label, icon = 'right-left', description = '1 jeton = 1 ticket', onSelect = function()
            local n = ask('Jetons → ' .. e.label, Config.Fair.maxPerAction)
            if n then notify(call('toScript', e.i, n)) end
        end }
        options[#options + 1] = { title = e.label .. ' → jetons', icon = 'right-left', onSelect = function()
            local n = ask(e.label .. ' → jetons', Config.Fair.maxPerAction)
            if n then notify(call('fromScript', e.i, n)) end
        end }
    end
    lib.registerContext({ id = 'gs_fair', title = 'Jetons de fête foraine', options = options })
    lib.showContext('gs_fair')
end

AddEventHandler('gs_casino:client:fair', open)

-- V12.63 · Photomaton (n° 189) : caméra face au joueur le temps du cliché (image réelle si screenshot-basic + hébergeur)
local busy = false
AddEventHandler('gs_casino:client:photobooth', function()
    if busy then return end
    local F = Config.Fair
    if lib.alertDialog({ header = 'Photomaton', centered = true, cancel = true,
        content = ('Une photo souvenir imprimée pour **%d jetons**. Serrez-vous dans la cabine : chacun aura sa copie.'):format(F.photoCost) }) ~= 'confirm' then return end
    busy = true
    local ped = cache.ped
    TaskStandStill(ped, 2500)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local front = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.7, 0.65)
    SetCamCoord(cam, front.x, front.y, front.z)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.55, true)
    SetCamFov(cam, 45.0)
    RenderScriptCams(true, false, 0, true, true)
    Wait(800)
    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
    local url, done = nil, GetResourceState('gs_phone') ~= 'started'
    if not done then
        CreateThread(function()
            local ok, u = pcall(function() return exports.gs_phone:TakePhoto() end)
            url, done = ok and u or nil, true
        end)
    end
    Wait(1200) -- le cliché est pris : on rend la caméra
    AnimpostfxPlay('MinigameTransitionOut', 500, false)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    local deadline = GetGameTimer() + 20000
    while not done and GetGameTimer() < deadline do Wait(100) end
    notify(lib.callback.await('gs_casino:photobooth', false, url))
    busy = false
end)

CreateThread(function()
    exports.gs_markers:Add('gs_casino:fair', { coords = Config.Fair.booth, style = 'shop', label = 'Jetons de fête foraine', event = 'gs_casino:client:fair',
        prompt = 'Guichet des jetons', reach = Config.Fair.range, distance = 20.0 })
    exports.gs_markers:Add('gs_casino:photobooth', { coords = Config.Fair.photobooth, style = 'shop', label = 'Photomaton', event = 'gs_casino:client:photobooth',
        prompt = 'Photomaton (photo souvenir)', reach = Config.Fair.range, distance = 20.0 }) -- V12.63
    exports.gs_markers:Add('gs_casino:fair2', { coords = Config.Lotto.cashier + vec3(1.2, 0.0, 0.0), style = 'shop', label = 'Jetons', event = 'gs_casino:client:fair',
        prompt = 'Jetons de fête foraine', reach = Config.Lotto.range, distance = 20.0 })
end)
