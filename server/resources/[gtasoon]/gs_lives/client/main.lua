-- gs_lives (client) · V12.60. /lives (ou F11 → Lives) : liste des joueurs à gauche, WATCH ouvre une fenêtre avec l'écran du
-- joueur (V12.64 : flux continu, ≈ 2,5 images/s). Fenêtres déplaçables (barre du haut), redimensionnables (coin), fermables (✕).
-- « Jouer » (ou Échap) rend la souris au jeu : les fenêtres restent affichées pendant que tu joues ; /lives pour reprendre la main.
local open = false   -- liste ouverte, souris dans l'interface
local count = 0      -- fenêtres ouvertes (le NUI tient la liste exacte)

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function focus(on)
    open = on
    SetNuiFocus(on, on)
    SendNUIMessage({ action = 'focus', on = on })
end

local function start()
    if open then return focus(false) end
    local ok, list = lib.callback.await('gs_lives:players', false)
    if not ok then return notify(false, list) end
    SendNUIMessage({ action = 'players', players = list, max = Config.MaxWindows, every = Config.Every })
    focus(true)
end

RegisterCommand(Config.Command, start, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Staff : voir l\'écran des joueurs dans des fenêtres (modération)')
exports('Open', start)

RegisterNUICallback('frame', function(d, cb) TriggerServerEvent('gs_lives:server:frame', tonumber(d.id)) cb(true) end)
RegisterNUICallback('close', function(d, cb) TriggerServerEvent('gs_lives:server:stop', tonumber(d.id)) cb(true) end)
RegisterNUICallback('windows', function(d, cb) count = tonumber(d.n) or 0 cb(true) end)
RegisterNUICallback('release', function(_, cb) focus(false) cb(true) end)
RegisterNUICallback('refresh', function(_, cb)
    local ok, list = lib.callback.await('gs_lives:players', false)
    if ok then SendNUIMessage({ action = 'players', players = list, max = Config.MaxWindows, every = Config.Every }) end
    cb(true)
end)

RegisterNetEvent('gs_lives:client:frame', function(target, data)
    SendNUIMessage({ action = 'frame', id = target, src = data })
end)

-- V12.62 · Bouton TP d'une fenêtre (proposition n° 136) : passe par l'action staff « goto » de gs_admin (droits + journal)
RegisterNUICallback('tp', function(d, cb)
    cb(true)
    local ok, msg = lib.callback.await('gs_admin:action', false, 'goto', tonumber(d.id))
    notify(ok, msg)
end)
-- V12.62 · Replay 30 s d'un joueur lié à un ticket (proposition n° 137)
RegisterNUICallback('replay', function(d, cb) TriggerServerEvent('gs_lives:server:replay', tonumber(d.id)) cb(true) end)
RegisterNetEvent('gs_lives:client:replay', function(target, frames, every)
    SendNUIMessage({ action = 'replay', id = target, frames = frames, every = every })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)

