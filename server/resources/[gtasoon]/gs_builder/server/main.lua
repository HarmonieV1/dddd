-- gs_builder (serveur) : registre des objets placés. Les clients créent les objets localement (non réseau)
-- seulement à proximité : aucun coût réseau ni entité serveur, même avec des milliers d'objets.
local Security = exports.gs_security

Builder = { objects = {}, count = 0, hides = {}, hideCount = 0 }

local function allowed(src) return IsPlayerAceAllowed(src, Config.Ace) end

local function num(v) return type(v) == 'number' and v == v and math.abs(v) < 100000 end

--- Valide un objet envoyé par le client. Retourne l'objet propre ou nil, raison.
function Builder.clean(src, o)
    if type(o) ~= 'table' then return nil, 'Données invalides.' end
    if type(o.model) ~= 'string' or not o.model:match('^[%w_]+$') or #o.model > 64 then return nil, 'Modèle invalide.' end
    for _, k in ipairs({ 'x', 'y', 'z', 'rx', 'ry', 'rz' }) do
        if not num(o[k]) then return nil, 'Position invalide.' end
    end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vec3(o.x, o.y, o.z)) > Config.MaxPlaceDistance then return nil, 'Trop loin de toi.' end
    return { model = o.model, x = o.x, y = o.y, z = o.z, rx = o.rx % 360, ry = o.ry % 360, rz = o.rz % 360 }
end

local function guard(src, key)
    if not Security:RateLimit(src, 'gs_builder:' .. key, 10, 10000) then return false, 'Doucement.' end
    if not allowed(src) then
        Security:LogStaff(('[Builder] %s a tenté %s sans permission'):format(GetPlayerName(src) or src, key))
        return false, 'Accès réservé au staff.'
    end
    return true
end

