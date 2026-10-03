-- gs_roadside (serveur) · V8 « Rencontres de la route ». Le serveur tire au sort (rareté, délai, hors de la ville,
-- au volant), garde la scène active et décide seul des gains / pertes à la fin (temps, distance, objets, position).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Roadside = { active = {}, last = {}, friends = {} } -- friends[cid] = { model, place } (auto-stoppeur aidé)

local function now() return os.time() end
local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function rnd(range) return math.random(range[1], range[2]) end
local function dist(a, b) return #(vec3(a.x, a.y, a.z) - vec3(b.x, b.y, b.z)) end

local function isNight()
    if GetResourceState('gs_weather') ~= 'started' then return false end
    local ok, h = pcall(function() return exports.gs_weather:GetGameTime() end)
    return ok and h and (h >= 21 or h < 6)
end

local function heatOf(src)
    if GetResourceState('gs_wanted') ~= 'started' then return 0 end
    local ok, h = pcall(function() return exports.gs_wanted:GetHeat(src) end)
    return ok and tonumber(h) or 0
end

--- Tirage pondéré d'un type de rencontre
function Roadside.pick()
    local total = 0
    for _, t in pairs(Config.Types) do total = total + t.weight end
    local r, keys = math.random() * total, {}
    for k in pairs(Config.Types) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        r = r - Config.Types[k].weight
        if r <= 0 then return k end
    end
    return keys[#keys]
end

--- Le client demande « une rencontre ? » après un moment de route hors de la ville. Le serveur vérifie tout.
function Roadside.roll(src)
    local cid = Bridge:GetIdentifier(src)
    local ped = GetPlayerPed(src)
    if not cid or ped == 0 or Roadside.active[src] then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    local c = GetEntityCoords(ped)
    if not Config.IsRural(c.x, c.y) then return nil end
    if Roadside.last[cid] and now() - Roadside.last[cid] < Config.Cooldown * 60 then return nil end
    if math.random() >= Config.Chance then return nil end
    Roadside.last[cid] = now()

    local kind = Roadside.pick()
    local def = Config.Types[kind]
    local scene = { kind = kind, token = math.random(100000, 999999), at = now(), start = { x = c.x, y = c.y, z = c.z } }
    local danger = isNight() and def.nightDanger or def.danger
    if kind == 'hitchhiker' and Roadside.friends[cid] and math.random() < Config.Friend.chance then
        scene.kind, scene.model = 'friend', Roadside.friends[cid].model -- l'auto-stoppeur aidé se souvient de toi
    elseif danger and math.random() < danger then
        scene.danger = true
    end
    if scene.kind == 'hitchhiker' or scene.kind == 'wallet' then
        -- destination : une ville assez loin
        local far = {}
        for i, p in ipairs(Config.Places) do if dist(p.coords, c) >= (Config.Types.hitchhiker.minDistance or 800.0) then far[#far + 1] = i end end
        scene.place = far[math.random(1, math.max(1, #far))] or 1
    end
    if scene.kind == 'hitchhiker' then
        scene.model = Config.Models[scene.danger and 'robber' or 'hitchhiker'][math.random(1, #Config.Models[scene.danger and 'robber' or 'hitchhiker'])]
    end
    scene.wanted = scene.kind == 'sheriff' and heatOf(src) > 0 or nil
    Roadside.active[src] = scene
    return { kind = scene.kind, token = scene.token, danger = scene.danger, model = scene.model, place = scene.place, wanted = scene.wanted }
end

local function collect(src, key)
    local cid = Bridge:GetIdentifier(src)
    if cid then Store.add(cid, key) end
end

local function pay(src, amount, why)
    if amount > 0 and Bridge:AddMoney(src, 'cash', amount) then notify(src, ('%s : +%d $'):format(why, amount), 'success') end
end

local function reportCrime(src, crime)
    if GetResourceState('gs_wanted') ~= 'started' then return end
    pcall(function() exports.gs_wanted:ReportCrime(src, crime, GetEntityCoords(GetPlayerPed(src))) end)
end

local function removePoints(src, n, why)
    if GetResourceState('gs_driving') ~= 'started' then return end
    pcall(function() exports.gs_driving:RemovePoints(src, n, why) end)
end

--- Fin d'une scène : le client dit ce qui s'est passé, le serveur vérifie et décide.
function Roadside.finish(src, token, outcome)
    local s = Roadside.active[src]
    if not s or s.token ~= token then return false, nil end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local here, elapsed = GetEntityCoords(ped), now() - s.at
    local def = Config.Types[s.kind] or {}
    local function done(key) Roadside.active[src] = nil collect(src, key) return true end

    if outcome == 'ignored' then Roadside.active[src] = nil return true end

    if s.kind == 'hitchhiker' and outcome == 'dropped' and not s.danger then
        local p = Config.Places[s.place]
        if not p or dist(here, p.coords) > 80.0 or dist(here, s.start) < def.minDistance * 0.6 or elapsed < 30 then return false, 'Ce n\'est pas ici.' end
        pay(src, rnd(def.pay), 'Auto-stoppeur déposé')
        local cid = Bridge:GetIdentifier(src)
        if cid then Roadside.friends[cid] = { model = s.model, place = s.place } end
        return done('hitchhiker')
    elseif s.kind == 'hitchhiker' and s.danger and outcome == 'robbed' then
        local cash = Bridge:GetMoney(src, 'cash') or 0
        local take = math.min(cash, Config.Rob.max)
        if take > 0 then Bridge:RemoveMoney(src, 'cash', take) end
        notify(src, take > 0 and ('Il est parti avec %d $.'):format(take) or 'Il repart les mains vides… tu n\'avais rien.', 'error')
        return done('robbed')
    elseif s.kind == 'hitchhiker' and s.danger and outcome == 'escaped' then
        return done('robbed')
    elseif s.kind == 'breakdown' and outcome == 'helped' and not s.danger then
        if dist(here, s.start) > Config.SpawnAhead + 200.0 then return false, 'Trop loin.' end
        local used = Bridge:GetItemCount(src, 'WEAPON_PETROLCAN') > 0 or Bridge:RemoveItem(src, 'repairkit', 1)
        if not used then return false, 'Il faudrait un jerrican ou un kit de réparation.' end
        pay(src, rnd(def.pay), 'Dépannage')
        return done('breakdown')
    elseif s.kind == 'breakdown' and s.danger and outcome == 'ambush' then
        return done('ambush')
    elseif (s.kind == 'accident' or s.kind == 'animal') and outcome == 'helped' then
        if dist(here, s.start) > Config.SpawnAhead + 200.0 then return false, 'Trop loin.' end
        if not Bridge:RemoveItem(src, def.item, 1) then return false, 'Il te faut un bandage.' end
        pay(src, rnd(def.pay), s.kind == 'accident' and 'Premiers secours' or 'Animal soigné')
        if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'legal', 5) end) end
        return done(s.kind)
    elseif s.kind == 'wallet' and outcome == 'returned' then
        local p = Config.Places[s.place]
        if not p or dist(here, p.coords) > 80.0 or elapsed < 30 then return false, 'Ce n\'est pas l\'adresse.' end
        pay(src, rnd(def.returned), 'Portefeuille rendu (récompense)')
        if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'legal', 8) end) end
        return done('wallet_returned')
    elseif s.kind == 'wallet' and outcome == 'kept' then
        pay(src, rnd(def.kept), 'Contenu du portefeuille')
        return done('wallet_kept')
    elseif s.kind == 'sheriff' and outcome == 'checked' then
        local lic = Bridge:GetLicences(src) or {}
        if s.wanted then
            notify(src, 'Le shérif te reconnaît : « Pas un geste ! »', 'error')
            TriggerClientEvent('gs_wanted:client:npcPolice', src, 2)
        elseif not lic.driver then
            Bridge:RemoveMoney(src, 'bank', def.fine)
            notify(src, ('Conduite sans permis : amende de %d $.'):format(def.fine), 'error')
        else
            notify(src, 'Papiers en règle. « Bonne route. »', 'success')
        end
        return done('sheriff')
    elseif s.kind == 'sheriff' and outcome == 'fled' then
        reportCrime(src, 'refusal')
        removePoints(src, def.points, 'Refus d\'obtempérer')
        return done('sheriff_fled')
    elseif s.kind == 'friend' and outcome == 'met' then
        pay(src, rnd(Config.Friend.gift), 'Un vieil ami de la route')
        return done('friend')
    end
    return false, nil
end

--- Vendeur ambulant : achat (scène active, vendeur à portée)
function Roadside.buy(src, token, index)
    local s = Roadside.active[src]
    local art = Config.Vendor[tonumber(index) or 0]
    if not s or s.token ~= token or s.kind ~= 'vendor' or not art then return false, 'Le vendeur est parti.' end
    if not Bridge:CanCarry(src, art.item, 1) then return false, 'Inventaire plein.' end
    if not Bridge:RemoveMoney(src, 'cash', art.price) then return false, 'Pas assez de liquide.' end
    Bridge:AddItem(src, art.item, 1)
    if not s.bought then s.bought = true collect(src, 'vendor') end
    return true, 'Merci, bonne route !'
end

lib.callback.register('gs_roadside:roll', function(src)
    if not Security:RateLimit(src, 'gs_roadside:roll', 1, 30000) then return nil end
    return Roadside.roll(src)
end)
lib.callback.register('gs_roadside:finish', function(src, token, outcome)
    if not Security:RateLimit(src, 'gs_roadside:finish', 4, 10000) then return false end
    return Roadside.finish(src, token, outcome)
end)
lib.callback.register('gs_roadside:buy', function(src, token, index)
    if not Security:RateLimit(src, 'gs_roadside:buy', 4, 5000) then return false, 'Doucement.' end
    return Roadside.buy(src, token, index)
end)
lib.callback.register('gs_roadside:collection', function(src)
    if not Security:RateLimit(src, 'gs_roadside:collection', 3, 5000) then return {} end
    local cid = Bridge:GetIdentifier(src)
    return cid and Store.list(cid) or {}
end)

AddEventHandler('playerDropped', function() Roadside.active[source] = nil end)

-- Scènes oubliées (client parti, crash) : nettoyées
CreateThread(function()
    Store.init()
    while true do
        Wait(60000)
        for src, s in pairs(Roadside.active) do
            if now() - s.at > Config.Lifetime + 900 then Roadside.active[src] = nil end
        end
    end
end)
