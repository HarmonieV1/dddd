-- gs_city (serveur) · V10 « Le quartier évolue ». Standing par quartier (persistant), nourri par les vrais événements
-- des autres ressources ; publié dans GlobalState.gsStanding = { [id] = niveau } pour les clients (déchets).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local S = Config.Standing

Standing = { value = {}, cleaned = {} } -- value[id] = -100..100 ; cleaned[cid] = { horodatages }

local function now() return os.time() end
function Standing.level(v)
    v = v or 0
    for i, l in ipairs(S.levels) do if v <= l.max then return i end end
    return #S.levels
end

local function publish()
    local out = {}
    for _, d in ipairs(Config.Districts) do
        local lvl = Standing.level(Standing.value[d.id])
        if lvl ~= 3 then out[d.id] = lvl end
    end
    GlobalState.gsStanding = out
end
local function save() SetResourceKvp('standing', json.encode(Standing.value)) end

--- Ajoute `delta` au quartier de `coords` (brève Weazel si le niveau change)
function Standing.add(coords, delta)
    local d = City.district(coords)
    if not d or not delta or delta == 0 then return nil end
    local before = Standing.level(Standing.value[d.id])
    local v = math.max(-S.max, math.min(S.max, (Standing.value[d.id] or 0) + delta))
    if math.abs(v) < 0.01 then v = nil end
    Standing.value[d.id] = v
    local after = Standing.level(Standing.value[d.id])
    if after ~= before then
        publish()
        local text = S.news[after]
        if text and GetResourceState('gs_social') == 'started' then
            pcall(function() exports.gs_social:Newsroom('standing_' .. d.id, text:format(d.label)) end)
        end
    end
    return after
end

--- Retour lent vers 0 (appelé chaque minute)
function Standing.drift()
    local step = S.drift / 60
    for id, v in pairs(Standing.value) do
        local nv = v > 0 and math.max(0, v - step) or math.min(0, v + step)
        if math.abs(nv) < 0.01 then nv = nil end
        Standing.value[id] = nv
    end
end

--- Multiplicateur de recette des commerces à `coords` (0.85 → 1.10)
function Standing.sales(coords)
    local d = City.district(coords)
    return d and S.levels[Standing.level(Standing.value[d.id])].sales or 1.0
end

--- Ramasser un tas de déchets : dans un quartier en déclin, près du tas, plafonné par heure
function Standing.clean(src, x, y, z)
    local c = vec3(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    if not Security:InRange(src, c, 4.0) then return false, 'Trop loin.' end
    local d = City.district(c)
    if not d or Standing.level(Standing.value[d.id]) > 2 then return false, 'Ce quartier est propre.' end
    local cid = Bridge:GetIdentifier(src)
    local list, t, keep = Standing.cleaned[cid] or {}, now(), {}
    for _, at in ipairs(list) do if t - at < 3600 then keep[#keep + 1] = at end end
    if #keep >= S.cleanPerHour then return false, 'La mairie a assez payé pour l\'heure : reviens plus tard.' end
    keep[#keep + 1] = t
    Standing.cleaned[cid] = keep
    local pay = math.random(S.cleanPay[1], S.cleanPay[2])
    Bridge:AddMoney(src, 'bank', pay, 'propreté (mairie)')
    Standing.add(c, S.clean)
    return true, ('Quartier nettoyé : +%d $ (mairie).'):format(pay)
end

-- Sources --------------------------------------------------------------------------------------------------------
AddEventHandler('gs_jobs:server:revenue', function(_, amount, coords) Standing.add(coords, (tonumber(amount) or 0) * S.revenue) end)
AddEventHandler('gs_wanted:server:reported', function(src, _, heat, coords)
    if not coords then local ped = GetPlayerPed(src) if ped and ped ~= 0 then coords = GetEntityCoords(ped) end end
    if coords then Standing.add(coords, -(tonumber(heat) or 0) * S.crime) end
end)
AddEventHandler('gs_gangs:server:tagged', function(_, coords, placed) Standing.add(coords, placed and -S.tag or S.untag) end)
AddEventHandler('gs_gangs:server:activity', function(_, _, coords) if coords then Standing.add(coords, -S.gang) end end)
AddEventHandler('gs_scars:server:repaired', function(coords) Standing.add(coords, S.repair) end)

lib.callback.register('gs_city:clean', function(src, x, y, z)
    if not Security:RateLimit(src, 'gs_city:clean', 2, 8000) then return false, 'Doucement.' end
    return Standing.clean(src, x, y, z)
end)

exports('GetStanding', function(coords)
    local d = City.district(coords)
    if not d then return 3, 'ordinaire' end
    local lvl = Standing.level(Standing.value[d.id])
    return lvl, S.levels[lvl].label
end)
exports('SalesFactor', Standing.sales)
exports('AddStanding', Standing.add) -- V10 : faits divers PNJ

CreateThread(function()
    local ok, v = pcall(json.decode, GetResourceKvpString('standing') or '{}')
    if ok and type(v) == 'table' then Standing.value = v end
    publish()
    local n = 0
    while true do
        Wait(60000)
        Standing.drift()
        n = n + 1
        if n % 10 == 0 then save() publish() end
    end
end)
