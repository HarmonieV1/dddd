-- gs_lives (serveur) · V12.60 (V12.62 : replay 30 s des tickets). Le staff demande une image de l'écran d'un joueur ; le serveur vérifie le rang et le mode staff,
-- demande une capture au joueur (V12.63 : faite chez lui par screenshot-basic, renvoyée par le réseau du jeu), puis la renvoie au
-- seul membre du staff qui regarde.
-- Rien n'est enregistré : l'image passe et disparaît. Le visionnage est tracé dans le journal staff.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Lives = { watching = {}, busy = {}, views = {}, replay = {}, reported = {}, waiters = {}, lastShot = {}, sent = {} } -- V12.64 : sent[staff][cible] = n° de la dernière image reçue -- watching[staff][cible] = true (déjà journalisé) ; busy[cible] = capture en cours (V12.62 : une par joueur regardé)
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
Lives.pending, Lives.last, Lives.nextReq, Lives.lastErr = {}, {}, 0, {} -- lastErr[cible] = { at, text } (V12.63 : appli staff) -- pending[id] = { target, cbs, at } ; last[cible] = { at, data, seq }
-- V12.64 · FLUIDITÉ (backtest : « ça marche mais ça rame vraiment ») : tant que quelqu'un regarde un joueur (fenêtre F11 ou
-- appli, `lease`), l'image suivante est demandée dès que la précédente est arrivée (au plus une toutes les Config.Every ms) :
-- elle est souvent déjà là quand le staff la réclame. Chaque image a un numéro (`seq`) : personne ne reçoit deux fois la même.
-- Les images sont réduites chez le joueur (Config.MaxWidth) et compressées en WebP : 4 à 6 fois plus légères qu'avant.
Lives.lease, Lives.seq, Lives.lastReq = {}, 0, {} -- lease[cible] = moment (ms) jusqu'où quelqu'un regarde ; lastReq[cible] = dernière demande

local pump -- défini plus bas (relance de la capture suivante)

local function resolve(id, ok, data)
    local p = Lives.pending[id]
    if not p then return end
    Lives.pending[id] = nil
    if Lives.busy[p.target] == id then Lives.busy[p.target] = nil end
    local seq
    if ok then
        Lives.seq = Lives.seq + 1
        seq = Lives.seq
        Lives.last[p.target], Lives.lastErr[p.target] = { at = GetGameTimer(), data = data, seq = seq }, nil
    else Lives.lastErr[p.target] = { at = GetGameTimer(), text = tostring(data) } end
    for _, cb in ipairs(p.cbs) do pcall(cb, ok, data, seq) end
    -- V12.64 : quelqu'un regarde encore → image suivante tout de suite en file (Lives.capture respecte Config.Every ;
    -- après un échec : 2 s d'attente, pour ne pas harceler le joueur)
    local lease = Lives.lease[p.target]
    if lease and GetGameTimer() < lease then
        if not ok then Lives.lastReq[p.target] = GetGameTimer() + 2000 - Config.Every end
        pump(p.target)
    end
end

