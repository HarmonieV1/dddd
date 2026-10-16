-- gs_city (serveur) · V12.63 « Voisins vigilants » (proposition n° 173). Un habitant (hors gang) rejoint les voisins
-- vigilants du quartier où il se trouve (/voisins). Chaque bénévole connecté : la tension du quartier retombe plus vite,
-- les témoins y appellent un peu plus volontiers la police (plafonnés), et il est prévenu (sans position) des délits
-- signalés dans son quartier. Adhésion en KVP par personnage (survit aux redémarrages).
local Bridge = exports.gs_bridge
local Security = exports.gs_security
local WC = Config.Watch

Watch = { cache = {}, count = {}, notified = {} } -- cache[cid] = { d = quartier, at = os.time() } ; count[quartier] = bénévoles connectés

local function kvp(cid) return 'watch:' .. tostring(cid) end
local function label(id) for _, d in ipairs(Config.Districts) do if d.id == id then return d.label end end return id end

function Watch.get(cid)
    if not cid then return nil end
    local w = Watch.cache[cid]
    if w == nil then
        local ok, d = pcall(json.decode, GetResourceKvpString(kvp(cid)) or '')
        w = (ok and type(d) == 'table' and type(d.d) == 'string' and d.d ~= '') and d or false -- d = '' : groupe quitté
        Watch.cache[cid] = w
    end
    return w or nil
end

--- Recompte les bénévoles connectés par quartier (appelé à chaque baisse de tension, une fois par minute)
function Watch.refresh()
    local count = {}
    for _, s in ipairs(GetPlayers()) do
        local w = Watch.get(Bridge:GetIdentifier(tonumber(s)))
        if w then count[w.d] = (count[w.d] or 0) + 1 end
    end
    Watch.count = count
end

local function members(id) return math.min(WC.maxMembers, Watch.count[id] or 0) end
--- Baisse de tension supplémentaire par minute dans ce quartier
function Watch.decayBonus(id) return members(id) * WC.decayPerMember end
--- Témoins plus prompts : multiplicateur (1.0 sans bénévole)
function Watch.reportFactor(id) return 1 + math.min(WC.maxReport, members(id) * WC.reportPerMember) end

local function inGang(src)
    if GetResourceState('gs_gangs') ~= 'started' then return false end
    local ok, g = pcall(function() return exports.gs_gangs:GetGang(src) end)
    return ok and g ~= nil
end

lib.callback.register('gs_city:watchInfo', function(src)
    if not Security:RateLimit(src, 'gs_city:watch', 6, 10000) then return nil end
    local ped = GetPlayerPed(src)
    local d = ped and ped ~= 0 and City.district(GetEntityCoords(ped))
    local w = Watch.get(Bridge:GetIdentifier(src))
    return { here = d and d.label or nil, hereId = d and d.id or nil, mine = w and label(w.d) or nil,
        count = d and (Watch.count[d.id] or 0) or 0, gang = inGang(src) }
end)

lib.callback.register('gs_city:watchJoin', function(src, join)
    if not Security:RateLimit(src, 'gs_city:watch', 6, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false, 'Personnage introuvable.' end
    local w = Watch.get(cid)
    if not join then
        if not w then return false, 'Tu ne fais partie d\'aucun groupe de voisins vigilants.' end
        SetResourceKvp(kvp(cid), json.encode({ d = '', at = w.at }))
        Watch.cache[cid] = false
        Watch.refresh()
        return true, ('Tu as quitté les voisins vigilants de %s.'):format(label(w.d))
    end
    if inGang(src) then return false, 'Les voisins vigilants ne recrutent pas les membres de gang.' end
    local ped = GetPlayerPed(src)
    local d = ped and ped ~= 0 and City.district(GetEntityCoords(ped))
    if not d then return false, 'Rends-toi dans un quartier de Los Santos pour rejoindre ses voisins vigilants.' end
    if w and w.d == d.id then return false, 'Tu fais déjà partie des voisins vigilants de ce quartier.' end
    local ok, prev = pcall(json.decode, GetResourceKvpString(kvp(cid)) or '')
    local last = ok and type(prev) == 'table' and tonumber(prev.at) or nil
    if last and os.time() - last < WC.changeHours * 3600 then -- première adhésion : libre
        return false, ('Tu as changé de groupe récemment : réessaie dans %d h.'):format(math.ceil((WC.changeHours * 3600 - (os.time() - last)) / 3600))
    end
    local nw = { d = d.id, at = os.time() }
    SetResourceKvp(kvp(cid), json.encode(nw))
    Watch.cache[cid] = nw
    Watch.refresh()
    return true, ('Bienvenue chez les voisins vigilants de %s : tu seras prévenu des délits signalés dans le quartier.'):format(d.label)
end)

local function crimeLabel(t)
    local ok, l = pcall(function() return exports.gs_wanted:CrimeLabel(t) end)
    return ok and type(l) == 'string' and l:lower() or 'incident'
end

-- Délit signalé : les bénévoles du quartier sont prévenus (sans position précise, au plus une fois par notifySeconds)
AddEventHandler('gs_wanted:server:reported', function(suspect, crimeType, _, coords)
    if not coords then return end
    local d = City.district(coords)
    if not d or (Watch.count[d.id] or 0) == 0 then return end
    local now = os.time()
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if src ~= tonumber(suspect) and now - (Watch.notified[src] or 0) >= WC.notifySeconds then
            local w = Watch.get(Bridge:GetIdentifier(src))
            if w and w.d == d.id then
                Watch.notified[src] = now
                TriggerClientEvent('ox_lib:notify', src, { title = 'Voisins vigilants · ' .. d.label, icon = 'eye', type = 'inform', duration = 8000,
                    description = ('Délit signalé dans le quartier (%s). La police est prévenue.'):format(crimeLabel(crimeType)) })
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cid = Bridge:GetIdentifier(src)
    Watch.notified[src] = nil
    if cid then Watch.cache[cid] = nil end
end)
