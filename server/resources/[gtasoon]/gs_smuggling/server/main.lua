-- gs_smuggling (serveur) · V8 « Contrebande maritime ». Tout se décide ici : droit de prendre une cargaison, bateau,
-- distances, délais, paiement, alerte radar.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Smuggling = { runs = {}, last = {} } -- runs[src] = { pickup, drop, loaded, at }

local function now() return os.time() end
local function count() local n = 0 for _ in pairs(Smuggling.runs) do n = n + 1 end return n end
local function near(src, c, r) local ped = GetPlayerPed(src) return ped ~= 0 and #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) <= r end

local function night()
    if GetResourceState('gs_weather') ~= 'started' then return true end
    local ok, h = pcall(function() return exports.gs_weather:GetGameTime() end)
    if not ok or not h then return true end
    return h >= Config.Hours[1] or h < Config.Hours[2]
end

local function allowed(src)
    local okG, gang = pcall(function() return exports.gs_gangs:GetGang(src) end)
    if okG and gang then return true end
    local okR, rep = pcall(function() return exports.gs_reputation:Get(src) end)
    return okR and type(rep) == 'table' and (rep.street or 0) >= Config.MinStreet
end

--- Bateau conduit par le joueur (classe 14) ou nil
local function boatOf(src)
    local ped = GetPlayerPed(src)
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if veh ~= 0 and GetVehicleType(veh) == 'boat' then return veh end
end

function Smuggling.take(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid or not near(src, Config.Contact, 4.0) then return false, 'Il n\'y a personne ici.' end
    if Smuggling.runs[src] then return false, 'Tu as déjà une cargaison en cours.' end
    if not night() then return false, '« Reviens à la nuit tombée. »' end
    if not allowed(src) then return false, '« Je ne te connais pas. »' end
    if Smuggling.last[cid] and now() - Smuggling.last[cid] < Config.Cooldown * 60 then return false, '« Fais-toi oublier un peu. »' end
    if count() >= Config.MaxActive then return false, '« Toutes les cargaisons sont parties. »' end
    Smuggling.last[cid] = now()
    local run = { pickup = math.random(1, #Config.Pickups), drop = math.random(1, #Config.Drops), at = now() }
    Smuggling.runs[src] = run
    return true, { pickup = run.pickup, drop = run.drop }
end

function Smuggling.load(src)
    local run = Smuggling.runs[src]
    if not run or run.loaded then return false, 'Rien à charger.' end
    local boat = boatOf(src)
    if not boat then return false, 'Il faut être à la barre d\'un bateau.' end
    if not near(src, Config.Pickups[run.pickup], 30.0) then return false, 'Les caisses sont plus loin.' end
    run.loaded = true
    -- radar côtier
    if math.random() < Config.Radar then
        local cops = GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:GetOnDutyPlayers('police') or {}
        if GetResourceState('gs_wanted') == 'started' then
            pcall(function() exports.gs_wanted:ReportCrime(src, 'smuggling', GetEntityCoords(GetPlayerPed(src)), { vehicle = boat }) end)
        end
        if #cops == 0 and math.random() < Config.CoastGuard.chance then TriggerClientEvent('gs_smuggling:client:coastguard', src) end
        Bridge:Notify(src, 'Le radar côtier t\'a peut-être repéré…', 'warning')
    end
    return true, 'Cargaison chargée. Direction la plage.'
end

function Smuggling.deliver(src)
    local run = Smuggling.runs[src]
    if not run or not run.loaded then return false, 'Tu n\'as rien à livrer.' end
    if not near(src, Config.Drops[run.drop], 30.0) then return false, 'Ce n\'est pas la bonne plage.' end
    if now() - run.at > Config.Timeout * 60 then Smuggling.runs[src] = nil return false, 'Trop tard : l\'acheteur est parti.' end
    Smuggling.runs[src] = nil
    local pay = math.random(Config.Pay[1], Config.Pay[2])
    if not (Bridge:ItemExists('black_money') and Bridge:AddItem(src, 'black_money', pay)) then Bridge:AddMoney(src, 'cash', pay) end
    if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'street', 10) end) end
    local okG, gang = pcall(function() return exports.gs_gangs:GetGang(src) end)
    if okG and gang then TriggerEvent('gs_gangs:server:activity', gang, 'smuggling', GetEntityCoords(GetPlayerPed(src)), 1) end
    return true, ('Livré. %d $ d\'argent sale.'):format(pay)
end

function Smuggling.cancel(src) Smuggling.runs[src] = nil return true end

lib.callback.register('gs_smuggling:action', function(src, action)
    if not Security:RateLimit(src, 'gs_smuggling:action', 3, 5000) then return false, 'Doucement.' end
    if action == 'take' then return Smuggling.take(src)
    elseif action == 'load' then return Smuggling.load(src)
    elseif action == 'deliver' then return Smuggling.deliver(src)
    elseif action == 'cancel' then return Smuggling.cancel(src) end
    return false
end)

AddEventHandler('playerDropped', function() Smuggling.runs[source] = nil end)
CreateThread(function()
    while true do
        Wait(60000)
        for src, run in pairs(Smuggling.runs) do if now() - run.at > Config.Timeout * 60 then Smuggling.runs[src] = nil end end
    end
end)