--- cb(ok, image | message, seq). Image récente (< 1 s) partagée, capture en cours rejointe, sinon nouvelle demande au joueur.
--- V12.64 : `after` = numéro de la dernière image déjà reçue par l'appelant : seule une image PLUS RÉCENTE lui est rendue.
function Lives.capture(target, quality, cb, after)
    target = math.tointeger(tonumber(target))
    if not target or not GetPlayerName(target) then return cb(false, 'Ce joueur n\'est plus en ville.') end
    if not Lives.ready() then return cb(false, 'screenshot-basic n\'est pas démarré.') end
    local l = Lives.last[target]
    if l and GetGameTimer() - l.at < 1000 and (l.seq or 0) > (tonumber(after) or 0) then return cb(true, l.data, l.seq) end
    local id = Lives.busy[target]
    if id and Lives.pending[id] then table.insert(Lives.pending[id].cbs, cb) return end
    Lives.nextReq = Lives.nextReq + 1
    id = Lives.nextReq
    -- V12.64 : au plus une demande au joueur toutes les Config.Every ms ; en attendant, la demande existe déjà (les autres
    -- fenêtres, l'appli et le replay la rejoignent au lieu d'en lancer une autre)
    local now = GetGameTimer()
    local delay = math.max(0, Config.Every - (now - (Lives.lastReq[target] or -math.huge)))
    Lives.lastReq[target] = now + delay
    Lives.pending[id] = { target = target, cbs = { cb }, at = now + delay }
    Lives.busy[target] = id
    local function send()
        if not Lives.pending[id] then return end
        TriggerClientEvent('gs_lives:client:capture', target, id, quality or Config.Quality, { maxWidth = Config.MaxWidth, encoding = Config.Encoding })
    end
    if delay > 0 then SetTimeout(delay, send) else send() end
    SetTimeout(8000 + delay, function() resolve(id, false, 'Le joueur ne répond pas (écran en chargement, menu Échap, ou screenshot-basic absent chez lui).') end)
end

--- V12.64 : quelqu'un regarde `target` pendant encore `ms` (fenêtre F11, appli) : la capture continue toute seule
function Lives.watch(target, ms)
    target = math.tointeger(tonumber(target))
    if not target then return end
    Lives.lease[target] = math.max(Lives.lease[target] or 0, GetGameTimer() + (ms or Config.Lease))
end

--- V12.64 : capture suivante d'un joueur regardé (une seule en cours, jamais l'image déjà reçue)
function pump(target)
    local lease = Lives.lease[target]
    if not lease or GetGameTimer() >= lease or not GetPlayerName(target) then Lives.lease[target] = nil return end
    if Lives.busy[target] and Lives.pending[Lives.busy[target]] then return end
    local l = Lives.last[target]
    Lives.capture(target, Config.Quality, function() end, l and l.seq or 0)
end
Lives.pump = pump

--- V12.64 : JPEG ou WebP (plus léger), rien d'autre
function Lives.isImage(data)
    local head = data:sub(1, 23)
    return head == 'data:image/jpeg;base64,' or head == 'data:image/webp;base64,'
end

RegisterNetEvent('gs_lives:server:shot', function(id, data)
    local src = source
    if not Security:RateLimit(src, 'gs_lives:shot', 40, 6000) then return end -- V12.64 : flux continu (≈ 2,5 images/s)
    local p = Lives.pending[math.tointeger(tonumber(id)) or -1]
    if not p or p.target ~= src then return end -- seulement le joueur visé, pour une demande en cours
    id = math.tointeger(tonumber(id))
    if type(data) ~= 'string' or #data > 3000000 or not Lives.isImage(data) then return resolve(id, false, 'Image refusée.') end
    resolve(id, true, data)
end)

