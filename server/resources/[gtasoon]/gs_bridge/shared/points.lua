-- gs_bridge/shared/points.lua : points déplaçables en jeu par le staff, pour TOUTES nos ressources.
-- À inclure après la config : shared_scripts { ..., 'shared/config.lua', '@gs_bridge/shared/points.lua' }.
-- 1. Remplace dans `Config` chaque position (vector3 / vector4) déplacée par le staff (GlobalState.gsPoints, sauvegardé
--    par gs_bridge) ; 2. côté client, déclare ces positions à gs_bridge pour le menu staff « Déplacer un point ».
-- Clé d'un point = ressource + chemin dans Config (ex : gs_harvest:Config.Activities.fishing.spots.3) : stable tant que
-- la config garde sa forme. Après un déplacement, la ressource est relancée (le nouveau point s'applique à tous).
do
    local res = GetCurrentResourceName()
    local overrides = GlobalState.gsPoints or {}
    local off = GlobalState.gsPointsOff or {}   -- V11.6 : points retirés par le staff → position hors carte
    local FAR = vector3(-9000.0, -9000.0, -500.0)
    local SKIP = { size = true, offset = true, rotation = true, rot = true, scale = true, color = true, colour = true, dims = true }
    local found = {}

    local function isPos(v)
        local t = type(v)
        if t ~= 'vector3' and t ~= 'vector4' then return false end
        return math.abs(v.x) > 50.0 or math.abs(v.y) > 50.0 -- les petites valeurs sont des tailles / décalages
    end

    local function walk(t, path, label, depth, seen)
        if depth > 7 or seen[t] then return end
        seen[t] = true
        local here = (type(t.label) == 'string' and t.label) or (type(t.name) == 'string' and t.name) or label
        for k, v in pairs(t) do
            if not SKIP[k] then
                local p = path .. '.' .. tostring(k)
                if isPos(v) then
                    local key = res .. ':' .. p
                    local o = overrides[key]
                    if o then
                        if type(v) == 'vector4' then t[k] = vector4(o.x, o.y, o.z, o.w or v.w) else t[k] = vector3(o.x, o.y, o.z) end
                    end
                    local what = type(k) == 'number' and ('point ' .. k) or tostring(k)
                    local real = vector3(t[k].x, t[k].y, t[k].z) -- gardée pour le menu staff (réactiver un point retiré)
                    if off[key] then
                        if type(v) == 'vector4' then t[k] = vector4(FAR.x, FAR.y, FAR.z, t[k].w) else t[k] = FAR end
                    end
                    found[#found + 1] = { key = key, label = ('%s · %s'):format(here or path:match('[^.]+$') or res, what),
                        coords = real, moved = o ~= nil, off = off[key] == true }
                elseif type(v) == 'table' then
                    walk(v, p, here, depth + 1, seen)
                end
            end
        end
    end

    if type(Config) == 'table' then walk(Config, 'Config', nil, 0, {}) end

    if not IsDuplicityVersion() and #found > 0 then
        CreateThread(function()
            Wait(500)
            TriggerEvent('gs_bridge:client:registerPoints', res, found)
        end)
    end
end
