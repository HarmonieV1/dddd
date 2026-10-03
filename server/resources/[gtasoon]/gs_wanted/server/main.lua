-- gs_wanted (serveur) : décide si un crime est signalé, construit le signalement, gère la chaleur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Wanted = { heat = {}, lastReport = {}, history = {}, nextId = 0, blind = {}, evidence = {} } -- blind[i] = fin de panne de la caméra i

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

--- Caméra en état de marche qui couvre `coords` → son nom, ou nil.
function Wanted.cameraAt(coords)
    local now = os.time()
    for i, cam in ipairs(Config.Cameras.list) do
        if (Wanted.blind[i] or 0) <= now and #(coords - cam.coords) <= Config.Cameras.radius then return cam.label end
    end
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
---@param opts table|nil { silenced = bool, vehicle = entity, alarm = bool }
--- Étoiles de la police IA pour un crime de cette gravité.
function Wanted.npcStars(heat)
    for _, s in ipairs(Config.NpcPolice.stars) do if heat <= s.heat then return s.stars end end
    return 4
end

--- Los Santos réactif (gs_city) : valeur du quartier, ou `default` si la ressource est arrêtée.
function Wanted.city(fn, coords, default)
    if GetResourceState('gs_city') ~= 'started' then return default end
    local ok, v = pcall(function() return exports.gs_city[fn](exports.gs_city, coords) end)
    return ok and tonumber(v) or default
end

