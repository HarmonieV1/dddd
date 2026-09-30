-- gs_city (serveur) : Los Santos réactif. Chaque crime signalé par gs_wanted fait monter la tension du quartier où il a
-- eu lieu ; elle redescend seule avec le temps. Les niveaux (GlobalState.gsCity) sont lus par les clients (passants,
-- trafic, message d'entrée), par gs_wanted (témoins, police IA) et racontés par Weazel News.
local Security = exports.gs_security

City = { heat = {} } -- heat[districtId] = tension

function City.district(coords)
    if not coords then return nil end
    local p, best, bestD = vec2(coords.x, coords.y), nil, nil
    for _, d in ipairs(Config.Districts) do
        local dist = #(p - d.center)
        if dist <= d.radius and (not bestD or dist < bestD) then best, bestD = d, dist end
    end
    return best
end

function City.level(heat)
    local lvl = 1
    for i, l in ipairs(Config.Levels) do if (heat or 0) >= l.min then lvl = i end end
    return lvl
end

local function publish()
    local out = {}
    for _, d in ipairs(Config.Districts) do
        local lvl = City.level(City.heat[d.id])
        if lvl > 1 then out[d.id] = lvl end
    end
    GlobalState.gsCity = out
end

local function news(d, before, after)
    if GetResourceState('gs_social') ~= 'started' then return end
    local text = after > before and Config.News[after] or (after == 1 and Config.News.calm) or nil
    if text then exports.gs_social:Newsroom('city_' .. d.id, text:format(d.label)) end
end

--- Ajoute de la tension au quartier de `coords`. Retourne le niveau du quartier (ou nil hors quartier).
function City.add(coords, amount)
    local d = City.district(coords)
    if not d then return nil end
    local before = City.level(City.heat[d.id])
    City.heat[d.id] = math.min(Config.MaxHeat, (City.heat[d.id] or 0) + math.max(0, tonumber(amount) or 0) * Config.HeatScale)
    local after = City.level(City.heat[d.id])
    if after ~= before then publish() news(d, before, after) end
    return after
end

function City.decay()
    local changed = false
    for _, d in ipairs(Config.Districts) do
        local h = City.heat[d.id]
        if h then
            local before = City.level(h)
            h = h - Config.DecayPerMinute
            City.heat[d.id] = h > 0 and h or nil
            local after = City.level(City.heat[d.id])
            if after ~= before then changed = true news(d, before, after) end
        end
    end
    if changed then publish() end
end

local function levelAt(coords)
    local d = City.district(coords)
    return d and Config.Levels[City.level(City.heat[d.id])] or Config.Levels[1]
end

exports('GetLevel', function(coords)
    local d = City.district(coords)
    if not d then return 1, nil end
    return City.level(City.heat[d.id]), d.label
end)
exports('ReportFactor', function(coords) return levelAt(coords).report or 1.0 end)
exports('NpcBonus', function(coords) return levelAt(coords).npcStars or 0 end)
exports('AddHeat', City.add)

-- Crimes signalés (gs_wanted) : coords du crime si fournies, sinon position du suspect.
AddEventHandler('gs_wanted:server:reported', function(src, _, heat, coords)
    if not coords then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        coords = GetEntityCoords(ped)
    end
    City.add(coords, heat)
end)

--- /quartiers : ambiance de chaque quartier (la plus tendue d'abord).
lib.callback.register('gs_city:status', function(src)
    if not Security:RateLimit(src, 'gs_city:status', 4, 10000) then return nil end
    local out = {}
    for _, d in ipairs(Config.Districts) do
        local h = City.heat[d.id] or 0
        local lvl = City.level(h)
        out[#out + 1] = { label = d.label, level = lvl, name = Config.Levels[lvl].label, pct = math.floor(h * 100 / Config.MaxHeat) }
    end
    table.sort(out, function(a, b) return a.pct > b.pct or (a.pct == b.pct and a.label < b.label) end)
    return out
end)

CreateThread(function()
    GlobalState.gsCity = {}
    while true do
        Wait(60000)
        City.decay()
    end
end)
