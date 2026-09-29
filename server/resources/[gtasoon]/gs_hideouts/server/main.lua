-- gs_hideouts (serveur) : location, entrée / sortie (monde séparé par locataire), coffre personnel.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Hideouts = { inside = {} } -- [src] = site

local WEEK = 7 * 24 * 3600

local function rental(src)
    local cid = Bridge:GetIdentifier(src)
    local r = cid and Store.get(cid)
    return cid, r
end

local function bucketOf(src) return Config.BucketBase + src end

lib.callback.register('gs_hideouts:info', function(src)
    if not Security:RateLimit(src, 'gs_hideouts:info', 5, 10000) then return nil end
    local _, r = rental(src)
    return r and { site = r.site, expires = r.expires, now = os.time() } or {}
end)

--- Louer (ou prolonger) : payé en banque, une seule planque par personnage, 4 semaines maximum d'avance.
lib.callback.register('gs_hideouts:rent', function(src, siteId, weeks)
    if not Security:RateLimit(src, 'gs_hideouts:rent', 3, 10000) then return false, 'Doucement.' end
    local site = Config.Sites[siteId]
    weeks = tonumber(weeks)
    if not site or not weeks or weeks ~= math.floor(weeks) or weeks < 1 or weeks > Config.MaxWeeks then return false, 'Invalide.' end
    local e = site.entrance
    if not Security:InRange(src, vec3(e.x, e.y, e.z), 5.0) then return false, 'Trop loin de la réception.' end
    local cid, r = rental(src)
    if not cid then return false, 'Invalide.' end
    local now = os.time()
    if r and r.site ~= siteId and r.expires > now then return false, 'Tu loues déjà une planque ailleurs.' end
    local base = (r and r.site == siteId and r.expires > now) and r.expires or now
    if base + weeks * WEEK > now + Config.MaxWeeks * WEEK then return false, ('%d semaines d\'avance maximum.'):format(Config.MaxWeeks) end
    local price = site.price * weeks
    if not Bridge:RemoveMoney(src, 'bank', price, 'location ' .. site.label) then return false, ('Il te faut %d $ en banque.'):format(price) end
    Store.set(cid, siteId, base + weeks * WEEK)
    return true, ('%s louée %d semaine(s) pour %d $.'):format(site.label, weeks, price)
end)

lib.callback.register('gs_hideouts:enter', function(src, siteId)
    if not Security:RateLimit(src, 'gs_hideouts:enter', 3, 10000) then return false, 'Doucement.' end
    local site = Config.Sites[siteId]
    if not site then return false, 'Invalide.' end
    local e = site.entrance
    if not Security:InRange(src, vec3(e.x, e.y, e.z), 5.0) then return false, 'Trop loin.' end
    local _, r = rental(src)
    if not r or r.site ~= siteId then return false, 'Ce n\'est pas ta chambre.' end
    if r.expires <= os.time() then return false, 'Location terminée : reloue à la réception (ton coffre t\'attend).' end
    Hideouts.inside[src] = siteId
    SetPlayerRoutingBucket(src, bucketOf(src))
    local i = Config.Interior
    SetEntityCoords(GetPlayerPed(src), i.x, i.y, i.z, false, false, false, false)
    return true
end)

lib.callback.register('gs_hideouts:exit', function(src)
    if not Security:RateLimit(src, 'gs_hideouts:exit', 3, 10000) then return false end
    local siteId = Hideouts.inside[src]
    if not siteId then return false end
    Hideouts.inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    local e = Config.Sites[siteId].entrance
    SetEntityCoords(GetPlayerPed(src), e.x, e.y, e.z, false, false, false, false)
    return true
end)

--- Coffre : seulement dans sa chambre (monde du locataire).
lib.callback.register('gs_hideouts:stash', function(src)
    if not Security:RateLimit(src, 'gs_hideouts:stash', 5, 10000) then return false end
    return Hideouts.inside[src] ~= nil and GetPlayerRoutingBucket(src) == bucketOf(src)
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    if Hideouts.inside[src] then
        local e = Config.Sites[Hideouts.inside[src]].entrance
        Hideouts.inside[src] = nil
        SetPlayerRoutingBucket(src, 0)
        local ped = GetPlayerPed(src)
        if ped ~= 0 then SetEntityCoords(ped, e.x, e.y, e.z, false, false, false, false) end
    end
end)

CreateThread(function()
    Store.init()
    if GetResourceState('ox_inventory') == 'started' then
        -- owner = true : chaque personnage a SON coffre sous ce même identifiant. [API] ox_inventory
        exports.ox_inventory:RegisterStash('gs_hideout', 'Coffre de la planque', Config.Stash.slots, Config.Stash.weight, true)
    end
end)
