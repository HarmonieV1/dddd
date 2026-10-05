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
        if s.kind ~= 'memorial' then keep[#keep + 1] = { kind = s.kind, x = s.x, y = s.y, z = s.z, label = s.label, text = s.text, gang = s.gang, zone = s.zone, by = s.by, at = s.at } end
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
    TriggerEvent('gs_scars:server:repaired', vec3(s.x, s.y, s.z)) -- V10 : le quartier évolue
    return true, ('Vitrine réparée : +%d $ (mairie)'):format(pay)
end

--- Guerre de territoire gagnée : fresque du vainqueur (remplace l'ancienne du quartier)
function Scars.mural(zone, gang, label, center, color)
    for id, s in pairs(Scars.list) do if s.kind == 'mural' and s.zone == zone then Scars.list[id] = nil end end
    return (Scars.add('mural', center, { zone = zone, gang = gang, color = color,
        label = ('%s · %s'):format(label, os.date('%d/%m')) }))
end

--- V11 · Lieux de mémoire : plaque (fusionnée avec une plaque du même genre à moins de 40 m : la date est mise à jour)
function Scars.plaque(coords, text, by)
    text = Security:Sanitize(text, Config.Plaques.maxLen)
    if not coords or not text or text == '' then return nil end
    coords = v3(coords)
    local n, oldest = 0, nil
    for id, s in pairs(Scars.list) do
        if s.kind == 'plaque' then
            n = n + 1
            if #(vec3(s.x, s.y, s.z) - coords) <= Config.Plaques.merge and s.text == text then s.at = now() publish() save() return id end
            if not oldest or s.at < Scars.list[oldest].at then oldest = id end
        end
    end
    if n >= Config.Plaques.max and oldest then Scars.list[oldest] = nil end
    local id = Scars.add('plaque', coords, { text = text, label = ('%s · %s'):format(text, os.date('%d/%m/%Y')), by = by })
    TriggerEvent('gs_scars:server:plaque', text, coords)
    return id
end

local function plaqueCmd(src, args)
    if src == 0 then return end
    local lvl = 0
    if GetResourceState('gs_admin') == 'started' then
        local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
        lvl = ok and (tonumber(l) or 0) or 0
    end
    if lvl < Config.Plaques.staffLevel then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local id = Scars.plaque(GetEntityCoords(ped), table.concat(args, ' '), 'staff:' .. (Bridge:GetIdentifier(src) or src))
    Bridge:Notify(src, id and 'Plaque posée : la ville s\'en souviendra.' or 'Usage : /plaque <texte (80 caractères max)>', id and 'success' or 'error')
end
RegisterCommand('plaque', plaqueCmd, false)
RegisterCommand('plaqueretirer', function(src)
    if src == 0 then return end
    local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    if not ok or (tonumber(l) or 0) < Config.Plaques.staffLevel then return end
    local id = near('plaque', GetEntityCoords(GetPlayerPed(src)), Config.Plaques.reach)
    if id then Scars.list[id] = nil publish() save() end
    Bridge:Notify(src, id and 'Plaque retirée.' or 'Aucune plaque à moins de 5 m.', id and 'success' or 'error')
end, false)

-- Branchements -------------------------------------------------------------------------------------------------
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if src and src > 0 and (tonumber(value) or 0) >= 2 then Scars.fell(src) end
end)
AddEventHandler('gs_wanted:server:crime', function(src, crimeType, coords)
    if Config.Glass.crimes[crimeType] then Scars.robbed(src, coords) end
    local what = Config.Plaques.crimes[crimeType]
    if what and coords then Scars.plaque(coords, 'Ici, ' .. what, 'auto') end -- V11 : lieux de mémoire
end)
AddEventHandler('gs_wanted:server:legend', function(src, name) -- V11 : fin d'une cavale légendaire (nom déjà public en jeu)
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and name then Scars.plaque(GetEntityCoords(ped), 'Ici s\'est achevée la cavale légendaire de ' .. tostring(name), 'auto') end
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
            if s.kind == 'plaque' and now() - s.at > Config.Plaques.days * 86400 then Scars.list[id] = nil changed = true end
        end
        if changed then publish() save() end
    end
end)
