-- Simulateur minimal FiveM / Qbox / BDD pour tester la logique SERVEUR des ressources gs_* hors jeu.
-- Ne remplace pas les tests en jeu de [TEST] : il ne simule ni le réseau, ni le client, ni oxmysql.

-- Vecteurs -----------------------------------------------------------------------------
local V = {}
V.__index = V
local function vec(x, y, z, w) return setmetatable({ x = x, y = y, z = z or 0.0, w = w }, V) end
V.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
function vec3(x, y, z) return vec(x, y, z) end
function vec4(x, y, z, w) return vec(x, y, z, w) end

-- Monde --------------------------------------------------------------------------------
GlobalState = {}
W = { now = 100000, players = {}, entities = {}, nextEntity = 5000, handlers = {}, callbacks = {},
      commands = {}, clientEvents = {}, notes = {}, audit = {}, logs = {} }

function GetGameTimer() return W.now end
os.time = function() return math.floor(W.now / 1000) end
function Wait() end
function CreateThread() end -- les boucles infinies (paie, flush) ne tournent pas en test
function GetConvar(_, default) return default end
function PerformHttpRequest() end
function GetCurrentResourceName() return 'gs_jobs' end
function GetResourceState() return 'started' end
function joaat(s) return #s end
GetHashKey = joaat
json = { encode = function() return '{}' end }
print = function(...) W.logs[#W.logs + 1] = table.concat({ ... }, ' ') end

function GetPlayerName(src) return W.players[src] and W.players[src].name or nil end
function GetPlayerPed(src) return W.players[src] and (1000 + src) or 0 end
function GetEntityCoords(ent)
    if ent > 1000 and ent < 2000 then return W.players[ent - 1000].pos end
    return W.entities[ent].pos
end
function DoesEntityExist(ent) return W.entities[ent] ~= nil end
function DeleteEntity(ent) W.entities[ent] = nil end
function GetEntityType(ent) return W.entities[ent] and W.entities[ent].type or 0 end
function GetAllVehicles()
    local l = {}
    for id, e in pairs(W.entities) do if e.type == 2 then l[#l + 1] = id end end
    return l
end
function CreateVehicleServerSetter(_, _, x, y, z)
    W.nextEntity = W.nextEntity + 1
    W.entities[W.nextEntity] = { type = 2, pos = vec3(x, y, z), state = {} }
    return W.nextEntity
end
function SetVehicleNumberPlateText(ent, p) W.entities[ent].plate = p end
function GetVehicleNumberPlateText(ent) return W.entities[ent].plate end
function TaskWarpPedIntoVehicle() end
function Entity(ent)
    local e = W.entities[ent]
    e.state = e.state or {}
    return { state = setmetatable({ set = function(_, k, v) e.state[k] = v end }, { __index = e.state }) }
end
function NetworkGetEntityFromNetworkId(id) return id end
function NetworkGetNetworkIdFromEntity(ent) return ent end
function NetworkGetEntityOwner(ent) return W.entities[ent].owner or -1 end

-- Events / callbacks -------------------------------------------------------------------
local function on(name, fn)
    W.handlers[name] = W.handlers[name] or {}
    table.insert(W.handlers[name], fn)
end
RegisterNetEvent = on
AddEventHandler = on
function TriggerEvent(name, ...)
    for _, fn in ipairs(W.handlers[name] or {}) do fn(...) end
end
function TriggerClientEvent(name, target, ...)
    W.clientEvents[#W.clientEvents + 1] = { name = name, target = target, args = { ... } }
end
--- Simule un event client → serveur.
function net(name, src, ...)
    for _, fn in ipairs(W.handlers[name] or {}) do source = src; fn(...) end
end
lib = {
    callback = { register = function(name, fn) W.callbacks[name] = fn end },
    addCommand = function(name, _, fn) W.commands[name] = fn end,
}
--- Simule lib.callback.await côté client.
function cb(name, src, ...) return W.callbacks[name](src, ...) end
function lastClientEvent(name, target)
    for i = #W.clientEvents, 1, -1 do
        local e = W.clientEvents[i]
        if e.name == name and (not target or e.target == target) then return e end
    end
end

-- Exports inter-ressources ---------------------------------------------------------------
local registry = {}
exports = setmetatable({}, {
    __call = function(_, name, fn) registry[CURRENT][name] = fn end,
    __index = function(_, res)
        return setmetatable({}, { __index = function(_, fnName)
            return function(_, ...) return registry[res][fnName](...) end
        end })
    end,
})
function loadResource(name, files)
    CURRENT = name
    registry[name] = registry[name] or {}
    for _, f in ipairs(files) do dofile(f) end
end
function provide(name, api) registry[name] = api end
--- Fonction exportée réelle (pour l'envelopper dans un faux sans boucle infinie).
function getExport(res, name) return registry[res][name] end

-- gs_bridge simulé (Qbox) -------------------------------------------------------------------
local function positiveInt(n) return type(n) == 'number' and n > 0 and n == math.floor(n) end
provide('gs_bridge', {
    IsLoaded = function(src) return W.players[src] ~= nil end,
    GetPlayers = function() local l = {} for s in pairs(W.players) do l[#l + 1] = s end return l end,
    GetIdentifier = function(src) return W.players[src] and W.players[src].cid end,
    GetSourceByIdentifier = function(cid)
        for s, p in pairs(W.players) do if p.cid == cid then return s end end
    end,
    GetName = function(src) return W.players[src] and W.players[src].name end,
    GetJob = function(src)
        local p = W.players[src]
        return p and { name = p.job.name, label = p.job.name, grade = p.job.grade, onduty = p.job.onduty } or nil
    end,
    SetJob = function(src, name, grade) W.players[src].job = { name = name, grade = grade, onduty = false } return true end,
    SetDuty = function(src, on) W.players[src].job.onduty = on return true end,
    ForgetJob = function() return true end,
    RegisterJobs = function() return true end,
    GetMoney = function(src, acc) return W.players[src].money[acc] end,
    AddMoney = function(src, acc, n)
        if not W.players[src] or not positiveInt(n) then return false end
        W.players[src].money[acc] = W.players[src].money[acc] + n
        return true
    end,
    RemoveMoney = function(src, acc, n)
        local p = W.players[src]
        if not p or not positiveInt(n) or p.money[acc] < n then return false end
        p.money[acc] = p.money[acc] - n
        return true
    end,
    GetItemCount = function(src, item) return W.players[src].items[item] or 0 end,
    ItemExists = function(item) return item ~= "introuvable" end,
    CanCarry = function(src, _, n) return W.players[src] ~= nil and positiveInt(n) and not W.players[src].full end,
    AddItem = function(src, item, n)
        local p = W.players[src]
        if not p or p.full then return false end
        p.items[item] = (p.items[item] or 0) + n
        return true
    end,
    RemoveItem = function(src, item, n)
        local p = W.players[src]
        if (p.items[item] or 0) < n then return false end
        p.items[item] = p.items[item] - n
        return true
    end,
    RegisterStash = function() return true end,
    Revive = function(src) W.players[src].revived = true W.players[src].downed = nil return true end,
    IsDowned = function(src) return W.players[src] ~= nil and W.players[src].downed == true end,
    RegisterGangs = function() return true end,
    SetGang = function(src, name, grade) W.players[src].gang = { name = name, grade = grade } return true end,
    GiveVehicle = function(src, model) if model == "casse" then return false end W.players[src].vehicles = (W.players[src].vehicles or 0) + 1 return true end,
    GiveVehicleKeys = function() return true end,
    Notify = function(src, msg, t) W.notes[src] = { msg = msg, type = t } end,
    GetGender = function(src) return W.players[src] and (W.players[src].gender or 'male') end,
    ListItems = function() return { { name = 'sandwich', label = 'Sandwich' } } end,
    CreateDrop = function(items, coords) W.drops = W.drops or {} W.drops[#W.drops + 1] = { items = items, coords = coords } return true end,
    SpawnVehicle = function(src, model, vtype, c, heading, plate, warp)
        if model == 'casse' then return 0 end
        local veh = CreateVehicleServerSetter(model, vtype, c.x, c.y, c.z, heading)
        W.entities[veh].model, W.entities[veh].plate, W.entities[veh].driver = model, plate, warp and src or nil
        return veh
    end,
})

-- gs_quests simulé : XP reçue par activité (les tests de gs_quests chargent la vraie ressource)
provide('gs_quests', { Reward = function(src, activity) W.rewards = W.rewards or {} W.rewards[#W.rewards + 1] = { src = src, activity = activity } return 1 end,
    AddXP = function() return 1 end, GetLevel = function() return 1 end,
    Track = function(src, activity) W.tracks = W.tracks or {} W.tracks[#W.tracks + 1] = { src = src, activity = activity } return true end,
    GetTitle = function() return 'Habitué' end,
    GetSummary = function() return { level = 3, title = 'Habitué', xp = 600, streak = 2, badges = { 'Premier contrat' } } end })

-- BDD simulée (même API que gs_jobs/server/db.lua) ---------------------------------------------
function mockDB()
    local members, societies, bills, nextBill = {}, {}, {}, 0
    local function key(cid, job) return cid .. '|' .. job end
    DB = {}
    function DB.init() for n, d in pairs(Jobs) do if d.society then societies[n] = 0 end end end
    function DB.getMemberships(cid)
        local l = {}
        for _, m in pairs(members) do if m.citizenid == cid then l[#l + 1] = { job = m.job, grade = m.grade } end end
        return l
    end
    function DB.countMemberships(cid) return #DB.getMemberships(cid) end
    function DB.getMember(cid, job)
        local m = members[key(cid, job)]
        return m and { grade = m.grade, name = m.name }
    end
    function DB.getEmployees(job)
        local l = {}
        for _, m in pairs(members) do if m.job == job then l[#l + 1] = { citizenid = m.citizenid, grade = m.grade, name = m.name } end end
        return l
    end
    function DB.addMember(cid, job, grade, name)
        assert(not members[key(cid, job)], 'clé dupliquée')
        members[key(cid, job)] = { citizenid = cid, job = job, grade = grade, name = name }
        return true
    end
    function DB.removeMember(cid, job)
        local had = members[key(cid, job)] ~= nil
        members[key(cid, job)] = nil
        return had
    end
    function DB.setGrade(cid, job, grade) members[key(cid, job)].grade = grade end
    function DB.updateName() end
    function DB.getSociety(job) return societies[job] or 0 end
    function DB.addSociety(job, n) if not societies[job] then return false end societies[job] = societies[job] + n return true end
    function DB.removeSociety(job, n)
        if not societies[job] or societies[job] < n then return false end
        societies[job] = societies[job] - n
        return true
    end
    function DB.createBill(cid, job, amount, reason, icid, iname)
        nextBill = nextBill + 1
        bills[nextBill] = { id = nextBill, citizenid = cid, job = job, amount = amount, reason = reason,
            issuer_citizenid = icid, issuer_name = iname, date = '01/01 00:00' }
        return nextBill
    end
    function DB.countBills(cid) local n = 0 for _, b in pairs(bills) do if b.citizenid == cid then n = n + 1 end end return n end
    function DB.getBills(cid) local l = {} for _, b in pairs(bills) do if b.citizenid == cid then l[#l + 1] = b end end return l end
    function DB.getBill(id, cid) local b = bills[id] return b and b.citizenid == cid and b or nil end
    function DB.deleteBill(id, cid) if DB.getBill(id, cid) then bills[id] = nil return true end return false end
    function DB.audit(action, job, actor, target, amount, details)
        W.audit[#W.audit + 1] = { action = action, job = job, actor = actor, target = target, amount = amount, details = details }
    end
end

--- Connecte un joueur simulé et déclenche le chargement comme le ferait gs_bridge.
function join(src, cid, name, pos, job)
    W.players[src] = { cid = cid, name = name, pos = pos, job = job or { name = 'unemployed', grade = 0, onduty = false },
        money = { cash = 0, bank = 0 }, items = {} }
    TriggerEvent('gs_bridge:server:playerLoaded', src)
end

function tp(src, pos) W.players[src].pos = pos end
function advance(ms) W.now = W.now + ms end

-- Ajouts pour gs_wanted / gs_economy / gs_duo ----------------------------------------------------------
function SetTimeout(_, fn) fn() end -- exécution immédiate en test
function GetAllPeds()
    local l = {}
    for id, e in pairs(W.entities) do if e.type == 1 then l[#l + 1] = id end end
    return l
end
function IsPedAPlayer(ped) return ped > 1000 and ped < 2000 end
function GetEntityHealth(ent) return W.entities[ent] and W.entities[ent].health or 200 end
function GetPlayers() local l = {} for s in pairs(W.players) do l[#l + 1] = tostring(s) end return l end
function GetSelectedPedWeapon(ped) return W.players[ped - 1000].weapon or joaat('WEAPON_UNARMED') end
function GetVehiclePedIsIn(ped) return W.players[ped - 1000].vehicle or 0 end
function GetEntityModel(ent) return W.entities[ent].model or 0 end
function GetEntityHeading() return 90.0 end
--- Ajoute `n` PNJ vivants autour de `pos`.
function spawnPeds(pos, n)
    for i = 1, n do
        W.nextEntity = W.nextEntity + 1
        W.entities[W.nextEntity] = { type = 1, pos = vec3(pos.x + i, pos.y, pos.z), health = 200 }
    end
end
function clearPeds() for id, e in pairs(W.entities) do if e.type == 1 then W.entities[id] = nil end end end
--- Force math.random : valeur fixe pour les tirages 0-1, ou restaure l'aléatoire.
local realRandom = math.random
function fixRandom(v)
    if v == nil then math.random = realRandom return end
    math.random = function(a, b)
        if a == nil then return v end
        if b == nil then return math.max(1, math.floor(v * a + 0.5)) end
        return a + math.floor((b - a) * v + 0.5)
    end
end

-- Ajouts pour gs_store
function RegisterCommand(name, fn) W.commands[name] = fn end
function GetPlayerIdentifierByType(src, kind)
    local p = W.players[src]
    return p and p[kind] or nil
end

-- Ajouts pour gs_social
function IsPlayerAceAllowed(src, ace) return W.players[src] ~= nil and W.players[src].aces ~= nil and W.players[src].aces[ace] == true end

-- Ajouts pour gs_police / gs_details : state bags joueur, objets serveur
W.pstate = {}
function Player(src)
    W.pstate[src] = W.pstate[src] or {}
    local st = W.pstate[src]
    return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) }
end
function CreateObjectNoOffset(hash, x, y, z)
    W.nextEntity = W.nextEntity + 1
    W.entities[W.nextEntity] = { type = 3, pos = vec3(x, y, z), model = hash }
    return W.nextEntity
end
function SetEntityHeading() end
function FreezeEntityPosition(ent, on) if W.entities[ent] then W.entities[ent].frozen = on elseif ent > 1000 and ent < 2000 and W.players[ent - 1000] then W.players[ent - 1000].frozen = on end end
if not GetPedInVehicleSeat then function GetPedInVehicleSeat(veh) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end end
