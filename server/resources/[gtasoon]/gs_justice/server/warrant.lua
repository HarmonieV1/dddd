-- gs_justice (serveur) · V10.1 « Mandat de perquisition ». Les autres ressources signalent les visites d'une planque
-- (événement serveur) ; trop d'allées et venues = signalement des voisins à la police ; mandat (juge ou juge de
-- permanence) ; perquisition = le coffre s'ouvre pour le policier sur place. Tout est vérifié ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local W = Config.Warrant

Warrant = { places = {}, requests = {} }
-- places[key] = { key, label, coords, score, last, suspect, since, stash, owners = { cid | gang }, warrant = { untilAt, by } }

local function now() return os.time() end
local function onDuty(src, job) return JobsApi:IsOnDutyAs(src, job) == true end
local function name(src) return Bridge:GetName(src) or GetPlayerName(src) or tostring(src) end
local function duty(job)
    local ok, l = pcall(function() return JobsApi:GetOnDutyPlayers(job) end)
    return ok and l or {}
end
local function zone(c)
    if GetResourceState('gs_rumors') ~= 'started' then return 'Los Santos' end
    local ok, z = pcall(function() return exports.gs_rumors:Zone(c) end)
    return ok and z or 'Los Santos'
end

--- Visite d'une planque (appelé par gs_gangs / gs_hideouts)
function Warrant.visit(key, label, coords, stash, owner)
    if type(key) ~= 'string' or not coords then return end
    local p = Warrant.places[key] or { key = key, score = 0, last = now() }
    p.label, p.coords, p.stash, p.owner = label, vec3(coords.x, coords.y, coords.z), stash, owner
    p.score = math.max(0, p.score - (now() - p.last) / (W.decay * 60)) + 1
    p.last = now()
    Warrant.places[key] = p
    if not p.suspect and p.score >= W.threshold then
        p.suspect, p.since = true, now()
        p.zone = zone(p.coords)
        for _, s in ipairs(duty(Config.PoliceJob)) do
            Bridge:Notify(s, ('Des voisins signalent des allées et venues suspectes : %s (%s). /mandat'):format(label, p.zone), 'warning')
        end
    end
    return p
end

local function active(p) return p.warrant and now() < p.warrant.untilAt end

--- Demande de mandat (policier en service)
function Warrant.request(src, key)
    if not onDuty(src, Config.PoliceJob) then return false, 'Réservé à la police en service.' end
    local p = Warrant.places[key]
    if not p or not p.suspect then return false, 'Aucun signalement pour ce lieu.' end
    if active(p) then return false, 'Un mandat est déjà en cours.' end
    if Warrant.requests[key] then return false, 'Demande déjà transmise au juge.' end
    Warrant.requests[key] = { by = src, byName = name(src), at = now() }
    local judges = duty(Config.JudgeJob)
    for _, j in ipairs(judges) do TriggerClientEvent('gs_justice:client:warrantRequest', j, key, p.label, p.zone, name(src)) end
    return true, #judges > 0 and 'Demande transmise au juge en service.'
        or ('Aucun juge en service : le juge de permanence statuera dans %d min.'):format(W.autoMinutes)
end

local function grant(key, by)
    local p, r = Warrant.places[key], Warrant.requests[key]
    Warrant.requests[key] = nil
    if not p then return end
    p.warrant = { untilAt = now() + W.valid * 60, by = by }
    if r and Bridge:IsLoaded(r.by) then Bridge:Notify(r.by, ('Mandat accordé (%s) pour %s : %d min.'):format(by, p.label, W.valid), 'success') end
end

--- Décision du juge
function Warrant.decide(src, key, ok)
    if not onDuty(src, Config.JudgeJob) then return false, 'Réservé aux juges en service.' end
    local r = Warrant.requests[key]
    if not r then return false, 'Plus de demande en attente.' end
    if ok then grant(key, 'juge ' .. name(src)) return true, 'Mandat accordé.' end
    Warrant.requests[key] = nil
    if Bridge:IsLoaded(r.by) then Bridge:Notify(r.by, 'Mandat refusé par le juge.', 'error') end
    return true, 'Mandat refusé.'
