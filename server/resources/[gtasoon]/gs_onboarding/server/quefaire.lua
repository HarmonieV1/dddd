-- gs_onboarding (serveur) · V10 « Que faire ? » : ce qui se passe MAINTENANT en ville, pour le menu du téléphone.
-- Seulement des infos publiques (jamais l'adresse du ring, jamais qui est où).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

local function started(r) return GetResourceState(r) == 'started' end
local function try(fn, default) local ok, v = pcall(fn) if ok and v ~= nil then return v end return default end

QueFaire = {}

--- Prochain rendez-vous fixe (aujourd'hui ou plus tard dans la semaine)
function QueFaire.nextWeekly(list, t)
    local now = t.hour * 60 + t.min
    local best, bestIn
    for _, w in ipairs(list or {}) do
        local h, m = w.from:match('^(%d+):(%d+)$')
        local start = tonumber(h) * 60 + tonumber(m)
        local days = (w.day - t.wday) % 7
        local inMin = days * 1440 + start - now
        if inMin < 0 then inMin = inMin + 7 * 1440 end
        if not bestIn or inMin < bestIn then best, bestIn = w, inMin end
    end
    return best and { label = best.label, desc = best.desc, when = bestIn < 1440 and best.day == t.wday and ('aujourd\'hui à ' .. best.from)
        or ('%s à %s'):format(best.dayName:lower(), best.from) } or nil
end

function QueFaire.live(src)
    local out = { services = {} }
    if started('gs_events') then
        local e = try(function() return exports.gs_events:Active() end)
        if e then out.event = { label = e.label, desc = e.desc } end
        out.next = QueFaire.nextWeekly(try(function() return exports.gs_events:Weekly() end, {}), os.date('*t'))
    end
    if started('gs_jobs') then
        for _, j in ipairs({ 'police', 'ambulance', 'mechanic', 'taxi' }) do
            out.services[j] = #try(function() return exports.gs_jobs:GetOnDutyPlayers(j) end, {})
        end
    end
    out.ring = started('gs_fightclub') and try(function() return exports.gs_fightclub:IsOpen() end, false) or false
    out.gang = started('gs_gangs') and try(function() return exports.gs_gangs:GetGang(src) end) or nil
    out.heat = started('gs_wanted') and try(function() return exports.gs_wanted:GetHeat(src) end, 0) or 0
    if started('gs_city') then out.hot = try(function() return exports.gs_city:HotDistricts() end, {}) end
    local cop = started('gs_jobs') and try(function() return exports.gs_jobs:IsOnDutyAs(src, 'police') end, false)
    if cop and started('gs_faitsdivers') then out.cases = try(function() return exports.gs_faitsdivers:OpenCount() end, 0) end -- police en service seulement
    local j = Bridge:GetJob(src)
    out.job = j and { name = j.name, label = j.label, onduty = j.onduty } or nil
    return out
end

lib.callback.register('gs_onboarding:quefaire', function(src)
    if not Security:RateLimit(src, 'gs_onboarding:quefaire', 6, 10000) then return nil end
    return QueFaire.live(src)
end)
