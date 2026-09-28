-- gs_security : briques défensives à utiliser dans TOUS les events serveur sensibles.
-- Usage type :
--   local Security = exports.gs_security
--   RegisterNetEvent('gs_x:buy', function(itemId)
--       local src = source
--       if not Security:RateLimit(src, 'gs_x:buy', 5, 10000) then return end
--       if not Security:InRange(src, shopCoords, 3.0) then return end
--       -- validation job / argent / item côté serveur ici
--   end)

local buckets = {} -- [src][key] = { count, resetAt }

-- Logs Discord ----------------------------------------------------------------
-- Les messages sont regroupés et envoyés toutes les 2 s (limite Discord ~30 req/min par webhook).
-- URL via convars (secrets.cfg) : gs_webhook_<canal> sinon gs_staff_webhook. Jamais en dur.

local queue = {} -- [url] = { lignes }

local function LogStaff(message, channel)
    message = tostring(message)
    print(('[gs_security] %s'):format(message))
    local url = channel and GetConvar('gs_webhook_' .. channel, '') or ''
    if url == '' then url = GetConvar('gs_staff_webhook', '') end
    if url == '' then return end
    queue[url] = queue[url] or {}
    local q = queue[url]
    if #q < 200 then q[#q + 1] = ('`%s` %s'):format(os.date('%H:%M:%S'), message:sub(1, 400)) end
end

local function send(url, lines)
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'GS Logs',
        content = table.concat(lines, '\n'),
        allowed_mentions = { parse = {} }, -- jamais de @everyone depuis un log
    }), { ['Content-Type'] = 'application/json' })
end

--- Envoie au plus 3 messages par webhook et par passage, le reste attend le suivant.
local function flush()
    for url, lines in pairs(queue) do
        local chunk, size, sent, i = {}, 0, 0, 1
        while i <= #lines do
            local line = lines[i]
            if size + #line + 1 > 1900 and #chunk > 0 then
                send(url, chunk)
                chunk, size, sent = {}, 0, sent + 1
                if sent >= 3 then break end
            else
                chunk[#chunk + 1] = line
                size, i = size + #line + 1, i + 1
            end
        end
        if #chunk > 0 then send(url, chunk) end
        local rest = {}
        for j = i, #lines do rest[#rest + 1] = lines[j] end
        queue[url] = #rest > 0 and rest or nil
    end
end

CreateThread(function()
    while true do
        Wait(2000)
        if next(queue) then flush() end
    end
end)

-- Rate-limit -------------------------------------------------------------------

--- Autorise au plus `max` appels par `windowMs` et par joueur/clé.
---@return boolean ok false si le joueur dépasse la limite (loggé une fois par fenêtre)
local function RateLimit(src, key, max, windowMs)
    if type(src) ~= 'number' or src <= 0 then return false end
    local now = GetGameTimer()
    local b = buckets[src]
    if not b then b = {}; buckets[src] = b end
    local e = b[key]
    if not e or now >= e.resetAt then
        b[key] = { count = 1, resetAt = now + windowMs }
        return true
    end
    e.count = e.count + 1
    if e.count > max then
        if e.count == max + 1 then
            LogStaff(('Rate-limit dépassé : id %s (%s) sur %s'):format(src, GetPlayerName(src) or '?', key))
        end
        return false
    end
    return true
end

-- Distances ----------------------------------------------------------------------

local function toVec3(c) return vec3(c.x, c.y, c.z) end

--- Le ped du joueur est à moins de `maxDist` de `coords` (vector3/vector4).
local function InRange(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - toVec3(coords)) <= maxDist
end

--- Deux joueurs sont à moins de `maxDist` l'un de l'autre.
local function PlayersInRange(src, target, maxDist)
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if not a or not b or a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= maxDist
end

--- Le joueur est à moins de `maxDist` d'une entité.
local function EntityInRange(src, entity, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not entity or not DoesEntityExist(entity) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= maxDist
end

-- Texte ------------------------------------------------------------------------------

--- Nettoie un texte venant du client : caractères de contrôle, balises, longueur.
---@return string|nil texte propre ou nil si vide/invalide
local function Sanitize(text, maxLen)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%c', ' '):gsub('[<>`@]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    text = text:sub(1, maxLen or 100)
    return text ~= '' and text or nil
end

AddEventHandler('playerDropped', function() buckets[source] = nil end)

exports('RateLimit', RateLimit)
exports('InRange', InRange)
exports('PlayersInRange', PlayersInRange)
exports('EntityInRange', EntityInRange)
exports('Sanitize', Sanitize)
exports('LogStaff', LogStaff)
