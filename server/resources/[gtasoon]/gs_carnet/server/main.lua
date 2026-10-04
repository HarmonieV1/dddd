-- gs_carnet (serveur) · V8 « Chaque voiture a une histoire ». Relevés faits ici (positions, carrosserie, peinture,
-- propriétaire) : le client n'envoie rien, il ne peut ni gonfler ni effacer le compteur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Carnet = { cache = {}, last = {} } -- cache[plate] = ligne ; last[plate] = { pos, body }

local function trim(p) return (p or ''):gsub('%s+$', '') end

local function colorName(c)
    if GetResourceState('gs_wanted') ~= 'started' then return nil end
    local ok, n = pcall(function() return exports.gs_wanted:ColorName(c) end)
    return ok and n or nil
end

--- Ligne du véhicule (créée au premier relevé), nil si ce n'est pas un véhicule de joueur.
function Carnet.row(plate)
    if Carnet.cache[plate] then return Carnet.cache[plate] end
    local owner = Bridge:GetVehicleOwner(plate)
    if not owner then return nil end
    local r = Store.get(plate) or { plate = plate, km = 0.0, owner = owner, owners = 1, color = -1 }
    Carnet.cache[plate] = r
    return r
end

--- Un relevé pour un véhicule conduit
function Carnet.sample(veh, driver)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local plate = trim(GetVehicleNumberPlateText(veh))
    local r = Carnet.row(plate)
    if not r then return end
    local pos, body, color = GetEntityCoords(veh), GetVehicleBodyHealth(veh), GetVehicleColours(veh)
    local prev = Carnet.last[plate]
    if prev then
        local d = #(pos - prev.pos)
        if d <= Config.MaxSpeed * Config.Sample then r.km = r.km + d / 1000.0 end
        if prev.body - body >= Config.Accident then
            Store.event(plate, 'accident', ('Accident (carrosserie %d %%)'):format(math.floor(body / 10)), false)
        end
    end
    Carnet.last[plate] = { pos = pos, body = body }
    local owner = Bridge:GetVehicleOwner(plate)
    if owner and owner ~= r.owner then
        r.owner, r.owners = owner, r.owners + 1
        Store.event(plate, 'owner', ('Changement de propriétaire (%de main)'):format(r.owners), false)
        TriggerEvent('gs_carnet:server:ownerChanged', plate) -- V9 : l'assurance recoupe
    end
    if driver then TriggerEvent('gs_carnet:server:driven', plate, driver) end
    if r.color ~= color then
        if r.color >= 0 then
            Store.event(plate, 'paint', ('Repeinte : %s → %s'):format(colorName(r.color) or '?', colorName(color) or '?'), false)
        end
        r.color = color
    end
    Store.save(r)
end

function Carnet.tick()
    local seen = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(id))
        local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and not seen[veh] then
            seen[veh] = true
            Carnet.sample(veh, tonumber(id))
        end
    end
end

-- Crimes avec un véhicule de joueur : noté au carnet, visible par la police seulement
AddEventHandler('gs_wanted:server:crime', function(_, crimeType, _, veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local plate = trim(GetVehicleNumberPlateText(veh))
    if not Carnet.row(plate) then return end
    local ok, label = pcall(function() return exports.gs_wanted:CrimeLabel(crimeType) end)
    Store.event(plate, 'crime', 'Impliqué : ' .. ((ok and label) or crimeType), true)
end)

--- Historique : public (kilomètres, accidents, propriétaires, peintures) ; la police voit aussi les crimes
function Carnet.view(plate, police)
    local r = Carnet.row(plate)
    if not r then return nil end
    return { plate = plate, km = math.floor(r.km), owners = r.owners, color = colorName(r.color), events = Store.events(plate, police, Config.Keep) }
end

lib.callback.register('gs_carnet:view', function(src, plate)
    if not Security:RateLimit(src, 'gs_carnet:view', 3, 5000) then return nil end
    local police = GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob)
    if not police then -- un civil : seulement le véhicule où il est assis
        local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
        if veh == 0 then return nil end
        plate = GetVehicleNumberPlateText(veh)
    end
    return Carnet.view(trim(tostring(plate or '')), police)
end)

-- V8 · Fausses plaques ---------------------------------------------------------------------------------------------
local function fakeText()
    local L, out = 'ABCDEFGHJKLMNPRSTUVWXYZ', ''
    for i = 1, 8 do
        if i <= 2 or i >= 6 then local k = math.random(1, #L) out = out .. L:sub(k, k) else out = out .. math.random(0, 9) end
    end
    return out
end

function Carnet.restorePlate(veh)
    if not DoesEntityExist(veh) then return false end
    local real = Entity(veh).state.gsRealPlate
    if not real then return false end
    SetVehicleNumberPlateText(veh, real)
    Entity(veh).state:set('gsRealPlate', nil, true)
    return true
end

function Carnet.fakePlate(src, netId)
    local F = Config.FakePlate
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, 'Aucun véhicule.' end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > F.range then return false, 'Approche-toi de la plaque.' end
    if Entity(veh).state.gsRealPlate then
        Carnet.restorePlate(veh)
        Bridge:AddItem(src, F.item, 1)
        Bridge:GiveVehicleKeys(src, veh)
        return true, 'Vraie plaque remise.'
    end
    if not Bridge:RemoveItem(src, F.item, 1) then return false, 'Il te faut une fausse plaque.' end
    local real, fake = trim(GetVehicleNumberPlateText(veh)), fakeText()
    Entity(veh).state:set('gsRealPlate', real, true)
    SetVehicleNumberPlateText(veh, fake)
    Bridge:GiveVehicleKeys(src, veh)
    SetTimeout(F.minutes * 60000, function() if DoesEntityExist(veh) and Entity(veh).state.gsRealPlate == real then Carnet.restorePlate(veh) end end)
    return true, ('Fausse plaque posée : %s (%d min). Remets la vraie avant de garer.'):format(fake, F.minutes)
end

lib.callback.register('gs_carnet:fakeplate', function(src, netId)
    if not Security:RateLimit(src, 'gs_carnet:fakeplate', 2, 10000) then return false, 'Doucement.' end
    return Carnet.fakePlate(src, netId)
end)

CreateThread(function()
    Store.init()
    while true do Wait(Config.Sample * 1000) Carnet.tick() end
end)
