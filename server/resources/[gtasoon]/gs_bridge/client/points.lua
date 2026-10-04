-- gs_bridge (client) : registre des points déplaçables déclarés par nos ressources (shared/points.lua).
local registry = {} -- [ressource] = { { key, label, coords, moved } }

AddEventHandler('gs_bridge:client:registerPoints', function(res, list)
    if type(res) == 'string' and type(list) == 'table' then registry[res] = list end
end)
AddEventHandler('onClientResourceStop', function(res) registry[res] = nil end)

--- Points à moins de `radius` m de `from`, du plus proche au plus loin. [API]
exports('NearbyPoints', function(from, radius)
    local out = {}
    for res, list in pairs(registry) do
        for _, p in ipairs(list) do
            local d = #(from - p.coords)
            if d <= radius then out[#out + 1] = { key = p.key, label = p.label, res = res, dist = d, moved = p.moved } end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end)

--- V10 : position actuelle d'un point (clé exacte, ou premier point dont la clé commence par `prefix`), déplacements
--- du staff compris. Sert au GPS de « Que faire ? ». [API]
exports('FindPoint', function(prefix)
    local best, bestKey
    for _, list in pairs(registry) do
        for _, p in ipairs(list) do
            if p.key == prefix then return p.coords end
            if p.key:sub(1, #prefix) == prefix and (not bestKey or p.key < bestKey) then best, bestKey = p.coords, p.key end
        end
    end
    return best
end)
