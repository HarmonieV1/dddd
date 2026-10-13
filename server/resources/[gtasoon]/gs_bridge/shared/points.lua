-- gs_bridge/shared/points.lua : points déplaçables en jeu par le staff, pour TOUTES nos ressources.
-- À inclure après la config : shared_scripts { ..., 'shared/config.lua', '@gs_bridge/shared/points.lua' }.
-- 1. Remplace dans `Config` chaque position (vector3 / vector4) déplacée par le staff (GlobalState.gsPoints, sauvegardé
--    par gs_bridge) ; 2. côté client, déclare ces positions à gs_bridge pour le menu staff « Déplacer un point ».
-- Clé d'un point = ressource + chemin dans Config (ex : gs_harvest:Config.Activities.fishing.spots.3) : stable tant que
-- la config garde sa forme. Après un déplacement, la ressource est relancée (le nouveau point s'applique à tous).
--
-- V12.37 · `GsPoints` : fonctions pures partagées autour des PNJ et objets posés par le staff (F11 → Monde et lieux →
-- « PNJ et objets »), publiés par gs_bridge dans GlobalState.gsStaffPeds : { id, kind ('ped' | 'prop'), target, model, scenario,
-- x, y, z, heading, by, at }. `target` relie l'entrée à un point : 'job:police:duty' (accueil), 'job:police:boss' (direction),
-- 'job:police:garage' (+ index si plusieurs points : 'job:police:duty2'), 'gang:ballas' (planque), ou 'libre' (décor sans
-- interaction). Un PNJ relié devient LE PNJ du point : il remplace celui de la config (gs_jobs/shared/jobs.lua `peds`) ou s'ajoute
-- s'il n'y en avait pas, et garde l'interaction du point (options ox_target fournies par la ressource).
GsPoints = GsPoints or {}

--- Cible d'un point de métier : 'job:<métier>:<rôle>' pour le premier point, suffixe numérique au-delà ('job:police:duty2').
function GsPoints.pedTarget(job, kind, idx)
    return ('job:%s:%s%s'):format(tostring(job), tostring(kind), (tonumber(idx) or 1) > 1 and tostring(idx) or '')
end

--- Entrée staff de type PNJ reliée à `target`, dans `list` (GlobalState.gsStaffPeds par défaut) ; nil sinon.
function GsPoints.staffPed(target, list)
    list = list or GlobalState.gsStaffPeds
    if type(target) ~= 'string' or type(list) ~= 'table' then return nil end
    for _, e in ipairs(list) do
        if type(e) == 'table' and e.kind == 'ped' and e.target == target then return e end
    end
    return nil
end

--- PNJ à afficher sur un point : celui du staff s'il en a relié un (position absolue `at`, `staffId` pour que gs_markers ne le
--- crée pas une seconde fois en PNJ d'ambiance), sinon `cfg` (PNJ de la config, éventuellement nil).
function GsPoints.pointPed(cfg, target, list)
    local e = GsPoints.staffPed(target, list)
    if not e then return cfg end
    return { model = e.model, scenario = e.scenario, staffId = e.id,
        at = { x = e.x + 0.0, y = e.y + 0.0, z = e.z + 0.0, heading = (e.heading or 0.0) + 0.0 } }
end

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

    -- V12.5 · Côté serveur : on dit à gs_bridge quelles positions déplacées ont VRAIMENT été appliquées au chargement.
    -- Sert à confirmer au staff, quelques secondes après « Placer ce point ici », que le déplacement a pris.
    if IsDuplicityVersion() then
        local applied = {}
        for _, f in ipairs(found) do if f.moved then applied[f.key] = { x = f.coords.x, y = f.coords.y, z = f.coords.z } end end
        TriggerEvent('gs_bridge:server:pointsLoaded', res, applied)
    end

    if not IsDuplicityVersion() and #found > 0 then
        CreateThread(function()
            Wait(500)
            TriggerEvent('gs_bridge:client:registerPoints', res, found)
        end)
    end
end
