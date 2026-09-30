-- gs_races (serveur) : chrono solo et courses à mise. Le serveur chronomètre, valide chaque point (position, ordre, vitesse
-- crédible, véhicule) et paie. Les clients ne font qu'afficher.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Races = { lobbies = {}, runs = {}, solo = {}, nextId = 0, topCache = nil, topAt = 0 }

--- Mise d'une course à plusieurs : gratuite pendant une « course improvisée » (tendance Vibe #course).
Races.freeUntil = 0
function Races.entry() return os.time() < Races.freeUntil and 0 or Config.Entry end
exports('SetFreeEntry', function(seconds) Races.freeUntil = os.time() + math.max(0, math.min(3600, tonumber(seconds) or 0)) return true end)

local function started(res) return GetResourceState(res) == 'started' end

--- Nom affiché dans les classements : pseudo Vibe si le joueur en a un, sinon « Prénom N. ».
local function display(src)
    local h = started('gs_social') and exports.gs_social:GetHandle(src)
    if h then return '@' .. h end
    local ci = Bridge:GetCharInfo(src) or {}
    return ('%s %s.'):format(ci.firstname or '?', (ci.lastname or '?'):sub(1, 1))
end

local function atStart(src, circuit)
    return Security:InRange(src, circuit.points[1], Config.StartRadius + Config.Tolerance)
end

local function driving(src)
    local ped = GetPlayerPed(src)
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
end

