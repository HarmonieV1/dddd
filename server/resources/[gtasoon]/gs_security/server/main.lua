-- gs_security : briques défensives à utiliser dans TOUS les events serveur sensibles.
-- Usage :
--   RegisterNetEvent('gs_x:buy', function(itemId)
--       local src = source
--       if not exports.gs_security:RateLimit(src, 'gs_x:buy', 5, 10000) then return end
--       if not exports.gs_security:InRange(src, shopCoords, 3.0) then return end
--       -- validation job/argent/item côté serveur ici
--   end)

local buckets = {} -- [src][key] = { count, resetAt }

--- Autorise au plus `max` appels par `windowMs` et par joueur/clé.
---@return boolean ok false si le joueur dépasse la limite (déjà loggé)
local function RateLimit(src, key, max, windowMs)
    if type(src) ~= 'number' or src <= 0 then return false end
    local now = GetGameTimer()
    buckets[src] = buckets[src] or {}
    local b = buckets[src][key]
    if not b or now >= b.resetAt then
        buckets[src][key] = { count = 1, resetAt = now + windowMs }
        return true
    end
    b.count = b.count + 1
    if b.count > max then
        if b.count == max + 1 then -- un seul log par fenêtre
            LogStaff(('Rate-limit dépassé : id %s sur %s'):format(src, key))
        end
        return false
    end
    return true
end

--- Vérifie que le ped du joueur est à moins de `maxDist` de `coords` (vector3).
local function InRange(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= maxDist
end

--- Log vers le webhook staff. URL via convar `gs_staff_webhook` (secrets.cfg), jamais en dur.
function LogStaff(message)
    local url = GetConvar('gs_staff_webhook', '')
    print(('[gs_security] %s'):format(message))
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST',
        json.encode({ username = 'GS Security', content = message:sub(1, 1900) }),
        { ['Content-Type'] = 'application/json' })
end

AddEventHandler('playerDropped', function() buckets[source] = nil end)

exports('RateLimit', RateLimit)
exports('InRange', InRange)
exports('LogStaff', LogStaff)
