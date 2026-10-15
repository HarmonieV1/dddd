-- gs_lives (client) · V12.60. /lives (ou F11 → Lives) : liste des joueurs à gauche, WATCH ouvre une fenêtre avec l'écran du
-- joueur (une image toutes les 1,5 s). Fenêtres déplaçables (barre du haut), redimensionnables (coin), fermables (✕).
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
