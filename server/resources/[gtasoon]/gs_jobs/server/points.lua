-- Points de métier déplaçables en jeu (menu staff F11) + armurerie de service.
-- Les points placés par le staff sont en BDD et remplacent ceux de jobs.lua (bâtiments fermés, futurs MLO).
-- Les clients reçoivent les points modifiés via GlobalState.gsJobPoints.

PointsStore = PointsStore or {
    init = function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `gs_job_points` (
            `job` VARCHAR(50) NOT NULL, `kind` VARCHAR(20) NOT NULL, `idx` INT UNSIGNED NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `w` FLOAT NOT NULL DEFAULT 0,
            PRIMARY KEY (`job`, `kind`, `idx`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end,
    all = function() return MySQL.query.await('SELECT job, kind, idx, x, y, z, w FROM gs_job_points') or {} end,
    save = function(job, kind, idx, c)
        MySQL.prepare('REPLACE INTO gs_job_points (job, kind, idx, x, y, z, w) VALUES (?, ?, ?, ?, ?, ?, ?)', { job, kind, idx, c.x, c.y, c.z, c.w or 0.0 })
    end,
}

GSJ.pointKinds = { duty = 'Prise de service', boss = 'Direction', stash = 'Coffre', armory = 'Équipement de service', cloakroom = 'Vestiaire', garage = 'Garage', garage_spawn = 'Sortie du garage' }

--- Applique un point sur la définition du job (mêmes règles côté client). Retourne true si le point existe.
function GSJ.applyPoint(job, kind, idx, c)
    local p = Jobs[job] and Jobs[job].points
    if not p then return false end
    local list = p[kind == 'garage_spawn' and 'garage' or kind]
    if type(list) ~= 'table' or not list[idx] then return false end
    if kind == 'stash' or kind == 'garage' then list[idx].coords = vec3(c.x, c.y, c.z)
    elseif kind == 'garage_spawn' then list[idx].spawn = vec4(c.x, c.y, c.z, c.w or 0.0)
    else list[idx] = vec3(c.x, c.y, c.z) end
    return true
end

local overrides = {}

local function publish() GlobalState.gsJobPoints = overrides end

function GSJ.loadPoints()
    PointsStore.init()
    for _, r in ipairs(PointsStore.all()) do
        if GSJ.applyPoint(r.job, r.kind, r.idx, r) then
            overrides[#overrides + 1] = { job = r.job, kind = r.kind, idx = r.idx, x = r.x, y = r.y, z = r.z, w = r.w }
        end
    end
    publish()
end

--- Staff : déplace un point existant à `c` (vec4). Retourne ok, err.
function GSJ.setPoint(job, kind, idx, c)
    idx = tonumber(idx)
    if not Jobs[job] then return false, 'Métier inconnu.' end
    if not GSJ.pointKinds[kind] or not idx then return false, 'Type de point inconnu.' end
    if not GSJ.applyPoint(job, kind, idx, c) then return false, 'Ce point n\'existe pas pour ce métier.' end
    PointsStore.save(job, kind, idx, c)
    for i = #overrides, 1, -1 do
        local o = overrides[i]
        if o.job == job and o.kind == kind and o.idx == idx then table.remove(overrides, i) end
    end
    overrides[#overrides + 1] = { job = job, kind = kind, idx = idx, x = c.x, y = c.y, z = c.z, w = c.w or 0.0 }
    publish()
    if kind == 'stash' then GSJ.registerStashes() end
    return true
end

--- Liste des points d'un job (pour le menu staff).
function GSJ.listPoints(job)
    local p, list = Jobs[job].points, {}
    for _, kind in ipairs({ 'duty', 'boss', 'armory', 'cloakroom', 'stash', 'garage' }) do
        for i, e in ipairs(p[kind] or {}) do
            local label = (kind == 'armory' and Jobs[job].armoryLabel or GSJ.pointKinds[kind]) .. (e.label and (' · ' .. e.label) or (#p[kind] > 1 and (' ' .. i) or ''))
            list[#list + 1] = { kind = kind, idx = i, label = label }
            if kind == 'garage' then list[#list + 1] = { kind = 'garage_spawn', idx = i, label = GSJ.pointKinds.garage_spawn .. (#p.garage > 1 and (' ' .. i) or '') } end
        end
    end
    return list
end

-- Armurerie : équipement de service, complété jusqu'au maximum, en service uniquement -----------------------

GSJ.armoryOk = {} -- [job] = { [item] = true } items présents dans ox_inventory

function GSJ.checkArmories()
    for name, def in pairs(Jobs) do
        GSJ.armoryOk[name] = {}
        for _, a in ipairs(def.armory or {}) do
            if Bridge:ItemExists(a.item) then GSJ.armoryOk[name][a.item] = true
            else print(('^3[gs_jobs] armurerie %s : item "%s" absent d\'ox_inventory (ignoré)^7'):format(name, a.item)) end
        end
    end
end

local function armoryEntry(def, item)
    for _, a in ipairs(def.armory or {}) do if a.item == item then return a end end
end

lib.callback.register('gs_jobs:armory', function(src, item)
    if not GSJ.guard(src, 'armory', 8, 10000) then return false, 'Doucement.' end
    local job, def = GSJ.activeJob(src)
    if not job or not def or not def.armory then return false, 'Pas d\'équipement de service pour ton métier.' end
    if not job.onduty then return false, 'Prends d\'abord ton service.' end
    if not GSJ.nearAny(src, def.points.armory, 2.0) then return false, 'Trop loin du point d\'équipement.' end
    local a = armoryEntry(def, item)
    if not a or not (GSJ.armoryOk[job.name] or {})[item] then return false, 'Équipement indisponible.' end
    if job.grade < (a.minGrade or 0) then return false, 'Grade insuffisant.' end
    local need = a.max - Bridge:GetItemCount(src, item)
    if need <= 0 then return false, 'Tu es déjà équipé.' end
    if not Bridge:AddItem(src, item, need) then return false, 'Inventaire plein.' end
    DB.audit('armory', job.name, GSJ.cid(src), nil, need, item)
    return true, ('+%d %s'):format(need, item)
end)
