-- gs_places (serveur) : lieux publics posés par le staff (parkings, boutiques de vêtements). Les parkings sont
-- déclarés à qbx_garages (RegisterGarage) ; la liste complète est publiée aux clients (GlobalState.gsPlaces).
local Security = exports.gs_security

Places = { list = {} } -- [key] = { id?, kind, label, coords = vec4, spawn = vec4? }

local function vec4of(r, p) return vec4(r[p .. 'x'] + 0.0, r[p .. 'y'] + 0.0, r[p .. 'z'] + 0.0, r[p .. 'h'] + 0.0) end

local function registerGarage(key, p)
    if p.kind ~= 'parking' or GetResourceState('qbx_garages') ~= 'started' then return end
    pcall(function()
        exports.qbx_garages:RegisterGarage(key, { label = p.label, vehicleType = 'car', accessPoints = { {
            blip = { name = 'Parking public', sprite = Config.Kinds.parking.blip.sprite, color = Config.Kinds.parking.blip.color },
            coords = p.coords, spawn = p.spawn or p.coords } } })
    end)
end

local function publish()
    local out = {}
    for key, p in pairs(Places.list) do
        out[#out + 1] = { key = key, kind = p.kind, label = p.label, x = p.coords.x, y = p.coords.y, z = p.coords.z }
    end
    GlobalState.gsPlaces = out
end

function Places.add(key, p)
    Places.list[key] = p
    registerGarage(key, p)
end

local function staff(src)
    return GetResourceState('gs_admin') == 'started' and (exports.gs_admin:GetStaffLevel(src) or 0) >= Config.StaffLevel
end

--- Staff : pose un lieu à sa position. Parking : être dans le véhicule, à l'endroit où les voitures sortiront.
lib.callback.register('gs_places:create', function(src, kind, label)
    if not Security:RateLimit(src, 'gs_places', 4, 10000) then return false, 'Doucement.' end
    if not staff(src) then return false, 'Réservé au staff.' end
    local k = Config.Kinds[kind]
    if not k then return false, 'Type inconnu.' end
    label = Security:Sanitize(label, 40) or k.label
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if kind == 'parking' and veh == 0 then return false, 'Mets-toi au volant, garé là où les voitures doivent sortir.' end
    local ent = veh ~= 0 and veh or ped
    local c, h = GetEntityCoords(ent), GetEntityHeading(ent)
    local pos = vec4(c.x, c.y, c.z, h)
    local id = MySQL.insert.await('INSERT INTO gs_places (kind, label, cx, cy, cz, ch) VALUES (?, ?, ?, ?, ?, ?)', { kind, label, c.x, c.y, c.z, h })
    if not id then return false, 'Erreur BDD.' end
    Places.add('gs_place_' .. id, { id = id, kind = kind, label = label, coords = pos, spawn = pos })
    publish()
    Security:LogStaff(('[Lieux] %s a posé « %s » (%s) en %.1f, %.1f'):format(GetPlayerName(src) or src, label, kind, c.x, c.y))
    return true, ('%s « %s » créé ici.'):format(k.label, label)
end)

--- Staff : retire le lieu posé en jeu le plus proche (les lieux de base se changent dans shared/config.lua).
lib.callback.register('gs_places:delete', function(src)
    if not Security:RateLimit(src, 'gs_places', 4, 10000) then return false, 'Doucement.' end
    if not staff(src) then return false, 'Réservé au staff.' end
    local c = GetEntityCoords(GetPlayerPed(src))
    local best, bestD
    for key, p in pairs(Places.list) do
        local d = #(vec3(p.coords.x, p.coords.y, p.coords.z) - c)
        if p.id and d <= Config.MaxDistance and (not bestD or d < bestD) then best, bestD = key, d end
    end
    if not best then return false, ('Aucun lieu posé en jeu à moins de %d m.'):format(Config.MaxDistance) end
    local p = Places.list[best]
    MySQL.query.await('DELETE FROM gs_places WHERE id = ?', { p.id })
    Places.list[best] = nil
    publish()
    return true, ('« %s » retiré (le parking disparaît au prochain redémarrage du serveur).'):format(p.label)
end)

function Places.load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_places` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `kind` VARCHAR(20) NOT NULL,
        `label` VARCHAR(40) NOT NULL,
        `cx` FLOAT NOT NULL, `cy` FLOAT NOT NULL, `cz` FLOAT NOT NULL, `ch` FLOAT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for i, d in ipairs(Config.Defaults) do Places.add('gs_place_default_' .. i, d) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM gs_places') or {}) do
        local pos = vec4of(r, 'c')
        Places.add('gs_place_' .. r.id, { id = r.id, kind = r.kind, label = r.label, coords = pos, spawn = pos })
    end
    publish()
end

-- qbx_garages redémarré : on lui redonne nos parkings
AddEventHandler('onResourceStart', function(res)
    if res ~= 'qbx_garages' then return end
    SetTimeout(2000, function() for key, p in pairs(Places.list) do registerGarage(key, p) end end)
end)

CreateThread(function() Places.load() end)
