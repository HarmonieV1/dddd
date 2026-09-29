-- gs_gangs (serveur). Gangs validés par le staff, membres, caisse, planque, territoires.
-- GlobalState.gsTerritories = { [id] = { owner, color, heat } } : répliqué à tous (carte), aucun event récurrent.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Gangs = {
    list = {},        -- [name] = { name, label, color, stash = vec3|nil }
    online = {},      -- [src] = { cid, gang, grade }
    invites = {},     -- [target] = { gang, from, expires }
    territories = {}, -- [id] = { owner, influence = { [gang] = n }, crimes = { os.time()... } }
    dirty = false,
}

local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function guard(src, key, max, window) return Security:RateLimit(src, 'gs_gangs:' .. key, max, window) end
local function clamp(v) return math.max(0, math.min(100, v)) end

local function stashId(gang) return 'gs_gang_' .. gang end

local function registerStash(g)
    if g.stash then Bridge:RegisterStash(stashId(g.name), 'Planque ' .. g.label, 80, 400000, { [g.name] = 0 }, g.stash) end
end

-- Membres ----------------------------------------------------------------------------------------------

function Gangs.memberOf(src) return Gangs.online[src] end

local function syncMember(src)
    local m = Gangs.online[src]
    if m and m.gang then Bridge:SetGang(src, m.gang, m.grade) else Bridge:SetGang(src, 'none', 0) end
    TriggerClientEvent('gs_gangs:client:membership', src, m and m.gang and {
        gang = m.gang, label = Gangs.list[m.gang].label, grade = m.grade,
        gradeLabel = Config.Grades[m.grade].label, stash = Gangs.list[m.gang].stash, color = Gangs.list[m.gang].color,
    } or nil)
end

