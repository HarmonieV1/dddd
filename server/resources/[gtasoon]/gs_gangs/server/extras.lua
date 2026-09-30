-- gs_gangs (serveur) : tags, garage du gang, receleur (vente en gros). Tout est revérifié ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

TagsStore = TagsStore or {
    init = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gang_tags` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `gang` VARCHAR(30) NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    all = function() return MySQL.query.await('SELECT id, gang, x, y, z, heading FROM gs_gang_tags') or {} end,
    insert = function(gang, c, h) return MySQL.insert.await('INSERT INTO gs_gang_tags (gang, x, y, z, heading) VALUES (?, ?, ?, ?, ?)', { gang, c.x, c.y, c.z, h }) end,
    delete = function(id) MySQL.prepare('DELETE FROM gs_gang_tags WHERE id = ?', { id }) end,
    garagesInit = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gang_garages` (
            `gang` VARCHAR(30) NOT NULL, `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `w` FLOAT NOT NULL,
            `paint` SMALLINT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (`gang`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    garages = function() return MySQL.query.await('SELECT gang, x, y, z, w, paint FROM gs_gang_garages') or {} end,
    fleetInit = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_gang_fleet` (
            `gang` VARCHAR(30) NOT NULL, `models` TEXT NOT NULL, `custom` TEXT NULL, PRIMARY KEY (`gang`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    fleetAll = function() return MySQL.query.await('SELECT gang, models, custom FROM gs_gang_fleet') or {} end,
    fleetSave = function(gang, models, custom)
        MySQL.prepare('REPLACE INTO gs_gang_fleet (gang, models, custom) VALUES (?, ?, ?)', { gang, json.encode(models), custom and json.encode(custom) or nil })
    end,
    saveGarage = function(gang, c, paint)
        MySQL.prepare('REPLACE INTO gs_gang_garages (gang, x, y, z, w, paint) VALUES (?, ?, ?, ?, ?, ?)', { gang, c.x, c.y, c.z, c.w or 0.0, paint })
    end,
}

Config.DefaultGangVehicles = Config.DefaultGangVehicles or { 'buccaneer2', 'chino', 'manchez' }

--- Garages (config + placés par le staff) publiés aux clients : { [gang] = { x, y, z, w, vehicles } }
local function publishGarages()
    local out = {}
    for gang, g in pairs(Config.GangGarages) do
        out[gang] = { x = g.garage.x, y = g.garage.y, z = g.garage.z, w = g.garage.w, vehicles = g.vehicles, custom = g.custom }
    end
    GlobalState.gsGangGarages = out
end

Extras = { tags = {}, vehicles = {} } -- tags[id] = { id, gang, x, y, z, heading } ; vehicles[src] = entity

local function notifyGang(gang, msg, t)
    for s, m in pairs(Gangs.online) do if m.gang == gang then Bridge:Notify(s, msg, t or 'inform') end end
end

local function member(src) local m = Gangs.online[src] return m and m.gang and m or nil end
local function started(res) return GetResourceState(res) == 'started' end

-- Tags -------------------------------------------------------------------------------------------------------------

local function publishTags()
    local list = {}
    for _, t in pairs(Extras.tags) do
        local g = Gangs.list[t.gang]
        if g then
            local rgb = Config.ColorRGB[g.color] or Config.ColorRGB.default
            list[#list + 1] = { id = t.id, label = g.label, r = rgb[1], g = rgb[2], b = rgb[3], x = t.x, y = t.y, z = t.z, h = t.heading }
        end
    end
    GlobalState.gsTags = list
end

function Extras.countTags(gang)
    local n = 0
    for _, t in pairs(Extras.tags) do if t.gang == gang then n = n + 1 end end
    return n
end

lib.callback.register('gs_gangs:tag', function(src, coords, heading)
    if not Security:RateLimit(src, 'gs_gangs:tag', 2, 10000) then return false, 'Doucement.' end
    local m = member(src)
    if not m then return false, 'Il faut être dans un gang pour taguer.' end
    local c = type(coords) == 'table' and tonumber(coords.x) and vec3(coords.x, coords.y, coords.z)
    if not c or not Security:InRange(src, c, Config.Tags.range + 1.0) then return false, 'Trop loin du mur.' end
    if Extras.countTags(m.gang) >= Config.Tags.maxPerGang then
        return false, ('Ton gang a déjà %d tags : efface-en un avant.'):format(Config.Tags.maxPerGang)
    end
    for _, t in pairs(Extras.tags) do
        if #(vec3(t.x, t.y, t.z) - c) < Config.Tags.minDistance then return false, 'Un tag existe déjà juste à côté.' end
    end
    if not Bridge:RemoveItem(src, 'spraycan', 1) then return false, 'Il te faut une bombe de peinture.' end
    local h = tonumber(heading) or 0.0
    local id = TagsStore.insert(m.gang, c, h)
    if not id then return false, 'Erreur.' end
    Extras.tags[id] = { id = id, gang = m.gang, x = c.x, y = c.y, z = c.z, heading = h }
    publishTags()
    local zone = Gangs.territoryAt(c)
    if zone then Gangs.addInfluence(m.gang, zone, Config.Tags.influence) end
    return true, 'Tag posé.'
end)

lib.callback.register('gs_gangs:eraseTag', function(src, id)
    if not Security:RateLimit(src, 'gs_gangs:erase', 2, 10000) then return false, 'Doucement.' end
    local t = Extras.tags[tonumber(id) or -1]
    if not t then return false, 'Tag introuvable.' end
    if not Security:InRange(src, vec3(t.x, t.y, t.z), Config.Tags.range + 1.0) then return false, 'Trop loin.' end
    Extras.tags[t.id] = nil
    TagsStore.delete(t.id)
    publishTags()
    local m = member(src)
    if m and m.gang ~= t.gang then
        local zone = Gangs.territoryAt(vec3(t.x, t.y, t.z))
        if zone then Gangs.addInfluence(t.gang, zone, -Config.Tags.influence) end
        notifyGang(t.gang, ('Un de vos tags a été effacé par %s.'):format(Gangs.list[m.gang].label), 'warning')
    end
    return true, 'Tag effacé.'
end)

-- Garage du gang ------------------------------------------------------------------------------------------------------

local BIKES = { manchez = true, daemon = true, hexer = true, zombiea = true, sanchez = true }

lib.callback.register('gs_gangs:garage', function(src, index)
    if not Security:RateLimit(src, 'gs_gangs:garage', 3, 10000) then return false, 'Doucement.' end
    local m = member(src)
    local g = m and Config.GangGarages[m.gang]
    if not g then return false, 'Pas de garage pour ton gang.' end
    local custom = index == 'custom' and g.custom or nil
    local model = custom and custom.model or g.vehicles[tonumber(index) or 0]
    if not model then return false, 'Véhicule inconnu.' end
    if not Security:InRange(src, vec3(g.garage.x, g.garage.y, g.garage.z), 6.0) then return false, 'Approche-toi du garage.' end
    local old = Extras.vehicles[src]
    if old and DoesEntityExist(old) then return false, 'Range d\'abord ton véhicule.' end
    local veh = Bridge:SpawnVehicle(src, model, BIKES[model] and 'bike' or 'automobile',
        g.garage, g.garage.w, m.gang:upper():sub(1, 4) .. math.random(1000, 9999), true)
    if not veh or veh == 0 then return false, 'Véhicule indisponible.' end
    if custom then SetVehicleColours(veh, custom.c1, custom.c2) else SetVehicleColours(veh, g.paint, g.paint) end
    Extras.vehicles[src] = veh
    return true, 'Véhicule sorti.'
end)

lib.callback.register('gs_gangs:garageStore', function(src)
    if not Security:RateLimit(src, 'gs_gangs:store', 3, 10000) then return false, 'Doucement.' end
    local veh = Extras.vehicles[src]
    if not veh or not DoesEntityExist(veh) then Extras.vehicles[src] = nil return false, 'Aucun véhicule du gang sorti.' end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 15.0 then return false, 'Ramène le véhicule au garage.' end
    DeleteEntity(veh)
    Extras.vehicles[src] = nil
    return true, 'Véhicule rangé.'
end)

-- Flotte du gang (chef) ------------------------------------------------------------------------------------------------

local function allowedModel(m) for _, c in ipairs(Config.GangFleet.choices) do if c == m then return true end end return false end
local function colour(c) c = tonumber(c) return c and c == math.floor(c) and c >= 0 and c <= 159 and c or nil end

function Extras.applyFleet(gang, models, custom)
    local g = Config.GangGarages[gang]
    if not g then return false end
    if models and #models > 0 then g.vehicles = models end
    g.custom = custom
    publishGarages()
    return true
end

lib.callback.register('gs_gangs:setFleet', function(src, models)
    if not Security:RateLimit(src, 'gs_gangs:setFleet', 3, 10000) then return false, 'Doucement.' end
    local m = member(src)
    if not m or m.grade < 3 then return false, 'Réservé au chef du gang.' end
    if not Config.GangGarages[m.gang] then return false, 'Place d\'abord le garage du gang (staff).' end
    if type(models) ~= 'table' or #models < 1 or #models > Config.GangFleet.max then return false, ('1 à %d véhicules.'):format(Config.GangFleet.max) end
    local seen, clean = {}, {}
    for _, v in ipairs(models) do
        if type(v) ~= 'string' or not allowedModel(v) or seen[v] then return false, 'Modèle non autorisé.' end
        seen[v] = true
        clean[#clean + 1] = v
    end
    Extras.applyFleet(m.gang, clean, Config.GangGarages[m.gang].custom)
    if TagsStore.fleetSave then TagsStore.fleetSave(m.gang, clean, Config.GangGarages[m.gang].custom) end
    return true, 'Flotte du gang mise à jour.'
end)

lib.callback.register('gs_gangs:setCustom', function(src, model, c1, c2)
    if not Security:RateLimit(src, 'gs_gangs:setCustom', 3, 10000) then return false, 'Doucement.' end
    local m = member(src)
    if not m or m.grade < 3 then return false, 'Réservé au chef du gang.' end
    local g = Config.GangGarages[m.gang]
    if not g then return false, 'Place d\'abord le garage du gang (staff).' end
    if type(model) ~= 'string' or not allowedModel(model) then return false, 'Modèle non autorisé.' end
    c1, c2 = colour(c1), colour(c2)
    if not c1 or not c2 then return false, 'Couleurs : 0 à 159.' end
    local custom = { model = model, c1 = c1, c2 = c2 }
    Extras.applyFleet(m.gang, g.vehicles, custom)
    if TagsStore.fleetSave then TagsStore.fleetSave(m.gang, g.vehicles, custom) end
    return true, 'Véhicule personnalisé du gang enregistré.'
end)

-- Receleur ------------------------------------------------------------------------------------------------------------

function Extras.fenceLocation()
    local f = Config.Fence
    return f.locations[math.floor(os.time() / (f.rotateMinutes * 60)) % #f.locations + 1]
end

local function fenceOpen()
    if not started('gs_weather') then return true end
    local hour = exports.gs_weather:GetGameTime()
    local from, to = Config.Fence.hours[1], Config.Fence.hours[2]
    return hour >= from or hour < to
end

lib.callback.register('gs_gangs:fenceInfo', function(src)
    if not Security:RateLimit(src, 'gs_gangs:fenceInfo', 5, 10000) then return nil end
    local m = member(src)
    if not m or m.grade < Config.Fence.minGrade then return nil end
    return { coords = Extras.fenceLocation(), open = fenceOpen() }
end)

lib.callback.register('gs_gangs:fenceSell', function(src, drugId)
    if not Security:RateLimit(src, 'gs_gangs:fenceSell', 2, 10000) then return false, 'Doucement.' end
    local m = member(src)
    if not m or m.grade < Config.Fence.minGrade then return false, 'Le receleur ne te connaît pas.' end
    if not fenceOpen() then return false, 'Le receleur ne travaille que la nuit.' end
    if not Security:InRange(src, Extras.fenceLocation(), 4.0) then return false, 'Trop loin.' end
    if not started('gs_drugs') then return false, 'Indisponible.' end
    local product
    for _, p in ipairs(exports.gs_drugs:GetSellables()) do if p.id == drugId then product = p end end
    if not product then return false, 'Produit inconnu.' end
    local have = Bridge:GetItemCount(src, product.item)
    if have < Config.Fence.minQty then return false, ('Il en veut au moins %d.'):format(Config.Fence.minQty) end
    local qty = math.min(have, Config.Fence.maxQty)
    local unit = math.floor((product.price[1] + product.price[2]) / 2 * Config.Fence.bonus)
    if not Bridge:RemoveItem(src, product.item, qty) then return false, 'Erreur.' end
    local total = unit * qty
    if not (Bridge:ItemExists('black_money') and Bridge:AddItem(src, 'black_money', total)) then Bridge:AddMoney(src, 'cash', total, 'receleur') end
    local zone = Gangs.territoryAt(GetEntityCoords(GetPlayerPed(src)))
    if zone then Gangs.addInfluence(m.gang, zone, 3) end
    if started('gs_wanted') and math.random() < Config.Fence.reportChance then
        exports.gs_wanted:ReportCrime(src, 'drug_sale', GetEntityCoords(GetPlayerPed(src)))
    end
    return true, ('%d × %s vendus %d $ (argent sale)'):format(qty, product.label, total)
end)

-- Cycle de vie --------------------------------------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    local veh = Extras.vehicles[src]
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    Extras.vehicles[src] = nil
end)

--- Staff : garage d'un gang à cette position (vec4), couleur de peinture GTA.
exports('AdminSetGarage', function(gang, coords, paint)
    if not Gangs.list[gang] then return false, 'Gang inconnu.' end
    paint = math.floor(tonumber(paint) or 0)
    local g = Config.GangGarages[gang] or { vehicles = Config.DefaultGangVehicles }
    g.garage, g.paint = vec4(coords.x, coords.y, coords.z, coords.w or 0.0), paint
    Config.GangGarages[gang] = g
    TagsStore.saveGarage(gang, g.garage, paint)
    publishGarages()
    return true
end)

function Extras.init()
    TagsStore.init()
    if TagsStore.garagesInit then
        TagsStore.garagesInit()
        for _, r in ipairs(TagsStore.garages()) do
            local g = Config.GangGarages[r.gang] or { vehicles = Config.DefaultGangVehicles }
            g.garage, g.paint = vec4(r.x, r.y, r.z, r.w), r.paint
            Config.GangGarages[r.gang] = g
        end
    end
    if TagsStore.fleetInit then
        TagsStore.fleetInit()
        for _, r in ipairs(TagsStore.fleetAll()) do
            local ok1, models = pcall(json.decode, r.models)
            local ok2, custom = pcall(json.decode, r.custom or 'null')
            if Config.GangGarages[r.gang] then Extras.applyFleet(r.gang, ok1 and models or nil, ok2 and custom or nil) end
        end
    end
    publishGarages()
    for _, row in ipairs(TagsStore.all()) do
        if Gangs.list[row.gang] then Extras.tags[row.id] = { id = row.id, gang = row.gang, x = row.x, y = row.y, z = row.z, heading = row.heading } end
    end
    publishTags()
end

CreateThread(function()
    Wait(2000) -- après Gangs.init (liste des gangs)
    Extras.init()
end)

-- Atelier de munitions artisanales : dans la planque, ferraille + cuivre → munitions. En 2 temps (durée réelle
-- vérifiée), plafond journalier par gang (anti-usine à balles).
Extras.craft = { pending = {}, made = {} } -- made[gang] = { day, rounds }

local function craftedToday(gang)
    local d = Extras.craft.made[gang]
    if not d or d.day ~= os.date('%Y-%m-%d') then d = { day = os.date('%Y-%m-%d'), rounds = 0 } Extras.craft.made[gang] = d end
    return d
end

lib.callback.register('gs_gangs:craftBegin', function(src, item)
    if not Security:RateLimit(src, 'gs_gangs:craftBegin', 4, 10000) then return false, 'Doucement.' end
    local m = member(src)
    local r = Config.AmmoCraft.recipes[item]
    if not m or not r then return false, 'Invalide.' end
    if m.grade < r.minGrade then return false, 'Grade insuffisant dans le gang.' end
    local stash = Gangs.list[m.gang] and Gangs.list[m.gang].stash
    if not stash or not Security:InRange(src, stash, Config.AmmoCraft.range) then return false, 'Ça se fait à la planque du gang.' end
    if craftedToday(m.gang).rounds + r.out > Config.AmmoCraft.dailyCap then return false, 'L\'atelier a assez tourné aujourd\'hui.' end
    if Bridge:GetItemCount(src, 'scrapmetal') < r.scrapmetal or Bridge:GetItemCount(src, 'copper') < r.copper then
        return false, ('Il faut %d ferraille et %d cuivre (ferrailleur).'):format(r.scrapmetal, r.copper)
    end
    Extras.craft.pending[src] = { item = item, gang = m.gang, doneAt = GetGameTimer() + r.time - 750 }
    return true, r.time
end)

lib.callback.register('gs_gangs:craftFinish', function(src)
    if not Security:RateLimit(src, 'gs_gangs:craftFinish', 4, 10000) then return false, 'Doucement.' end
    local p = Extras.craft.pending[src]
    Extras.craft.pending[src] = nil
    if not p or GetGameTimer() < p.doneAt then return false, 'Interrompu.' end
    local r = Config.AmmoCraft.recipes[p.item]
    if not Bridge:RemoveItem(src, 'scrapmetal', r.scrapmetal) then return false, 'Il manque de la ferraille.' end
    if not Bridge:RemoveItem(src, 'copper', r.copper) then Bridge:AddItem(src, 'scrapmetal', r.scrapmetal) return false, 'Il manque du cuivre.' end
    if not Bridge:AddItem(src, p.item, r.out) then
        Bridge:AddItem(src, 'scrapmetal', r.scrapmetal) Bridge:AddItem(src, 'copper', r.copper)
        return false, 'Tu ne peux pas porter plus.'
    end
    local d = craftedToday(p.gang)
    d.rounds = d.rounds + r.out
    return true, ('%s fabriquées (%d / %d aujourd\'hui pour le gang).'):format(r.label, d.rounds, Config.AmmoCraft.dailyCap)
end)

RegisterNetEvent('gs_gangs:server:craftCancel', function()
    if Security:RateLimit(source, 'gs_gangs:craftCancel', 4, 10000) then Extras.craft.pending[source] = nil end
end)
