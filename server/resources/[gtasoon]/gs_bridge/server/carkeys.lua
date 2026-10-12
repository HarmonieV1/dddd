-- gs_bridge (serveur) · V12.26 : clés de véhicule en OBJET (gs_carkey), par-dessus qbx_vehiclekeys.
-- qbx_vehiclekeys garde la main (démarrer, verrouiller avec L) ; l'objet en est le reflet dans le sac :
--  - chaque fois que le joueur reçoit des clés (garage, concession, location, métier, staff, vol réussi…), il reçoit
--    UNE clé « Clé — Modèle » avec la plaque (une seule par plaque, jamais redonnée s'il l'a jetée ou donnée) ;
--  - double-clic sur la clé près du véhicule : verrouille / déverrouille, et donne l'accès à qui la tient (prêter sa
--    voiture = donner la clé) ;
--  - jamais aucun accès sans être à côté du véhicule (même contrôle que qbx_vehiclekeys).
-- Point d'entrée unique : l'état « keysList » que qbx_vehiclekeys tient sur chaque joueur.

local ITEM = 'gs_carkey'
local RANGE = 25.0 -- distance max pour que la clé agisse sur le véhicule
local OX = exports.ox_inventory
local given = {} -- [citizenid] = { [sessionId] = true } : clés déjà remises en objet (survit à une reconnexion)

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function plateOf(veh) return trim(GetVehicleNumberPlateText(veh)) end

local function citizenId(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end) -- [API]
    return ok and p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function modelLabel(veh)
    local ok, v = pcall(function() return exports.qbx_core:GetVehiclesByHash(GetEntityModel(veh)) end) -- [API]
    if ok and type(v) == 'table' and v.name then return trim((v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. v.name) end
    return 'Véhicule'
end

local function vehicleBySession(sessionId)
    for _, v in ipairs(GetAllVehicles()) do
        if Entity(v).state.sessionId == sessionId then return v end
    end
end

local function hasKeyItem(src, plate)
    local ok, items = pcall(function() return OX:Search(src, 'slots', ITEM) end) -- [API]
    for _, it in pairs(ok and items or {}) do
        if it.metadata and it.metadata.plate == plate then return true end
    end
    return false
end

--- Donne la clé-objet d'un véhicule (une par plaque). Retourne true si une clé a été ajoutée.
local function GiveKeyItem(src, veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local plate = plateOf(veh)
    if plate == '' or hasKeyItem(src, plate) then return false end
    local label = modelLabel(veh)
    return OX:AddItem(src, ITEM, 1, { plate = plate, label = ('Clé — %s'):format(label),
        description = ('%s · plaque %s. Double-clic près du véhicule : verrouiller / déverrouiller.'):format(label, plate) }) and true or false
end

-- Nouvelles clés dans qbx_vehiclekeys → clé en objet. Lancé un peu après : la plaque du garage / de la concession est
-- posée juste après la création du véhicule.
AddStateBagChangeHandler('keysList', nil, function(bagName, _, value)
    local src = tonumber(tostring(bagName):match('^player:(%d+)$'))
    if not src or type(value) ~= 'table' then return end
    CreateThread(function()
        Wait(1500)
        local cid = citizenId(src)
        if not cid then return end
        given[cid] = given[cid] or {}
        for sessionId in pairs(value) do
            if not given[cid][sessionId] then
                local veh = vehicleBySession(sessionId)
                if veh and plateOf(veh) ~= '' then
                    given[cid][sessionId] = true
                    GiveKeyItem(src, veh)
                end
            end
        end
    end)
end)

local function nearestWithPlate(src, plate)
    local pc = GetEntityCoords(GetPlayerPed(src))
    local best, bestD
    for _, v in ipairs(GetAllVehicles()) do
        if plateOf(v) == plate then
            local d = #(GetEntityCoords(v) - pc)
            if d <= RANGE and (not bestD or d < bestD) then best, bestD = v, d end
        end
    end
    return best
end

--- Utilisation de l'objet (ox_inventory : server.export = 'gs_bridge.useCarKey'). L'objet n'est jamais consommé.
exports('useCarKey', function(event, _, inventory, slot)
    if event ~= 'usingItem' then return end
    local src = inventory and inventory.id
    if type(src) ~= 'number' then return false end
    local item = OX:GetSlot(src, slot) -- [API]
    local plate = item and item.metadata and item.metadata.plate
    if type(plate) ~= 'string' then return false end
    local veh = nearestWithPlate(src, plate)
    if not veh then
        TriggerClientEvent('ox_lib:notify', src, { description = ('Aucun véhicule %s à proximité.'):format(plate), type = 'error' })
        return false
    end
    pcall(function()
        if not exports.qbx_vehiclekeys:HasKeys(src, veh) then exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end -- [API]
    end)
    local locked = (Entity(veh).state.doorslockstate or GetVehicleDoorLockStatus(veh)) == 2
    pcall(function() exports.qbx_vehiclekeys:SetLockState(veh, locked and 'unlock' or 'lock') end) -- [API]
    TriggerClientEvent('gs_bridge:client:carKeyUsed', src, NetworkGetNetworkIdFromEntity(veh), not locked)
    TriggerClientEvent('ox_lib:notify', src, { description = locked and 'Véhicule déverrouillé.' or 'Véhicule verrouillé.', type = 'success' })
    return false -- jamais consommée
end)

exports('GiveKeyItem', GiveKeyItem)