-- V12.63 · La capture a échoué chez le joueur : la raison va dans la fenêtre du staff et (une fois par minute) dans la console
Lives.failLog = 0
RegisterNetEvent('gs_lives:server:shotFail', function(id, reason)
    local src = source
    if not Security:RateLimit(src, 'gs_lives:shotFail', 40, 6000) then return end
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
--- V12.63 (backtest : l'appli affichait « serveur injoignable ») : l'appli ne garde plus la connexion ouverte en attendant la
--- capture. Request lance une capture (sans attendre), Peek rend tout de suite la dernière image (et son âge en ms) ou la raison
--- du dernier échec. L'appli redemande toutes les 1,5 s : l'image arrive à la demande suivante.
exports('Request', function(target, quality)
    Lives.watch(target, Config.Lease) -- V12.64 : l'appli regarde ce joueur, la capture continue toute seule
    local l = Lives.last[math.tointeger(tonumber(target)) or -1]
    Lives.capture(target, quality, function() end, l and l.seq or 0)
end)
exports('Peek', function(target)
    target = math.tointeger(tonumber(target))
    local l, e = target and Lives.last[target], target and Lives.lastErr[target]
    local now = GetGameTimer()
    return { img = l and l.data or nil, age = l and (now - l.at) or nil, seq = l and l.seq or nil, -- V12.64 : numéro de l'image
        err = (e and (not l or e.at > l.at)) and e.text or nil } -- une table (sûr entre ressources)
end)

-- V12.64 : la fenêtre redemande dès qu'elle a reçu une image (≈ 2,5 images/s) ; limite : 12 demandes par fenêtre en 3 s
RegisterNetEvent('gs_lives:server:frame', function(target)
    local src = source
    target = math.tointeger(tonumber(target))
    if not target or not GetPlayerName(target) then return end -- V12.63 : se regarder soi-même = test
    if not Security:RateLimit(src, 'gs_lives:frame', Config.MaxWindows * 12, 3000) then return end
    if not Lives.allowed(src) or not Lives.ready() then return end
    Lives.watching[src] = Lives.watching[src] or {}
    if not Lives.watching[src][target] then
        Lives.watching[src][target] = true
        Lives.views[#Lives.views + 1] = os.time() -- V12.61 : rapport staff de fin de soirée
        while #Lives.views > 500 do table.remove(Lives.views, 1) end -- V12.62 : la liste ne grossit pas sans fin
        Security:LogStaff(('[Lives] %s regarde l\'écran de %s [%d]'):format(GetPlayerName(src) or src, GetPlayerName(target) or '?', target), 'staff')
    end
    Lives.lastShot[target] = GetGameTimer() -- une fenêtre le filme : le replay n'a pas besoin de capture en plus
    Lives.watch(target, Config.Lease) -- V12.64 : capture continue tant que la fenêtre est ouverte
    Lives.sent[src] = Lives.sent[src] or {}
    local waitAt = Lives.sent[src].wait and Lives.sent[src].wait[target]
    if waitAt and GetGameTimer() - waitAt < 9000 then return end -- déjà en attente de l'image suivante
    Lives.sent[src].wait = Lives.sent[src].wait or {}
    Lives.sent[src].wait[target] = GetGameTimer()
    Lives.capture(target, Config.Quality, function(ok, data, seq)
        local mine = Lives.sent[src]
        if mine and mine.wait then mine.wait[target] = nil end
        if not GetPlayerName(src) then return end
        if not ok then return TriggerClientEvent('gs_lives:client:frameError', src, target, data) end
        if mine then mine[target] = seq end
        TriggerLatentClientEvent('gs_lives:client:frame', src, 3000000, target, data) -- latent : pas d'à-coup réseau
        local r = Lives.replay[target] -- un ticket est ouvert : l'image sert aussi au replay
        if r and GetGameTimer() - (r.at or -math.huge) >= Config.Replay.every then -- V12.64 : au rythme du replay (30 s gardées)
            r.at = GetGameTimer()
            r.frames[#r.frames + 1] = data
            if #r.frames > Config.Replay.frames then table.remove(r.frames, 1) end
        end
    end, Lives.sent[src][target])
end)

RegisterNetEvent('gs_lives:server:stop', function(target)
    if not Security:RateLimit(source, 'gs_lives:stop', 10, 5000) then return end
    local w = Lives.watching[source]
    if w then w[tonumber(target) or -1] = nil end
    local m = Lives.sent[source] -- V12.64 : la fenêtre rouvre proprement (plus d'attente fantôme)
    if m then m[tonumber(target) or -1] = nil if m.wait then m.wait[tonumber(target) or -1] = nil end end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Lives.watching[src] = nil
    for _, w in pairs(Lives.watching) do w[src] = nil end
    Lives.busy[src], Lives.waiters[src], Lives.lastShot[src], Lives.last[src], Lives.lastErr[src] = nil, nil, nil, nil, nil -- pas de capture « en cours » orpheline
    Lives.lease[src], Lives.sent[src] = nil, nil -- V12.64
    for _, m in pairs(Lives.sent) do m[src] = nil if m.wait then m.wait[src] = nil end end
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
                r.at = GetGameTimer()
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
