-- gs_wanted (serveur) · V8 « La ville se souvient » : description brute du suspect par les témoins et mémoire de la
-- ville (tenue, véhicule). Tout est lu côté serveur (OneSync) : le client ne peut ni cacher ni inventer un détail.
local Bridge = exports.gs_bridge

Memory = { list = {} } -- list[cid] = { { id, outfit, plate, color, at }, … } (plus récent en premier)

local UNARMED = GetHashKey('WEAPON_UNARMED')

function Memory.colorName(index)
    index = tonumber(index)
    if not index then return nil end
    for _, c in ipairs(Config.Colors) do
        for i = 2, #c do if index >= c[i][1] and index <= c[i][2] then return c[1] end end
    end
end

--- Empreinte de la tenue : masque, bas, chaussures, haut + couvre-chef. Une autre tenue = une autre empreinte.
function Memory.outfitOf(ped)
    local parts = {}
    for _, comp in ipairs(Config.Memory.outfit) do
        parts[#parts + 1] = ('%d:%d'):format(GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp))
    end
    parts[#parts + 1] = 'p' .. GetPedPropIndex(ped, 0)
    return table.concat(parts, '|')
end

-- V8 · Signes distinctifs : zones tatouées du personnage (apparence enregistrée en base, illenium-appearance)
Memory.marks = {} -- [src] = { head = true, arms = true, torso = true }
local ZONES = { ZONE_HEAD = 'head', ZONE_LEFT_ARM = 'arms', ZONE_RIGHT_ARM = 'arms', ZONE_TORSO = 'torso' }

function Memory.parseTattoos(skin)
    local ok, t = pcall(function() return type(skin) == 'string' and json.decode(skin) or skin end)
    local out = {}
    if not ok or type(t) ~= 'table' or type(t.tattoos) ~= 'table' then return out end
    for zone, list in pairs(t.tattoos) do
        if ZONES[zone] and type(list) == 'table' and next(list) then out[ZONES[zone]] = true end
    end
    return out
end

function Memory.loadMarks(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid or not MySQL or GetResourceState('oxmysql') ~= 'started' then return end
    MySQL.scalar('SELECT skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { cid }, function(skin)
        Memory.marks[src] = Memory.parseTattoos(skin)
    end)
end
AddEventHandler('gs_bridge:server:playerLoaded', function(src) Memory.loadMarks(src) end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Memory.marks[src] = nil end)
-- Passage chez le tatoueur / le magasin de vêtements : apparence ré-enregistrée → on relit
local Security = exports.gs_security
RegisterNetEvent('illenium-appearance:server:saveAppearance', function()
    local src = source
    if not Security:RateLimit(src, 'gs_wanted:marks', 2, 10000) then return end
    SetTimeout(3000, function() Memory.loadMarks(src) end)
end)

--- Tatouages qu'un témoin peut voir avec cette tenue
function Memory.visibleMarks(src, ped, masked)
    local m, out = Memory.marks[src], {}
    if not m then return out end
    local g = Bridge:GetGender(src) == 'female' and 'female' or 'male'
    if m.head and not masked then out[#out + 1] = 'tatouage au visage' end
    if m.arms and Config.Memory.bareArms[g][GetPedDrawableVariation(ped, 3)] then out[#out + 1] = 'bras tatoués' end
    if m.torso and Config.Memory.bareTorso[g][GetPedDrawableVariation(ped, 11)] then out[#out + 1] = 'torse tatoué' end
    return out
end

--- Ce que les témoins ont pu voir, selon la précision. Retourne une liste de détails (texte brut pour la police).
function Memory.describe(src, precision, veh)
    local see, out = Config.Memory.see, {}
    local ped = GetPlayerPed(src)
    if ped == 0 then return out end
    if precision >= see.gender then out[#out + 1] = Bridge:GetGender(src) == 'female' and 'Femme' or 'Homme' end
    local masked = GetPedDrawableVariation(ped, 1) > 0
    if masked and precision >= see.mask then out[#out + 1] = 'masqué' end
    if GetPedPropIndex(ped, 0) >= 0 and precision >= see.hat then out[#out + 1] = 'couvre-chef' end
    if GetPedDrawableVariation(ped, 5) > 0 and precision >= see.bag then out[#out + 1] = 'sac' end
    if GetPedDrawableVariation(ped, 9) > 0 and precision >= see.armour then out[#out + 1] = 'gilet pare-balles' end
    if GetSelectedPedWeapon(ped) ~= UNARMED and precision >= see.armed then out[#out + 1] = 'armé' end
    if precision >= Config.Memory.tattooSee then
        for _, mark in ipairs(Memory.visibleMarks(src, ped, masked)) do out[#out + 1] = mark end
    end
    if veh and veh ~= 0 and DoesEntityExist(veh) and precision >= see.vehicle then
        local kind = Config.VehicleTypes[GetVehicleType(veh)] or 'Véhicule'
        local primary = GetVehicleColours(veh)
        local color = Memory.colorName(primary)
        out[#out + 1] = color and ('%s (%s)'):format(kind, color) or kind
    end
    return out, masked
end

--- Le suspect correspond-il à un signalement récent ? (même tenue, ou même plaque ET même couleur)
---@return table|nil souvenir, string|nil ce qui a été reconnu ('tenue' | 'véhicule')
function Memory.recall(cid, ped, veh)
    local list = Memory.list[cid]
    if not list or ped == 0 then return nil end
    local now, outfit = os.time(), Memory.outfitOf(ped)
    local plate, color
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '')
        color = GetVehicleColours(veh)
    end
    for _, m in ipairs(list) do
        if now - m.at <= Config.Memory.hours * 3600 then
            if m.outfit == outfit then return m, 'tenue' end
            if plate and m.plate == plate and m.color == color then return m, 'véhicule' end
        end
    end
end

function Memory.remember(cid, reportId, ped, veh)
    if not cid or ped == 0 then return end
    local m = { id = reportId, outfit = Memory.outfitOf(ped), at = os.time() }
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        m.plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '')
        m.color = GetVehicleColours(veh)
    end
    local list = Memory.list[cid] or {}
    table.insert(list, 1, m)
    list[Config.Memory.keep + 1] = nil
    Memory.list[cid] = list
end

--- Visage connu : nom du suspect si un témoin le reconnaît (célèbre, à visage découvert, bonne visibilité).
function Memory.famous(src, precision, masked)
    if masked or precision < Config.Fame.precision or GetResourceState('gs_reputation') ~= 'started' then return nil end
    local ok, rep = pcall(function() return exports.gs_reputation:Get(src) end)
    if not ok or type(rep) ~= 'table' then return nil end
    if math.max(rep.media or 0, rep.street or 0) < Config.Fame.at or math.random() >= Config.Fame.chance then return nil end
    return Bridge:GetName(src)
end

-- La ville oublie : ménage des souvenirs trop vieux
function Memory.forget()
    local now = os.time()
    for cid, list in pairs(Memory.list) do
        for i = #list, 1, -1 do
            if now - list[i].at > Config.Memory.hours * 3600 then table.remove(list, i) end
        end
        if #list == 0 then Memory.list[cid] = nil end
    end
end
CreateThread(function()
    while true do Wait(300000) Memory.forget() end
end)
exports('ColorName', Memory.colorName)
-- Description complète d'un joueur (photo, avis de recherche) : jamais le nom
exports('Describe', function(src)
    local ped = GetPlayerPed(src)
    local d = Memory.describe(src, 1.0, ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0)
    return #d > 0 and table.concat(d, ', ') or 'silhouette floue'
end)
