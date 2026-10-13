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

-- V12.5 · Ce que chaque ressource a réellement appliqué à son dernier chargement (événement LOCAL serveur : AddEventHandler,
-- jamais RegisterNetEvent, un client ne peut pas l'envoyer).
local loaded = {} -- [ressource] = { at = horodatage, applied = { [clé] = { x, y, z } } }
AddEventHandler('gs_bridge:server:pointsLoaded', function(res, applied)
    if type(res) == 'string' and type(applied) == 'table' then loaded[res] = { at = GetGameTimer(), applied = applied } end
end)

--- Le point `key` est-il chargé à la position `c` (à 0,5 m près) par une ressource (re)démarrée après `since` ? [API]
--- Retourne 'ok' | 'pas_relance' (la ressource n'a pas redémarré) | 'ancienne_position' (redémarrée sans le déplacement).
local function CheckPoint(key, c, since)
    local res = parseKey(key)
    if not res then return 'pas_relance' end
    local l = loaded[res]
    if not l or l.at < since then return 'pas_relance' end
    local a = l.applied[key]
    if not a or #(vector3(a.x, a.y, a.z) - vector3(c.x, c.y, c.z)) > 0.5 then return 'ancienne_position' end
    return 'ok'
end

-- V12.37 · Placement libre (menu staff F11) : le client envoie la pose choisie à l'aperçu, le serveur la vérifie ici.
--- Pose `{ x, y, z, w | heading }` propre (nombres finis, bornés, cap ramené dans [0, 360[) et à ≤ `maxDist` m (60 par défaut)
--- du staff `from` (vector3 ou nil pour ne pas vérifier la distance). Retourne la pose ou nil, message. [API]
local function CleanPose(pose, from, maxDist)
    if type(pose) ~= 'table' then return nil, 'Position invalide.' end
    local out = {}
    for i, k in ipairs({ 'x', 'y', 'z' }) do
        local v = tonumber(pose[k])
        if not v or v ~= v or math.abs(v) >= 100000.0 then return nil, 'Position invalide.' end
        out[i] = v + 0.0
    end
    local w = tonumber(pose.w or pose.heading or 0.0)
    if not w or w ~= w or math.abs(w) >= 100000.0 then return nil, 'Orientation invalide.' end
    maxDist = maxDist or 60.0
    if from and #(vector3(out[1], out[2], out[3]) - vector3(from.x, from.y, from.z)) > maxDist then
        return nil, ('Trop loin de toi (%d m max).'):format(maxDist)
    end
    return { x = out[1], y = out[2], z = out[3], w = w % 360.0 }
end

-- V12.37 · PNJ et objets posés par le staff (F11 → Monde et lieux → « PNJ et objets »), reliés à un métier, un gang ou libres.
-- Table SQL gs_staff_peds chargée au démarrage, publiée dans GlobalState.gsStaffPeds (voir shared/points.lua, `GsPoints`) ;
-- créés localement à proximité par gs_markers (PNJ d'ambiance, objets) ou par le point de métier / gang qui les a repris.
StaffPedsStore = StaffPedsStore or {
    init = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_staff_peds` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(8) NOT NULL,
            `target` VARCHAR(48) NOT NULL DEFAULT 'libre',
            `model` VARCHAR(64) NOT NULL,
            `scenario` VARCHAR(48) NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
            `by` VARCHAR(100) NOT NULL DEFAULT '',
            `at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`), KEY `target` (`target`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    all = function() return MySQL.query.await('SELECT id, kind, target, model, scenario, x, y, z, heading, `by`, `at` FROM gs_staff_peds ORDER BY id') or {} end,
    insert = function(e)
        return MySQL.insert.await('INSERT INTO gs_staff_peds (kind, target, model, scenario, x, y, z, heading, `by`, `at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { e.kind, e.target, e.model, e.scenario, e.x, e.y, e.z, e.heading, e.by, e.at })
    end,
    delete = function(id) MySQL.update('DELETE FROM gs_staff_peds WHERE id = ?', { id }) end,
}

StaffPeds = { list = {}, max = 200 } -- list : entrées publiées, triées par id

local function publishStaffPeds() GlobalState.gsStaffPeds = StaffPeds.list end

function StaffPeds.load()
    StaffPedsStore.init()
    StaffPeds.list = {}
    for _, r in ipairs(StaffPedsStore.all()) do
        StaffPeds.list[#StaffPeds.list + 1] = { id = r.id, kind = r.kind, target = r.target, model = r.model, scenario = r.scenario,
            x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, heading = (r.heading or 0.0) + 0.0, by = r.by, at = r.at }
    end
    publishStaffPeds()
end

--- Ajoute un PNJ (`kind` = 'ped') ou un objet ('prop') posé par le staff : `e` = { kind, target, model, scenario?, x, y, z,
--- heading, by }. Validation de forme ici ; le sens de `target` (métier / gang existant) et les droits sont vérifiés par gs_admin.
--- Un seul PNJ staff par cible métier / gang. Retourne true, id ou false, message. [API]
local function AddStaffPed(e)
    if type(e) ~= 'table' or (e.kind ~= 'ped' and e.kind ~= 'prop') then return false, 'Type invalide.' end
    if type(e.model) ~= 'string' or #e.model > 64 or not e.model:match('^[%w_]+$') then return false, 'Modèle invalide.' end
    local target = e.target == nil and 'libre' or e.target
    if type(target) ~= 'string' or #target > 48 or not target:match('^[%w_:]+$') then return false, 'Cible invalide.' end
    local scenario = e.scenario
    if scenario == '' then scenario = nil end
    if scenario ~= nil and (type(scenario) ~= 'string' or #scenario > 48 or not scenario:match('^[%u_]+$')) then return false, 'Scénario invalide.' end
    local pose, err = CleanPose({ x = e.x, y = e.y, z = e.z, w = e.heading }, nil)
    if not pose then return false, err end
    if #StaffPeds.list >= StaffPeds.max then return false, ('Limite atteinte (%d PNJ et objets) : retire-en d\'abord.'):format(StaffPeds.max) end
    if e.kind == 'ped' and target ~= 'libre' then
        for _, o in ipairs(StaffPeds.list) do
            if o.kind == 'ped' and o.target == target then return false, 'Ce point a déjà un PNJ posé par le staff : retire-le d\'abord.' end
        end
    end
    local entry = { kind = e.kind, target = target, model = e.model, scenario = scenario, x = pose.x, y = pose.y, z = pose.z, heading = pose.w,
        by = type(e.by) == 'string' and e.by:sub(1, 100) or '', at = os.time() }
    local id = StaffPedsStore.insert(entry)
    if not id then return false, 'Erreur BDD.' end
    entry.id = id
    StaffPeds.list[#StaffPeds.list + 1] = entry
    publishStaffPeds()
    return true, id
end

--- Retire une entrée par id. Retourne true, entrée ou false, message. [API]
local function RemoveStaffPed(id)
    id = tonumber(id)
    if not id then return false, 'Entrée inconnue.' end
    for i, o in ipairs(StaffPeds.list) do
        if o.id == id then
            table.remove(StaffPeds.list, i)
            StaffPedsStore.delete(id)
            publishStaffPeds()
            return true, o
        end
    end
    return false, 'Entrée inconnue (déjà retirée ?).'
end

--- Liste des PNJ et objets posés par le staff (copie, triée par id). [API]
local function ListStaffPeds()
    local out = {}
    for i, o in ipairs(StaffPeds.list) do out[i] = o end
    return out
end

CreateThread(function() StaffPeds.load() end)

exports('CleanPose', CleanPose)
exports('AddStaffPed', AddStaffPed)
exports('RemoveStaffPed', RemoveStaffPed)
exports('ListStaffPeds', ListStaffPeds)
exports('CheckPoint', CheckPoint)
exports('SetPoint', SetPoint)
exports('ResetPoint', ResetPoint)
exports('DisablePoint', DisablePoint)
exports('EnablePoint', EnablePoint)
