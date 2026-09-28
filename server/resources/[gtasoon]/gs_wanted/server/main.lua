-- gs_wanted (serveur) : décide si un crime est signalé, construit le signalement, gère la chaleur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Wanted = { heat = {}, lastReport = {}, history = {}, nextId = 0 }

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function toVec3(c) return vec3(c.x, c.y, c.z) end

local function isPoliceOnDuty(src)
    return JobsApi:IsOnDutyAs(src, Config.PoliceJob)
end

-- Contexte monde (gs_weather optionnel) -------------------------------------------------------

function Wanted.visibility()
    local factor = 1.0
    if GetResourceState('gs_weather') == 'started' then
        local w = exports.gs_weather
        local hour = w:GetGameTime()
        for _, t in ipairs(Config.TimeFactor) do
            if hour >= t.from and hour < t.to then factor = factor * t.factor break end
        end
        factor = factor * (Config.WeatherFactor[w:GetWeather()] or 1.0)
        if w:IsBlackout() then factor = factor * Config.BlackoutFactor end
    end
    return factor
end

function Wanted.inSafeZone(coords)
    for _, z in ipairs(Config.SafeZones) do
        if #(coords - z.coords) <= z.radius then return true end
    end
    return false
end

--- Témoins autour de `coords` : PNJ vivants + joueurs (hors suspect). Détecte aussi un policier en service.
function Wanted.witnesses(coords, suspect)
    local count, police = 0, false
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and GetEntityHealth(ped) > 0
            and #(GetEntityCoords(ped) - coords) <= Config.Witness.radius then
            count = count + 1
        end
    end
    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        if pid ~= suspect then
            local ped = GetPlayerPed(pid)
            local dist = ped ~= 0 and #(GetEntityCoords(ped) - coords) or math.huge
            if dist <= Config.Witness.radius then count = count + 1 end
            if dist <= Config.Witness.policeRadius and isPoliceOnDuty(pid) then police = true end
        end
    end
    return count, police
end

-- Chaleur ----------------------------------------------------------------------------------------

local function pushHeat(src)
    TriggerClientEvent('gs_wanted:client:heat', src, Wanted.heat[src] or 0)
end

function Wanted.addHeat(src, amount)
    if type(amount) ~= 'number' or amount <= 0 then return end
    Wanted.heat[src] = clamp((Wanted.heat[src] or 0) + amount, 0, Config.Heat.max)
    Wanted.lastReport[src] = os.time()
    pushHeat(src)
end

function Wanted.clearHeat(src)
    Wanted.heat[src], Wanted.lastReport[src] = nil, nil
    pushHeat(src)
end

function Wanted.decay()
    local now = os.time()
    for src, heat in pairs(Wanted.heat) do
        if now - (Wanted.lastReport[src] or 0) >= Config.Heat.quietMinutes * 60 then
            local new = heat - Config.Heat.decayPerMinute
            Wanted.heat[src] = new > 0 and new or nil
            pushHeat(src)
        end
    end
end

-- Signalement ------------------------------------------------------------------------------------

