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
function Carnet.sample(veh)
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
    end
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
            Carnet.sample(veh)
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

CreateThread(function()
    Store.init()
    while true do Wait(Config.Sample * 1000) Carnet.tick() end
end)
