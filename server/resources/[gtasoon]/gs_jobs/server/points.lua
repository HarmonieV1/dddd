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
    local have = Bridge:GetItemCount(src, item)
    local need = a.max - have
    if need <= 0 then return false, 'Tu es déjà équipé.' end
    if not Bridge:AddItem(src, item, need) then return false, 'Inventaire plein.' end
    Armory.note(src, item, need, have) -- V12.37 : prêté, repris à la fin du service
    DB.audit('armory', job.name, GSJ.cid(src), nil, need, item)
    return true, ('+%d %s'):format(need, item)
end)

-- V12.37 · Équipement de service PRÊTÉ, pas donné ----------------------------------------------------------------------
-- Retour du fondateur (13/10) : « quand on quitte le LSPD on peut garder toutes nos armes à patch ». Ce que l'armurerie
-- fournit (quantités) est noté par joueur et repris à la fin du service (point, F6, téléphone, /service), au changement de
-- métier, au licenciement / à la démission du métier actif et à la déconnexion (GSJ.endService → gs_jobs:internal:endService).
-- Règles : le joueur garde tout ce qu'il possédait avant (on note la quantité qu'il avait à la 1re fourniture et on ne descend
-- jamais en dessous) ; ce qui a été consommé (munitions tirées, gilet porté, pansements) n'est pas réclamé. Mémoire serveur +
-- KVP par citizenid : déconnecté avant que le serveur ait pu reprendre (Qbox décharge le joueur avant nous), c'est repris à la
-- connexion suivante, une fois l'inventaire chargé (Config.Armory.restoreDelay).
Armory = { issued = {} } -- [src] = { [item] = { given = quantité fournie, base = quantité possédée avant la 1re fourniture } }

local function armoryKvp(cid) return 'gs_jobs:armory:' .. cid end

--- Sérialisation volontairement simple ("item=fourni/avant,…", triée) : lisible dans le KVP, sans json.
function Armory.encode(t)
    local parts = {}
    for item, e in pairs(t or {}) do
        if e.given > 0 then parts[#parts + 1] = ('%s=%d/%d'):format(item, e.given, e.base or 0) end
    end
    table.sort(parts)
    return table.concat(parts, ',')
end

function Armory.decode(s)
    local t = {}
    if type(s) ~= 'string' then return t end
    for item, given, base in s:gmatch('([^=,/]+)=(%d+)/(%d+)') do t[item] = { given = tonumber(given), base = tonumber(base) } end
    return t
end

local function armoryPersist(src, cid)
    cid = cid or Bridge:GetIdentifier(src)
    if not cid then return end
    local s = Armory.encode(Armory.issued[src])
    if s == '' then DeleteResourceKvp(armoryKvp(cid)) else SetResourceKvp(armoryKvp(cid), s) end
end

--- Note une fourniture : `n` objets donnés, le joueur en avait `before`.
function Armory.note(src, item, n, before)
    local t = Armory.issued[src] or {}
    local e = t[item]
    if e then e.given = e.given + n else t[item] = { given = n, base = before or 0 } end
    Armory.issued[src] = t
    armoryPersist(src)
end

--- Reprend l'équipement fourni encore sur le joueur : au plus la quantité fournie, sans descendre sous ce qu'il avait avant.
--- Retourne le nombre d'objets repris. Joueur déjà déchargé (déconnexion) : la mémoire part, le KVP reste → reconnexion.
function Armory.takeBack(src)
    local t = Armory.issued[src]
    Armory.issued[src] = nil
    if not t or next(t) == nil then return 0 end
    if not Bridge:IsLoaded(src) then return 0 end
    local cid = Bridge:GetIdentifier(src)
    local taken, left, details = 0, {}, {}
    for item, e in pairs(t) do
        local take = math.min(e.given, Bridge:GetItemCount(src, item) - (e.base or 0))
        if take > 0 then
            if Bridge:RemoveItem(src, item, take) then
                taken = taken + take
                details[#details + 1] = ('%s x%d'):format(item, take)
            else
                left[item] = e -- retrait refusé par l'inventaire : on réessaiera (prochaine fin de service / connexion)
            end
        end
    end
    if next(left) ~= nil then Armory.issued[src] = left end
    armoryPersist(src, cid)
    if taken > 0 then
        local job = Bridge:GetJob(src)
        DB.audit('armory_return', job and job.name or nil, cid, nil, taken, table.concat(details, ', '):sub(1, 250))
        GSJ.notify(src, L('armory_returned'), 'inform')
    end
    return taken
end

--- Connexion / redémarrage de gs_jobs : le joueur est remis hors service (GSJ.load) ; l'équipement noté en KVP est repris une
--- fois l'inventaire chargé. S'il a repris son service entre-temps, tout sera rendu à sa prochaine fin de service.
function Armory.restore(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local t = Armory.decode(GetResourceKvpString(armoryKvp(cid)))
    if next(t) == nil then return end
    Armory.issued[src] = t
    SetTimeout(Config.Armory.restoreDelay, function()
        local j = Bridge:GetJob(src)
        if Bridge:GetIdentifier(src) == cid and not (j and j.onduty) then Armory.takeBack(src) end
    end)
end

AddEventHandler('gs_jobs:internal:endService', function(src) Armory.takeBack(src) end)
AddEventHandler('gs_bridge:server:playerLoaded', function(src) Armory.restore(src) end)