local function maskPlate(plate, precision)
    if not plate then return nil end
    plate = plate:gsub('%s+$', '')
    local shown = math.floor(#plate * precision)
    return plate:sub(1, shown) .. ('*'):rep(#plate - shown)
end

--- Évalue un crime. Retourne le signalement envoyé à la police, ou nil s'il passe inaperçu.
---@param opts table|nil { silenced = bool, vehicle = entity }
function Wanted.report(src, crimeType, coords, opts)
    local crime = Config.Crimes[crimeType]
    if not crime or not coords then return nil end
    coords = toVec3(coords)
    opts = opts or {}
    if Wanted.inSafeZone(coords) then return nil end

    local count, police = Wanted.witnesses(coords, src)
    local visibility = Wanted.visibility()
    local chance, precision
    if police then
        chance, precision = 1.0, 1.0
    else
        chance = crime.chance + count * Config.Witness.perWitness
        chance = chance * visibility * (opts.silenced and Config.SilencedFactor or 1.0)
        chance = chance * (1 + (Wanted.heat[src] or 0) / Config.Heat.recognition)
        chance = clamp(chance, 0, Config.Witness.maxChance)
        precision = clamp(count * 0.15 + visibility * 0.4, 0, 1)
    end
    if math.random() >= chance then return nil end

    -- Zone floutée : le centre est décalé aléatoirement dans le rayon d'incertitude.
    local radius = lerp(Config.Precision.blurMax, Config.Precision.blurMin, precision)
    local angle, shift = math.random() * 2 * math.pi, math.random() * radius * 0.8
    Wanted.nextId = Wanted.nextId + 1
    local report = {
        id = Wanted.nextId,
        crime = crimeType,
        label = crime.label,
        coords = vec3(coords.x + math.cos(angle) * shift, coords.y + math.sin(angle) * shift, coords.z),
        radius = math.floor(radius),
        witnesses = police and -1 or count,  -- -1 = constaté par un agent
        precision = precision,
        delay = police and 0 or math.floor(lerp(Config.Precision.delayMax, Config.Precision.delayMin, precision)),
    }
    local veh = opts.vehicle
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        report.model = GetEntityModel(veh)
        report.plate = maskPlate(GetVehicleNumberPlateText(veh), precision)
    end

    Wanted.addHeat(src, crime.heat)
    TriggerEvent('gs_wanted:server:reported', src, crimeType, crime.heat)
    SetTimeout(report.delay * 1000, function()
        table.insert(Wanted.history, 1, report)
        Wanted.history[Config.Dispatch.history + 1] = nil
        for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do
            TriggerClientEvent('gs_wanted:client:dispatch', cop, report)
        end
    end)
    return report
end

-- Détections envoyées par le client (le client ne choisit que le type, le serveur vérifie) ------

local UNARMED = GetHashKey('WEAPON_UNARMED')

RegisterNetEvent('gs_wanted:server:shot', function(silenced)
    local src = source
    if not Security:RateLimit(src, 'gs_wanted:shot', 1, 10000) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetSelectedPedWeapon(ped) == UNARMED or isPoliceOnDuty(src) then return end
    Wanted.report(src, 'gunshot', GetEntityCoords(ped), { silenced = silenced == true, vehicle = GetVehiclePedIsIn(ped, false) })
end)

RegisterNetEvent('gs_wanted:server:carjack', function()
    local src = source
    if not Security:RateLimit(src, 'gs_wanted:carjack', 1, 20000) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or isPoliceOnDuty(src) then return end
    Wanted.report(src, 'carjack', GetEntityCoords(ped), { vehicle = GetVehiclePedIsIn(ped, false) })
end)

-- Explosions : détectées côté serveur (le client ne peut pas les cacher).
AddEventHandler('explosionEvent', function(sender)
    local src = tonumber(sender)
    if not src or not Security:RateLimit(src, 'gs_wanted:explosion', 1, 10000) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or isPoliceOnDuty(src) then return end
    Wanted.report(src, 'explosion', GetEntityCoords(ped))
end)

lib.callback.register('gs_wanted:history', function(src)
    if not Security:RateLimit(src, 'gs_wanted:history', 5, 10000) or not isPoliceOnDuty(src) then return {} end
    return Wanted.history
end)

CreateThread(function()
    while true do
        Wait(60000)
        Wanted.decay()
    end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    Wanted.heat[src], Wanted.lastReport[src] = nil, nil
end)

lib.addCommand('effacerrecherche', {
    help = 'Remet la chaleur d\'un joueur à zéro (staff)',
    params = { { name = 'target', type = 'playerId', help = 'ID serveur' } },
    restricted = 'group.admin',
}, function(src, args)
    Wanted.clearHeat(args.target)
    Security:LogStaff(('/effacerrecherche %s par %s'):format(args.target, src == 0 and 'console' or GetPlayerName(src)))
end)

-- API pour les autres ressources (braquages, drogue, duo...) ---------------------------------------
exports('ReportCrime', function(src, crimeType, coords, opts) return Wanted.report(src, crimeType, coords, opts) ~= nil end)
exports('GetHeat', function(src) return Wanted.heat[src] or 0 end)
exports('AddHeat', Wanted.addHeat)
exports('ClearHeat', Wanted.clearHeat)
