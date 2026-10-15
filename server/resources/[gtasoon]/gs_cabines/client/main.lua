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
        anim = { dict = 'cellphone@', clip = 'cellphone_call_listen_base' }, prop = { model = 'prop_phone_ing', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        disable = { move = true, car = true, combat = true } }) then return end
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    notify(lib.callback.await('gs_cabines:call', false, kind, r[1], { x = c.x, y = c.y, z = c.z, street = street }))
end

CreateThread(function()
    Wait(2000)
    exports.ox_target:addModel(Config.Models, {
        { name = 'gs_cabines_police', icon = 'fas fa-phone', label = ('Appel anonyme à la police (%d $)'):format(Config.Price), distance = 2.0,
          onSelect = function(data) call('police', data.entity) end },
        { name = 'gs_cabines_press', icon = 'fas fa-newspaper', label = ('Appeler la rédaction Weazel (%d $)'):format(Config.Price), distance = 2.0,
          onSelect = function(data) call('press', data.entity) end },
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
    if res == GetCurrentResourceName() then pcall(function() exports.ox_target:removeModel(Config.Models, { 'gs_cabines_police', 'gs_cabines_press' }) end) end
end)
