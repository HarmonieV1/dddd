-- gs_lives (serveur) · V12.60 (V12.62 : replay 30 s des tickets). Le staff demande une image de l'écran d'un joueur ; le serveur vérifie le rang et le mode staff,
-- demande une capture au joueur (V12.63 : faite chez lui par screenshot-basic, renvoyée par le réseau du jeu), puis la renvoie au
-- seul membre du staff qui regarde.
-- Rien n'est enregistré : l'image passe et disparaît. Le visionnage est tracé dans le journal staff.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Lives = { watching = {}, busy = {}, views = {}, replay = {}, reported = {}, waiters = {}, lastShot = {} } -- watching[staff][cible] = true (déjà journalisé) ; busy[cible] = capture en cours (V12.62 : une par joueur regardé)
-- V12.62 : replay[cible] = { frames = { images }, busy } ; reported[cible] = n° du ticket ouvert (gs_admin)

local function started(r) return GetResourceState(r) == 'started' end

function Lives.allowed(src)
    if not started('gs_admin') then return false, 'gs_admin n\'est pas démarré.' end
    local okL, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    if not okL or (tonumber(lvl) or 0) < Config.Level then return false, 'Réservé au staff (modérateur et plus).' end
    local okD, duty = pcall(function() return exports.gs_admin:IsOnDuty(src) end)
    if okD and duty == false then return false, 'Passe en mode staff d\'abord (F11 → 1re ligne).' end
    return true
end

function Lives.ready() return started('screenshot-basic') end