local function fmt(ms) return ('%d:%02d.%03d'):format(ms // 60000, (ms // 1000) % 60, ms % 1000) end
Races.fmt = fmt

local function begin(src, lobby, delayMs)
    Races.runs[src] = { lobby = lobby, cp = 1, startedAt = GetGameTimer() + delayMs, lastAt = GetGameTimer() + delayMs,
        lastPos = Config.Circuits[lobby.circuit].points[1] }
    TriggerClientEvent('gs_races:client:begin', src, lobby.circuit, delayMs, #lobby.players)
end

local function leave(src, refund)
    local run = Races.runs[src]
    Races.runs[src] = nil
    for id, l in pairs(Races.lobbies) do
        for i, p in ipairs(l.players) do
            if p == src then
                table.remove(l.players, i)
                if l.state == 'open' and refund and l.entry > 0 then
                    Bridge:AddMoney(src, 'cash', l.entry, 'mise de course remboursée')
                    l.pot = l.pot - l.entry
                end
                break
            end
        end
        if #l.players == 0 then Races.lobbies[id] = nil end
    end
    return run
end

--- Ouvre (ou rejoint) une course. mode = 'solo' | 'group'
lib.callback.register('gs_races:start', function(src, circuitId, mode)
    if not Security:RateLimit(src, 'gs_races:start', 3, 10000) then return false, 'Doucement.' end
    local c = Config.Circuits[circuitId]
    if not c or (mode ~= 'solo' and mode ~= 'group') then return false, 'Circuit inconnu.' end
    if Races.runs[src] then return false, 'Tu es déjà dans une course.' end
    if not atStart(src, c) then return false, 'Présente-toi sur la ligne de départ.' end
    if not driving(src) then return false, 'Il faut être au volant.' end
    if mode == 'solo' then
        if (Races.solo[src] or 0) > os.time() then return false, 'Souffle un peu entre deux chronos.' end
        Races.nextId = Races.nextId + 1
        local l = { id = Races.nextId, circuit = circuitId, players = { src }, state = 'running', entry = 0, pot = 0, finished = 0, solo = true,
            endsAt = os.time() + Config.MaxDuration }
        Races.lobbies[l.id] = l
        begin(src, l, Config.Countdown * 1000)
        return true, 'Chrono lancé.'
    end
    local lobby
    for _, l in pairs(Races.lobbies) do if l.circuit == circuitId and l.state == 'open' then lobby = l break end end
    if lobby and #lobby.players >= Config.MaxPlayers then return false, 'Course complète.' end
    local entry = lobby and lobby.entry or Races.entry() -- on paie la mise du lobby rejoint (gratuit s'il a été ouvert gratuit)
    if entry > 0 and not Bridge:RemoveMoney(src, 'cash', entry, 'mise de course') then return false, ('Mise : %d $ en liquide.'):format(entry) end
    if not lobby then
        Races.nextId = Races.nextId + 1
        lobby = { id = Races.nextId, circuit = circuitId, players = {}, state = 'open', entry = entry, pot = 0, finished = 0,
            startAt = os.time() + Config.JoinWindow }
        Races.lobbies[lobby.id] = lobby
        if math.random() < Config.PoliceChance and started('gs_wanted') then
            exports.gs_wanted:ReportCrime(src, 'street_race', c.points[1])
        end
    end
    table.insert(lobby.players, src)
    lobby.pot = lobby.pot + lobby.entry
    Races.runs[src] = { lobby = lobby, waiting = true }
    return true, ('Inscrit. Départ dans %d s si au moins 2 pilotes.'):format(math.max(0, lobby.startAt - os.time()))
end)

--- Lobbies ouverts : lancement (≥ 2 pilotes toujours sur la ligne, au volant) ou annulation avec remboursement.
function Races.tick()
    local now = os.time()
    for id, l in pairs(Races.lobbies) do
        if l.state == 'open' and now >= l.startAt then
            local ready = {}
            for _, src in ipairs(l.players) do
                if Bridge:IsLoaded(src) and atStart(src, Config.Circuits[l.circuit]) and driving(src) then ready[#ready + 1] = src
                else
                    Bridge:AddMoney(src, 'cash', l.entry, 'mise de course remboursée')
                    Races.runs[src] = nil
                    l.pot = l.pot - l.entry
                    if Bridge:IsLoaded(src) then Bridge:Notify(src, 'Tu n\'étais pas sur la ligne : mise remboursée.', 'inform') end
                end
            end
            l.players = ready
            if #ready < 2 then
                for _, src in ipairs(ready) do
                    Bridge:AddMoney(src, 'cash', l.entry, 'mise de course remboursée')
                    l.pot = l.pot - l.entry
                    Races.runs[src] = nil
                    Bridge:Notify(src, 'Pas assez de pilotes : mise remboursée.', 'inform')
                end
                Races.lobbies[id] = nil
            else
                l.state, l.endsAt, l.starters = 'running', now + Config.MaxDuration, #ready
                for _, src in ipairs(ready) do begin(src, l, Config.Countdown * 1000) end
            end
        elseif l.state == 'running' and now >= l.endsAt then
            for _, src in ipairs(l.players) do
                Races.runs[src] = nil
                TriggerClientEvent('gs_races:client:end', src, 'Course abandonnée (temps écoulé).')
            end
            Races.lobbies[id] = nil
        end
    end
end

--- Le joueur annonce avoir atteint le point courant : position, ordre, vitesse, véhicule vérifiés ici.
lib.callback.register('gs_races:checkpoint', function(src)
    if not Security:RateLimit(src, 'gs_races:checkpoint', 6, 5000) then return false end
    local run = Races.runs[src]
    if not run or run.waiting or GetGameTimer() < run.startedAt then return false end
    local lobby = run.lobby
    local pts = Config.Circuits[lobby.circuit].points
    local target = pts[run.cp + 1]
    if not target then return false end
    if not driving(src) then return false, 'Il faut rester au volant.' end
    if not Security:InRange(src, target, Config.CheckpointRadius + Config.Tolerance) then return false end
    local elapsed = (GetGameTimer() - run.lastAt) / 1000
    if elapsed < #(target - run.lastPos) / Config.MaxSpeed then
        Security:LogStaff(('[Course] temps impossible : %s sur %s'):format(GetPlayerName(src) or src, lobby.circuit))
        leave(src, false)
        TriggerClientEvent('gs_races:client:end', src, 'Course annulée : trajet impossible.')
        return false
    end
    run.cp, run.lastAt, run.lastPos = run.cp + 1, GetGameTimer(), target
    if run.cp < #pts then return true, run.cp end
    -- arrivée
    local ms = GetGameTimer() - run.startedAt
    lobby.finished = lobby.finished + 1
    local position = lobby.finished
    local name = display(src)
    local cid = Bridge:GetIdentifier(src)
    local record = cid and Store.record(lobby.circuit, cid, name, ms)
    local prize = 0
    if not lobby.solo then
        local shares = Config.Shares[math.min(lobby.starters or 2, 3)]
        local share = shares[position]
        if share then prize = math.floor(lobby.pot * Config.PotKeep * share) end
        if prize > 0 then Bridge:AddMoney(src, 'cash', prize, 'course de rue') end
    end
    Races.topCache = nil
    leave(src, false) -- sort du lobby (supprimé quand le dernier pilote a fini)
    if started('gs_quests') then exports.gs_quests:Track(src, 'race') end
    TriggerClientEvent('gs_races:client:end', src, ('%s · %s%s%s'):format(Config.Circuits[lobby.circuit].label, fmt(ms),
        lobby.solo and '' or (' · ' .. position .. 'e'), prize > 0 and (' · +' .. prize .. ' $') or ''), true)
    if record then Bridge:Notify(src, 'Record personnel !', 'success') end
    if not lobby.solo and position == 1 and started('gs_social') then
        exports.gs_social:Newsroom('race', ('SPORTS MÉCANIQUES · %s remporte « %s » en %s. La police dénonce des rodéos urbains.'):format(name, Config.Circuits[lobby.circuit].label, fmt(ms)))
    end
    return true, nil, { ms = ms, position = position, prize = prize }
end)

lib.callback.register('gs_races:cancel', function(src)
    if not Security:RateLimit(src, 'gs_races:cancel', 3, 10000) then return false end
    local run = leave(src, true)
    return run ~= nil
end)

--- Circuits + meilleurs temps (menu de la ligne de départ).
lib.callback.register('gs_races:list', function(src)
    if not Security:RateLimit(src, 'gs_races:list', 6, 10000) then return nil end
    local out = {}
    for id, c in pairs(Config.Circuits) do
        local top = {}
        for i, r in ipairs(Store.top(id, 3)) do top[i] = { name = r.name, time = fmt(r.ms) } end
        local open
        for _, l in pairs(Races.lobbies) do if l.circuit == id and l.state == 'open' then open = { players = #l.players, pot = l.pot, left = math.max(0, l.startAt - os.time()) } end end
        out[#out + 1] = { id = id, label = c.label, top = top, open = open, points = #c.points }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return { circuits = out, entry = Races.entry() }
end)

--- Classements (Vibe) : { { id, label, top = { { name, time } } } } ; cache 60 s.
exports('GetTop', function(limit)
    if not Races.topCache or os.time() - Races.topAt > 60 then
        local out = {}
        for id, c in pairs(Config.Circuits) do
            local top = {}
            for i, r in ipairs(Store.top(id, limit or 3)) do top[i] = { name = r.name, time = fmt(r.ms) } end
            out[#out + 1] = { id = id, label = c.label, top = top }
        end
        table.sort(out, function(a, b) return a.label < b.label end)
        Races.topCache, Races.topAt = out, os.time()
    end
    return Races.topCache
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) leave(src, true) end)
AddEventHandler('playerDropped', function() leave(source, true) end)

CreateThread(function()
    Store.init()
    while true do
        Wait(1000)
        Races.tick()
    end
end)
