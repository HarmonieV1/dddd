-- gs_city (serveur) · V12.63 « Le quartier adopte quelqu'un » (proposition n° 148). Points d'activité légale par quartier
-- (KVP par personnage, survivent aux redémarrages), titre « figure du coin », salut au retour, remise dans les commerces du
-- quartier (gs_economy, export FigureDiscount). Rien de privé n'est publié.
local Bridge = exports.gs_bridge
local FG = Config.Figure

Figure = { cache = {}, here = {}, greeted = {} } -- cache[cid] = { pts = { [quartier] = n }, at = semaine } ; here[src] = quartier actuel

local function week() return math.floor(os.time() / (7 * 86400)) end
local function kvp(cid) return 'figure:' .. tostring(cid) end

function Figure.get(cid)
    if not cid then return nil end
    local f = Figure.cache[cid]
    if not f then
        local ok, d = pcall(json.decode, GetResourceKvpString(kvp(cid)) or '')
        f = (ok and type(d) == 'table' and type(d.pts) == 'table') and d or { pts = {}, at = week() }
        Figure.cache[cid] = f
    end
    local w = week()
    if (f.at or w) < w then -- semaines passées sans activité : les points baissent
        for id, n in pairs(f.pts) do f.pts[id] = math.floor(n * (1 - FG.decay) ^ (w - f.at)) end
        f.at = w
    end
    return f
end

--- Quartier dont ce personnage est la figure (le plus haut au-dessus du seuil), ou nil
function Figure.districtOf(cid)
    local f = Figure.get(cid)
    if not f then return nil end
    local best, bestN
    for id, n in pairs(f.pts) do if n >= FG.threshold and (not bestN or n > bestN) then best, bestN = id, n end end
    return best
end

local function label(id) for _, d in ipairs(Config.Districts) do if d.id == id then return d.label end end return id end

function Figure.add(src, activity)
    local gain = FG.points[activity]
    if not gain then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local d = City.district(GetEntityCoords(ped))
    local cid = Bridge:GetIdentifier(src)
    if not d or not cid then return end
    local f = Figure.get(cid)
    local before = (f.pts[d.id] or 0) >= FG.threshold
    f.pts[d.id] = (f.pts[d.id] or 0) + gain
    f.at = week()
    SetResourceKvp(kvp(cid), json.encode(f))
    if not before and f.pts[d.id] >= FG.threshold then
        Figure.greeted[src] = os.time()
        TriggerClientEvent('ox_lib:notify', src, { title = 'Figure du coin', icon = 'house-flag', type = 'success', duration = 12000,
            description = ('%s t\'a adopté : les habitants te saluent, et les commerces du quartier te font %d %% de remise.'):format(d.label, math.floor(FG.discount * 100)) })
    end
end

AddEventHandler('gs_quests:server:activity', function(src, activity) Figure.add(tonumber(src) or src, activity) end)

--- Remise de la figure du coin dans le quartier où se trouve le joueur (gs_economy) : 0 ou Config.Figure.discount
function Figure.discount(src)
    local cid = Bridge:GetIdentifier(src)
    local mine = cid and Figure.districtOf(cid)
    if not mine then return 0 end
    local ped = GetPlayerPed(src)
    local d = ped and ped ~= 0 and City.district(GetEntityCoords(ped))
    return (d and d.id == mine) and FG.discount or 0
end
exports('FigureDiscount', Figure.discount)
exports('FigureOf', function(src) local cid = Bridge:GetIdentifier(src) local id = cid and Figure.districtOf(cid) return id and label(id) or nil end)

--- Salut au retour dans son quartier (au plus une fois par greetMinutes)
function Figure.tick()
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local ped = GetPlayerPed(src)
        local d = ped and ped ~= 0 and City.district(GetEntityCoords(ped))
        local now = d and d.id or nil
        if now ~= Figure.here[src] then
            Figure.here[src] = now
            local cid = now and Bridge:GetIdentifier(src)
            if cid and Figure.districtOf(cid) == now and os.time() - (Figure.greeted[src] or 0) >= FG.greetMinutes * 60 then
                Figure.greeted[src] = os.time()
                TriggerClientEvent('ox_lib:notify', src, { title = d.label, icon = 'hand', type = 'inform', duration = 7000,
                    description = 'Les habitants te reconnaissent : « Te revoilà ! » Tu es une figure du coin.' })
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    local cid = Bridge:GetIdentifier(src)
    Figure.here[src], Figure.greeted[src] = nil, nil
    if cid then Figure.cache[cid] = nil end
end)

CreateThread(function()
    while true do
        Wait(FG.checkEvery)
        Figure.tick()
    end
end)