lib.callback.register('gs_lives:players', function(src)
    if not Security:RateLimit(src, 'gs_lives:players', 6, 10000) then return false, 'Doucement.' end
    local ok, err = Lives.allowed(src)
    if not ok then return false, err end
    if not Lives.ready() then return false, 'Il manque la ressource screenshot-basic (voir docs/PHOTOS.md, étape 1).' end
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local r = Lives.replay[s] -- V12.63 : soi-même aussi (« (toi : test) ») pour vérifier les Lives sans second joueur
        out[#out + 1] = { id = s, name = (Bridge:GetName(s) or GetPlayerName(s) or ('Joueur ' .. s)) .. (s == src and ' (toi : test)' or ''),
            account = GetPlayerName(s) or '', ticket = Lives.reported[s], replay = r and #r.frames > 0 or nil } -- V12.62
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return true, out
end)

-- V12.63 · CAPTURE (backtest : « la connexion charge indéfiniment ») ------------------------------------------------------
-- Avant : requestClientScreenshot, qui fait ENVOYER l'image par le joueur à une adresse web du serveur (http://IP:30120) ;
-- ce chemin échoue en silence chez beaucoup de joueurs (connexion par cfx.re, https, pare-feu) et la fenêtre attendait sans fin.
-- Maintenant : le serveur demande au joueur une capture (requestScreenshot côté joueur, rien ne passe par le web), le joueur la
-- renvoie par le réseau du jeu (événement latent). Une seule capture en cours par joueur, partagée entre F11, les replays et
-- l'appli staff (export Capture). Une réponse n'est acceptée que du joueur visé et pour une demande en cours.
Lives.pending, Lives.last, Lives.nextReq = {}, {}, 0 -- pending[id] = { target, cbs, gen } ; last[cible] = { at, data }

local function resolve(id, ok, data)
    local p = Lives.pending[id]
    if not p then return end
    Lives.pending[id] = nil
    if Lives.busy[p.target] == id then Lives.busy[p.target] = nil end
    if ok then Lives.last[p.target] = { at = GetGameTimer(), data = data } end
    for _, cb in ipairs(p.cbs) do pcall(cb, ok, data) end
end

--- cb(ok, image | message). Image récente (< 1 s) partagée, capture en cours rejointe, sinon nouvelle demande au joueur.
function Lives.capture(target, quality, cb)
    target = math.tointeger(tonumber(target))
    if not target or not GetPlayerName(target) then return cb(false, 'Ce joueur n\'est plus en ville.') end
    if not Lives.ready() then return cb(false, 'screenshot-basic n\'est pas démarré.') end
    local l = Lives.last[target]
    if l and GetGameTimer() - l.at < 1000 then return cb(true, l.data) end
    local id = Lives.busy[target]
    if id and Lives.pending[id] then table.insert(Lives.pending[id].cbs, cb) return end
    Lives.nextReq = Lives.nextReq + 1
    id = Lives.nextReq
    Lives.pending[id] = { target = target, cbs = { cb } }
    Lives.busy[target] = id
    TriggerClientEvent('gs_lives:client:capture', target, id, quality or Config.Quality)
    SetTimeout(8000, function() resolve(id, false, 'Le joueur ne répond pas (écran en chargement, menu Échap, ou screenshot-basic absent chez lui).') end)
end

RegisterNetEvent('gs_lives:server:shot', function(id, data)
    local src = source
    if not Security:RateLimit(src, 'gs_lives:shot', 12, 6000) then return end
    local p = Lives.pending[math.tointeger(tonumber(id)) or -1]
    if not p or p.target ~= src then return end -- seulement le joueur visé, pour une demande en cours
    id = math.tointeger(tonumber(id))
    if type(data) ~= 'string' or #data > 3000000 or data:sub(1, 23) ~= 'data:image/jpeg;base64,' then return resolve(id, false, 'Image refusée.') end
    resolve(id, true, data)
end)

-- V12.63 · La capture a échoué chez le joueur : la raison va dans la fenêtre du staff et (une fois par minute) dans la console
Lives.failLog = 0
RegisterNetEvent('gs_lives:server:shotFail', function(id, reason)
    local src = source
    if not Security:RateLimit(src, 'gs_lives:shotFail', 12, 6000) then return end
    id = math.tointeger(tonumber(id))
    local p = id and Lives.pending[id]
    if not p or p.target ~= src then return end
    reason = Security:Sanitize(tostring(reason or '?'), 160) or '?'
    if GetGameTimer() - Lives.failLog > 60000 then
        Lives.failLog = GetGameTimer()
        print(('^3[gs_lives] capture impossible chez %s [%d] : %s^0'):format(GetPlayerName(src) or '?', src, reason))
    end
    resolve(id, false, 'Capture impossible : ' .. reason .. '.')
end)

exports('Capture', function(target, quality, cb) Lives.capture(target, quality, cb) end) -- appli staff (gs_admin/web.lua)

RegisterNetEvent('gs_lives:server:frame', function(target)
    local src = source
    target = math.tointeger(tonumber(target))
    if not target or not GetPlayerName(target) then return end -- V12.63 : se regarder soi-même = test
    if not Security:RateLimit(src, 'gs_lives:frame', Config.MaxWindows * 3, 3000) then return end
    if not Lives.allowed(src) or not Lives.ready() then return end
    Lives.watching[src] = Lives.watching[src] or {}
    if not Lives.watching[src][target] then
        Lives.watching[src][target] = true
        Lives.views[#Lives.views + 1] = os.time() -- V12.61 : rapport staff de fin de soirée
        while #Lives.views > 500 do table.remove(Lives.views, 1) end -- V12.62 : la liste ne grossit pas sans fin
        Security:LogStaff(('[Lives] %s regarde l\'écran de %s [%d]'):format(GetPlayerName(src) or src, GetPlayerName(target) or '?', target), 'staff')
    end
    Lives.lastShot[target] = GetGameTimer() -- une fenêtre le filme : le replay n'a pas besoin de capture en plus
    Lives.capture(target, Config.Quality, function(ok, data)
        if not GetPlayerName(src) then return end
        if not ok then return TriggerClientEvent('gs_lives:client:frameError', src, target, data) end
        TriggerLatentClientEvent('gs_lives:client:frame', src, 1500000, target, data) -- latent : pas d'à-coup réseau
        local r = Lives.replay[target] -- un ticket est ouvert : l'image sert aussi au replay
        if r then
            r.frames[#r.frames + 1] = data
            if #r.frames > Config.Replay.frames then table.remove(r.frames, 1) end
        end
    end)
end)

RegisterNetEvent('gs_lives:server:stop', function(target)
    if not Security:RateLimit(source, 'gs_lives:stop', 10, 5000) then return end
    local w = Lives.watching[source]
    if w then w[tonumber(target) or -1] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Lives.watching[src] = nil
    for _, w in pairs(Lives.watching) do w[src] = nil end
    Lives.busy[src], Lives.waiters[src], Lives.lastShot[src], Lives.last[src] = nil, nil, nil, nil -- pas de capture « en cours » orpheline
    for id, p in pairs(Lives.pending) do if p.target == src then resolve(id, false, 'Le joueur est parti.') end end
    Lives.replay[src], Lives.reported[src] = nil, nil
end)

-- V12.62 · Replay staff 30 s (proposition n° 137) ---------------------------------------------------------------
-- Tant qu'un ticket est ouvert, l'écran de son auteur (et du joueur qu'il a nommé : « /report 12 … ») est gardé en
-- mémoire : les `Config.Replay.frames` dernières images, une toutes les `every` ms. Rien n'est écrit sur le disque ;
-- le ticket fermé (ou le joueur parti), tout est effacé. Le staff le revoit depuis /lives (bouton REPLAY).
function Lives.replayTick()
    local R = Config.Replay
    if not R.enabled or not Lives.ready() or not started('gs_admin') then Lives.replay, Lives.reported = {}, {} return end
    local ok, list = pcall(function() return exports.gs_admin:ReportedPlayers() end)
    Lives.reported = ok and type(list) == 'table' and list or {}
    local n = 0
    for target in pairs(Lives.replay) do if not Lives.reported[target] then Lives.replay[target] = nil end end -- ticket fermé : effacé
    for target in pairs(Lives.reported) do
        n = n + 1
        if n > R.max then break end
        local r = Lives.replay[target] or { frames = {} }
        Lives.replay[target] = r
        local recent = Lives.lastShot[target] and GetGameTimer() - Lives.lastShot[target] < R.every -- déjà filmé par une fenêtre Lives
        if not r.busy and not recent and GetPlayerName(target) then
            r.busy = true
            Lives.capture(target, R.quality, function(okC, data) -- V12.63 : même capture que F11 et l'appli
                r.busy = false
                if not okC or Lives.replay[target] ~= r then return end
                r.frames[#r.frames + 1] = data
                if #r.frames > R.frames then table.remove(r.frames, 1) end
            end)
        end
    end
end

RegisterNetEvent('gs_lives:server:replay', function(target)
    local src = source
    target = tonumber(target)
    if not Security:RateLimit(src, 'gs_lives:replay', 3, 10000) then return end
    if not target or not Lives.allowed(src) then return end
    local r = Lives.replay[target]
    if not r or #r.frames == 0 then return TriggerClientEvent('ox_lib:notify', src, { description = 'Pas encore d\'images pour ce joueur.', type = 'error' }) end
    Security:LogStaff(('[Lives] %s revoit les %d dernières images de %s [%d] (ticket #%s)'):format(GetPlayerName(src) or src, #r.frames,
        GetPlayerName(target) or '?', target, tostring(Lives.reported[target] or '?')), 'staff')
    local copy = {}
    for i, f in ipairs(r.frames) do copy[i] = f end
    TriggerLatentClientEvent('gs_lives:client:replay', src, 2000000, target, copy, Config.Replay.every) -- latent : pas d'à-coup réseau
end)

CreateThread(function()
    while true do
        Wait(Config.Replay.every)
        Lives.replayTick()
    end
end)

--- V12.61 · Nombre de visionnages depuis `since` (rapport staff de fin de soirée, gs_discord)
exports('ViewsSince', function(since)
    local n = 0
    for _, t in ipairs(Lives.views) do if t >= (tonumber(since) or 0) then n = n + 1 end end
    return n
end)

--- V12.63 · Appli staff externe (gs_admin/web.lua) : joueurs qui ont un replay ({ [id] = { ticket, frames } }) et ses images
exports('ReplayInfo', function()
    local out = {}
    for id, r in pairs(Lives.replay) do if #r.frames > 0 then out[id] = { ticket = Lives.reported[id], frames = #r.frames } end end
    return out
end)
exports('ReplayFrames', function(target)
    local r = Lives.replay[tonumber(target) or -1]
    if not r then return {} end
    local copy = {}
    for i, f in ipairs(r.frames) do copy[i] = f end
    return copy
end)
