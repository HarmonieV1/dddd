-- gs_market (serveur) : relève les indices chaque heure, garde l'historique, sert la « Bourse » de Vibe (cache court).
local Security = exports.gs_security

Market = { cache = nil, cacheAt = 0 }

local function started(res) return GetResourceState(res) == 'started' end

--- Valeurs actuelles des indices (nil si la source n'est pas disponible).
function Market.read()
    local v = {}
    if started('gs_economy') then
        local e = exports.gs_economy
        v.prices = math.floor((e:GetPriceIndex() or 1) * 1000 + 0.5) / 10   -- 100 pts = prix d'équilibre
        v.fuel = e:GetBuyPrice('jerry_can')
        v.metals = e:GetSellPrice('copper')
    end
    v.housing = Store.housing()
    local w = Store.wealth()
    v.wealth = w and math.floor(w / 10000 + 0.5) / 100 or nil                -- en millions
    return v
end

function Market.snapshot(now)
    local rows = {}
    for id, value in pairs(Market.read()) do if type(value) == 'number' then rows[id] = value end end
    Store.add(now or os.time(), rows)
    Market.cache = nil
end

--- Données de la Bourse : valeur courante, variation sur 24 h, historique (pour le graphique).
function Market.data(now)
    now = now or os.time()
    local hist = {}
    for _, r in ipairs(Store.history(now - Config.KeepHours * 3600)) do
        hist[r.idx] = hist[r.idx] or {}
        hist[r.idx][#hist[r.idx] + 1] = { ts = r.ts, v = r.value }
    end
    local current = Market.read()
    local out = {}
    for _, def in ipairs(Config.Indices) do
        local h = hist[def.id] or {}
        local cur = current[def.id] or (h[#h] and h[#h].v)
        if cur then
            local ref
            for _, p in ipairs(h) do if p.ts <= now - 86400 then ref = p.v end end
            ref = ref or (h[1] and h[1].v)
            local points = {}
            for i, p in ipairs(h) do points[i] = p.v end
            points[#points + 1] = cur
            out[#out + 1] = { id = def.id, label = def.label, unit = def.unit, icon = def.icon, value = cur,
                change = (ref and ref ~= 0) and ((cur - ref) / ref * 100) or 0, history = points }
        end
    end
    return out
end

lib.callback.register('gs_market:data', function(src)
    if not Security:RateLimit(src, 'gs_market:data', 5, 10000) then return nil end
    if not Market.cache or os.time() - Market.cacheAt > Config.CacheSeconds then
        Market.cache, Market.cacheAt = Market.data(), os.time()
    end
    return Market.cache
end)

CreateThread(function()
    Store.init()
    while true do
        Market.snapshot()
        Store.purge(os.time() - Config.KeepHours * 3600)
        Wait(Config.SnapshotMinutes * 60000)
    end
end)
