-- gs_phone (client) : ouverture (F1) avec animation + téléphone en main, relais NUI <-> serveur,
-- notifications SMS / appels / urgences. 0 boucle au repos (horloge seulement quand le téléphone est ouvert).
local open = false
local prop
local silent = GetResourceKvpInt('gs_phone_silent') == 1
-- V10 : réglages, notifications, appels récents (mémoire du PC du joueur, rien côté serveur)
local walk = GetResourceKvpInt('gs_phone_walk') == 1          -- marcher le téléphone ouvert
local wallpaper = GetResourceKvpInt('gs_phone_wallpaper')
local notifs = {}                                               -- { { icon, title, text, time } } (session)
local typing = false

local function loadJson(key, default)
    local ok, v = pcall(json.decode, GetResourceKvpString(key) or '')
    return ok and type(v) == 'table' and v or default
end
local function saveJson(key, v) SetResourceKvp(key, json.encode(v)) end
local function now() return GetCloudTimeAsInt() end

local function pushNotif(icon, title, text)
    table.insert(notifs, 1, { icon = icon, title = title, text = (text or ''):sub(1, 120), time = now() })
    notifs[21] = nil
    SendNUIMessage({ action = 'notifs', notifs = notifs })
end

local recents = loadJson('gs_phone_recents', {})
local function addRecent(number, kind)
    table.insert(recents, 1, { number = number, kind = kind, time = now() })
    recents[26] = nil
    saveJson('gs_phone_recents', recents)
end

local function phoneInHand(on)
    local ped = PlayerPedId()
    if on then
        if IsPedInAnyVehicle(ped, false) then return end
        lib.requestAnimDict('cellphone@')
        TaskPlayAnim(ped, 'cellphone@', 'cellphone_text_in', 3.0, -1, -1, 50, 0, false, false, false)
        local model = GetHashKey('prop_npc_phone_02')
        lib.requestModel(model)
        local c = GetEntityCoords(ped)
        prop = CreateObject(model, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    else
        StopAnimTask(ped, 'cellphone@', 'cellphone_text_in', 1.0)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        prop = nil
    end
end

local function clock()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

local function close()
    if not open then return end
    open = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    phoneInHand(false)
end

local function openPhone()
    if open then return close() end
    local data = lib.callback.await('gs_phone:open', false)
    if data == false then return lib.notify({ description = 'Tu n\'as pas de téléphone.', type = 'error' }) end
    if not data then return end
    data.clock, data.silent = clock(), silent
    data.vice = GetResourceState('gs_world') == 'started' and exports.gs_world:GetViceFilter() or false
    data.walk, data.wallpaper, data.notifs, data.recents = walk, wallpaper, notifs, recents
    open = true
    typing = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(walk) -- V10 : on peut marcher le téléphone ouvert (option)
    SendNUIMessage({ action = 'open', data = data })
    phoneInHand(true)
    CreateThread(function()
        while open do
            Wait(10000)
            if open then SendNUIMessage({ action = 'clock', clock = clock() }) end
        end
    end)
    if walk then -- seulement téléphone ouvert ET option active : caméra, tir et menu pause bloqués, le reste libre
        CreateThread(function()
            while open do
                DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 257, true)
                DisableControlAction(0, 199, true) DisableControlAction(0, 200, true) DisablePlayerFiring(PlayerId(), true)
                Wait(0)
            end
        end)
    end
end

RegisterCommand('telephone', openPhone, false)
RegisterKeyMapping('telephone', 'Téléphone', 'keyboard', Config.Key)

-- NUI → serveur ------------------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) close() cb(true) end)

RegisterNUICallback('thread', function(b, cb) cb(lib.callback.await('gs_phone:thread', false, b.peer) or {}) end)