end

--- Perquisition sur place : ouvre le coffre pour le policier, prévient les occupants
function Warrant.raid(src, key)
    if not onDuty(src, Config.PoliceJob) then return false, 'Réservé à la police en service.' end
    local p = Warrant.places[key]
    if not p or not active(p) then return false, 'Pas de mandat valide pour ce lieu.' end
    if not Security:InRange(src, p.coords, W.range) then return false, 'Rends-toi sur place.' end
    if not p.raided then
        p.raided = true
        if p.owner and p.owner.gang and GetResourceState('gs_gangs') == 'started' then
            for _, s in ipairs(Bridge:GetPlayers() or {}) do
                local ok, g = pcall(function() return exports.gs_gangs:GetGang(s) end)
                if ok and g == p.owner.gang then Bridge:Notify(s, 'Perquisition en cours à votre planque !', 'error') end
            end
        elseif p.owner and p.owner.cid then
            local s = Bridge:GetSourceByIdentifier(p.owner.cid)
            if s then Bridge:Notify(s, 'La police perquisitionne ta chambre !', 'error') end
        end
        Security:LogStaff(('[Perquisition] %s · %s par %s'):format(p.label, p.zone or '?', name(src)), 'jobs')
    end
    if p.stash and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:forceOpenInventory(src, 'stash', p.stash) -- [API] ox_inventory
    end
    return true, 'Perquisition : le coffre est ouvert.'
end

--- Ce que voit la police / le juge (/mandat)
function Warrant.list(src)
    local cop, judge = onDuty(src, Config.PoliceJob), onDuty(src, Config.JudgeJob)
    if not cop and not judge then return nil end
    local out = {}
    for key, p in pairs(Warrant.places) do
        if p.suspect then
            out[#out + 1] = { key = key, label = p.label, zone = p.zone, warrant = active(p) and math.ceil((p.warrant.untilAt - now()) / 60) or nil,
                pending = Warrant.requests[key] ~= nil, x = p.coords.x, y = p.coords.y }
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return { places = out, judge = judge, cop = cop }
end

--- Juge de permanence, oubli des signalements, fin des mandats
function Warrant.tick()
    for key, r in pairs(Warrant.requests) do
        if #duty(Config.JudgeJob) == 0 and now() - r.at >= W.autoMinutes * 60 then grant(key, 'juge de permanence') end
    end
    for key, p in pairs(Warrant.places) do
        if p.warrant and now() >= p.warrant.untilAt then
            p.warrant, p.suspect, p.score, p.raided = nil, false, 0, nil -- fin de l'affaire : on repart de zéro
        elseif not p.suspect and p.score <= 0.01 and now() - p.last > W.decay * 60 * 6 then
            Warrant.places[key] = nil
        elseif p.suspect and not p.warrant and now() - p.last > W.suspectHours * 3600 then
            p.suspect, p.score = false, 0
        end
    end
end

AddEventHandler('gs_justice:server:visit', function(key, label, coords, stash, owner) Warrant.visit(key, label, coords, stash, owner) end)

lib.callback.register('gs_justice:warrant', function(src, action, key, ok)
    if not Security:RateLimit(src, 'gs_justice:warrant', 5, 10000) then return false, 'Doucement.' end
    if action == 'list' then return Warrant.list(src) end
    key = tostring(key or '')
    if action == 'request' then return Warrant.request(src, key) end
    if action == 'decide' then return Warrant.decide(src, key, ok == true) end
    if action == 'raid' then return Warrant.raid(src, key) end
    return false, 'Action inconnue.'
end)

CreateThread(function()
    while true do Wait(60000) Warrant.tick() end
end)
