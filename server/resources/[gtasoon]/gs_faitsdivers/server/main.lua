-- gs_faitsdivers (serveur) · V10 « La ville a ses propres criminels ». Le serveur choisit le fait divers, prévient les
-- services en service (police, EMS si besoin, presse), vérifie la présence sur place et paie. Les joueurs passent
-- toujours avant : rien n'est créé si des crimes de joueurs ont eu lieu récemment.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

FD = { open = {}, crimes = {}, nextId = 0 }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function onDuty(job)
    if not started('gs_jobs') then return {} end
    local ok, l = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
    return ok and l or {}
end
local function zone(c)
    if not started('gs_rumors') then return 'Los Santos' end
    local ok, z = pcall(function() return exports.gs_rumors:Zone(c) end)
    return ok and z or 'Los Santos'
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

--- La ville est-elle calme côté joueurs ?
function FD.quiet()
    local t, keep = now(), {}
    for _, at in ipairs(FD.crimes) do if t - at < Config.QuietWindow * 60 then keep[#keep + 1] = at end end
    FD.crimes = keep
    return #keep < Config.QuietCrimes
end

local function recipients(case)
    local list = {}
    for _, s in ipairs(onDuty(Config.PoliceJob)) do list[s] = true end
    if Config.Kinds[case.kind].ems then for _, s in ipairs(onDuty(Config.EmsJob)) do list[s] = true end end
    for _, s in ipairs(onDuty(Config.PressJob)) do list[s] = true end
    return list
end

local function public(case)
    return { id = case.id, kind = case.kind, label = Config.Kinds[case.kind].label, icon = Config.Kinds[case.kind].icon,
        action = Config.Kinds[case.kind].action, x = case.coords.x, y = case.coords.y, z = case.coords.z, zone = case.zone, model = case.model, plate = case.plate }
end

--- Crée un fait divers (kind / spot forcés possibles pour le staff et les tests)
function FD.create(kind, spotIndex)
    local spots = {}
    for i, s in ipairs(Config.Spots) do
        for _, k in ipairs(s.kinds) do if (not kind or k == kind) then spots[#spots + 1] = { i = i, kind = k } break end end
    end
    local pick = spotIndex and { i = spotIndex, kind = kind or Config.Spots[spotIndex].kinds[1] } or spots[math.random(1, math.max(1, #spots))]
    if not pick then return nil end
    for _, c in pairs(FD.open) do if c.spot == pick.i then return nil end end -- déjà une affaire à cet endroit
    FD.nextId = FD.nextId + 1
    local s = Config.Spots[pick.i]
    local models = Config.Models[pick.kind]
    local case = { id = FD.nextId, kind = pick.kind, spot = pick.i, coords = s.coords, zone = zone(s.coords), at = now(), done = {},
        model = models and models[math.random(1, #models)] or nil, plate = pick.kind == 'hitrun' and ('%02d%s%03d'):format(math.random(10, 99), string.char(math.random(65, 90), math.random(65, 90)), math.random(100, 999)) or nil }
    FD.open[case.id] = case
    TriggerEvent('gs_faitsdivers:server:new', Config.Kinds[case.kind].label, case.zone) -- V10 : Radio Los Santos
    for src in pairs(recipients(case)) do TriggerClientEvent('gs_faitsdivers:client:new', src, public(case)) end
    if started('gs_rumors') then pcall(function() exports.gs_rumors:Add(('il s\'est passé quelque chose du côté de %s'):format(case.zone), Config.Kinds[case.kind].label .. ' à ' .. case.zone .. '.', s.coords) end) end
    return case
end

--- Tirage périodique
function FD.tick()
    for id, c in pairs(FD.open) do
        if now() - c.at > Config.Lifetime * 60 then
            FD.open[id] = nil
            TriggerClientEvent('gs_faitsdivers:client:closed', -1, id)
            if started('gs_social') then pcall(function() exports.gs_social:Newsroom('fd_' .. id, ('%s à %s : l\'auteur court toujours.'):format(Config.Kinds[c.kind].label, c.zone)) end) end
            if started('gs_city') then pcall(function() exports.gs_city:AddStanding(c.coords, -2) end) end
        end
    end
    if #onDuty(Config.PoliceJob) < Config.MinPolice or count(FD.open) >= Config.MaxOpen or not FD.quiet() then return nil end
    if math.random() >= Config.Chance then return nil end
    return FD.create()
end

--- Traitement sur place : policier (ou EMS pour un corps / un accident), une seule fois par personne et par affaire
function FD.handle(src, id)
    local c = FD.open[tonumber(id) or 0]
    if not c then return false, 'Affaire déjà traitée.' end
    local job = Bridge:GetJob(src)
    local police = started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob)
    local ems = Config.Kinds[c.kind].ems and job and job.name == Config.EmsJob and job.onduty
    if not police and not ems then return false, 'Réservé à la police (et aux EMS sur un corps ou un accident).' end
    if not Security:InRange(src, c.coords, Config.Range + 2.0) then return false, 'Approche-toi de la scène.' end
    local cid = Bridge:GetIdentifier(src)
    if c.done[cid] then return false, 'Tu as déjà fait tes constatations.' end
    c.done[cid] = true
    local K = Config.Kinds[c.kind]
    local pay = math.random(K.reward[1], K.reward[2])
    Bridge:AddMoney(src, 'bank', pay, 'fait divers')
    if started('gs_reputation') then pcall(function() exports.gs_reputation:Add(src, 'legal', 3) end) end
    if police then -- la police clôt l'affaire
        FD.open[c.id] = nil
        TriggerClientEvent('gs_faitsdivers:client:closed', -1, c.id)
        if started('gs_social') then pcall(function() exports.gs_social:Newsroom('fd_' .. c.id, K.brief:format(c.zone)) end) end
        if started('gs_city') then pcall(function() exports.gs_city:AddStanding(c.coords, 1) end) end
        local lead = c.plate and (' Plaque relevée : %s.'):format(c.plate) or ''
        return true, ('Affaire close : +%d $.%s'):format(pay, lead)
    end
    return true, ('Constatations médicales : +%d $.'):format(pay)
end

function FD.list(src)
    local job = Bridge:GetJob(src)
    if not job or not job.onduty then return {} end
    local out = {}
    for _, c in pairs(FD.open) do
        if job.name == Config.PoliceJob or job.name == Config.PressJob or (Config.Kinds[c.kind].ems and job.name == Config.EmsJob)
            or (started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob)) then out[#out + 1] = public(c) end
    end
    return out
end

AddEventHandler('gs_wanted:server:crime', function()
    FD.crimes[#FD.crimes + 1] = now()
    if #FD.crimes > 50 then FD.quiet() end -- élague même quand la police est absente
end)

lib.callback.register('gs_faitsdivers:handle', function(src, id)
    if not Security:RateLimit(src, 'gs_faitsdivers:handle', 2, 5000) then return false, 'Doucement.' end
    return FD.handle(src, id)
end)
lib.callback.register('gs_faitsdivers:list', function(src)
    if not Security:RateLimit(src, 'gs_faitsdivers:list', 4, 5000) then return {} end
    return FD.list(src)
end)

exports('OpenCount', function() return count(FD.open) end)
exports('Create', function(kind) local c = FD.create(kind) return c and c.id or nil end) -- staff (F11 → Événements)

CreateThread(function()
    while true do Wait(Config.Every * 60000) FD.tick() end
end)

-- Staff (F11 → Événements → Fait divers) : en lancer un tout de suite, même si la ville n'est pas calme
RegisterCommand('faitdivers', function(src, args)
    if src ~= 0 then
        local ok, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
        if not (ok and (tonumber(lvl) or 0) >= 3) then return end
    end
    local kind = Config.Kinds[args[1] or ''] and args[1] or nil
    local c = FD.create(kind)
    local msg = c and ('Fait divers lancé : %s à %s.'):format(Config.Kinds[c.kind].label, c.zone) or 'Impossible (lieu déjà occupé ?).'
    if src == 0 then print(msg) else Bridge:Notify(src, msg, c and 'success' or 'error') end
end, false)