RegisterNUICallback('send', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:send', false, b.peer, b.text)
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('addContact', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:addContact', false, b.name, b.number)
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('deleteContact', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:deleteContact', false, b.id)
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('call', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:call', false, b.number)
    if ok then addRecent(b.number, 'out') end
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('answer', function(b, cb)
    cb({ ok = lib.callback.await('gs_phone:answer', false, b.id) == true })
end)

RegisterNUICallback('hangup', function(_, cb) TriggerServerEvent('gs_phone:server:hangup') cb(true) end)

RegisterNUICallback('transfer', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:transfer', false, b.number, b.amount)
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('emergency', function(b, cb)
    local ok, res = lib.callback.await('gs_phone:emergency', false, b.service, b.text)
    cb({ ok = ok == true, message = res })
end)

-- Réutilise les factures de gs_jobs (mêmes règles serveur)
RegisterNUICallback('bills', function(_, cb) cb(lib.callback.await('gs_jobs:billing:list', false) or {}) end)
RegisterNUICallback('payBill', function(b, cb)
    local ok, res = lib.callback.await('gs_jobs:billing:pay', false, b.id)
    cb({ ok = ok == true, message = res })
end)

RegisterNUICallback('duty', function(_, cb) TriggerServerEvent('gs_jobs:server:toggleDuty') cb(true) end)
-- Applis qui ouvrent un menu d'une autre ressource (le téléphone se range) : plus RP qu'une commande tapée
local EXTERNAL = { jobs = 'job', carnet = 'carnet', journal = 'journal', orders = 'commandes' }
RegisterNUICallback('openApp', function(b, cb)
    cb(true)
    close()
    if EXTERNAL[b.app] then return ExecuteCommand(EXTERNAL[b.app]) end
    if b.app == 'unknown' then
        -- Numéro « Inconnu » : le contact du marché noir et le tableau des contrats (accès vérifié par gs_blackmarket)
        lib.registerContext({ id = 'gs_phone_unknown', title = 'Inconnu', options = {
            { title = 'Appeler le contact', description = 'Il te donne le lieu du rendez-vous (GPS)', icon = 'user-secret',
              onSelect = function() ExecuteCommand('contact') end },
            { title = 'Contrats', description = 'Petits boulots entre gens discrets', icon = 'file-signature',
              onSelect = function() ExecuteCommand('contrats') end },
        } })
        lib.showContext('gs_phone_unknown')
    end
end)

-- App Vibe : relais vers gs_social (mêmes callbacks serveur, mêmes règles que l'ancienne app Néon)
local VIBE = { setHandle = { 'gs_social:setHandle', 'handle' }, post = { 'gs_social:post', 'content' }, like = { 'gs_social:like', 'id' },
    delete = { 'gs_social:delete', 'id' }, report = { 'gs_social:report', 'id' },
    follow = { 'gs_social:follow', 'handle' }, verify = { 'gs_social:verify', 'handle' }, flash = { 'gs_social:flash', 'content' } }
RegisterNUICallback('vibe', function(b, cb)
    if GetResourceState('gs_social') ~= 'started' then return cb(b.op == 'open' and false or { ok = false, message = 'Vibe est hors ligne.' }) end
    if b.op == 'open' then return cb(lib.callback.await('gs_social:open', false) or false) end
    if b.op == 'profile' then return cb(lib.callback.await('gs_social:profile', false, b.handle) or false) end
    if b.op == 'top' then return cb(lib.callback.await('gs_social:top', false) or false) end
    if b.op == 'market' then return cb(GetResourceState('gs_market') == 'started' and lib.callback.await('gs_market:data', false) or false) end
    if b.op == 'post' then
        local ok, msg = lib.callback.await('gs_social:post', false, b.content, b.image)
        return cb({ ok = ok == true, message = msg })
    end
    if b.op == 'story' then
        local ok, msg = lib.callback.await('gs_social:story', false, b.url)
        return cb({ ok = ok == true, message = msg })
    end
    local route = VIBE[b.op]
    if not route then return cb({ ok = false }) end
    local ok, msg = lib.callback.await(route[1], false, b[route[2]])
    cb({ ok = ok == true, message = msg })
end)

-- Appareil photo : le téléphone se cache, capture (screenshot-basic), envoi au serveur qui l'héberge, puis retour.
local uploads = {}
RegisterNetEvent('gs_social:client:uploaded', function(token, url, err) if uploads[token] then uploads[token] = { url = url, err = err } end end)
--- Capture l'écran et l'envoie à l'hébergeur via le serveur → url | nil, erreur. Utilisée par Vibe et par la bodycam police.
local function takePhoto()
    if GetResourceState('screenshot-basic') ~= 'started' then return nil, 'Appareil photo indisponible (screenshot-basic).' end
    local token = ('%d%d'):format(GetGameTimer(), math.random(1000, 9999))
    uploads[token] = true
    exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.6 }, function(data) -- [API] screenshot-basic
        TriggerLatentServerEvent('gs_social:server:upload', 250000, token, data)
    end)
    local deadline = GetGameTimer() + 20000
    while uploads[token] == true and GetGameTimer() < deadline do Wait(100) end
    local res = uploads[token]
    uploads[token] = nil
    if type(res) ~= 'table' or not res.url then return nil, type(res) == 'table' and res.err or 'Envoi trop long, réessaie.' end
    return res.url
end
exports('TakePhoto', takePhoto)

RegisterNUICallback('vibePhoto', function(_, cb)
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
    phoneInHand(false)
    Wait(350)
    local url, err = takePhoto()
    if open then SetNuiFocus(true, true) SendNUIMessage({ action = 'show' }) phoneInHand(true) end
    cb(url and { ok = true, url = url } or { ok = false, message = err })
end)

-- Temps réel : le fil Vibe se met à jour si le téléphone est ouvert
RegisterNetEvent('gs_social:client:new', function(post) if open then SendNUIMessage({ action = 'vibeNew', post = post }) end end)
RegisterNetEvent('gs_social:client:likes', function(id, likes) if open then SendNUIMessage({ action = 'vibeLikes', id = id, likes = likes }) end end)
RegisterNetEvent('gs_social:client:removed', function(id) if open then SendNUIMessage({ action = 'vibeRemoved', id = id }) end end)
RegisterNetEvent('gs_social:client:story', function(story) if open then SendNUIMessage({ action = 'vibeStory', story = story }) end end)

-- App Boulots (gs_gigs)
local function gigsUp() return GetResourceState('gs_gigs') == 'started' end
RegisterNUICallback('gigsList', function(_, cb) cb(gigsUp() and exports.gs_gigs:List() or false) end)
RegisterNUICallback('gigsAccept', function(b, cb)
    if not gigsUp() then return cb({ ok = false, message = 'Service indisponible.' }) end
    local ok, msg = exports.gs_gigs:Accept(tonumber(b.id))
    cb({ ok = ok == true, message = msg })
end)
RegisterNUICallback('gigsCancel', function(_, cb) cb({ ok = gigsUp() and exports.gs_gigs:Cancel() == true, message = 'Boulot annulé.' }) end)

-- Filtre « Vice » (gs_world)
RegisterNUICallback('viceFilter', function(b, cb)
    if GetResourceState('gs_world') == 'started' then exports.gs_world:SetViceFilter(b.on == true) end
    cb(true)
end)

RegisterNUICallback('silent', function(b, cb)
    silent = b.silent == true
    SetResourceKvpInt('gs_phone_silent', silent and 1 or 0)
    cb(true)
end)

-- Serveur → joueur --------------------------------------------------------------------------------
RegisterNetEvent('gs_phone:client:message', function(msg)
    if open then SendNUIMessage({ action = 'message', message = msg }) else pushNotif('💬', msg.from, msg.content) end
    if silent then return end
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
    if not open then lib.notify({ title = 'SMS · ' .. msg.from, description = msg.content:sub(1, 90), icon = 'comment', duration = 6000 }) end
end)

local ringing -- appel entrant pas encore décroché (pour « appel manqué »)
RegisterNetEvent('gs_phone:client:incoming', function(call)
    ringing = call.number
    SendNUIMessage({ action = 'incoming', call = call })
    if not silent then PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', false) end
    if not open then
        lib.notify({ title = 'Appel entrant', description = call.number .. ' · ' .. Config.Key .. ' pour répondre', icon = 'phone', type = 'inform', duration = Config.RingSeconds * 1000 })
    end
end)

RegisterNetEvent('gs_phone:client:callStarted', function(call)
    if ringing then addRecent(ringing, 'in') ringing = nil end
    SendNUIMessage({ action = 'callStarted', call = call })
end)

RegisterNetEvent('gs_phone:client:callEnded', function(reason)
    if ringing then addRecent(ringing, 'missed') pushNotif('📵', 'Appel manqué', ringing) ringing = nil end
    SendNUIMessage({ action = 'callEnded', reason = reason, recents = recents })
    if not open and reason then lib.notify({ description = reason, icon = 'phone-slash' }) end
end)

RegisterNetEvent('gs_phone:client:emergency', function(a)
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = 'Appel ' .. a.service .. ' · ' .. a.number, description = a.text, type = 'warning', icon = 'truck-medical', duration = 12000 })
    pushNotif('🚨', 'Appel ' .. a.service, a.text)
    local blip = AddBlipForCoord(a.coords.x, a.coords.y, a.coords.z)
    SetBlipSprite(blip, 817)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Appel ' .. a.service)
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.EmergencyBlipSeconds * 1000, function() RemoveBlip(blip) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        if open then SetNuiFocus(false, false) end
        phoneInHand(false)
    end
end)

-- V10 · Nouvelles applis -------------------------------------------------------------------------------------
-- Que faire ? (gs_onboarding) : ce qui se passe maintenant + toutes les activités en boutons
RegisterNUICallback('guide', function(_, cb)
    local ok, d = pcall(function() return exports.gs_onboarding:GuideData() end)
    cb(ok and d or false)
end)
RegisterNUICallback('guideAction', function(b, cb)
    local ok, leave = pcall(function() return exports.gs_onboarding:GuideAction(b.ref) end)
    cb(true)
    if ok and leave then close() end
end)

-- Plans : mes lieux favoris, partager ma position, itinéraire depuis un SMS
local function street(c)
    local a, b = GetStreetNameAtCoord(c.x, c.y, c.z)
    local name = GetStreetNameFromHashKey(a)
    if b ~= 0 then name = name .. ' / ' .. GetStreetNameFromHashKey(b) end
    return ('%s, %s'):format(name, GetLabelText(GetNameOfZone(c.x, c.y, c.z)))
end
RegisterNUICallback('places', function(_, cb) cb(loadJson('gs_phone_places', {})) end)
RegisterNUICallback('placeSave', function(b, cb)
    local list = loadJson('gs_phone_places', {})
    if #list >= 20 then return cb({ ok = false, message = '20 lieux au maximum.' }) end
    local c = GetEntityCoords(PlayerPedId())
    local name = tostring(b.name or ''):sub(1, 30)
    list[#list + 1] = { id = now(), name = name ~= '' and name or street(c), x = math.floor(c.x), y = math.floor(c.y), z = math.floor(c.z) }
    saveJson('gs_phone_places', list)
    cb({ ok = true, message = list })
end)
RegisterNUICallback('placeDelete', function(b, cb)
    local list, out = loadJson('gs_phone_places', {}), {}
    for _, p in ipairs(list) do if p.id ~= b.id then out[#out + 1] = p end end
    saveJson('gs_phone_places', out)
    cb({ ok = true, message = out })
end)
RegisterNUICallback('placeGo', function(b, cb)
    local x, y = tonumber(b.x), tonumber(b.y)
    if x and y then SetNewWaypoint(x + 0.0, y + 0.0) end
    cb({ ok = x ~= nil, message = 'GPS réglé.' })
end)
RegisterNUICallback('myPosition', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    cb({ street = street(c), x = math.floor(c.x), y = math.floor(c.y) })
end)

-- Notes (sur le PC du joueur)
RegisterNUICallback('notes', function(_, cb) cb(loadJson('gs_phone_notes', {})) end)
RegisterNUICallback('noteSave', function(b, cb)
    local list = loadJson('gs_phone_notes', {})
    local text = tostring(b.text or ''):sub(1, 600)
    local found = false
    for _, n in ipairs(list) do if n.id == b.id then n.text, n.time, found = text, now(), true end end
    if not found then
        if #list >= 30 then return cb({ ok = false, message = '30 notes au maximum.' }) end
        table.insert(list, 1, { id = now() * 100 + math.random(0, 99), text = text, time = now() })
    end
    saveJson('gs_phone_notes', list)
    cb({ ok = true, message = list })
end)
RegisterNUICallback('noteDelete', function(b, cb)
    local list, out = loadJson('gs_phone_notes', {}), {}
    for _, n in ipairs(list) do if n.id ~= b.id then out[#out + 1] = n end end
    saveJson('gs_phone_notes', out)
    cb({ ok = true, message = out })
end)

-- Ville : ambiance et standing des quartiers, météo
local WEATHER = { CLEAR = 'Ensoleillé', EXTRASUNNY = 'Grand soleil', CLOUDS = 'Nuageux', OVERCAST = 'Couvert', RAIN = 'Pluie',
    CLEARING = 'Éclaircies', THUNDER = 'Orage', SMOG = 'Brume', FOGGY = 'Brouillard', XMAS = 'Neige', SNOW = 'Neige', BLIZZARD = 'Blizzard' }
RegisterNUICallback('city', function(_, cb)
    local w = GlobalState.gsWeather or {}
    cb({ districts = lib.callback.await('gs_city:status', false) or {}, weather = WEATHER[w.type or ''] or w.type or '?',
        storm = GlobalState.gsStorm ~= nil and GlobalState.gsStorm ~= false, clock = clock() })
end)

-- Réglages et notifications
RegisterNUICallback('walk', function(b, cb)
    walk = b.on == true
    SetResourceKvpInt('gs_phone_walk', walk and 1 or 0)
    cb({ ok = true, message = walk and 'Tu peux marcher téléphone ouvert (rouvre-le).' or 'Téléphone en plein écran (rouvre-le).' })
end)
RegisterNUICallback('wallpaper', function(b, cb)
    wallpaper = math.max(0, math.min(5, math.floor(tonumber(b.id) or 0)))
    SetResourceKvpInt('gs_phone_wallpaper', wallpaper)
    cb(true)
end)
RegisterNUICallback('clearNotifs', function(_, cb) notifs = {} cb(true) end)
RegisterNUICallback('clearRecents', function(_, cb) recents = {} saveJson('gs_phone_recents', recents) cb(true) end)
-- Saisie de texte : le perso ne doit pas bouger quand on tape (mode marche)
RegisterNUICallback('typing', function(b, cb)
    typing = b.on == true
    if open and walk then SetNuiFocusKeepInput(not typing) end
    cb(true)
end)