function Wanted.report(src, crimeType, coords, opts)
    local crime = Config.Crimes[crimeType]
    if not crime or not coords then return nil end
    coords = toVec3(coords)
    opts = opts or {}
    if Wanted.inSafeZone(coords) then return nil end
    -- V8 : chaque crime laisse des traces (gs_evidence), qu'il soit signalé ou non
    TriggerEvent('gs_wanted:server:crime', src, crimeType, coords, opts.vehicle)

    local count, police = Wanted.witnesses(coords, src)
    local visibility = Wanted.visibility()
    local chance, precision
    if police then
        chance, precision = 1.0, 1.0
    else
        chance = crime.chance + count * Config.Witness.perWitness
        chance = chance * visibility * (opts.silenced and Config.SilencedFactor or 1.0)
        chance = chance * (1 + (Wanted.heat[src] or 0) / Config.Heat.recognition)
        chance = chance * Wanted.city('ReportFactor', coords, 1.0) -- quartier tendu (gs_city) : témoins plus prompts
        chance = clamp(chance, 0, Config.Witness.maxChance)
        precision = clamp(count * 0.15 + visibility * 0.4, 0, 1)
    end
    -- Caméra de surveillance : signalement quasi certain, zone précise, plaque lisible
    local camera = not police and Wanted.cameraAt(coords) or nil
    if camera then
        chance = clamp(chance + Config.Cameras.chanceBonus, 0, Config.Witness.maxChance)
        precision = math.max(precision, Config.Cameras.precision)
    end
    -- Alarme silencieuse (braquage) : signalement certain et précis, quels que soient les témoins.
    if opts.alarm then chance, precision = 1.0, math.max(precision, 0.85) end
    -- La ville se souvient : même tenue ou même véhicule qu'un signalement récent → reconnu plus vite
    local cid, ped, veh = Bridge:GetIdentifier(src), GetPlayerPed(src), opts.vehicle
    local seen, seenBy = Memory.recall(cid, ped, veh)
    if seen then
        chance = clamp(chance + Config.Memory.linkChance, 0, math.max(chance, Config.Witness.maxChance))
        precision = clamp(precision + Config.Memory.linkPrecision, 0, 1)
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
        camera = camera,
        precision = precision,
        delay = police and 0 or math.floor(lerp(Config.Precision.delayMax, Config.Precision.delayMin, precision)),
    }
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        report.model = GetEntityModel(veh)
        report.plate = maskPlate(GetVehicleNumberPlateText(veh), precision)
    end
    local masked
    report.desc, masked = Memory.describe(src, precision, veh)
    report.named = Memory.famous(src, precision, masked)
    if seen then report.linked, report.linkedBy = seen.id, seenBy end
    Memory.remember(cid, report.id, ped, veh)
    TriggerEvent('gs_wanted:server:report', report) -- V8 : rumeurs (jamais l'identité, sauf visage connu)

    if camera then -- preuve vidéo pour la police (description, jamais l'identité)
        table.insert(Wanted.evidence, 1, { label = crime.label, camera = camera, date = os.date('%d/%m %H:%M'), plate = report.plate,
            gender = Bridge:GetGender(src) == 'female' and 'femme' or 'homme', desc = table.concat(report.desc, ', ') })
        Wanted.evidence[Config.Cameras.keep + 1] = nil
    end
    Wanted.addHeat(src, crime.heat)
    TriggerEvent('gs_wanted:server:reported', src, crimeType, crime.heat, coords)
    SetTimeout(report.delay * 1000, function()
        table.insert(Wanted.history, 1, report)
        Wanted.history[Config.Dispatch.history + 1] = nil
        local cops = JobsApi:GetOnDutyPlayers(Config.PoliceJob)
        for _, cop in ipairs(cops) do
            TriggerClientEvent('gs_wanted:client:dispatch', cop, report)
        end
        if #cops < Config.NpcPolice.minCops then
            TriggerClientEvent('gs_wanted:client:npcPolice', src, math.min(5, Wanted.npcStars(crime.heat) + Wanted.city('NpcBonus', coords, 0)))
        end
    end)
    return report
end

-- Police IA : patrouilles créées par le serveur ----------------------------------------------------------------
Wanted.units = {}      -- [src] = { { veh, peds = {}, born } }
Wanted.unitAsk = {}    -- [src] = os.time() de la dernière demande

local function unitCount()
    local n = 0
    for _, list in pairs(Wanted.units) do n = n + #list end
    return n
end

--- Supprime les patrouilles d'un joueur (fin de poursuite, départ).
function Wanted.clearUnits(src)
    for _, u in ipairs(Wanted.units[src] or {}) do
        for _, p in ipairs(u.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
        if DoesEntityExist(u.veh) then DeleteEntity(u.veh) end
    end
    Wanted.units[src] = nil
end

--- Crée des patrouilles aux positions de route proposées par le client (le serveur limite le nombre et la distance).
--- Retourne la liste { { veh = netId, peds = { netId… } } }.
function Wanted.spawnUnits(src, stars, positions)
    local U = Config.NpcPolice.units
    local now = os.time()
    if (Wanted.unitAsk[src] or 0) + U.cooldown > now then return {} end
    Wanted.unitAsk[src] = now
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or type(positions) ~= 'table' then return {} end
    local me = GetEntityCoords(ped)
    local mine = Wanted.units[src] or {}
    Wanted.units[src] = mine
    local want = math.min(U.maxUnits, math.max(1, tonumber(stars) or 1)) - #mine
    local county = me.y > 1200.0 -- au nord de Vinewood : shérif
    local out = {}
    for _, pos in ipairs(positions) do
        if want <= 0 or unitCount() >= U.maxServer then break end
        if type(pos) == 'table' and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z) then
            local c = vector3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
            local d = #(c - me)
            if d > 60.0 and d < 400.0 then
                local veh = CreateVehicle(GetHashKey(county and U.vehicles.county or U.vehicles.city), c.x, c.y, c.z, tonumber(pos.w) or 0.0, true, true)
                local deadline = GetGameTimer() + 2000
                while not DoesEntityExist(veh) and GetGameTimer() < deadline do Wait(0) end
                if DoesEntityExist(veh) then
                    local u = { veh = veh, peds = {}, born = now }
                    for seat = -1, 0 do
                        local p = CreatePedInsideVehicle(veh, 6, GetHashKey(county and U.peds.county or U.peds.city), seat, true, true)
                        if p and p ~= 0 then
                            GiveWeaponToPed(p, GetHashKey(U.weapons[math.min(3, math.max(1, tonumber(stars) or 1))]), 120, false, true)
                            SetPedArmour(p, U.armour)
                            u.peds[#u.peds + 1] = p
                        end
                    end
                    mine[#mine + 1] = u
                    local nets = {}
                    for _, p in ipairs(u.peds) do nets[#nets + 1] = NetworkGetNetworkIdFromEntity(p) end
                    out[#out + 1] = { veh = NetworkGetNetworkIdFromEntity(veh), peds = nets }
                    want = want - 1
                end
            end
        end
    end
    return out
end

lib.callback.register('gs_wanted:npcUnits', function(src, stars, positions)
    if not Security:RateLimit(src, 'gs_wanted:npcUnits', 2, 15000) then return {} end
    return Wanted.spawnUnits(src, stars, positions)
end)

RegisterNetEvent('gs_wanted:server:npcClear', function()
    local src = source
    if not Security:RateLimit(src, 'gs_wanted:npcClear', 3, 10000) then return end
    SetTimeout(15000, function() Wanted.clearUnits(src) end) -- le temps qu'ils repartent
end)

-- Ménage : patrouilles trop vieilles ou joueur parti
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, list in pairs(Wanted.units) do
            if not GetPlayerName(src) then Wanted.clearUnits(src)
            else
                for i = #list, 1, -1 do
                    if now - list[i].born > Config.NpcPolice.units.lifetime then
                        for _, p in ipairs(list[i].peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
                        if DoesEntityExist(list[i].veh) then DeleteEntity(list[i].veh) end
                        table.remove(list, i)
                    end
                end
            end
        end
    end
end)
AddEventHandler('playerDropped', function() Wanted.clearUnits(source) end)

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

--- Aveugle les caméras à moins de `radius` m de `coords` pendant `seconds` (pirate d'un gros coup).
function Wanted.blindCameras(coords, radius, seconds)
    local n, until_ = 0, os.time() + (seconds or Config.Cameras.blindSeconds)
    for i, cam in ipairs(Config.Cameras.list) do
        if #(toVec3(coords) - cam.coords) <= (radius or 60.0) then Wanted.blind[i] = until_ n = n + 1 end
    end
    return n
end
exports('BlindCameras', Wanted.blindCameras)
exports('GetEvidence', function() return Wanted.evidence end)

-- API pour les autres ressources (braquages, drogue, duo...) ---------------------------------------
exports('ReportCrime', function(src, crimeType, coords, opts) return Wanted.report(src, crimeType, coords, opts) ~= nil end)
exports('GetHeat', function(src) return Wanted.heat[src] or 0 end)
exports('AddHeat', Wanted.addHeat)
exports('ClearHeat', Wanted.clearHeat)
-- Derniers signalements (rumeurs, historique des véhicules…) : jamais l'identité, sauf visage connu
exports('GetHistory', function() return Wanted.history end)
exports('CrimeLabel', function(t) return Config.Crimes[t] and Config.Crimes[t].label or nil end)
