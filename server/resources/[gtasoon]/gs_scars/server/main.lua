-- gs_scars (serveur) · V9 « Les cicatrices de la ville ». Publication : GlobalState.gsScars (liste compacte).
-- Les vitrines et fresques survivent aux redémarrages (KVP) ; les mémoriaux s'effacent avec le temps.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Scars = { list = {}, nextId = 0, lastMemorial = {} }

local function now() return os.time() end
local function v3(c) return vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end

local function save()
    local keep = {}
    for _, s in pairs(Scars.list) do
        if s.kind ~= 'memorial' then keep[#keep + 1] = { kind = s.kind, x = s.x, y = s.y, z = s.z, label = s.label, gang = s.gang, zone = s.zone, by = s.by, at = s.at } end
    end
    SetResourceKvp('gs_scars', json.encode(keep))
end

local function publish()
    local out = {}
    for id, s in pairs(Scars.list) do
        out[#out + 1] = { id = id, kind = s.kind, x = s.x, y = s.y, z = s.z, label = s.label, color = s.color }
    end
    GlobalState.gsScars = out
end

function Scars.count() local n = 0 for _ in pairs(Scars.list) do n = n + 1 end return n end

function Scars.add(kind, coords, data)
    coords = v3(coords)
    if Scars.count() >= Config.Max then -- la plus vieille part
        local oldest
        for id, s in pairs(Scars.list) do if not oldest or s.at < Scars.list[oldest].at then oldest = id end end
        Scars.list[oldest] = nil
    end
    Scars.nextId = Scars.nextId + 1
    local s = { kind = kind, x = coords.x, y = coords.y, z = coords.z, at = now() }
    for k, v in pairs(data or {}) do s[k] = v end
    Scars.list[Scars.nextId] = s
    publish()
    if kind ~= 'memorial' then save() end
    return Scars.nextId, s
end

local function near(kind, coords, r)
    for id, s in pairs(Scars.list) do
        if s.kind == kind and #(vec3(s.x, s.y, s.z) - coords) <= r then return id, s end
    end
end

--- Quelqu'un tombe : mémorial (fusionné avec un mémorial proche, un par joueur et par quart d'heure)
function Scars.fell(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local cid = Bridge:GetIdentifier(src)
    if cid and Scars.lastMemorial[cid] and Scars.lastMemorial[cid] + Config.Memorial.perPlayer > now() then return end
    if cid then Scars.lastMemorial[cid] = now() end
    local c = GetEntityCoords(ped)
    local id, s = near('memorial', c, Config.Memorial.merge)
    if s then s.at = now() publish() return id end
    return (Scars.add('memorial', c, { label = 'Mémorial' }))
end

--- Braquage : vitrine brisée à réparer (sauf si déjà une vitrine brisée tout près)
function Scars.robbed(src, coords)
    coords = v3(coords)
    if near('glass', coords, Config.Glass.merge) then return nil end
    return (Scars.add('glass', coords, { label = 'Vitrine brisée', by = Bridge:GetIdentifier(src) }))
end

--- Ouvrier de la ville : réparer une vitrine (payé par la mairie, jamais à l'auteur du braquage)
function Scars.repair(src, id)
    local s = Scars.list[tonumber(id) or 0]
    if not s or s.kind ~= 'glass' then return false, 'Déjà réparée.' end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vec3(s.x, s.y, s.z)) > 6.0 then return false, 'Trop loin.' end
    if s.by and s.by == Bridge:GetIdentifier(src) then return false, '« Toi ? Réparer ce que tu as cassé ? On ne paie pas ça. »' end
    Scars.list[tonumber(id)] = nil
    publish() save()
    local pay = math.random(Config.Glass.pay[1], Config.Glass.pay[2])
    Bridge:AddMoney(src, 'bank', pay)
    if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'legal', 2) end) end
    return true, ('Vitrine réparée : +%d $ (mairie)'):format(pay)
end

--- Guerre de territoire gagnée : fresque du vainqueur (remplace l'ancienne du quartier)
function Scars.mural(zone, gang, label, center, color)
    for id, s in pairs(Scars.list) do if s.kind == 'mural' and s.zone == zone then Scars.list[id] = nil end end
    return (Scars.add('mural', center, { zone = zone, gang = gang, color = color,
        label = ('%s · %s'):format(label, os.date('%d/%m')) }))
end

-- Branchements -------------------------------------------------------------------------------------------------
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if src and src > 0 and (tonumber(value) or 0) >= 2 then Scars.fell(src) end
end)
AddEventHandler('gs_wanted:server:crime', function(src, crimeType, coords)
    if Config.Glass.crimes[crimeType] then Scars.robbed(src, coords) end
end)
AddEventHandler('gs_gangs:server:warWon', function(zone, gang, gangLabel, center, color)
    Scars.mural(zone, gang, 'Fresque des ' .. (gangLabel or gang), center, color)
end)

lib.callback.register('gs_scars:repair', function(src, id)
    if not Security:RateLimit(src, 'gs_scars:repair', 2, 10000) then return false, 'Doucement.' end
    return Scars.repair(src, id)
end)

-- Démarrage : vitrines et fresques gardées ; ménage des mémoriaux trop vieux
CreateThread(function()
    local ok, saved = pcall(function() return json.decode(GetResourceKvpString('gs_scars') or '[]') end)
    for _, s in ipairs(ok and saved or {}) do
        Scars.nextId = Scars.nextId + 1
        Scars.list[Scars.nextId] = s
    end
    publish()
    while true do
        Wait(60000)
        local changed = false
        for id, s in pairs(Scars.list) do
            if s.kind == 'memorial' and now() - s.at > Config.Memorial.hours * 3600 then Scars.list[id] = nil changed = true end
        end
        if changed then publish() end
    end
end)
