-- gs_stats (serveur) · V9 « Statistiques de rétention » (staff) : sessions par licence (pas par personnage), première
-- venue, retour J+1 et dans les 7 jours, abandon à la première session, durée moyenne, pic de joueurs du jour.
local Bridge = exports.gs_bridge

Retention = { open = {}, peak = 0, peakDay = nil } -- open[src] = { license, at }

local function now() return os.time() end
local function day(ts) return (ts + Config.TzOffset) // 86400 end

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
end

function Retention.start(src)
    local lic = license(src)
    if not lic or Retention.open[src] then return end
    Retention.open[src] = { license = lic, at = now() }
    Store.firstSeen(lic, now())
    local n, d = #GetPlayers(), day(now())
    if Retention.peakDay ~= d then Retention.peakDay, Retention.peak = d, 0 end
    if n > Retention.peak then Retention.peak = n SetResourceKvpInt('peak:' .. d, n) end
end

function Retention.stop(src)
    local o = Retention.open[src]
    Retention.open[src] = nil
    if o and now() - o.at >= 30 then Store.session(o.license, o.at, now()) end
end

function Retention.firstOf(src)
    local lic = license(src)
    return lic and Store.firstOf(lic) or nil
end

--- Calcul pur (testable) : firsts = { { license, first_at } }, sessions = { { license, start_at, end_at } }
function Retention.compute(firsts, sessions, t)
    t = t or now()
    local today = day(t)
    local byLic = {}
    for _, s in ipairs(sessions) do
        byLic[s.license] = byLic[s.license] or {}
        table.insert(byLic[s.license], s)
    end
    local out = { new7 = 0, d1 = { back = 0, of = 0 }, d7 = { back = 0, of = 0 }, drop = { short = 0, of = 0 }, daily = {} }
    for _, f in ipairs(firsts) do
        local fd = day(f.first_at)
        if today - fd < 7 then out.new7 = out.new7 + 1 end
        local list = byLic[f.license] or {}
        -- première session
        local first
        for _, s in ipairs(list) do if not first or s.start_at < first.start_at then first = s end end
        if first then
            out.drop.of = out.drop.of + 1
            if first.end_at - first.start_at < Config.ShortSession * 60 then out.drop.short = out.drop.short + 1 end
        end
        local back1, back7 = false, false
        for _, s in ipairs(list) do
            local sd = day(s.start_at)
            if sd == fd + 1 then back1 = true end
            if sd > fd and sd <= fd + 7 then back7 = true end
        end
        if today > fd + 1 then out.d1.of = out.d1.of + 1 if back1 then out.d1.back = out.d1.back + 1 end end
        if today > fd + 7 then out.d7.of = out.d7.of + 1 if back7 then out.d7.back = out.d7.back + 1 end end
    end
    -- 7 derniers jours : joueurs uniques, nouveaux, durée moyenne
    local total, count = 0, 0
    for i = 6, 0, -1 do
        local d = today - i
        local uniq, n, newN = {}, 0, 0
        for _, s in ipairs(sessions) do
            if day(s.start_at) == d then
                if not uniq[s.license] then uniq[s.license] = true n = n + 1 end
                total, count = total + (s.end_at - s.start_at), count + 1
            end
        end
        for _, f in ipairs(firsts) do if day(f.first_at) == d then newN = newN + 1 end end
        out.daily[#out.daily + 1] = { label = os.date('%d/%m', d * 86400 - Config.TzOffset + 43200), players = n, new = newN,
            peak = GetResourceKvpInt('peak:' .. d) }
    end
    out.avg = count > 0 and math.floor(total / count / 60) or 0
    local function pct(x) return x.of > 0 and math.floor(x.back / x.of * 100 + 0.5) or nil end
    out.d1.pct, out.d7.pct = pct(out.d1), pct(out.d7)
    out.drop.pct = out.drop.of > 0 and math.floor(out.drop.short / out.drop.of * 100 + 0.5) or nil
    return out
end

function Retention.report()
    local firsts, sessions = Store.since(now() - 40 * 86400)
    return Retention.compute(firsts, sessions)
end

local function staff(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(tostring(src), 'command') then return true end
    local ok, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and (tonumber(lvl) or 0) >= Config.StaffLevel
end

lib.callback.register('gs_stats:retention', function(src)
    if not exports.gs_security:RateLimit(src, 'gs_stats:retention', 2, 10000) or not staff(src) then return nil end
    return Retention.report()
end)

RegisterCommand('gsstats', function(src)
    if src ~= 0 then return end
    local r = Retention.report()
    print(('[gs_stats] nouveaux 7 j : %d | retour J+1 : %s %% | retour sous 7 j : %s %% | abandon 1re session : %s %% | session moyenne : %d min')
        :format(r.new7, r.d1.pct or '-', r.d7.pct or '-', r.drop.pct or '-', r.avg))
    for _, d in ipairs(r.daily) do print(('  %s : %d joueurs, %d nouveaux, pic %d'):format(d.label, d.players, d.new, d.peak)) end
end, true)

-- Dès la connexion (avant la création de perso) : ceux qui partent pendant la création sont justement les abandons
AddEventHandler('playerJoining', function() Retention.start(source) end)
AddEventHandler('gs_bridge:server:playerLoaded', function(src) Retention.start(src) end) -- filet (ressource relancée en cours de partie)
AddEventHandler('playerDropped', function() Retention.stop(source) end)
