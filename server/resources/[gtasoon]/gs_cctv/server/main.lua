-- gs_cctv (serveur) · V10.1 « Caméras de surveillance ». Le serveur relève lui-même les véhicules conduits par des
-- joueurs près des caméras (aucune donnée du client), garde un historique court par caméra et le montre à la police.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

CCTV = { log = {}, seen = {}, blind = {} } -- log[cam] = { passages } ; seen[cam .. plate] = horodatage ; blind[cam] = fin

local function now() return os.time() end
local function trim(p) return ((p or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local R2 = Config.Radius * Config.Radius

local function colorName(veh)
    if GetResourceState('gs_wanted') ~= 'started' then return nil end
    local ok, n = pcall(function() return exports.gs_wanted:ColorName((GetVehicleColours(veh))) end)
    return ok and n or nil
end
local function modelName(veh)
    if GetResourceState('gs_wanted') ~= 'started' then return 'Véhicule' end
    local ok, d = pcall(function() return exports.gs_wanted:VehicleType(veh) end)
    return ok and d or 'Véhicule'
end

function CCTV.active(i) return not CCTV.blind[i] or now() >= CCTV.blind[i] end

--- Un relevé : chaque véhicule conduit par un joueur, près d'une caméra active
function CCTV.sample()
    local t = now()
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(id))
        local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local p = GetEntityCoords(veh)
            for i, cam in ipairs(Config.Cameras) do
                local dx, dy = p.x - cam.coords.x, p.y - cam.coords.y
                if dx * dx + dy * dy <= R2 and CCTV.active(i) then
                    local plate = trim(GetVehicleNumberPlateText(veh))
                    local key = i .. ':' .. plate
                    if not CCTV.seen[key] or t - CCTV.seen[key] >= Config.Dedupe then
                        CCTV.seen[key] = t
                        local l = CCTV.log[i] or {}
                        table.insert(l, 1, { at = t, plate = plate, model = modelName(veh), color = colorName(veh),
                            kmh = math.floor(GetEntitySpeed(veh) * 3.6) })
                        l[Config.Keep + 1] = nil
                        CCTV.log[i] = l
                    end
                end
            end
        end
    end
end

--- Ménage : passages trop vieux, mémoire des doublons
function CCTV.clean()
    local limit = now() - Config.MaxAge * 60
    for i, l in pairs(CCTV.log) do
        for k = #l, 1, -1 do if l[k].at < limit then l[k] = nil end end
        if #l == 0 then CCTV.log[i] = nil end
    end
    for k, at in pairs(CCTV.seen) do if at < now() - Config.Dedupe then CCTV.seen[k] = nil end end
end

local function atTerminal(src)
    for _, t in ipairs(Config.Terminals) do if Security:InRange(src, t, Config.TerminalRange + 1.5) then return true end end
    return false
end
local function isCop(src)
    return GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob) == true
end

--- Passages par plaque (morceau) ou par caméra ; les plus récents d'abord (30 max)
function CCTV.find(query, cam)
    query = tostring(query or ''):upper():gsub('[^%w]', '')
    cam = tonumber(cam)
    local out = {}
    for i, l in pairs(CCTV.log) do
        if not cam or cam == i then
            for _, e in ipairs(l) do
                if query == '' or e.plate:upper():gsub('%s', ''):find(query, 1, true) then
                    out[#out + 1] = { cam = Config.Cameras[i].label, at = os.date('%H:%M', e.at), ts = e.at, plate = e.plate, model = e.model, color = e.color, kmh = e.kmh }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.ts > b.ts end)
    for k = #out, 31, -1 do out[k] = nil end
    return out
end

--- Recherche police : en service, devant un ordinateur du commissariat
function CCTV.search(src, query, cam)
    if not isCop(src) then return false, 'Réservé à la police en service.' end
    if not atTerminal(src) then return false, 'Il faut être devant un ordinateur du commissariat.' end
    return true, CCTV.find(query, cam)
end

function CCTV.cameras(src)
    if not isCop(src) then return {} end
    local out = {}
    for i, c in ipairs(Config.Cameras) do out[i] = { label = c.label, active = CCTV.active(i), count = #(CCTV.log[i] or {}) } end
    return out
end

--- Aveugler une caméra (bombe de peinture) : signalé comme vandalisme, la police voit la caméra hors service
function CCTV.blindCam(src, i)
    i = tonumber(i)
    local cam = i and Config.Cameras[i]
    if not cam then return false, 'Caméra inconnue.' end
    if not Security:InRange(src, cam.coords, Config.Blind.range + 6.0) then return false, 'Trop loin.' end
    if not CCTV.active(i) then return false, 'Cette caméra ne voit déjà plus rien.' end
    if not Bridge:RemoveItem(src, Config.Blind.item, 1) then return false, 'Il te faut une bombe de peinture.' end
    CCTV.blind[i] = now() + Config.Blind.minutes * 60
    GlobalState.gsCctvBlind = (function() local l = {} for k, v in pairs(CCTV.blind) do if v > now() then l[#l + 1] = k end end return l end)()
    if GetResourceState('gs_wanted') == 'started' then pcall(function() exports.gs_wanted:ReportCrime(src, 'racket', cam.coords) end) end
    return true, ('Objectif peint : la caméra %s est aveugle pour %d min.'):format(cam.label, Config.Blind.minutes)
end

lib.callback.register('gs_cctv:search', function(src, query, cam)
    if not Security:RateLimit(src, 'gs_cctv:search', 5, 10000) then return false, 'Doucement.' end
    return CCTV.search(src, query, cam)
end)
lib.callback.register('gs_cctv:cameras', function(src)
    if not Security:RateLimit(src, 'gs_cctv:cameras', 5, 10000) then return {} end
    return CCTV.cameras(src)
end)
lib.callback.register('gs_cctv:blind', function(src, i)
    if not Security:RateLimit(src, 'gs_cctv:blind', 2, 10000) then return false, 'Doucement.' end
    return CCTV.blindCam(src, i)
end)

exports('Search', function(plate) return CCTV.find(plate) end) -- pour d'autres ressources (enquêtes)
--- V11.2 : black-out de quartier (gs_city) : toutes les caméras dans le rayon sont aveugles pendant `minutes`
exports('BlindArea', function(x, y, radius, minutes)
    local n, untilTs = 0, now() + (tonumber(minutes) or 15) * 60
    for i, cam in ipairs(Config.Cameras) do
        if #(vec2(cam.coords.x, cam.coords.y) - vec2(x, y)) <= radius then CCTV.blind[i] = math.max(CCTV.blind[i] or 0, untilTs) n = n + 1 end
    end
    GlobalState.gsCctvBlind = (function() local l = {} for k, v in pairs(CCTV.blind) do if v > now() then l[#l + 1] = k end end return l end)()
    return n
end)

CreateThread(function()
    GlobalState.gsCctvBlind = {}
    local n = 0
    while true do
        Wait(Config.Sample * 1000)
        CCTV.sample()
        n = n + 1
        if n % 15 == 0 then
            CCTV.clean()
            local l = {}
            for k, v in pairs(CCTV.blind) do if v > now() then l[#l + 1] = k else CCTV.blind[k] = nil end end
            GlobalState.gsCctvBlind = l
        end
    end
end)
