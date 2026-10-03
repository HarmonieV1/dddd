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