-- V12.63 · Capture demandée par le serveur (ce joueur est regardé par le staff) : faite ici par screenshot-basic, renvoyée par le
-- réseau du jeu (avant : envoi par une adresse web du serveur, qui échouait en silence : « la connexion charge indéfiniment »)
-- V12.64 · fluidité : image réduite (maxWidth) et WebP. Si le jeu ne sait pas faire de WebP (il rend alors un PNG, lourd),
-- on repasse en JPEG pour toute la session.
local webpBroken = false
local function shoot(id, quality, opts, retry)
    local encoding = (opts.encoding == 'webp' and not webpBroken) and 'webp' or 'jpg'
    local maxWidth = math.tointeger(tonumber(opts.maxWidth)) or 0
    local done = false
    local ok, err = pcall(function()
        exports['screenshot-basic']:requestScreenshot({ encoding = encoding, quality = tonumber(quality) or 0.45, maxWidth = maxWidth > 0 and maxWidth or nil }, function(data) -- [API] screenshot-basic
            if done then return end
            done = true
            if type(data) == 'string' and encoding == 'webp' and data:sub(1, 15) == 'data:image/png;' and not retry then
                webpBroken = true -- pas de WebP ici : même capture refaite tout de suite en JPEG, puis JPEG pour la session
                return shoot(id, quality, opts, true)
            end
            local head = type(data) == 'string' and data:sub(1, 23) or ''
            if head ~= 'data:image/jpeg;base64,' and head ~= 'data:image/webp;base64,' then
                return TriggerServerEvent('gs_lives:server:shotFail', id, ('capture vide ou invalide (%s)'):format(type(data) == 'string' and data:sub(1, 30) or type(data)))
            end
            TriggerLatentServerEvent('gs_lives:server:shot', 1500000, id, data) -- V12.63 : envoi 3× plus rapide
        end)
    end)
    if not ok then done = true return TriggerServerEvent('gs_lives:server:shotFail', id, 'appel à screenshot-basic refusé : ' .. tostring(err):sub(1, 120)) end
    SetTimeout(6000, function()
        if done then return end
        done = true
        TriggerServerEvent('gs_lives:server:shotFail', id, 'screenshot-basic n\'a pas répondu en 6 s chez ce joueur (menu Échap, écran de chargement, ou capture bloquée par le jeu)')
    end)
end

RegisterNetEvent('gs_lives:client:capture', function(id, quality, opts)
    -- V12.63 (backtest « les Lives ne marchent toujours pas ») : chaque échec est renvoyé au serveur avec sa raison,
    -- affichée dans la fenêtre du staff et dans la console du serveur (avant : attente muette puis « ne répond pas »)
    if GetResourceState('screenshot-basic') ~= 'started' then
        return TriggerServerEvent('gs_lives:server:shotFail', id, 'screenshot-basic n\'est pas démarré chez ce joueur')
    end
    shoot(id, quality, type(opts) == 'table' and opts or {})
end)

-- V12.63 · Le joueur regardé ne répond pas : la fenêtre l'affiche au lieu de « Connexion à l'écran… » sans fin
RegisterNetEvent('gs_lives:client:frameError', function(target, msg)
    SendNUIMessage({ action = 'frameError', id = target, text = msg })
end)

-- V12.63 · Test de capture sur SON PC (sans le serveur) : /livestest dans F8. Dit si screenshot-basic répond, en combien de
-- temps et quelle taille d'image : permet de savoir si le souci vient du jeu du joueur (version Canary, menu…) ou d'ailleurs.
RegisterCommand('livestest', function()
    if GetResourceState('screenshot-basic') ~= 'started' then return print('^1[livestest] screenshot-basic n\'est pas démarré chez toi.^0') end
    local t0, done = GetGameTimer(), false
    print('[livestest] capture demandée à screenshot-basic…')
    local ok, err = pcall(function()
        exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.4 }, function(data)
            done = true
            local good = type(data) == 'string' and data:sub(1, 23) == 'data:image/jpeg;base64,'
            print(('%s[livestest] réponse en %d ms : %s (%d caractères)^0'):format(good and '^2' or '^1', GetGameTimer() - t0,
                good and 'image OK' or 'image invalide', type(data) == 'string' and #data or 0))
            lib.notify({ description = good and 'Lives : capture OK sur ton PC.' or 'Lives : image invalide (voir F8).', type = good and 'success' or 'error' })
        end)
    end)
    if not ok then return print('^1[livestest] appel refusé : ' .. tostring(err) .. '^0') end
    SetTimeout(8000, function()
        if done then return end
        print('^1[livestest] AUCUNE réponse de screenshot-basic en 8 s. Essaie avec FiveM en version normale (pas Canary) : Paramètres → Mise à jour.^0')
        lib.notify({ description = 'Lives : screenshot-basic ne répond pas sur ton PC (voir F8).', type = 'error' })
    end)
end, false)
