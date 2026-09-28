-- gs_social (client) : ouvre l'app NUI Néon et relaie ses actions au serveur. 0 boucle.
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

RegisterCommand('neon', toggle, false)
RegisterKeyMapping('neon', 'Réseau social Néon', 'keyboard', Config.Key)

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
        lib.notify({ title = 'Néon · @' .. post.handle, description = post.content:sub(1, 90), icon = 'hashtag', duration = 5000 })
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
