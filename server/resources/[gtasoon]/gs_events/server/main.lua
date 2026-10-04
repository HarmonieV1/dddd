-- gs_events (serveur) : événement actif = événement staff en cours, sinon celui du calendrier. Autres ressources : exports
-- GetXpMultiplier() et GetBonus('wheel').
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Events = { manual = nil }

local function inRange(md, from, to)
    if from <= to then return md >= from and md <= to end
    return md >= from or md <= to -- à cheval sur le nouvel an
end

local function minutes(hhmm) local h, m = hhmm:match('^(%d+):(%d+)$') return tonumber(h) * 60 + tonumber(m) end

--- V9 · Rendez-vous fixe en cours pour t = { wday, hour, min } (os.date('*t'))
function Events.weekly(t)
    local now = t.hour * 60 + t.min
    for _, w in ipairs(Config.Weekly or {}) do
        if w.day == t.wday and now >= minutes(w.from) and now < minutes(w.to) then
            return { id = w.id, label = w.label, xp = w.xp or 1.0, wheel = w.wheel or 0, desc = w.desc, weekly = true }
        end
    end
end

--- V9 · Rendez-vous qui commence dans `ahead` minutes exactement (rappel)
function Events.upcoming(t, ahead)
    local now = t.hour * 60 + t.min
    for _, w in ipairs(Config.Weekly or {}) do
        if w.day == t.wday and minutes(w.from) - now == ahead then return w end
    end
end

--- Événement actif : { id, label, xp, wheel, desc, manual } ou nil. Priorité : staff > rendez-vous fixe > calendrier.
function Events.active(mmdd)
    if Events.manual then
        if os.time() < Events.manual.endsAt then return Events.manual end
        Events.manual = nil
    end
    if not mmdd then
        local w = Events.weekly(os.date('*t'))
        if w then return w end
    end
    mmdd = mmdd or os.date('%m-%d')
    for _, e in ipairs(Config.Calendar) do
        if inRange(mmdd, e.from, e.to) then return e end
    end
end

local function publish()
    local e = Events.active()
    GlobalState.gsEvent = e and { id = e.id, label = e.label, desc = e.desc, endsAt = e.endsAt } or nil
end

exports('Active', function() return Events.active() end)
exports('GetXpMultiplier', function() local e = Events.active() return e and e.xp or 1.0 end)
exports('GetBonus', function(name) local e = Events.active() return e and e[name] or 0 end)

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local e = Events.active()
    if e then Bridge:Notify(src, ('Événement : %s. %s'):format(e.label, e.desc), 'inform') end
end)

--- /gsevent start <id> <minutes> | stop | status
function Events.command(src, args)
    local action = args.action
    if action == 'start' then
        local def = Config.Manual[args.a or '']
        local minutes = math.floor(tonumber(args.b) or 0)
        if not def then return false, 'Événements : ' .. table.concat((function() local l = {} for id in pairs(Config.Manual) do l[#l + 1] = id end table.sort(l) return l end)(), ', ') end
        if minutes < 5 or minutes > Config.MaxManualMinutes then return false, ('Durée : 5 à %d minutes.'):format(Config.MaxManualMinutes) end
        Events.manual = { id = args.a, label = def.label, xp = def.xp, wheel = def.wheel, desc = def.desc, manual = true, endsAt = os.time() + minutes * 60 }
        publish()
        for _, s in ipairs(Bridge:GetPlayers()) do Bridge:Notify(s, ('ÉVÉNEMENT : %s pendant %d min ! %s'):format(def.label, minutes, def.desc), 'success') end
        Security:LogStaff(('[Événement] %s lancé par %s pour %d min'):format(def.label, src == 0 and 'console' or (GetPlayerName(src) or src), minutes))
        return true, 'Événement lancé.'
    elseif action == 'stop' then
        Events.manual = nil
        publish()
        return true, 'Événement staff arrêté.'
    end
    local e = Events.active()
    return true, e and ('Actif : %s (XP ×%.2f, +%d tour(s) de roue)%s'):format(e.label, e.xp, e.wheel, e.manual and ' [staff]' or '') or 'Aucun événement.'
end

RegisterCommand('gsevent', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ManageAce) then return end
    if not Security:RateLimit(src == 0 and 1 or src, 'gs_events:cmd', 5, 10000) then return end
    local ok, msg = Events.command(src, { action = args[1] or 'status', a = args[2], b = args[3] })
    if src == 0 then print(msg) else Bridge:Notify(src, msg, ok and 'success' or 'error') end
end, false)

local reminded = {}
function Events.remind(t)
    for _, ahead in ipairs({ Config.Remind, 0 }) do
        local w = Events.upcoming(t, ahead)
        local key = w and ('%s:%d:%d'):format(w.id, t.yday or 0, ahead)
        if w and not reminded[key] then
            reminded[key] = true
            local msg = ahead > 0 and ('Rendez-vous dans %d min : %s. %s'):format(ahead, w.label, w.desc) or ('C\'est parti : %s ! %s'):format(w.label, w.desc)
            for _, s in ipairs(Bridge:GetPlayers()) do Bridge:Notify(s, msg, 'success') end
            if GetResourceState('gs_discord') == 'started' then
                pcall(function() exports.gs_discord:Announce(ahead > 0 and ('⏰ %s à %s'):format(w.label, w.from) or ('🎉 %s'):format(w.label), w.desc) end)
            end
            return w, ahead
        end
    end
end

lib.callback.register('gs_events:weekly', function(src)
    if not Security:RateLimit(src, 'gs_events:weekly', 3, 5000) then return nil end
    local e = Events.active()
    return { active = e and e.label or nil }
end)

CreateThread(function()
    while true do
        publish()
        Events.remind(os.date('*t'))
        Wait(60000)
    end
end)
