-- gs_lives (serveur) · V12.60. Le staff demande une image de l'écran d'un joueur ; le serveur vérifie le rang et le mode staff,
-- la demande à screenshot-basic (capture côté joueur, envoyée au serveur), puis la renvoie au seul membre du staff qui regarde.
-- Rien n'est enregistré : l'image passe et disparaît. Le visionnage est tracé dans le journal staff.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Lives = { watching = {}, busy = {}, views = {} } -- watching[staff][cible] = true (déjà journalisé) ; busy[staff .. ':' .. cible] = capture en cours

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
        if s ~= src then out[#out + 1] = { id = s, name = Bridge:GetName(s) or GetPlayerName(s) or ('Joueur ' .. s), account = GetPlayerName(s) or '' } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return true, out
end)

RegisterNetEvent('gs_lives:server:frame', function(target)
    local src = source
    target = tonumber(target)
    if not target or not GetPlayerName(target) or target == src then return end
    if not Security:RateLimit(src, 'gs_lives:frame', Config.MaxWindows * 3, 3000) then return end
    if not Lives.allowed(src) or not Lives.ready() then return end
    local key = src .. ':' .. target
    if Lives.busy[key] then return end -- une capture à la fois par fenêtre
    Lives.watching[src] = Lives.watching[src] or {}
    if not Lives.watching[src][target] then
        Lives.watching[src][target] = true
        Lives.views[#Lives.views + 1] = os.time() -- V12.61 : rapport staff de fin de soirée
        Security:LogStaff(('[Lives] %s regarde l\'écran de %s [%d]'):format(GetPlayerName(src) or src, GetPlayerName(target) or '?', target), 'staff')
    end
    Lives.busy[key] = true
    local okS = pcall(function()
        exports['screenshot-basic']:requestClientScreenshot(target, { encoding = 'jpg', quality = Config.Quality }, function(err, data) -- [API] screenshot-basic
            Lives.busy[key] = nil
            if err or type(data) ~= 'string' or not GetPlayerName(src) then return end
            TriggerLatentClientEvent('gs_lives:client:frame', src, 1500000, target, data) -- latent : pas d'à-coup réseau
        end)
    end)
    if not okS then Lives.busy[key] = nil end
    SetTimeout(10000, function() Lives.busy[key] = nil end) -- joueur qui ne répond pas : la fenêtre redemande plus tard
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
end)

--- V12.61 · Nombre de visionnages depuis `since` (rapport staff de fin de soirée, gs_discord)
exports('ViewsSince', function(since)
    local n = 0
    for _, t in ipairs(Lives.views) do if t >= (tonumber(since) or 0) then n = n + 1 end end
    return n
end)
