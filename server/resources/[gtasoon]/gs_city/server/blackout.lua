-- gs_city (serveur) · V11.2 « Black-out de quartier ». État : GlobalState.gsBlackout = { [quartier] = fin (os.time) }.
-- Saboter : outil consommé, crime signalé (police), caméras du quartier aveuglées, tension en hausse, brève Weazel.
-- Réparer : n'importe qui sur place, payé par la mairie (jamais le saboteur). Retour automatique après Config.Blackout.minutes.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local B = Config.Blackout

Blackout = { active = {}, last = {}, by = {} } -- active[id] = fin ; last[id] = dernier sabotage ; by[id] = identifiant du saboteur

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function district(id) for _, d in ipairs(Config.Districts) do if d.id == id then return d end end end
local function publish()
    local out = {}
    for id, t in pairs(Blackout.active) do if t > now() then out[id] = t end end
    GlobalState.gsBlackout = out
end
local function news(id, key)
    local d = district(id)
    if d and started('gs_social') then pcall(function() exports.gs_social:Newsroom('blackout_' .. id, B.news[key]:format(d.label)) end) end
end

function Blackout.isOn(id) return (Blackout.active[id] or 0) > now() end

function Blackout.sabotage(src, id)
    local tr, d = B.transformers[id], district(id)
    if not tr or not d then return false, 'Transformateur inconnu.' end
    if not Security:InRange(src, tr.coords, B.range + 4.0) then return false, 'Trop loin.' end
    if Blackout.isOn(id) then return false, 'Le quartier est déjà dans le noir.' end
    if Blackout.last[id] and Blackout.last[id] + B.cooldown > now() then return false, 'Le transformateur a été renforcé après la dernière panne. Reviens plus tard.' end
    if not Bridge:RemoveItem(src, B.item, 1) then return false, 'Il te faut un outil (crochet).' end
    Blackout.active[id], Blackout.last[id], Blackout.by[id] = now() + B.minutes * 60, now(), Bridge:GetIdentifier(src)
    publish()
    if started('gs_cctv') then pcall(function() exports.gs_cctv:BlindArea(d.center.x, d.center.y, d.radius, B.minutes) end) end
    if started('gs_wanted') then pcall(function() exports.gs_wanted:ReportCrime(src, 'racket', tr.coords) end) end
    City.add(tr.coords, B.heat)
    news(id, 'cut')
    TriggerEvent('gs_city:server:blackout', id, true)
    Security:LogStaff(('[Black-out] %s par %s'):format(d.label, Bridge:GetName(src) or src), 'jobs')
    return true, ('Les lumières de %s s\'éteignent… Tu as %d minutes avant le retour du courant.'):format(d.label, B.minutes)
end

function Blackout.restore(id, src)
    if not Blackout.isOn(id) then return false end
    Blackout.active[id], Blackout.by[id] = nil, nil
    publish()
    news(id, 'back')
    TriggerEvent('gs_city:server:blackout', id, false)
    return true
end

function Blackout.repair(src, id)
    local tr, d = B.transformers[id], district(id)
    if not tr or not d then return false, 'Transformateur inconnu.' end
    if not Security:InRange(src, tr.coords, B.range + 4.0) then return false, 'Trop loin.' end
    if not Blackout.isOn(id) then return false, 'Le courant passe déjà.' end
    if Blackout.by[id] and Blackout.by[id] == Bridge:GetIdentifier(src) then return false, '« Réparer ce que tu as saboté ? La mairie ne paie pas ça. »' end
    Blackout.restore(id, src)
    local pay = math.random(B.pay[1], B.pay[2])
    Bridge:AddMoney(src, 'bank', pay)
    if started('gs_reputation') then pcall(function() exports.gs_reputation:Add(src, 'legal', 3) end) end
    return true, ('Courant rétabli à %s : +%d $ (mairie).'):format(d.label, pay)
end

lib.callback.register('gs_city:blackoutSabotage', function(src, id)
    if not Security:RateLimit(src, 'gs_city:blackoutSabotage', 2, 15000) then return false, 'Doucement.' end
    return Blackout.sabotage(src, tostring(id))
end)
lib.callback.register('gs_city:blackoutRepair', function(src, id)
    if not Security:RateLimit(src, 'gs_city:blackoutRepair', 2, 15000) then return false, 'Doucement.' end
    return Blackout.repair(src, tostring(id))
end)

CreateThread(function()
    publish()
    while true do
        Wait(30000)
        for id, t in pairs(Blackout.active) do if t <= now() then Blackout.restore(id) end end
    end
end)
