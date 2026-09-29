-- gs_reputation (serveur) : jauges en mémoire pour les joueurs connectés (écrites en base toutes les minutes si modifiées),
-- gains par activité et par like Vibe, effets exposés aux autres ressources (remise, bonus drogue, salutation).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Rep = { byCid = {}, dirty = {} }
local KINDS = { street = true, legal = true, media = true }

local function repOf(cid)
    if not Rep.byCid[cid] then Rep.byCid[cid] = Store.load(cid) end
    return Rep.byCid[cid]
end

function Rep.add(cid, kind, n)
    if not cid or not KINDS[kind] or type(n) ~= 'number' then return end
    local r = repOf(cid)
    r[kind] = math.max(0, math.min(Config.Max, r[kind] + math.floor(n)))
    Rep.dirty[cid] = true
end

function Rep.tier(value)
    local label = Config.Tiers[1].label
    for _, t in ipairs(Config.Tiers) do if value >= t.at then label = t.label end end
    return label
end

--- Valeur du barème (seuils → valeur) pour une jauge.
local function scale(tbl, value)
    local best = 0
    for at, v in pairs(tbl) do if value >= at and v > best then best = v end end
    return best
end

AddEventHandler('gs_quests:server:activity', function(src, activity)
    local g = Config.Gains[activity]
    if g then Rep.add(Bridge:GetIdentifier(src), g[1], g[2]) end
end)

AddEventHandler('gs_social:server:liked', function(authorCid, liked)
    Rep.add(authorCid, 'media', liked and Config.LikePoints or -Config.LikePoints)
end)

exports('Get', function(src) local cid = Bridge:GetIdentifier(src) return cid and repOf(cid) or nil end)
exports('Add', function(src, kind, n) Rep.add(Bridge:GetIdentifier(src), kind, n) end)
exports('GetDiscount', function(src) local cid = Bridge:GetIdentifier(src) return cid and scale(Config.LegalDiscount, repOf(cid).legal) or 0 end)
exports('GetStreetBonus', function(src) local cid = Bridge:GetIdentifier(src) return cid and scale(Config.StreetBonus, repOf(cid).street) or 0 end)
exports('ShouldGreet', function(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    local r = repOf(cid)
    return r.legal >= Config.GreetAt or r.media >= Config.GreetAt
end)

lib.callback.register('gs_reputation:get', function(src)
    if not Security:RateLimit(src, 'gs_reputation:get', 5, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local r = repOf(cid)
    local out = {}
    for _, k in ipairs({ 'street', 'legal', 'media' }) do out[k] = { value = r[k], tier = Rep.tier(r[k]) } end
    out.discount = scale(Config.LegalDiscount, r.legal)
    out.streetBonus = scale(Config.StreetBonus, r.street)
    return out
end)

function Rep.flush()
    for cid in pairs(Rep.dirty) do Store.save(cid, Rep.byCid[cid]) end
    Rep.dirty = {}
end

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    local cid = Bridge:GetIdentifier(src)
    if cid and Rep.dirty[cid] then Store.save(cid, Rep.byCid[cid]) Rep.dirty[cid] = nil end
    if cid then Rep.byCid[cid] = nil end
end)

CreateThread(function()
    Store.init()
    while true do
        Wait(Config.FlushSeconds * 1000)
        Rep.flush()
    end
end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Rep.flush() end end)
