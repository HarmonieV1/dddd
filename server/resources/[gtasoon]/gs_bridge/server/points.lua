-- gs_bridge (serveur) : positions déplacées par le staff (voir shared/points.lua). Sauvegarde KVP (synchrone : prêt avant
-- le démarrage des autres ressources, qui lisent GlobalState.gsPoints en chargeant leur config).
local KVP = 'gs_points'

local function loadPoints()
    local raw = GetResourceKvpString(KVP)
    local ok, data = pcall(json.decode, raw or '{}')
    return ok and type(data) == 'table' and data or {}
end

local points = loadPoints()
GlobalState.gsPoints = points

-- V11.6 · Points retirés (désactivés, réversible) : la ressource reçoit une position hors carte, le menu staff garde
-- la vraie pour pouvoir le réactiver.
local KVP_OFF = 'gs_points_off'
local off = (function()
    local ok, data = pcall(json.decode, GetResourceKvpString(KVP_OFF) or '{}')
    return ok and type(data) == 'table' and data or {}
end)()
GlobalState.gsPointsOff = off

local function save()
    SetResourceKvp(KVP, json.encode(points))
    GlobalState.gsPoints = points
    SetResourceKvp(KVP_OFF, json.encode(off))
    GlobalState.gsPointsOff = off
end

--- Clé valide : « ressource:Config.chemin » d'une ressource gs_ démarrée (jamais gs_bridge lui-même).
local function parseKey(key)
    if type(key) ~= 'string' or #key > 200 then return nil end
    local res, path = key:match('^(gs_[%w_]+):(Config[%w_%.]+)$')
    if not res or res == 'gs_bridge' or GetResourceState(res) ~= 'started' then return nil end
    return res, path
end

--- Relance une ressource ; celles qui en dépendent (arrêtées avec elle par FiveM) sont relancées aussi.
local function restart(res)
    local before = {}
    for i = 0, GetNumResources() - 1 do
        local r = GetResourceByFindIndex(i)
        if r and GetResourceState(r) == 'started' then before[#before + 1] = r end
    end
    SetTimeout(300, function()
        StopResource(res)
        SetTimeout(500, function()
            StartResource(res)
            SetTimeout(500, function()
                for _, r in ipairs(before) do if GetResourceState(r) == 'stopped' then StartResource(r) end end
            end)
        end)
    end)
end

--- Déplace un point (c : vector3/vector4) puis relance sa ressource. Retourne true, ressource ou false, message. [API]
local function SetPoint(key, c)
    local res = parseKey(key)
    if not res then return false, 'Point inconnu.' end
    if type(c) ~= 'vector3' and type(c) ~= 'vector4' and type(c) ~= 'table' then return false, 'Position invalide.' end
    points[key] = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = c.w and (c.w + 0.0) or nil }
    save()
    restart(res)
    return true, res
end

--- Remet la position d'origine (celle de la config). [API]
local function ResetPoint(key)
    local res = parseKey(key)
    if not res or not points[key] then return false, 'Ce point n\'a pas été déplacé.' end
    points[key] = nil
    save()
    restart(res)
    return true, res
end

--- V11.6 · Retire un point du jeu (position hors carte) ; réversible avec EnablePoint. [API]
local function DisablePoint(key)
    local res = parseKey(key)
    if not res then return false, 'Point inconnu.' end
    if off[key] then return false, 'Ce point est déjà retiré.' end
    off[key] = true
    save()
    restart(res)
    return true, res
end

local function EnablePoint(key)
    local res = parseKey(key)
    if not res or not off[key] then return false, 'Ce point n\'est pas retiré.' end
    off[key] = nil
    save()
    restart(res)
    return true, res
end

exports('SetPoint', SetPoint)
exports('ResetPoint', ResetPoint)
exports('DisablePoint', DisablePoint)
exports('EnablePoint', EnablePoint)
