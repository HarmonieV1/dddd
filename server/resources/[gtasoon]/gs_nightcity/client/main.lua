-- gs_nightcity (client) · V10.2 « Ville de jour / ville de nuit ». PNJ LOCAUX (non réseau), créés seulement à
-- l'approche ET au bon moment de la journée, retirés sinon : aucun coût quand on est loin. Une seule boucle, 2 s.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function inRange(h, r) if r.from <= r.to then return h >= r.from and h < r.to end return h >= r.from or h < r.to end
local function moment()
    local h = GetClockHours()
    if inRange(h, Config.Night) then return 'night' end
    if inRange(h, Config.Day) then return 'day' end
    return 'between'
end

local spawned = {} -- [key] = { peds }

local function spawnPed(model, c, scenario, offset)
    local hash = GetHashKey(model)
    if not lib.requestModel(hash, 5000) then return nil end
    local x, y = c.x + (offset and offset.x or 0.0), c.y + (offset and offset.y or 0.0)
    local ped = CreatePed(4, hash, x, y, c.z, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    local ok, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
    if ok and math.abs(gz - c.z) < 3.0 then SetEntityCoords(ped, x, y, gz, false, false, false, false) end
    SetEntityHeading(ped, c.w)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    return ped
end

local function despawn(key)
    for _, p in ipairs(spawned[key] or {}) do if DoesEntityExist(p) then DeletePed(p) end end
    spawned[key] = nil
end

local OFFSETS = { vec2(0.0, 0.0), vec2(1.6, 0.4), vec2(-1.2, 1.1), vec2(0.6, -1.5) }

-- Marché de nuit : menu d'achat
AddEventHandler('gs_nightcity:client:market', function(i)
    local m = Config.Markets[i]
    if moment() ~= 'night' then return notify(false, 'Le stand n\'ouvre que la nuit.') end
    local o = {}
    for _, it in ipairs(Config.MarketItems) do
        local label = it.item
        pcall(function() local d = exports.ox_inventory:Items(it.item) label = d and d.label or it.item end) -- [API] ox_inventory
        o[#o + 1] = { title = label, description = ('%d $'):format(it.price), icon = 'utensils', onSelect = function()
            local r = lib.inputDialog(label, { { type = 'number', label = 'Combien ?', default = 1, min = 1, max = 10, required = true } })
            if r then notify(lib.callback.await('gs_nightcity:buy', false, i, it.item, r[1])) end
        end }
    end
    lib.registerContext({ id = 'gs_nightcity_market', title = m.label, options = o })
    lib.showContext('gs_nightcity_market')
end)

local markers = {}
local function setMarkers(on)
    for i, m in ipairs(Config.Markets) do
        local key = 'gs_nightcity:market:' .. i
        if on and not markers[key] then
            local h = math.rad(m.coords.w)
            exports.gs_markers:Add(key, { coords = vec3(m.coords.x - math.sin(h), m.coords.y + math.cos(h), m.coords.z), style = 'shop',
                label = m.label, prompt = m.label, event = 'gs_nightcity:client:market', args = { i }, reach = 1.8 })
            markers[key] = true
        elseif not on and markers[key] then
            exports.gs_markers:Remove(key)
            markers[key] = nil
        end
    end
end

CreateThread(function()
    while true do
        local now = moment()
        local me = GetEntityCoords(cache.ped)
        setMarkers(now == 'night')
        for i, a in ipairs(Config.Ambience) do
            local key = 'amb' .. i
            local d = #(me - a.coords.xyz)
            if a.when == now and d < Config.SpawnRange and not spawned[key] then
                spawned[key] = {}
                for j, p in ipairs(a.peds) do spawned[key][j] = spawnPed(p[1], a.coords, p[2], OFFSETS[j]) end
            elseif spawned[key] and (a.when ~= now or d > Config.DespawnRange) then
                despawn(key)
            end
        end
        for i, m in ipairs(Config.Markets) do
            local key = 'mk' .. i
            local d = #(me - m.coords.xyz)
            if now == 'night' and d < Config.SpawnRange and not spawned[key] then
                spawned[key] = { spawnPed(m.model, m.coords, 'WORLD_HUMAN_STAND_IMPATIENT') }
                if spawned[key][1] then FreezeEntityPosition(spawned[key][1], true) SetEntityInvincible(spawned[key][1], true) end
            elseif spawned[key] and (now ~= 'night' or d > Config.DespawnRange) then
                despawn(key)
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(spawned) do despawn(key) end
    setMarkers(false)
end)