function Gangs.load(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local row = Store.member(cid)
    local gang = row and Gangs.list[row.gang] and row.gang or nil
    Gangs.online[src] = { cid = cid, gang = gang, grade = gang and row.grade or 0 }
    syncMember(src)
end

local function sourceOf(cid)
    for s, m in pairs(Gangs.online) do if m.cid == cid then return s end end
end

function Gangs.addMember(cid, gang, grade, name)
    if not Gangs.list[gang] or not Config.Grades[grade] then return false, 'Gang ou grade invalide.' end
    if Store.member(cid) then return false, 'Déjà dans un gang.' end
    if Store.countMembers(gang) >= Config.MaxMembers then return false, 'Gang complet.' end
    if not Store.addMember(cid, gang, grade, name or '') then return false, 'Erreur.' end
    local s = sourceOf(cid)
    if s then Gangs.online[s].gang, Gangs.online[s].grade = gang, grade syncMember(s) end
    return true
end

function Gangs.removeMember(cid)
    if not Store.removeMember(cid) then return false end
    local s = sourceOf(cid)
    if s then Gangs.online[s].gang, Gangs.online[s].grade = nil, 0 syncMember(s) end
    return true
end

-- Actions joueurs -----------------------------------------------------------------------------------------

lib.callback.register('gs_gangs:info', function(src)
    if not guard(src, 'info', 5, 10000) then return nil end
    local m = Gangs.online[src]
    if not m or not m.gang then return false end
    local g = Gangs.list[m.gang]
    local territories = {}
    for id, t in pairs(Gangs.territories) do
        territories[#territories + 1] = { id = id, label = Config.Territories[id].label, mine = t.owner == m.gang,
            owner = t.owner and Gangs.list[t.owner] and Gangs.list[t.owner].label or nil, influence = t.influence[m.gang] or 0 }
    end
    table.sort(territories, function(a, b) return a.influence > b.influence end)
    local members = Store.members(m.gang)
    local onlineCids = {}
    for _, o in pairs(Gangs.online) do onlineCids[o.cid] = true end
    for _, mm in ipairs(members) do mm.online = onlineCids[mm.citizenid] == true mm.gradeLabel = Config.Grades[mm.grade].label end
    return {
        label = g.label, grade = m.grade, canManage = Config.Grades[m.grade].manage == true,
        canBank = Config.Grades[m.grade].bank == true, money = Store.money(m.gang),
        members = members, territories = territories, myCid = m.cid,
    }
end)

lib.callback.register('gs_gangs:invite', function(src, target)
    if not guard(src, 'invite', 3, 30000) then return false, 'Doucement.' end
    local m = Gangs.online[src]
    target = tonumber(target)
    if not m or not m.gang or not Config.Grades[m.grade].manage then return false, 'Réservé aux cadres du gang.' end
    local t = Gangs.online[target]
    if not t or target == src then return false, 'Joueur introuvable.' end
    if t.gang then return false, 'Déjà dans un gang.' end
    if not Security:PlayersInRange(src, target, Config.InviteRange) then return false, 'Trop loin.' end
    Gangs.invites[target] = { gang = m.gang, from = src, expires = os.time() + Config.InviteTimeout }
    TriggerClientEvent('gs_gangs:client:invite', target, Gangs.list[m.gang].label)
    return true, 'Proposition envoyée.'
end)

RegisterNetEvent('gs_gangs:server:answer', function(accept)
    local src = source
    if not guard(src, 'answer', 3, 10000) then return end
    local inv = Gangs.invites[src]
    Gangs.invites[src] = nil
    if not inv or os.time() > inv.expires or accept ~= true then return end
    local ok, err = Gangs.addMember(Gangs.online[src].cid, inv.gang, 0, Bridge:GetName(src))
    notify(src, ok and ('Bienvenue dans %s.'):format(Gangs.list[inv.gang].label) or err, ok and 'success' or 'error')
    if ok then Security:LogStaff(('[Gang] %s rejoint %s'):format(Gangs.online[src].cid, inv.gang), 'jobs') end
end)

lib.callback.register('gs_gangs:manage', function(src, action, cid, grade)
    if not guard(src, 'manage', 5, 10000) then return false, 'Doucement.' end
    local m = Gangs.online[src]
    if not m or not m.gang or not Config.Grades[m.grade].manage then return false, 'Réservé aux cadres du gang.' end
    if type(cid) ~= 'string' or cid == m.cid then return false, 'Impossible sur toi-même.' end
    local target = Store.member(cid)
    if not target or target.gang ~= m.gang then return false, 'Pas dans ton gang.' end
    if target.grade >= m.grade then return false, 'Grade égal ou supérieur au tien.' end
    if action == 'kick' then
        Gangs.removeMember(cid)
        return true, 'Membre exclu.'
    elseif action == 'grade' then
        grade = tonumber(grade)
        if not grade or not Config.Grades[grade] or grade >= m.grade then return false, 'Grade invalide.' end
        Store.setGrade(cid, grade)
        local s = sourceOf(cid)
        if s then Gangs.online[s].grade = grade syncMember(s) end
        return true, 'Grade mis à jour.'
    end
    return false, 'Action inconnue.'
end)

RegisterNetEvent('gs_gangs:server:leave', function()
    local src = source
    if not guard(src, 'leave', 2, 10000) then return end
    local m = Gangs.online[src]
    if m and m.gang then
        if m.grade == 3 then return notify(src, 'Le chef ne peut pas partir : passe le relais au staff.', 'error') end
        Gangs.removeMember(m.cid)
        notify(src, 'Tu as quitté le gang.', 'inform')
    end
end)

lib.callback.register('gs_gangs:bank', function(src, action, amount)
    if not guard(src, 'bank', 5, 10000) then return false, 'Doucement.' end
    local m = Gangs.online[src]
    amount = tonumber(amount)
    if not m or not m.gang then return false, 'Pas de gang.' end
    if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 10000000 then return false, 'Montant invalide.' end
    if action == 'deposit' then
        if not Bridge:RemoveMoney(src, 'cash', amount, 'caisse gang') then return false, 'Pas assez de liquide.' end
        Store.addMoney(m.gang, amount)
    elseif action == 'withdraw' then
        if not Config.Grades[m.grade].bank then return false, 'Réservé au chef.' end
        if not Store.removeMoney(m.gang, amount) then return false, 'Caisse insuffisante.' end
        if not Bridge:AddMoney(src, 'cash', amount, 'caisse gang') then Store.addMoney(m.gang, amount) return false, 'Erreur.' end
    else
        return false, 'Action inconnue.'
    end
    Security:LogStaff(('[Gang] %s %s %d $ (%s)'):format(m.cid, action, amount, m.gang), 'jobs')
    return true, 'Caisse mise à jour.'
end)

-- Territoires -------------------------------------------------------------------------------------------------

local function territoryAt(coords)
    for id, t in pairs(Config.Territories) do
        if #(coords - t.center) <= t.radius then return id end
    end
end
Gangs.territoryAt = territoryAt

local function publish()
    local now, out = os.time(), {}
    for id, t in pairs(Gangs.territories) do
        local heat = 0
        for i = #t.crimes, 1, -1 do
            if now - t.crimes[i] > Config.Territory.heatWindow then table.remove(t.crimes, i) else heat = heat + 1 end
        end
        local g = t.owner and Gangs.list[t.owner]
        out[id] = { owner = g and g.label or nil, color = g and g.color or 0, heat = heat }
    end
    GlobalState.gsTerritories = out
end

--- Recalcule le propriétaire : gang le plus influent au-dessus du seuil (égalité = le tenant garde).
local function resolveOwner(id, t)
    local best, bestVal = t.owner, t.owner and (t.influence[t.owner] or 0) or 0
    for gang, v in pairs(t.influence) do
        if v > bestVal and Gangs.list[gang] then best, bestVal = gang, v end
    end
    if bestVal < Config.Territory.ownThreshold then best = nil end
    if best ~= t.owner then
        local old = t.owner
        t.owner = best
        for s, m in pairs(Gangs.online) do
            if m.gang and (m.gang == best or m.gang == old) then
                notify(s, m.gang == best and ('Votre gang contrôle désormais %s !'):format(Config.Territories[id].label)
                    or ('Vous avez perdu %s.'):format(Config.Territories[id].label), m.gang == best and 'success' or 'error')
            end
        end
    end
end

--- Tick d'influence : présence des membres, présence policière, déclin des absents.
function Gangs.tick()
    local presence, police = {}, {}
    for id in pairs(Config.Territories) do presence[id], police[id] = {}, 0 end
    for src, m in pairs(Gangs.online) do
        local ped = GetPlayerPed(src)
        local zone = ped ~= 0 and territoryAt(GetEntityCoords(ped))
        if zone then
            if m.gang then presence[zone][m.gang] = (presence[zone][m.gang] or 0) + 1 end
            if JobsApi:IsOnDutyAs(src, Config.PoliceJob) then police[zone] = police[zone] + 1 end
        end
    end
    local cfg = Config.Territory
    for id, t in pairs(Gangs.territories) do
        for gang in pairs(Gangs.list) do
            local here = presence[id][gang]
            local v = t.influence[gang] or 0
            if here then v = v + math.min(cfg.presenceCap, here * cfg.presencePerMember) else v = v - cfg.decay end
            v = clamp(v - police[id] * cfg.policePerCop)
            t.influence[gang] = v > 0 and v or nil
        end
        resolveOwner(id, t)
    end
    Gangs.dirty = true
    publish()
end

--- Racket : revenu horaire versé au prorata du tick pour chaque quartier tenu.
function Gangs.payRacket()
    local share = math.floor(Config.Territory.racketPerHour * Config.Territory.tickMinutes / 60)
    for _, t in pairs(Gangs.territories) do
        if t.owner and Gangs.list[t.owner] and share > 0 then Store.addMoney(t.owner, share) end
    end
end

-- Crimes signalés : chaleur du quartier + influence du gang de l'auteur
AddEventHandler('gs_wanted:server:reported', function(src)
    local ped = GetPlayerPed(src)
    local zone = ped ~= 0 and territoryAt(GetEntityCoords(ped))
    if not zone then return end
    local t = Gangs.territories[zone]
    t.crimes[#t.crimes + 1] = os.time()
    local m = Gangs.online[src]
    if m and m.gang then
        t.influence[m.gang] = clamp((t.influence[m.gang] or 0) + Config.Territory.crimeBonus)
        resolveOwner(zone, t)
    end
    publish()
end)

-- Staff -------------------------------------------------------------------------------------------------------

local function reply(src, msg)
    if src == 0 then print('[gs_gangs] ' .. msg) else notify(src, msg) end
end

lib.addCommand('gsgang', {
    help = 'Gangs (staff) : create <nom> <couleur> <label> | delete <nom> | add <id> <nom> <grade> | remove <id> | planque <nom>',
    params = {
        { name = 'action', type = 'string' },
        { name = 'a', type = 'string', optional = true },
        { name = 'b', type = 'string', optional = true },
        { name = 'c', type = 'longString', optional = true },
    },
    restricted = 'group.admin',
}, function(src, args)
    local who = src == 0 and 'console' or GetPlayerName(src)
    if args.action == 'create' then
        local name, color, label = args.a, tonumber(args.b), args.c
        if not name or not name:match('^[%w_]+$') or #name > 30 or not color or not label then return reply(src, 'Usage : create <nom> <couleur blip> <label>') end
        if not Store.createGang(name, label:sub(1, 50), color) then return reply(src, 'Nom déjà pris.') end
        Gangs.list[name] = { name = name, label = label:sub(1, 50), color = color }
        Bridge:RegisterGangs({ [name] = label:sub(1, 50) })
        Security:LogStaff(('/gsgang create %s par %s'):format(name, who))
        return reply(src, 'Gang créé : ' .. label)
    elseif args.action == 'delete' then
        if not Gangs.list[args.a] then return reply(src, 'Gang inconnu.') end
        Store.deleteGang(args.a)
        Gangs.list[args.a] = nil
        for _, t in pairs(Gangs.territories) do t.influence[args.a] = nil if t.owner == args.a then t.owner = nil end end
        for s, m in pairs(Gangs.online) do if m.gang == args.a then m.gang, m.grade = nil, 0 syncMember(s) end end
        publish()
        Security:LogStaff(('/gsgang delete %s par %s'):format(args.a, who))
        return reply(src, 'Gang supprimé.')
    elseif args.action == 'add' then
        local target = tonumber(args.a)
        local m = target and Gangs.online[target]
        if not m then return reply(src, 'Joueur introuvable.') end
        local ok, err = Gangs.addMember(m.cid, args.b, tonumber(args.c) or 0, Bridge:GetName(target))
        Security:LogStaff(('/gsgang add %s %s par %s'):format(m.cid, tostring(args.b), who))
        return reply(src, ok and 'Ajouté.' or err)
    elseif args.action == 'remove' then
        local m = Gangs.online[tonumber(args.a) or -1]
        if not m then return reply(src, 'Joueur introuvable.') end
        Gangs.removeMember(m.cid)
        return reply(src, 'Retiré.')
    elseif args.action == 'planque' then
        local g = Gangs.list[args.a]
        if not g or src == 0 then return reply(src, 'Gang inconnu (commande en jeu uniquement).') end
        g.stash = GetEntityCoords(GetPlayerPed(src))
        Store.setStash(g.name, g.stash)
        registerStash(g)
        for s, m in pairs(Gangs.online) do if m.gang == g.name then syncMember(s) end end
        return reply(src, 'Planque placée ici.')
    end
    reply(src, 'Action inconnue.')
end)

-- Cycle de vie ---------------------------------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerLoaded', function(src) Gangs.load(src) end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Gangs.online[src], Gangs.invites[src] = nil, nil end)

function Gangs.init()
    Store.init()
    local existing = {}
    for _, row in ipairs(Store.gangs()) do existing[row.name] = true end
    for _, g in ipairs(Config.DefaultGangs or {}) do
        if not existing[g.name] and Store.createGang(g.name, g.label, g.color) then
            Store.setStash(g.name, g.stash)
            print(('[gs_gangs] gang par défaut créé : %s'):format(g.label))
        end
    end
    for _, row in ipairs(Store.gangs()) do
        local g = { name = row.name, label = row.label, color = row.color }
        if row.stash_x then g.stash = vec3(row.stash_x, row.stash_y, row.stash_z) end
        Gangs.list[row.name] = g
        registerStash(g)
    end
    local declared = {}
    for name, g in pairs(Gangs.list) do declared[name] = g.label end
    if next(declared) then Bridge:RegisterGangs(declared) end
    for id in pairs(Config.Territories) do Gangs.territories[id] = { owner = nil, influence = {}, crimes = {} } end
    for _, row in ipairs(Store.territories()) do
        local t = Gangs.territories[row.id]
        if t then
            t.owner = Gangs.list[row.owner or ''] and row.owner or nil
            t.influence = json.decode(row.influence) or {}
        end
    end
    publish()
end

function Gangs.save()
    if not Gangs.dirty then return end
    Gangs.dirty = false
    local rows = {}
    for id, t in pairs(Gangs.territories) do rows[#rows + 1] = { id, t.owner, json.encode(t.influence) } end
    Store.saveTerritories(rows)
end

CreateThread(function()
    Gangs.init()
    for _, src in ipairs(Bridge:GetPlayers()) do Gangs.load(src) end
    while true do
        Wait(Config.Territory.tickMinutes * 60000)
        Gangs.tick()
        Gangs.payRacket()
        Gangs.save()
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Gangs.save() end end)

--- Place la planque d'un gang (outil gs_builder). coords = vector3.
exports('SetStash', function(gang, coords)
    local g = Gangs.list[gang]
    if not g or not coords then return false end
    g.stash = vec3(coords.x, coords.y, coords.z)
    Store.setStash(g.name, g.stash)
    registerStash(g)
    for s, m in pairs(Gangs.online) do if m.gang == g.name then syncMember(s) end end
    return true
end)
--- Staff (tests) : place le joueur dans `gang` au `grade` (quitte son gang actuel). gang = nil : retire.
exports('AdminSetGang', function(src, gang, grade)
    local m = Gangs.online[src]
    if not m then return false, 'Joueur non chargé.' end
    if gang ~= nil and not Gangs.list[gang] then return false, 'Gang inconnu.' end
    if m.gang then Gangs.removeMember(m.cid) end
    if gang == nil then return true end
    return Gangs.addMember(m.cid, gang, tonumber(grade) or 0, Bridge:GetName(src))
end)

exports('ListGangs', function()
    local l = {}
    for name, g in pairs(Gangs.list) do l[#l + 1] = { name = name, label = g.label } end
    table.sort(l, function(a, b) return a.label < b.label end)
    return l
end)

exports('GetGang', function(src) local m = Gangs.online[src] return m and m.gang, m and m.grade end)
exports('GetTerritoryAt', function(coords) return territoryAt(coords) end)
exports('GetTerritoryOwner', function(id) return Gangs.territories[id] and Gangs.territories[id].owner end)
function Gangs.addInfluence(gang, id, n)
    local t = Gangs.territories[id]
    if not t or not Gangs.list[gang] or type(n) ~= 'number' then return false end
    t.influence[gang] = clamp((t.influence[gang] or 0) + n)
    resolveOwner(id, t)
    Gangs.dirty = true
    publish()
    return true
end
exports('AddInfluence', Gangs.addInfluence)
