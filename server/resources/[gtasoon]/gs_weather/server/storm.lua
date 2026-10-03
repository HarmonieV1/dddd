-- gs_weather (serveur) · V8 « Météo événementielle » : la tempête ferme des routes et crée des interventions payées.
-- Publication via GlobalState.gsStorm = { roads = { idx… }, incidents = { [id] = idx } } (aucun event récurrent).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local S = Config.Storm

Storm = { incidents = {} }

local function shuffle(n)
    local t = {}
    for i = 1, n do t[i] = i end
    for i = n, 2, -1 do local j = math.random(1, i) t[i], t[j] = t[j], t[i] end
    return t
end

local function publish()
    if not Storm.roads then GlobalState.gsStorm = nil return end
    local inc = {}
    for id, idx in pairs(Storm.incidents) do inc[tostring(id)] = idx end
    GlobalState.gsStorm = { roads = Storm.roads, incidents = inc }
end

function Storm.start()
    local r, s = shuffle(#S.roads), shuffle(#S.spots)
    Storm.roads, Storm.incidents = {}, {}
    for i = 1, math.min(S.closures, #r) do Storm.roads[i] = r[i] end
    for i = 1, math.min(S.incidents, #s) do Storm.incidents[i] = s[i] end
    publish()
    local names = {}
    for _, i in ipairs(Storm.roads) do names[#names + 1] = S.roads[i].label end
    if GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('flash', 'Tempête : routes fermées · ' .. table.concat(names, ' · ')) end)
    end
end

function Storm.stop()
    Storm.roads, Storm.incidents = nil, {}
    publish()
end

--- Intervention : mécano en service, ou n'importe qui avec un kit de réparation (consommé)
function Storm.fix(src, id)
    id = tonumber(id)
    local idx = id and Storm.incidents[id]
    if not idx then return false, 'Déjà dégagé.' end
    local c = S.spots[idx].coords
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > 8.0 then return false, 'Trop loin.' end
    local mech = GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:IsOnDutyAs(src, S.mechanicJob)
    if not mech and not Bridge:RemoveItem(src, S.repairItem, 1) then return false, 'Il faut être mécano en service ou avoir un kit de réparation.' end
    Storm.incidents[id] = nil
    publish()
    local amount = math.random(S.pay[1], S.pay[2])
    Bridge:AddMoney(src, 'bank', amount)
    return true, ('Intervention terminée : +%d $ (prime tempête)'):format(amount)
end

lib.callback.register('gs_weather:stormFix', function(src, id)
    if not Security:RateLimit(src, 'gs_weather:stormFix', 2, 8000) then return false, 'Doucement.' end
    return Storm.fix(src, id)
end)

AddEventHandler('gs_weather:server:eventStarted', function(id) if id == 'storm' then Storm.start() end end)
AddEventHandler('gs_weather:server:eventEnded', function(id) if id == 'storm' then Storm.stop() end end)