lib.callback.register('gs_builder:list', function(src)
    if not Security:RateLimit(src, 'gs_builder:list', 3, 10000) then return nil end
    local list = {}
    for id, o in pairs(Builder.objects) do list[#list + 1] = { id = id, model = o.model, x = o.x, y = o.y, z = o.z, rx = o.rx, ry = o.ry, rz = o.rz } end
    return list
end)

lib.callback.register('gs_builder:canUse', function(src)
    if not Security:RateLimit(src, 'gs_builder:canUse', 5, 10000) then return false end
    return allowed(src)
end)

lib.callback.register('gs_builder:place', function(src, data)
    local ok, err = guard(src, 'place')
    if not ok then return false, err end
    if Builder.count >= Config.MaxObjects then return false, 'Limite d\'objets atteinte.' end
    local o, reason = Builder.clean(src, data)
    if not o then return false, reason end
    local id = Store.insert(o, GetPlayerName(src) or '?')
    if not id then return false, 'Erreur BDD.' end
    o.id = id
    Builder.objects[id], Builder.count = o, Builder.count + 1
    TriggerClientEvent('gs_builder:client:set', -1, o)
    Security:LogStaff(('[Builder] %s place %s #%d (%.1f, %.1f, %.1f)'):format(GetPlayerName(src), o.model, id, o.x, o.y, o.z))
    return true, id
end)

lib.callback.register('gs_builder:update', function(src, id, data)
    local ok, err = guard(src, 'update')
    if not ok then return false, err end
    id = tonumber(id)
    local current = Builder.objects[id]
    if not current then return false, 'Objet introuvable.' end
    data = type(data) == 'table' and data or {}
    data.model = current.model
    local o, reason = Builder.clean(src, data)
    if not o then return false, reason end
    o.id = id
    Builder.objects[id] = o
    Store.update(id, o)
    TriggerClientEvent('gs_builder:client:set', -1, o)
    return true
end)

lib.callback.register('gs_builder:delete', function(src, id)
    local ok, err = guard(src, 'delete')
    if not ok then return false, err end
    id = tonumber(id)
    local o = Builder.objects[id]
    if not o then return false, 'Objet introuvable.' end
    Builder.objects[id], Builder.count = nil, Builder.count - 1
    Store.delete(id)
    TriggerClientEvent('gs_builder:client:remove', -1, id)
    Security:LogStaff(('[Builder] %s supprime %s #%d'):format(GetPlayerName(src), o.model, id))
    return true
end)

-- Objets de la map d'origine (poubelle, banc, barrière…) : retirés pour tout le monde par un masque de modèle
-- (CreateModelHide côté client). Le hash vient de l'objet visé ; réversible depuis le menu.
lib.callback.register('gs_builder:hides', function(src)
    if not Security:RateLimit(src, 'gs_builder:hides', 3, 10000) then return nil end
    local list = {}
    for _, h in pairs(Builder.hides) do list[#list + 1] = h end
    return list
end)

lib.callback.register('gs_builder:hide', function(src, data)
    local ok, err = guard(src, 'hide')
    if not ok then return false, err end
    if Builder.hideCount >= Config.MaxHides then return false, 'Limite d\'objets retirés atteinte.' end
    if type(data) ~= 'table' or math.type(data.hash) ~= 'integer' or math.abs(data.hash) > 0xFFFFFFFF then return false, 'Objet invalide.' end
    for _, k in ipairs({ 'x', 'y', 'z' }) do if not num(data[k]) then return false, 'Position invalide.' end end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vec3(data.x, data.y, data.z)) > Config.MaxPlaceDistance then return false, 'Trop loin de toi.' end
    local h = { hash = data.hash, x = data.x, y = data.y, z = data.z }
    local id = Store.hideInsert(h, GetPlayerName(src) or '?')
    if not id then return false, 'Erreur BDD.' end
    h.id = id
    Builder.hides[id], Builder.hideCount = h, Builder.hideCount + 1
    TriggerClientEvent('gs_builder:client:hide', -1, h)
    Security:LogStaff(('[Builder] %s retire un objet de la map #%d (%.1f, %.1f, %.1f)'):format(GetPlayerName(src), id, h.x, h.y, h.z))
    return true, 'Objet retiré pour tout le monde.'
end)

lib.callback.register('gs_builder:unhide', function(src, id)
    local ok, err = guard(src, 'unhide')
    if not ok then return false, err end
    id = tonumber(id)
    local h = Builder.hides[id]
    if not h then return false, 'Introuvable.' end
    Builder.hides[id], Builder.hideCount = nil, Builder.hideCount - 1
    Store.hideDelete(id)
    TriggerClientEvent('gs_builder:client:unhide', -1, h)
    return true, 'Objet de la map remis.'
end)

-- Points d'organisation (planques de gang) : position du staff
lib.callback.register('gs_builder:gangs', function(src)
    if not guard(src, 'gangs') or GetResourceState('gs_gangs') ~= 'started' then return {} end
    return exports.gs_gangs:ListGangs()
end)

lib.callback.register('gs_builder:setStash', function(src, gang)
    local ok, err = guard(src, 'stash')
    if not ok then return false, err end
    if GetResourceState('gs_gangs') ~= 'started' then return false, 'gs_gangs non démarré.' end
    local c = GetEntityCoords(GetPlayerPed(src))
    if not exports.gs_gangs:SetStash(tostring(gang), c) then return false, 'Gang inconnu.' end
    Security:LogStaff(('[Builder] %s place la planque de %s'):format(GetPlayerName(src), gang))
    return true, 'Planque placée ici.'
end)

CreateThread(function()
    Store.init()
    for _, o in ipairs(Store.all()) do
        Builder.objects[o.id] = o
        Builder.count = Builder.count + 1
    end
    for _, h in ipairs(Store.hides()) do
        Builder.hides[h.id] = h
        Builder.hideCount = Builder.hideCount + 1
    end
    print(('[gs_builder] %d objets chargés, %d objets de la map retirés'):format(Builder.count, Builder.hideCount))
end)
