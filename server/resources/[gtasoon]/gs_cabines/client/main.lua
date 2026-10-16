-- gs_cabines (client) · V12.60. Alt sur une cabine ou un téléphone mural du jeu : appel anonyme à la police ou à la
-- rédaction Weazel. La position envoyée est celle de la cabine visée (le serveur vérifie qu'on est à côté).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function call(kind, entity)
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    local title = kind == 'police' and 'Appel anonyme à la police' or 'Tuyau anonyme à Weazel News'
    local r = lib.inputDialog(title, { { type = 'textarea', label = kind == 'police' and 'Ce que tu signales (lieu, ce que tu as vu)' or 'Ton tuyau pour la rédaction',
        required = true, min = 5, max = Config.MaxLength, autosize = true } })
    if not r or not r[1] then return end
    local c = GetEntityCoords(entity)
    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    if not lib.progressBar({ duration = Config.CallTime, label = 'Une pièce, le numéro… ça sonne.', canCancel = true,
        anim = { dict = 'cellphone@', clip = 'cellphone_call_listen_base' }, prop = { model = 'prop_cs_phone_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        disable = { move = true, car = true, combat = true } }) then return end
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    notify(lib.callback.await('gs_cabines:call', false, kind, r[1], { x = c.x, y = c.y, z = c.z, street = street }))
end

-- V12.61 · Appel vers un numéro (masqué) : en ligne tant qu'on reste à la cabine ; X ou s'éloigner = raccrocher
local inBoothCall = false
local function callNumber(entity)
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    local r = lib.inputDialog('Appeler un numéro (masqué)', { { type = 'input', label = 'Numéro (ex. 555-1234)', required = true, max = 12 } })
    if not r or not r[1] then return end
    local c = GetEntityCoords(entity)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    local ok, msg = lib.callback.await('gs_cabines:number', false, r[1], { x = c.x, y = c.y, z = c.z, street = street })
    if not ok then return notify(false, msg) end
    inBoothCall = true
    lib.requestAnimDict('cellphone@')
    TaskPlayAnim(cache.ped, 'cellphone@', 'cellphone_call_listen_base', 3.0, 3.0, -1, 49, 0, false, false, false)
    lib.showTextUI('Cabine · ça sonne (numéro masqué) · X : raccrocher', { position = 'bottom-center', icon = 'phone' })
    CreateThread(function()
        -- par frame : seulement pendant l'appel depuis la cabine (touche X lue à chaque image)
        while inBoothCall do
            if IsControlJustPressed(0, 73) or #(GetEntityCoords(cache.ped) - c) > 4.0 or IsEntityDead(cache.ped) then
                TriggerServerEvent('gs_phone:server:hangup')
                break
            end
            Wait(0)
        end
        inBoothCall = false
        lib.hideTextUI()
        StopAnimTask(cache.ped, 'cellphone@', 'cellphone_call_listen_base', 1.0)
    end)
end
RegisterNetEvent('gs_phone:client:callStarted', function() if inBoothCall then lib.showTextUI('Cabine · en ligne (numéro masqué) · X : raccrocher', { position = 'bottom-center', icon = 'phone' }) end end)
RegisterNetEvent('gs_phone:client:callEnded', function() inBoothCall = false end)

-- V12.61 · Écoute (police) : chaque appel passé depuis une cabine sur écoute arrive au central
local function isCop()
    local ok, job = pcall(function() return exports.gs_bridge:GetJob() end)
    return ok and job and job.name == Config.PoliceJob and job.onduty and (tonumber(job.grade) or 0) >= Config.Tap.grade
end
local function tap(action, entity)
    local c = GetEntityCoords(entity)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    if action == 'on' and lib.alertDialog({ header = 'Mettre la cabine sur écoute', centered = true, cancel = true,
        content = ('Mandat du juge obtenu (RP) ? Pendant %d h, chaque appel passé d\'ici arrive au central.'):format(Config.Tap.hours) }) ~= 'confirm' then return end
    notify(lib.callback.await('gs_cabines:tap', false, action, { x = c.x, y = c.y, z = c.z, street = street }))
end
RegisterNetEvent('gs_cabines:client:tapped', function(t)
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = ('Écoute · cabine %s · %s'):format(t.street or '', t.at or ''), icon = 'headphones', type = 'inform', duration = 15000,
        description = ('Appelant : %s · %s%s'):format(t.gender or '?', t.what or 'appel', t.text and (' · « ' .. t.text .. ' »') or '') })
end)

CreateThread(function()
    Wait(2000)
    exports.ox_target:addModel(Config.Models, {
        { name = 'gs_cabines_police', icon = 'fas fa-phone', label = ('Appel anonyme à la police (%d $)'):format(Config.Price), distance = 2.0,
          onSelect = function(data) call('police', data.entity) end },
        { name = 'gs_cabines_press', icon = 'fas fa-newspaper', label = ('Appeler la rédaction Weazel (%d $)'):format(Config.Price), distance = 2.0,
          onSelect = function(data) call('press', data.entity) end },
        { name = 'gs_cabines_number', icon = 'fas fa-phone-volume', label = ('Appeler un numéro, masqué (%d $)'):format(Config.Price), distance = 2.0,
          onSelect = function(data) callNumber(data.entity) end },
        { name = 'gs_cabines_tap', icon = 'fas fa-headphones', label = 'Police : mettre sur écoute (mandat)', distance = 2.0,
          canInteract = isCop, onSelect = function(data) tap('on', data.entity) end },
        { name = 'gs_cabines_untap', icon = 'fas fa-ear-deaf', label = 'Police : retirer l\'écoute', distance = 2.0,
          canInteract = isCop, onSelect = function(data) tap('off', data.entity) end },
    })
end)

-- Rédaction Weazel en service : tuyau reçu en direct, ou /tuyaux pour ceux laissés sur la messagerie
RegisterNetEvent('gs_cabines:client:tip', function(t)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    lib.notify({ title = 'Tuyau anonyme (cabine' .. (t.street and (', ' .. t.street) or '') .. ')', description = '« ' .. t.text .. ' »',
        type = 'inform', icon = 'newspaper', duration = 15000 })
end)
RegisterCommand('tuyaux', function()
    local ok, list = lib.callback.await('gs_cabines:tips', false)
    if not ok then return notify(false, list) end
    local o = {}
    for _, t in ipairs(list) do
        o[#o + 1] = { title = '« ' .. t.text .. ' »', icon = 'phone', readOnly = true,
            description = ('%s · il y a %d min'):format(t.street or 'cabine', math.floor((GetCloudTimeAsInt() - t.at) / 60)) }
    end
    if #o == 0 then o[1] = { title = 'Messagerie vide', icon = 'inbox', readOnly = true } end
    lib.registerContext({ id = 'gs_cabines_tips', title = 'Messagerie de la rédaction', options = o })
    lib.showContext('gs_cabines_tips')
end, false)
TriggerEvent('chat:addSuggestion', '/tuyaux', 'Rédaction Weazel en service : écouter les tuyaux laissés depuis les cabines')

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then pcall(function() exports.ox_target:removeModel(Config.Models, { 'gs_cabines_police', 'gs_cabines_press', 'gs_cabines_number', 'gs_cabines_tap', 'gs_cabines_untap' }) end) end
end)

-- V12.63 · Fausse alerte (police en service) : /faussealerte [n° de l'appel, sinon le dernier]
RegisterCommand('faussealerte', function(_, args)
    notify(lib.callback.await('gs_cabines:falseAlarm', false, tonumber(args[1])))
end, false)
TriggerEvent('chat:addSuggestion', '/faussealerte', 'Police : classer un appel anonyme de cabine en fausse alerte (amende si l\'appel est retrouvé)', { { name = 'n°', help = 'numéro de l\'appel (dans l\'alerte du central), vide = le dernier' } })
