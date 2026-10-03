-- gs_social (client) : Vibe, réseau social. Vit dans le téléphone (gs_phone, app Vibe) ; /vibe ouvre la version grand écran.
local open = false
local muted = GetResourceKvpInt('gs_social_muted') == 1

local function close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function toggle()
    if open then return close() end
    local data = lib.callback.await('gs_social:open', false)
    if not data then return end
    data.muted = muted
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterCommand('vibe', toggle, false) -- pas de touche dédiée : l'app Vibe du téléphone (F1) suffit

RegisterNUICallback('close', function(_, cb) close() cb(true) end)

-- Actions : { result = ok, message = msg }
for _, action in ipairs({ 'setHandle', 'post', 'like', 'delete', 'report' }) do
    RegisterNUICallback(action, function(body, cb)
        local ok, msg
        if action == 'setHandle' then ok, msg = lib.callback.await('gs_social:setHandle', false, body.handle)
        elseif action == 'post' then ok, msg = lib.callback.await('gs_social:post', false, body.content)
        elseif action == 'like' then ok, msg = lib.callback.await('gs_social:like', false, body.id)
        elseif action == 'delete' then ok, msg = lib.callback.await('gs_social:delete', false, body.id)
        else ok, msg = lib.callback.await('gs_social:report', false, body.id) end
        cb({ ok = ok == true, message = msg })
    end)
end

RegisterNUICallback('mute', function(body, cb)
    muted = body.muted == true
    SetResourceKvpInt('gs_social_muted', muted and 1 or 0)
    cb(true)
end)

RegisterNetEvent('gs_social:client:new', function(post)
    if open then
        SendNUIMessage({ action = 'new', post = post })
    elseif not muted then
        lib.notify({ title = 'Vibe · @' .. post.handle, description = post.content:sub(1, 90), icon = 'hashtag', duration = 5000 })
    end
end)

RegisterNetEvent('gs_social:client:likes', function(id, likes)
    if open then SendNUIMessage({ action = 'likes', id = id, likes = likes }) end
end)

RegisterNetEvent('gs_social:client:removed', function(id)
    if open then SendNUIMessage({ action = 'removed', id = id }) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)

-- Bandeau Weazel News aux couleurs de la chaîne (rouge Weazel, texte blanc, en haut de l'écran) : flash info, articles,
-- brèves de faits divers. Toutes les annonces Weazel passent par là.
local WEAZEL_STYLE = { backgroundColor = '#c8102e', color = '#ffffff', borderLeft = '6px solid #ffffff', fontWeight = 600,
    ['.description'] = { color = '#ffffff', opacity = 0.95 } }
local function weazel(kind, text, duration)
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ id = 'weazel', title = 'WEAZEL NEWS · ' .. kind, description = text, icon = 'tv', iconColor = '#ffffff',
        position = 'top', style = WEAZEL_STYLE, duration = duration or 11000 })
end
RegisterNetEvent('gs_social:client:weazel', weazel)

RegisterNetEvent('gs_social:client:flash', function(handle, content)
    weazel('FLASH INFO', ('@%s : %s'):format(handle, content:sub(1, 160)), 12000)
end)

-- Tendances Vibe : annonce + rassemblement (blip, présence comptée automatiquement sur place)
RegisterNetEvent('gs_social:client:trend', function(msg)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    lib.notify({ title = '🔥 Tendance sur Vibe', description = msg, type = 'inform', icon = 'hashtag', duration = 12000 })
end)

local gatherBlip, gatherWatch = nil, false
local function onGathering(g)
    if gatherBlip then RemoveBlip(gatherBlip) gatherBlip = nil end
    if not g then return end
    gatherBlip = AddBlipForCoord(g.x, g.y, g.z)
    SetBlipSprite(gatherBlip, 280) SetBlipColour(gatherBlip, 48) SetBlipScale(gatherBlip, 1.1) SetBlipFlashes(gatherBlip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('#rassemblement · ' .. g.label) EndTextCommandSetBlipName(gatherBlip)
    if gatherWatch then return end
    gatherWatch = true
    CreateThread(function()
        local counted = false
        while GlobalState.gsVibeGathering and not counted do
            local cur = GlobalState.gsVibeGathering
            if #(GetEntityCoords(cache.ped) - vec3(cur.x, cur.y, cur.z)) < Config.Trends.rassemblement.radius then
                local ok, msg = lib.callback.await('gs_social:attend', false)
                if ok then lib.notify({ description = msg, type = 'success' }) end
                counted = true
            end
            Wait(3000)
        end
        gatherWatch = false
    end)
end
AddStateBagChangeHandler('gsVibeGathering', 'global', function(_, _, value) onGathering(value) end)
CreateThread(function() onGathering(GlobalState.gsVibeGathering) end)
