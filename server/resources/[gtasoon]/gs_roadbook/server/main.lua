-- gs_roadbook (serveur) : étapes dans l'ordre (position + vitesse crédible), photos sur place, arrivée : XP (bonus duo),
-- titres d'explorateur, classement. Le client affiche l'itinéraire et les anecdotes.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Roadbook = { runs = {}, recent = {} } -- runs[src] = { route, step, photos = {}, startedAt, lastAt, lastPos } ; recent = arrivées

--- Road trip du mois : carnet en vedette (rotation), clé du mois ('2026-09'), nom du mois.
function Roadbook.monthly()
    local t = os.date('*t')
    local rot = Config.Monthly.rotation
    return rot[((t.year * 12 + t.month) % #rot) + 1], ('%04d-%02d'):format(t.year, t.month), Config.MonthNames[t.month]
end

local function started(res) return GetResourceState(res) == 'started' end

local function display(src)
    local h = started('gs_social') and exports.gs_social:GetHandle(src)
    if h then return '@' .. h end
    local ci = Bridge:GetCharInfo(src) or {}
    return ('%s %s.'):format(ci.firstname or '?', (ci.lastname or '?'):sub(1, 1))
end

function Roadbook.titleFor(count)
    local best
    for _, t in ipairs(Config.Titles) do if count >= t.count then best = t.label end end
    return best
end

lib.callback.register('gs_roadbook:list', function(src)
    if not Security:RateLimit(src, 'gs_roadbook:list', 6, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local done, out = Store.done(cid), {}
    for id, r in pairs(Config.Routes) do
        out[#out + 1] = { id = id, label = r.label, desc = r.desc, xp = r.xp, steps = #r.steps, best = done[id] }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    local count = 0
    for _ in pairs(done) do count = count + 1 end
    local mid, month, monthName = Roadbook.monthly()
    local monthly = { id = mid, label = Config.Routes[mid].label, month = monthName, done = Store.monthDone(cid, month),
        xpMult = Config.Monthly.xpMult, money = Config.Monthly.money, top = {} }
    for i, r in ipairs(Store.monthTop(month, 5)) do monthly.top[i] = { name = r.name, minutes = r.seconds // 60, convoy = r.convoy } end
    return { routes = out, active = Roadbook.runs[src] and Roadbook.runs[src].route, title = Roadbook.titleFor(count), monthly = monthly }
end)

lib.callback.register('gs_roadbook:start', function(src, id)
    if not Security:RateLimit(src, 'gs_roadbook:start', 3, 10000) then return false, 'Doucement.' end
    local r = Config.Routes[id]
    if not r then return false, 'Carnet inconnu.' end
    if not Security:InRange(src, r.steps[1].coords, Config.Radius) then return false, 'Rends-toi au départ : ' .. r.steps[1].label .. '.' end
    Roadbook.runs[src] = { route = id, step = 1, photos = {}, startedAt = os.time(), lastAt = GetGameTimer(), lastPos = r.steps[1].coords }
    return true, 1
end)

lib.callback.register('gs_roadbook:step', function(src)
    if not Security:RateLimit(src, 'gs_roadbook:step', 4, 5000) then return false end
    local run = Roadbook.runs[src]
    if not run then return false end
    local r = Config.Routes[run.route]
    if os.time() - run.startedAt > Config.MaxHours * 3600 then Roadbook.runs[src] = nil return false, 'Carnet expiré : recommence-le.' end
    local nextStep = r.steps[run.step + 1]
    if not nextStep or not Security:InRange(src, nextStep.coords, Config.Radius) then return false end
    local elapsed = (GetGameTimer() - run.lastAt) / 1000
    if elapsed < #(nextStep.coords - run.lastPos) / Config.MaxSpeed then
        Roadbook.runs[src] = nil
        Security:LogStaff(('[Carnet] trajet impossible : %s sur %s'):format(GetPlayerName(src) or src, run.route))
        return false, 'Carnet annulé : trajet impossible.'
    end
    run.step, run.lastAt, run.lastPos = run.step + 1, GetGameTimer(), nextStep.coords
    if run.step < #r.steps then return true, run.step end
    return true, run.step, Roadbook.finish(src, run)
end)

lib.callback.register('gs_roadbook:photo', function(src, stepIndex)
    if not Security:RateLimit(src, 'gs_roadbook:photo', 4, 10000) then return false end
    local run = Roadbook.runs[src]
    stepIndex = tonumber(stepIndex)
    if not run or not stepIndex or stepIndex > run.step then return false, 'Atteins d\'abord cette étape.' end
    local s = Config.Routes[run.route].steps[stepIndex]
    if not s or not s.photo then return false, 'Pas de spot photo ici.' end
    if run.photos[stepIndex] then return false, 'Déjà photographié.' end
    if not Security:InRange(src, s.coords, Config.PhotoRadius + 3.0) then return false, 'Approche-toi du spot.' end
    run.photos[stepIndex] = true
    return true, 'Clic ! Souvenir ajouté au carnet.'
end)

--- Arrivée : XP (bonus si le partenaire de duo est là), titre, classement. Retourne le résumé pour le client.
function Roadbook.finish(src, run)
    Roadbook.runs[src] = nil
    local r = Config.Routes[run.route]
    local cid = Bridge:GetIdentifier(src)
    local before = 0
    for _ in pairs(Store.done(cid)) do before = before + 1 end
    local photos = 0
    for _ in pairs(run.photos) do photos = photos + 1 end
    local seconds = os.time() - run.startedAt
    Store.finish(cid, run.route, display(src), seconds, photos)
    local after = 0
    for _ in pairs(Store.done(cid)) do after = after + 1 end
    local mult, duo = 1.0, false
    if started('gs_duo') then
        local partner = exports.gs_duo:GetPartner(src)
        if partner and Security:PlayersInRange(src, partner, Config.DuoRadius) then mult, duo = Config.DuoBonus, true end
    end
    -- Road trip du mois : premier fini du mois = XP multipliée + prime ; convoi = équipiers arrivés juste avant, à côté
    local monthly
    local mid, month = Roadbook.monthly()
    local now = os.time()
    if run.route == mid and not Store.monthDone(cid, month) then
        local M, convoy = Config.Monthly, 0
        for _, f in ipairs(Roadbook.recent) do
            if f.src ~= src and f.route == run.route and now - f.at <= M.convoyWindow and Security:PlayersInRange(src, f.src, M.convoyRadius) then
                convoy = convoy + 1
            end
        end
        convoy = math.min(convoy, M.convoyMax)
        mult = mult * M.xpMult * (1 + convoy * M.convoyBonus)
        Store.monthFinish(cid, month, display(src), seconds, convoy)
        Bridge:AddMoney(src, 'bank', M.money, 'road trip du mois')
        monthly = { money = M.money, convoy = convoy }
    end
    table.insert(Roadbook.recent, 1, { src = src, route = run.route, at = now })
    Roadbook.recent[21] = nil
    local xp = math.floor(r.xp * mult * (1 + photos * 0.1))
    if started('gs_quests') then exports.gs_quests:AddXP(src, xp, 'carnet de route') end
    local newTitle = after > before and Roadbook.titleFor(after) ~= Roadbook.titleFor(before) and Roadbook.titleFor(after) or nil
    return { route = r.label, seconds = seconds, photos = photos, xp = xp, duo = duo, title = newTitle, monthly = monthly }
end

exports('GetExplorers', function(limit) return Store.explorers(limit or 5) end)

--- Départ du road trip du mois (événement staff) : point de départ et nom du carnet en vedette.
exports('MonthlyStart', function()
    local mid = Roadbook.monthly()
    local r = Config.Routes[mid]
    return r.steps[1].coords, r.label
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Roadbook.runs[src] = nil end)
CreateThread(function() Store.init() end)
