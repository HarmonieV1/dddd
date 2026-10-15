-- gs_cimetiere (serveur) · V12.60. Tombes gardées en KVP (survivent aux redémarrages), publiées dans GlobalState.gsGraves.
-- Seul le staff (niveau Config.StaffLevel) pose ou retire une tombe ; tout le monde dépose des fleurs (payées, limitées).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Cimetiere = { graves = {}, nextId = 0, flowered = {} } -- flowered[cid .. ':' .. id] = os.time() du dernier dépôt

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end

local function level(src)
    if not started('gs_admin') then return 0 end
    local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and tonumber(l) or 0
end

local function save()
    local list = {}
    for _, g in pairs(Cimetiere.graves) do list[#list + 1] = g end
    table.sort(list, function(a, b) return a.id < b.id end)
    SetResourceKvp('graves', json.encode(list))
end

local function publish()
    local out = {}
    for _, g in pairs(Cimetiere.graves) do
        out[#out + 1] = { id = g.id, name = g.name, epitaph = g.epitaph, died = g.died, x = g.x, y = g.y, z = g.z, h = g.h,
            flowers = (g.flowersAt or 0) + Config.FlowerHours * 3600 > now() }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    GlobalState.gsGraves = out
end

--- Prochain emplacement libre du carré (grille depuis Config.Origin, orientée comme lui).
function Cimetiere.slot()
    local used = {}
    for _, g in pairs(Cimetiere.graves) do if g.slot then used[g.slot] = true end end
    local G, o = Config.Grid, Config.Origin
    for i = 1, G.max do
        if not used[i] then
            local row, col = (i - 1) // G.perRow, (i - 1) % G.perRow
            local h = math.rad(o.w)
            local rx, ry = math.cos(h), math.sin(h)     -- le long de la rangée
            local fx, fy = -math.sin(h), math.cos(h)    -- d'une rangée à l'autre
            return i, vec3(o.x + rx * col * G.gap - fx * row * G.rowGap, o.y + ry * col * G.gap - fy * row * G.rowGap, o.z), o.w
        end
    end
    return nil
end

--- Pose une tombe. at = position (sinon le prochain emplacement du carré). Renvoie l'id ou nil, message.
function Cimetiere.bury(name, epitaph, at, heading, by)
    name = Security:Sanitize(name, 120)
    epitaph = Security:Sanitize(epitaph or '', 300) or ''
    if not name or (utf8.len(name) or 0) < 2 then return nil, 'Nom trop court.' end
    local function cut(s, n) if utf8.len(s) and utf8.len(s) > n then return s:sub(1, utf8.offset(s, n + 1) - 1) end return s end
    name, epitaph = cut(name, Config.Max.name), cut(epitaph, Config.Max.epitaph)
    local slot
    if not at then
        slot, at, heading = Cimetiere.slot()
        if not slot then return nil, 'Le carré est plein : pose la tombe à la main (« Poser ici »).' end
    end
    Cimetiere.nextId = Cimetiere.nextId + 1
    local g = { id = Cimetiere.nextId, name = name, epitaph = epitaph, died = os.date('%d/%m/%Y'), x = at.x + 0.0, y = at.y + 0.0,
        z = at.z + 0.0, h = (heading or 0.0) + 0.0, slot = slot, by = by or '', flowersAt = now() } -- fleurs du jour de l'enterrement
    Cimetiere.graves[g.id] = g
    save() publish()
    -- Avis de décès : Weazel tout de suite (fil Vibe), Gazette du dimanche (gs_city), lieu de mémoire (gs_memoire)
    -- V12.62 (relecture) : une clé par tombe (avant : 'deces' pour toutes → le 2e avis rapproché était refusé sans le dire)
    g.published = false
    if started('gs_social') then
        local ok, sent = pcall(function() return exports.gs_social:Newsroom('deces:' .. g.id, ('AVIS DE DÉCÈS · %s nous a quittés. %s Repose au cimetière de Hill Valley.'):format(
            name, epitaph ~= '' and ('« ' .. epitaph .. ' »') or '')) end)
        g.published = ok and sent == true
    end
    TriggerEvent('gs_cimetiere:server:buried', name, epitaph)
    return g.id
end

function Cimetiere.remove(id)
    id = tonumber(id)
    if not id or not Cimetiere.graves[id] then return false end
    Cimetiere.graves[id] = nil
    save() publish()
    return true
end

--- Fleurs : liquide payé, une fois par 10 min et par tombe pour un même joueur, à côté de la tombe.
function Cimetiere.flowers(src, id)
    local g = Cimetiere.graves[tonumber(id) or 0]
    if not g then return false, 'Tombe introuvable.' end
    if not Security:InRange(src, vec3(g.x, g.y, g.z), 4.0) then return false, 'Approche-toi de la tombe.' end
    local cid = Bridge:GetIdentifier(src)
    local key = (cid or src) .. ':' .. g.id
    if Cimetiere.flowered[key] and Cimetiere.flowered[key] + Config.FlowerCooldown > now() then return false, 'Tu viens déjà de déposer des fleurs.' end
    if not Bridge:RemoveMoney(src, 'cash', Config.FlowerPrice, 'fleurs (cimetière)') then
        return false, ('Il faut %d $ en liquide pour le fleuriste.'):format(Config.FlowerPrice)
    end
    for k, t in pairs(Cimetiere.flowered) do if t + Config.FlowerCooldown <= now() then Cimetiere.flowered[k] = nil end end -- V12.62 : ménage
    Cimetiere.flowered[key] = now()
    g.flowersAt = now()
    save() publish()
    return true, ('Tu déposes des fleurs pour %s.'):format(g.name)
end

-- Rappels ---------------------------------------------------------------------------------------------------------------
lib.callback.register('gs_cimetiere:flowers', function(src, id)
    if not Security:RateLimit(src, 'gs_cimetiere:flowers', 3, 10000) then return false, 'Doucement.' end
    return Cimetiere.flowers(src, id)
end)

--- Staff : 'list' | 'bury' { name, epitaph, here } | 'remove' { id } | 'player' { target, epitaph } (mort RP d'un joueur)
lib.callback.register('gs_cimetiere:staff', function(src, action, data)
    if not Security:RateLimit(src, 'gs_cimetiere:staff', 10, 10000) then return false, 'Doucement.' end
    if level(src) < Config.StaffLevel then return false, 'Réservé au staff (admin).' end
    data = type(data) == 'table' and data or {}
    local who = 'staff:' .. (Bridge:GetIdentifier(src) or tostring(src))
    if action == 'list' then return true, GlobalState.gsGraves or {} end
    if action == 'remove' then
        local ok = Cimetiere.remove(data.id)
        if ok then Security:LogStaff(('[Cimetière] %s a retiré la tombe n°%s'):format(GetPlayerName(src) or src, tostring(data.id)), 'staff') end
        return ok, ok and 'Tombe retirée.' or 'Tombe introuvable.'
    end
    local name, at, heading = data.name, nil, nil
    if action == 'player' then -- mort RP d'un joueur en ligne : son nom de personnage (jamais son nom de compte)
        local t = tonumber(data.target)
        name = t and Bridge:GetName(t)
        if not name then return false, 'Joueur introuvable.' end
    elseif action ~= 'bury' then return false, 'Action inconnue.' end
    if data.here then
        local ped = GetPlayerPed(src)
        if ped == 0 then return false, 'Position introuvable.' end
        at, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    end
    local id, err = Cimetiere.bury(name, data.epitaph, at, heading, who)
    if not id then return false, err end
    Security:LogStaff(('[Cimetière] %s a posé la tombe de %s (n°%d)'):format(GetPlayerName(src) or src, Cimetiere.graves[id].name, id), 'staff')
    local g = Cimetiere.graves[id]
    return true, ('Tombe de %s posée (%s).'):format(g.name, g.published and 'avis de décès publié' or 'avis de décès pas publié : fil Weazel saturé cette heure-ci, il paraîtra dans la Gazette')
end)

exports('Bury', function(name, epitaph) return Cimetiere.bury(name, epitaph, nil, nil, 'auto') end)

CreateThread(function()
    local ok, saved = pcall(function() return json.decode(GetResourceKvpString('graves') or '[]') end)
    for _, g in ipairs(ok and type(saved) == 'table' and saved or {}) do
        if type(g) == 'table' and tonumber(g.id) then
            Cimetiere.graves[g.id] = g
            if g.id > Cimetiere.nextId then Cimetiere.nextId = g.id end
        end
    end
    publish()
    while true do
        Wait(15 * 60000) -- les fleurs fanent : publication rafraîchie
        publish()
    end
end)
