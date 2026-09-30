-- gs_rental (serveur) : une location à la fois par joueur, véhicule créé ici (clés données), retiré à l'échéance.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Rental = { active = {} } -- [src] = { veh, model, expires, warned }

local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end

--- Paie en liquide, sinon par la banque.
local function pay(src, amount)
    if Bridge:GetMoney(src, 'cash') >= amount then return Bridge:RemoveMoney(src, 'cash', amount, 'location') end
    return Bridge:RemoveMoney(src, 'bank', amount, 'location')
end

local function spotFree(spawn)
    for _, v in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(v) - vec3(spawn.x, spawn.y, spawn.z)) < 3.0 then return false end
    end
    return true
end

function Rental.clear(src)
    local r = Rental.active[src]
    Rental.active[src] = nil
    if r and DoesEntityExist(r.veh) then DeleteEntity(r.veh) end
end

lib.callback.register('gs_rental:rent', function(src, pointId, vehicleId)
    if not Security:RateLimit(src, 'gs_rental:rent', 3, 10000) then return false, 'Doucement.' end
    local point, v = Config.Points[tonumber(pointId)], Config.Vehicles[tonumber(vehicleId)]
    if not point or not v or v.kind ~= point.kind then return false, 'Indisponible.' end
    if not Security:InRange(src, point.coords, Config.Radius + 2.0) then return false, 'Approche-toi du comptoir.' end
    if Rental.active[src] then return false, 'Tu as déjà une location en cours : rends-la d\'abord.' end
    if not spotFree(point.spawn) then return false, 'La place est occupée, libère-la.' end
    if not pay(src, v.price) then return false, ('Il te faut %d $.'):format(v.price) end
    local plate = ('LOC%04d'):format(math.random(0, 9999))
    local veh = Bridge:SpawnVehicle(src, v.model, v.type, point.spawn, point.spawn.w, plate, true)
    if not veh or veh == 0 then
        Bridge:AddMoney(src, 'cash', v.price, 'location remboursée')
        return false, 'Véhicule indisponible, remboursé.'
    end
    Rental.active[src] = { veh = veh, model = v.model, expires = os.time() + v.minutes * 60 }
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'rental') end
    return true, ('%s loué %d min pour %d $. Rends-le à n\'importe quel point de location.'):format(v.label, v.minutes, v.price)
end)

lib.callback.register('gs_rental:return', function(src, pointId)
    if not Security:RateLimit(src, 'gs_rental:return', 3, 10000) then return false, 'Doucement.' end
    local point = Config.Points[tonumber(pointId)]
    local r = Rental.active[src]
    if not point or not r then return false, 'Aucune location en cours.' end
    if not Security:InRange(src, point.coords, Config.Radius + 2.0) then return false, 'Approche-toi du comptoir.' end
    if DoesEntityExist(r.veh) and #(GetEntityCoords(r.veh) - point.coords) > Config.ReturnRadius then
        return false, 'Ramène le véhicule près du comptoir.'
    end
    Rental.clear(src)
    return true, 'Véhicule rendu, merci !'
end)

lib.callback.register('gs_rental:status', function(src)
    if not Security:RateLimit(src, 'gs_rental:status', 10, 10000) then return nil end
    local r = Rental.active[src]
    return r and { model = r.model, left = math.max(0, r.expires - os.time()) } or nil
end)

--- Toutes les 30 s : avertissement, puis retrait (après un délai de grâce si le joueur est encore dedans).
function Rental.tick()
    local now = os.time()
    for src, r in pairs(Rental.active) do
        if not DoesEntityExist(r.veh) then
            Rental.active[src] = nil
            notify(src, 'Ta location est terminée (véhicule détruit ou disparu).', 'warning')
        elseif now >= r.expires + Config.Grace * 60
            or (now >= r.expires and GetPedInVehicleSeat(r.veh, -1) == 0) then
            Rental.clear(src)
            notify(src, 'Location terminée : le véhicule a été récupéré.', 'inform')
        elseif not r.warned and now >= r.expires - Config.WarnBefore * 60 then
            r.warned = true
            notify(src, ('Ta location se termine dans %d min.'):format(math.ceil((r.expires - now) / 60)), 'warning')
        end
    end
end

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Rental.clear(src) end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Rental.active) do Rental.clear(src) end
end)

CreateThread(function()
    while true do
        Wait(30000)
        Rental.tick()
    end
end)
