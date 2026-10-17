-- gs_showroom (serveur) · V12.40 « mettre les véhicules d'exposition sur notre concession (map Patoche), pouvoir choisir et
-- essayer comme à la première concession ». Le staff pose les emplacements (sa position, son cap) et le modèle exposé ; le
-- vendeur en service change le modèle ; tout joueur essaie 2 min ou achète. Tout est vérifié ici : niveau staff / métier,
-- distance, catalogue Qbox (prix, catégories exclues), paiement (carte, sinon espèces), un essai à la fois.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Showroom = { slots = {}, starts = {}, testing = {}, lastTest = {} }

local function staffLevel(src)
    if GetResourceState('gs_admin') ~= 'started' then return 0 end
    local ok, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and tonumber(lvl) or 0
end

--- Catalogue Qbox : { name, brand, price, category } ou nil si le modèle n'existe pas / n'est pas vendable ici.
local function catalog(model)
    if type(model) ~= 'string' or not model:match('^[%w_]+$') then return nil end
    local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByName() end) -- [API] qbx_core
    local v = ok and type(list) == 'table' and list[model:lower()] or nil
    if not v or Config.Excluded[v.category or ''] or not tonumber(v.price) or tonumber(v.price) <= 0 then return nil end
    return v
end

local function publish()
    local slots = {}
    for id, s in pairs(Showroom.slots) do slots[#slots + 1] = { id = id, dealer = s.dealer, model = s.model, x = s.x, y = s.y, z = s.z, h = s.h } end
    table.sort(slots, function(a, b) return a.id < b.id end)
    GlobalState.gsShowroom = { slots = slots, starts = Showroom.starts }
end

local function loadSlots()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_showroom_slots` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `dealer` VARCHAR(30) NOT NULL, `model` VARCHAR(40) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL, PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_showroom_starts` (
        `dealer` VARCHAR(30) NOT NULL, `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL, PRIMARY KEY (`dealer`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for _, r in ipairs(MySQL.query.await('SELECT * FROM gs_showroom_slots') or {}) do
        Showroom.slots[r.id] = { dealer = r.dealer, model = r.model, x = r.x, y = r.y, z = r.z, h = r.h }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM gs_showroom_starts') or {}) do
        Showroom.starts[r.dealer] = { x = r.x, y = r.y, z = r.z, h = r.h }
    end
    publish()
end
MySQL.ready(loadSlots)

local function near(src, s, range)
    return s and #(GetEntityCoords(GetPlayerPed(src)) - vec3(s.x, s.y, s.z)) <= (range or Config.Range)
end

local function isDealer(src, dealer)
    local d = Config.Dealers[dealer]
    if not d then return false end
    for _, job in ipairs(d.jobs or {}) do
        if exports.gs_jobs:IsOnDutyAs(src, job) then return true end
    end
    return false
end

--- V12.62 · Un vendeur de cette concession est-il en service ? (sinon, n'importe qui sur place peut changer le modèle exposé)
local function dealerOnDuty(dealer)
    local d = Config.Dealers[dealer]
    if not d or GetResourceState('gs_jobs') ~= 'started' then return false end
    for _, job in ipairs(d.jobs or {}) do
        local ok, list = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
        if ok and type(list) == 'table' and #list > 0 then return true end
    end
    return false
end

-- Staff : poser / retirer / départ des essais -----------------------------------------------------------------------------
lib.callback.register('gs_showroom:staff', function(src, action, data)
    if not Security:RateLimit(src, 'gs_showroom:staff', 10, 10000) then return false, 'Doucement.' end
    if staffLevel(src) < Config.StaffLevel then return false, 'Réservé au super-admin et au fondateur.' end
    data = type(data) == 'table' and data or {}
    local ped = GetPlayerPed(src)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    if action == 'add' then
        if not Config.Dealers[data.dealer] then return false, 'Concession inconnue.' end
        local v = catalog(data.model)
        if not v then return false, 'Modèle inconnu du catalogue (ou non vendable ici).' end
        local id = MySQL.insert.await('INSERT INTO gs_showroom_slots (dealer, model, x, y, z, h) VALUES (?, ?, ?, ?, ?, ?)',
            { data.dealer, data.model:lower(), c.x, c.y, c.z, h })
        if not id then return false, 'Erreur d\'enregistrement.' end
        Showroom.slots[id] = { dealer = data.dealer, model = data.model:lower(), x = c.x, y = c.y, z = c.z, h = h }
        publish()
        Security:LogStaff(('[Concession] %s a posé %s (%s) n°%d'):format(GetPlayerName(src) or src, data.model, data.dealer, id), 'staff')
        return true, ('%s exposée ici (emplacement n°%d). Écarte-toi pour la voir apparaître.'):format(v.name or data.model, id)
    elseif action == 'remove' then
        local id = tonumber(data.id)
        if not id or not Showroom.slots[id] then return false, 'Emplacement inconnu.' end
        MySQL.update.await('DELETE FROM gs_showroom_slots WHERE id = ?', { id })
        Showroom.slots[id] = nil
        publish()
        return true, ('Emplacement n°%d retiré.'):format(id)
    elseif action == 'move' then -- V12.41 : replacer un emplacement existant à la position du staff
        local id = tonumber(data.id)
        local s = id and Showroom.slots[id]
        if not s then return false, 'Emplacement inconnu.' end
        MySQL.update.await('UPDATE gs_showroom_slots SET x = ?, y = ?, z = ?, h = ? WHERE id = ?', { c.x, c.y, c.z, h, id })
        s.x, s.y, s.z, s.h = c.x, c.y, c.z, h
        publish()
        return true, ('Emplacement n°%d replacé ici. Écarte-toi pour le voir.'):format(id)
    elseif action == 'start' then
        if not Config.Dealers[data.dealer] then return false, 'Concession inconnue.' end
        MySQL.update.await('REPLACE INTO gs_showroom_starts (dealer, x, y, z, h) VALUES (?, ?, ?, ?, ?)', { data.dealer, c.x, c.y, c.z, h })
        Showroom.starts[data.dealer] = { x = c.x, y = c.y, z = c.z, h = h }
        publish()
        return true, 'Départ des essais posé ici (place-toi sur la route, dans le sens de la sortie).'
    end
    return false, 'Action inconnue.'
end)

-- Vendeur en service (ou staff) : changer le modèle exposé ------------------------------------------------------------------
lib.callback.register('gs_showroom:setModel', function(src, id, model)
    if not Security:RateLimit(src, 'gs_showroom:setModel', 6, 10000) then return false, 'Doucement.' end
    local s = Showroom.slots[tonumber(id) or 0]
    if not s then return false, 'Emplacement inconnu.' end
    local staff = staffLevel(src) >= Config.StaffLevel
    local civil = not staff and not isDealer(src, s.dealer)
    if civil and dealerOnDuty(s.dealer) then return false, 'Un vendeur est en service : demande-lui de changer le modèle.' end -- V12.62
    if not staff and not near(src, s, 15.0) then return false, 'Approche-toi du véhicule exposé.' end -- V12.41 : le staff change de loin (F11)
    local v = catalog(model)
    if not v then return false, 'Modèle inconnu du catalogue (ou non vendable ici).' end
    MySQL.update.await('UPDATE gs_showroom_slots SET model = ? WHERE id = ?', { model:lower(), id })
    s.model = model:lower()
    publish()
    if civil then Security:LogStaff(('[Concession] %s [%d] (aucun vendeur en service) expose %s (n°%d)'):format(GetPlayerName(src) or '?', src, model, id), 'staff') end
    return true, ('%s exposée.'):format(v.name or model)
end)

-- Essai : 2 min, départ posé par le staff, retour automatique devant le véhicule exposé ----------------------------------------
local function endTest(src, why)
    local t = Showroom.testing[src]
    if not t then return end
    Showroom.testing[src] = nil
    if DoesEntityExist(t.veh) then DeleteEntity(t.veh) end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then SetEntityCoords(ped, t.back.x, t.back.y, t.back.z, false, false, false, false) end
    TriggerClientEvent('gs_showroom:client:testEnd', src, why)
end

lib.callback.register('gs_showroom:test', function(src, id)
    if not Security:RateLimit(src, 'gs_showroom:test', 3, 10000) then return false, 'Doucement.' end
    local s = Showroom.slots[tonumber(id) or 0]
    if not s or not near(src, s) then return false, 'Approche-toi du véhicule exposé.' end
    if Showroom.testing[src] then return false, 'Un essai est déjà en cours.' end
    if (Showroom.lastTest[src] or 0) + Config.TestDrive.cooldown > os.time() then return false, 'Un essai à la fois : attends un peu.' end
    local start = Showroom.starts[s.dealer]
    if not start then return false, 'Les essais ne sont pas encore ouverts ici (le staff doit poser le départ des essais).' end
    if not catalog(s.model) then return false, 'Ce modèle n\'est plus au catalogue.' end
    local veh = Bridge:SpawnVehicle(src, s.model, 'automobile', vec3(start.x, start.y, start.z), start.h, ('ESSAI%03d'):format(math.random(0, 999)), true)
    if not veh or veh == 0 then return false, 'Essai impossible pour le moment (véhicule non créé).' end
    Showroom.lastTest[src] = os.time()
    Showroom.testing[src] = { veh = veh, untilAt = os.time() + Config.TestDrive.seconds, start = vec3(start.x, start.y, start.z),
        back = vec3(s.x, s.y, s.z) }
    return true, ('Essai de %d min : profites-en, retour automatique à la fin.'):format(math.floor(Config.TestDrive.seconds / 60)), Config.TestDrive.seconds
end)

lib.callback.register('gs_showroom:stopTest', function(src)
    if not Security:RateLimit(src, 'gs_showroom:stopTest', 3, 10000) then return false end
    if Showroom.testing[src] then endTest(src, 'Essai terminé.') end
    return true
end)

CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for src, t in pairs(Showroom.testing) do
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 or not DoesEntityExist(t.veh) then endTest(src, 'Essai terminé.')
            elseif now >= t.untilAt then endTest(src, 'Fin de l\'essai : retour à la concession.')
            elseif #(GetEntityCoords(ped) - t.start) > Config.TestDrive.maxDistance then endTest(src, 'Trop loin de la concession : essai terminé.') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local t = Showroom.testing[source]
    if t and DoesEntityExist(t.veh) then DeleteEntity(t.veh) end
    Showroom.testing[source], Showroom.lastTest[source] = nil, nil
end)

-- Achat : carte, sinon espèces ; véhicule livré au garage ; commission à la caisse de la concession -------------------------
lib.callback.register('gs_showroom:buy', function(src, id)
    if not Security:RateLimit(src, 'gs_showroom:buy', 2, 10000) then return false, 'Doucement.' end
    local s = Showroom.slots[tonumber(id) or 0]
    if not s or not near(src, s) then return false, 'Approche-toi du véhicule exposé.' end
    local v = catalog(s.model)
    if not v then return false, 'Ce modèle n\'est plus au catalogue.' end
    local price = math.floor(tonumber(v.price))
    if Showroom.testing[src] then return false, 'Termine d\'abord ton essai (/finessai).' end
    local acc = Bridge:Pay(src, price, 'achat véhicule ' .. s.model, 'bank')
    if not acc then return false, ('Il te faut %d $ (carte ou espèces).'):format(price) end
    -- V12.41 : comme la concession Qbox : véhicule à ton nom, sorti au départ des essais, toi au volant, clés (+ clé en objet)
    local ok, plate, out = Bridge:GiveVehicle(src, s.model, Showroom.starts[s.dealer])
    if not ok then
        Bridge:AddMoney(src, acc, price, 'remboursement achat véhicule')
        return false, 'Achat impossible pour le moment : remboursé.'
    end
    local cut = math.floor(price * Config.Commission)
    local job = Config.Dealers[s.dealer] and Config.Dealers[s.dealer].jobs and Config.Dealers[s.dealer].jobs[1]
    if cut > 0 and job then pcall(function() exports.gs_jobs:AddSocietyMoney(job, cut, true) end) end
    Security:LogStaff(('[Concession] %s a acheté %s (%d $)'):format(GetPlayerName(src) or src, s.model, price), 'economy')
    if out then
        return true, ('%s achetée %d $ : elle est à toi (plaque %s), clés en poche. Bonne route !'):format(v.name or s.model, price, plate or '?')
    end
    return true, ('%s achetée %d $ (plaque %s) : la sortie est encombrée, elle t\'attend dans tes garages.'):format(v.name or s.model, price, plate or '?')
end)

-- V12.41 : le client sait s'il est staff (option « Changer le modèle » au Alt, comme le vendeur)
lib.callback.register('gs_showroom:me', function(src)
    if not Security:RateLimit(src, 'gs_showroom:me', 3, 10000) then return false end
    return staffLevel(src) >= Config.StaffLevel
end)

exports('ListSlots', function() return Showroom.slots end)
