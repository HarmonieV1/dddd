-- gs_races (serveur) · V12.40 « laisser les admins créer des courses de rue avec des points sur mesure, éphémères ou à vie ».
-- Le staff (gs_admin, niveau ≥ Config.Custom.staffLevel) ouvre un brouillon, pose ses points là où il se trouve (dans
-- l'ordre : 1er = départ, dernier = arrivée), choisit une durée de vie (heures) ou « permanente », enregistre. La course
-- rejoint Config.Circuits (serveur + clients via GlobalState.gsRaceCustom) : elle apparaît chez l'organisateur avec chrono,
-- mises, classement et contrôles anti-triche, comme les circuits livrés. Les courses éphémères disparaissent seules.
local Security = exports.gs_security

Custom = { drafts = {}, races = {} } -- races[id] = { label, points = { vec3 }, expiresAt (os.time ou nil), author, vehicle (V12.63) }

--- V12.63 · Véhicule imposé : nom de modèle GTA (lettres, chiffres, _), '' = libre
function Custom.model(v)
    if type(v) ~= 'string' then return nil end
    v = v:lower():gsub('%s', '')
    if v == '' then return '' end
    if #v < 2 or #v > 30 or not v:match('^[%w_]+$') then return nil end
    return v
end

local function level(src)
    if GetResourceState('gs_admin') ~= 'started' then return 0 end
    local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and tonumber(l) or 0
end

local function key(id) return 'c' .. id end

local function publish()
    local out = {}
    for id, r in pairs(Custom.races) do
        local pts = {}
        for i, p in ipairs(r.points) do pts[i] = { x = p.x, y = p.y, z = p.z } end
        out[key(id)] = { label = r.label, points = pts, expiresAt = r.expiresAt, vehicle = r.vehicle }
        Config.Circuits[key(id)] = { label = r.label, points = r.points, custom = true, vehicle = r.vehicle }
    end
    for k, c in pairs(Config.Circuits) do if c.custom and not out[k] then Config.Circuits[k] = nil end end
    GlobalState.gsRaceCustom = out
end

function Custom.load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_race_custom` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `label` VARCHAR(40) NOT NULL, `points` TEXT NOT NULL,
        `expires_at` INT UNSIGNED NULL, `author` VARCHAR(60) NOT NULL DEFAULT '', PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    pcall(MySQL.query.await, 'ALTER TABLE `gs_race_custom` ADD COLUMN IF NOT EXISTS `vehicle` VARCHAR(30) NULL') -- V12.63 : véhicule imposé
    for _, r in ipairs(MySQL.query.await('SELECT * FROM gs_race_custom') or {}) do
        local ok, pts = pcall(json.decode, r.points)
        if ok and type(pts) == 'table' and #pts >= 2 then
            local list = {}
            for i, p in ipairs(pts) do list[i] = vec3(p.x, p.y, p.z) end
            Custom.races[r.id] = { label = r.label, points = list, expiresAt = r.expires_at, author = r.author, vehicle = r.vehicle ~= '' and r.vehicle or nil }
        end
    end
    publish()
end

--- Courses éphémères arrivées à expiration : retirées (base, serveur, clients).
function Custom.expire(now)
    local changed = false
    for id, r in pairs(Custom.races) do
        if r.expiresAt and r.expiresAt <= now then
            MySQL.update.await('DELETE FROM gs_race_custom WHERE id = ?', { id })
            Custom.races[id], changed = nil, true
        end
    end
    if changed then publish() end
end

lib.callback.register('gs_races:editor', function(src, action, data)
    if not Security:RateLimit(src, 'gs_races:editor', 20, 10000) then return false, 'Doucement.' end
    local C = Config.Custom
    if level(src) < C.staffLevel then return false, 'Réservé au staff (admin).' end
    data = type(data) == 'table' and data or {}
    local d = Custom.drafts[src]
    if action == 'new' then
        local label = Security:Sanitize(data.label, 120)
        -- V12.59 : coupé à 40 CARACTÈRES (pas octets) : un accent coupé en deux faisait refuser l'enregistrement par la base
        if label and utf8.len(label) and utf8.len(label) > 40 then label = label:sub(1, utf8.offset(label, 41) - 1) end
        if not label or (utf8.len(label) or 0) < 3 then return false, 'Nom de course trop court (3 caractères minimum).' end
        local hours = tonumber(data.hours) or 0
        if hours ~= 0 and (hours < 1 or hours > C.maxHours) then return false, ('Durée : 1 à %d heures, ou 0 = permanente.'):format(C.maxHours) end
        Custom.drafts[src] = { label = label, hours = math.floor(hours), points = {} }
        return true, ('Brouillon « %s » ouvert : place-toi au départ et pose les points dans l\'ordre.'):format(label)
    end
    if action == 'list' then
        local out = {}
        for id, r in pairs(Custom.races) do out[#out + 1] = { id = id, label = r.label, points = #r.points, expiresAt = r.expiresAt, author = r.author, vehicle = r.vehicle } end
        table.sort(out, function(a, b) return a.id < b.id end)
        return true, out, d and { label = d.label, hours = d.hours, points = #d.points, vehicle = d.vehicle } or nil
    end
    if action == 'setvehicle' then -- V12.63 : changer le véhicule imposé d'une course enregistrée ('' = libre)
        local id, model = tonumber(data.id), Custom.model(data.model)
        if not id or not Custom.races[id] then return false, 'Course inconnue.' end
        if not model then return false, 'Nom de modèle invalide (ex. sultan, elegy2) ; vide = véhicule libre.' end
        MySQL.update.await('UPDATE gs_race_custom SET vehicle = ? WHERE id = ?', { model ~= '' and model or nil, id })
        Custom.races[id].vehicle = model ~= '' and model or nil
        publish()
        return true, model ~= '' and ('Véhicule imposé : %s.'):format(model) or 'Véhicule libre.'
    end
    if action == 'delete' then
        local id = tonumber(data.id)
        if not id or not Custom.races[id] then return false, 'Course inconnue.' end
        MySQL.update.await('DELETE FROM gs_race_custom WHERE id = ?', { id })
        Custom.races[id] = nil
        publish()
        return true, 'Course supprimée.'
    end
    if not d then return false, 'Aucun brouillon : commence par « Nouvelle course ».' end
    if action == 'point' then
        if #d.points >= C.maxPoints then return false, ('%d points maximum.'):format(C.maxPoints) end
        local c = GetEntityCoords(GetPlayerPed(src))
        local last = d.points[#d.points]
        if last and #(c - last) < C.minGap then return false, ('Trop près du point précédent (%d m minimum).'):format(C.minGap) end
        d.points[#d.points + 1] = vec3(c.x, c.y, c.z)
        return true, ('Point %d posé%s.'):format(#d.points, #d.points == 1 and ' (départ)' or '')
    elseif action == 'undo' then
        if #d.points == 0 then return false, 'Aucun point à retirer.' end
        d.points[#d.points] = nil
        return true, ('Dernier point retiré (%d restant%s).'):format(#d.points, #d.points > 1 and 's' or '')
    elseif action == 'vehicle' then -- V12.63 : véhicule imposé du brouillon
        local model = Custom.model(data.model)
        if not model then return false, 'Nom de modèle invalide (ex. sultan, elegy2) ; vide = véhicule libre.' end
        d.vehicle = model ~= '' and model or nil
        return true, d.vehicle and ('Véhicule imposé : %s.'):format(d.vehicle) or 'Véhicule libre.'
    elseif action == 'cancel' then
        Custom.drafts[src] = nil
        return true, 'Brouillon abandonné.'
    elseif action == 'save' then
        if #d.points < C.minPoints then return false, ('Au moins %d points (départ, passages, arrivée).'):format(C.minPoints) end
        local pts = {}
        for i, p in ipairs(d.points) do pts[i] = { x = p.x, y = p.y, z = p.z } end
        local expiresAt = d.hours > 0 and (os.time() + d.hours * 3600) or nil
        local okDb, id = pcall(MySQL.insert.await, 'INSERT INTO gs_race_custom (label, points, expires_at, author, vehicle) VALUES (?, ?, ?, ?, ?)',
            { d.label, json.encode(pts), expiresAt, (GetPlayerName(src) or ''):sub(1, 60), d.vehicle })
        if not okDb or not id then -- V12.59 : la cause est écrite dans la console du serveur (avant : message muet)
            print(('^1[gs_races] Course « %s » non enregistrée : %s^0'):format(d.label, tostring(okDb and 'insertion refusée' or id)))
            return false, 'Erreur d\'enregistrement (détail dans la console du serveur). Le brouillon est gardé : réessaie.'
        end
        Custom.races[id] = { label = d.label, points = d.points, expiresAt = expiresAt, author = GetPlayerName(src) or '', vehicle = d.vehicle }
        Custom.drafts[src] = nil
        publish()
        Security:LogStaff(('[Courses] %s a créé « %s » (%d points, %s)'):format(GetPlayerName(src) or src, d.label, #d.points,
            expiresAt and (d.hours .. ' h') or 'permanente'), 'staff')
        return true, ('Course « %s » créée (%d points, %s) : elle est chez l\'organisateur de courses.'):format(d.label, #d.points,
            expiresAt and ('%d h'):format(d.hours) or 'permanente')
    end
    return false, 'Action inconnue.'
end)

AddEventHandler('playerDropped', function() Custom.drafts[source] = nil end)
