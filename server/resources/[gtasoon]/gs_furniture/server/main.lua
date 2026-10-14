-- gs_furniture (serveur) · V12.58 Réglages de mobilier par modèle, posés en jeu par le staff (/meubleregle) et gardés
-- (KVP) : un banc où l'on s'asseyait derrière se corrige une fois pour toutes, pour tout le monde, sans toucher au code.
Furniture = { adj = {} } -- [modèle] = { z, y, h }

local KEY = 'gs_furniture:adj'
local function clamp(v, lo, hi) v = tonumber(v) if not v or v ~= v then return nil end return math.max(lo, math.min(hi, v)) end
local function round(v, n) local m = 10 ^ n return math.floor(v * m + 0.5) / m end

local function publish() GlobalState.gsFurniture = Furniture.adj end

local function save()
    SetResourceKvp(KEY, json.encode(Furniture.adj))
    publish()
end

--- Enregistre (ou efface si `v` est nil) le réglage d'un modèle connu. true, message.
function Furniture.set(model, v)
    if type(model) ~= 'string' or not Config.Furniture.models[model] then return false, 'Meuble inconnu.' end
    if v == nil then
        Furniture.adj[model] = nil
        save()
        return true, ('Réglage d\'origine remis pour %s.'):format(model)
    end
    if type(v) ~= 'table' then return false, 'Réglage invalide.' end
    local z, y, h = clamp(v.z, -1.0, 3.0), clamp(v.y, -2.0, 2.0), clamp(v.h, -720.0, 720.0)
    if not (z and y and h) then return false, 'Réglage invalide.' end
    Furniture.adj[model] = { z = round(z, 2), y = round(y, 2), h = round(h % 360.0, 1) }
    save()
    return true, ('Enregistré pour tous les %s (hauteur %.2f, avant/arrière %.2f, rotation %.0f°).'):format(model, z, y, h % 360.0)
end

lib.callback.register('gs_furniture:adjust', function(src, model, v)
    if not exports.gs_security:RateLimit(src, 'gs_furniture:adjust', 4, 10000) then return false, 'Doucement.' end
    if not IsPlayerAceAllowed(src, 'gs.admin.admin') then return false, 'Réservé au staff.' end
    local ok, msg = Furniture.set(model, v)
    if ok then print(('[gs_furniture] %s : %s'):format(GetPlayerName(src) or src, msg)) end
    return ok, msg
end)

CreateThread(function()
    local raw = GetResourceKvpString(KEY)
    local ok, t = pcall(json.decode, raw or '{}')
    Furniture.adj = {}
    if ok and type(t) == 'table' then
        for model, v in pairs(t) do if Config.Furniture.models[model] and type(v) == 'table' then Furniture.adj[model] = v end end
    end
    publish()
end)
